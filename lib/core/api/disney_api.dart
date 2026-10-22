import 'package:core/models/character.dart';
import 'package:core/models/character_appearance.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'api_error_detail.dart';

/// The Disney API root.
const String _disneyBaseUrl = 'https://api.disneyapi.dev';

const Duration _disneyTimeout = Duration(seconds: 10);

/// Typed Disney API error carrying a user-facing [message] and a redacted
/// debug [detail] (consumed by `extractApiError`).
class DisneyApiException implements Exception {
  const DisneyApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'DisneyApiException: $message (status: $statusCode)';
}

/// One page of characters plus the flag a pager needs.
class DisneyPagedResult<T> {
  const DisneyPagedResult({
    required this.results,
    required this.page,
    required this.totalPages,
  });

  final List<T> results;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Disney API — an open catalog of Disney characters. Keyless.
final Provider<DisneyApi> disneyApiProvider = Provider<DisneyApi>((Ref ref) {
  return DisneyApi(
    createApiDio(
      baseUrl: _disneyBaseUrl,
      connectTimeout: _disneyTimeout,
      receiveTimeout: _disneyTimeout,
    ),
  );
});

/// Disney API client. The catalog has no biography for a character, so the
/// works it appears in stand in as the description.
class DisneyApi {
  const DisneyApi(this._dio);

  final Dio _dio;

  /// Page of characters whose name contains [query]. The API matches the name
  /// case-insensitively and as a substring. [page] is 1-based.
  Future<DisneyPagedResult<Character>> searchCharacters({
    required String query,
    int page = 1,
    int limit = 25,
  }) async {
    final Response<dynamic> res = await _get(
      '/character',
      <String, dynamic>{
        'name': query,
        'page': page,
        'pageSize': limit,
      },
    );
    final Map<String, dynamic> body = _body(res, 'Disney search failed');
    final Map<String, dynamic> info = body['info'] is Map<String, dynamic>
        ? body['info'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final int totalPages = (info['totalPages'] as num?)?.toInt() ?? page;
    return DisneyPagedResult<Character>(
      results: _charactersFrom(body['data']),
      page: page,
      totalPages: totalPages,
    );
  }

  /// One character by its API id. Null when not found.
  Future<Character?> getCharacter(int id) async {
    try {
      final Response<dynamic> res = await _get('/character/$id');
      final Map<String, dynamic> body = _body(res, 'Disney character failed');
      final Object? data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return _characterFrom(data);
    } on DisneyApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Response<dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      return await _dio.get<dynamic>(path, queryParameters: query);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _body(Response<dynamic> res, String message) {
    final Object? body = res.data;
    if (res.statusCode != 200 || body is! Map<String, dynamic>) {
      throw DisneyApiException(message, statusCode: res.statusCode);
    }
    return body;
  }

  /// A single match comes back as a bare object instead of a one-item list.
  List<Character> _charactersFrom(Object? data) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      items.addAll(data.whereType<Map<String, dynamic>>());
    } else if (data is Map<String, dynamic>) {
      items.add(data);
    }
    final List<Character> characters = <Character>[];
    for (final Map<String, dynamic> item in items) {
      final Character? character = _characterFrom(item);
      if (character != null) characters.add(character);
    }
    return characters;
  }

  Character? _characterFrom(Map<String, dynamic> json) {
    final int? id = (json['_id'] as num?)?.toInt();
    if (id == null) return null;
    final String? name = _text(json['name']);
    if (name == null) return null;
    final List<String> films = _titles(json['films']);
    final List<String> shortFilms = _titles(json['shortFilms']);
    final List<String> tvShows = _titles(json['tvShows']);
    final List<String> videoGames = _titles(json['videoGames']);
    // The catalog has no bio, so the works the character is in become one.
    final List<String> described = _dedupe(<String>[
      ...films,
      ...tvShows,
      ...videoGames,
      ...shortFilms,
    ]).take(5).toList();
    final Map<String, CharacterAppearance> appearsIn =
        <String, CharacterAppearance>{};
    for (final String title in _dedupe(<String>[
      ...films,
      ...shortFilms,
      ...tvShows,
      ...videoGames,
    ])) {
      appearsIn[title] = CharacterAppearance(title: title);
    }
    final List<String> allies = _titles(json['allies']);
    return Character(
      id: id,
      source: DataSource.disney,
      name: name,
      description: _describe(described),
      imageUrl: _text(json['imageUrl']),
      affiliation: allies.isEmpty ? null : allies.join(', '),
      franchise: 'Disney',
      firstAppearance: _firstOf(<List<String>>[
        films,
        shortFilms,
        tvShows,
        videoGames,
      ]),
      publisher: 'Disney',
      alignment: _text(json['alignment']),
      appearsIn: appearsIn.isEmpty ? null : appearsIn,
      // The payload's own `url` points at a plural endpoint that does not
      // answer, so the working one is built here.
      externalUrl: _text(json['sourceUrl']) ?? '$_disneyBaseUrl/character/$id',
      updatedAt: _now(),
    );
  }

  List<String> _titles(Object? value) {
    if (value is! List<dynamic>) return const <String>[];
    final List<String> titles = <String>[];
    for (final Object? title in value) {
      final String? name = _text(title);
      if (name != null) titles.add(name);
    }
    return titles;
  }

  List<String> _dedupe(List<String> titles) {
    final List<String> unique = <String>[];
    for (final String title in titles) {
      if (!unique.contains(title)) unique.add(title);
    }
    return unique;
  }

  String? _firstOf(List<List<String>> lists) {
    for (final List<String> titles in lists) {
      if (titles.isNotEmpty) return titles.first;
    }
    return null;
  }

  String? _describe(List<String> works) {
    if (works.isEmpty) return null;
    if (works.length == 1) return 'Appears in ${works.first}.';
    final String list =
        '${works.sublist(0, works.length - 1).join(', ')} and ${works.last}';
    return 'Appears in $list.';
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  DisneyApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 404) {
      message = 'Character not found';
    } else if (statusCode == 429) {
      message = 'Disney API rate limit exceeded';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'Disney request failed';
    }
    return DisneyApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.disney.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
