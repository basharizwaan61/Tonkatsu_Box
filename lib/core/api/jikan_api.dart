import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'api_error_detail.dart';

/// Jikan's REST root; every endpoint hangs off `/v4`.
const String _jikanBaseUrl = 'https://api.jikan.moe/v4';

const Duration _jikanTimeout = Duration(seconds: 10);

/// Typed Jikan error carrying a user-facing [message] and a redacted debug
/// [detail] (consumed by `extractApiError`).
class JikanApiException implements Exception {
  const JikanApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'JikanApiException: $message (status: $statusCode)';
}

/// One page of characters plus the flag a pager needs.
class JikanPagedResult<T> {
  const JikanPagedResult({
    required this.results,
    required this.page,
    required this.totalPages,
  });

  final List<T> results;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Jikan — the unofficial MyAnimeList API. Keyless, and the host answers 3
/// requests a second and 60 a minute, so the shared per-host queue paces it.
final Provider<JikanApi> jikanApiProvider = Provider<JikanApi>((Ref ref) {
  return JikanApi(
    createApiDio(
      baseUrl: _jikanBaseUrl,
      connectTimeout: _jikanTimeout,
      receiveTimeout: _jikanTimeout,
    ),
  );
});

/// Jikan client. Search rows carry no biography and a shorter work list than
/// `/full`, so [getCharacter] is what fills in a character properly.
class JikanApi {
  const JikanApi(this._dio);

  final Dio _dio;

  /// Page of characters matching [query]. [page] is 1-based.
  Future<JikanPagedResult<Character>> searchCharacters({
    required String query,
    int page = 1,
    int limit = 25,
    String orderBy = 'favorites',
    String sort = 'desc',
  }) async {
    final Response<dynamic> res = await _get(
      '/characters',
      <String, dynamic>{
        'q': query,
        'page': page,
        'limit': limit,
        'order_by': orderBy,
        'sort': sort,
      },
    );
    final Map<String, dynamic> body = _body(res, 'Jikan search failed');
    final Map<String, dynamic> pagination =
        body['pagination'] is Map<String, dynamic>
            ? body['pagination'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final int totalPages =
        (pagination['last_visible_page'] as num?)?.toInt() ?? page;
    return JikanPagedResult<Character>(
      results: _charactersFrom(body['data']),
      page: page,
      totalPages: totalPages,
    );
  }

  /// Full record for one character, biography included. Null when not found.
  Future<Character?> getCharacter(int id) async {
    try {
      final Response<dynamic> res = await _get('/characters/$id/full');
      final Map<String, dynamic> body = _body(res, 'Jikan character failed');
      return _characterFrom(body);
    } on JikanApiException catch (e) {
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
      throw JikanApiException(message, statusCode: res.statusCode);
    }
    return body;
  }

  List<Character> _charactersFrom(Object? data) {
    if (data is! List<dynamic>) return const <Character>[];
    final List<Character> characters = <Character>[];
    for (final Object? item in data) {
      if (item is! Map<String, dynamic>) continue;
      final Character? character = _characterFrom(item);
      if (character != null) characters.add(character);
    }
    return characters;
  }

  /// The first anime entry is the main series, so it doubles as franchise and
  /// first appearance.
  Character? _characterFrom(Map<String, dynamic> json) {
    final int? id = (json['mal_id'] as num?)?.toInt();
    if (id == null) return null;
    final String? name = _text(json['name']);
    if (name == null) return null;
    final List<Map<String, dynamic>> anime = _works(json['anime']);
    final List<Map<String, dynamic>> manga = _works(json['manga']);
    final Map<String, String> appearsIn = <String, String>{};
    for (final Map<String, dynamic> work in <Map<String, dynamic>>[
      ...anime,
      ...manga,
    ]) {
      final String? title = _text(work['title']);
      if (title == null) continue;
      appearsIn[title] = _text(work['mal_url']) ?? _text(work['url']) ?? '';
    }
    final String? firstWork =
        anime.isEmpty ? null : _text(anime.first['title']);
    final String externalUrl =
        _text(json['url']) ?? 'https://myanimelist.net/character/$id';
    return Character(
      id: id,
      source: DataSource.jikan,
      name: name,
      nameNative: _text(json['name_kanji']),
      description: _text(json['about']),
      imageUrl: _imageUrl(json),
      aliases: _nicknames(json['nicknames']),
      franchise: firstWork,
      firstAppearance: firstWork,
      appearsIn: appearsIn.isEmpty ? null : appearsIn,
      externalUrl: externalUrl,
      popularity: (json['favorites'] as num?)?.toInt(),
      updatedAt: _now(),
    );
  }

  String? _imageUrl(Map<String, dynamic> json) {
    final Object? images = json['images'];
    if (images is! Map<String, dynamic>) return null;
    final Object? jpg = images['jpg'];
    if (jpg is! Map<String, dynamic>) return null;
    return _text(jpg['image_url']);
  }

  List<String>? _nicknames(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> names = <String>[];
    for (final Object? nickname in value) {
      final String? name = _text(nickname);
      if (name != null) names.add(name);
    }
    return names.isEmpty ? null : names;
  }

  List<Map<String, dynamic>> _works(Object? value) {
    if (value is! List<dynamic>) return const <Map<String, dynamic>>[];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  JikanApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 404) {
      message = 'Character not found';
    } else if (statusCode == 429) {
      message = 'Jikan rate limit exceeded (3/second, 60/minute)';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'Jikan request failed';
    }
    return JikanApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.jikan.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
