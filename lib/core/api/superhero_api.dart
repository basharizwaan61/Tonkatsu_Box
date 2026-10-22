import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_key_initializer.dart';
import 'api_dio.dart';
import 'api_error_detail.dart';

/// SuperHero API root; the user's token is a path segment, not a header.
const String _superHeroBaseUrl = 'https://superheroapi.com';

const Duration _superHeroTimeout = Duration(seconds: 10);

/// Typed SuperHero API error carrying a user-facing [message] and a redacted
/// debug [detail] (consumed by `extractApiError`).
class SuperHeroApiException implements Exception {
  const SuperHeroApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'SuperHeroApiException: $message (status: $statusCode)';
}

/// One page of characters plus the flag a pager needs.
class SuperHeroPagedResult<T> {
  const SuperHeroPagedResult({
    required this.results,
    required this.page,
    required this.totalPages,
  });

  final List<T> results;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Wires [SuperHeroApi] with the user's API token. There is no built-in token,
/// so requests throw [SuperHeroApiException] until one is entered in
/// Credentials.
final Provider<SuperHeroApi> superHeroApiProvider =
    Provider<SuperHeroApi>((Ref ref) {
  final SuperHeroApi api = SuperHeroApi();
  final ApiKeys keys = ref.read(apiKeysProvider);
  final String? token = keys.superHeroApiToken;
  if (token != null && token.isNotEmpty) {
    api.setToken(token);
  }
  return api;
});

/// SuperHero API client — DC and Marvel heroes and heroines. The free user
/// token is a path segment, so every request carries it in the URL.
class SuperHeroApi {
  SuperHeroApi({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: _superHeroBaseUrl,
              connectTimeout: _superHeroTimeout,
              receiveTimeout: _superHeroTimeout,
            );

  final Dio _dio;
  String? _token;

  void setToken(String token) => _token = token;

  void clearToken() => _token = null;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Characters whose name matches [query]. The API answers every match in
  /// one response, so the list is capped at [limit] and there is one page.
  Future<SuperHeroPagedResult<Character>> searchCharacters({
    required String query,
    int page = 1,
    int limit = 25,
  }) async {
    final String token = _requireToken();
    final String encodedQuery = Uri.encodeComponent(query.trim());
    final Response<dynamic> res =
        await _get('/api/$token/search/$encodedQuery');
    final Map<String, dynamic> body = _body(res, 'SuperHero search failed');
    final List<Character> characters = _charactersFrom(body['results']);
    return SuperHeroPagedResult<Character>(
      results: characters.length > limit
          ? characters.sublist(0, limit)
          : characters,
      page: page,
      totalPages: page,
    );
  }

  /// One character by its API id. Null when not found.
  Future<Character?> getCharacter(int id) async {
    final String token = _requireToken();
    try {
      final Response<dynamic> res = await _get('/api/$token/$id');
      final Map<String, dynamic> body =
          _body(res, 'SuperHero character failed');
      final List<Character> characters = _charactersFrom(body['results']);
      return characters.isEmpty ? null : characters.first;
    } on SuperHeroApiException catch (e) {
      if (e.statusCode == 404) return null;
      // A missing character answers with an error envelope, not with a 404.
      if (e.message.toLowerCase().contains('not found')) return null;
      rethrow;
    }
  }

  /// Lightweight token check for the Credentials "test" button.
  Future<bool> validateToken(String token) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>('/api/$token/1');
      final Object? body = res.data;
      if (res.statusCode != 200 || body is! Map<String, dynamic>) return false;
      return _text(body['response']) == 'success';
    } on DioException {
      return false;
    }
  }

  String _requireToken() {
    final String? token = _token;
    if (token == null || token.isEmpty) {
      throw const SuperHeroApiException('SuperHero API token not set');
    }
    return token;
  }

  Future<Response<dynamic>> _get(String path) async {
    try {
      return await _dio.get<dynamic>(path);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// A bad token answers HTTP 200 with an error envelope, so the `response`
  /// field decides — not the status code.
  Map<String, dynamic> _body(Response<dynamic> res, String message) {
    final Object? body = res.data;
    if (res.statusCode != 200 || body is! Map<String, dynamic>) {
      throw SuperHeroApiException(message, statusCode: res.statusCode);
    }
    if (_text(body['response']) != 'success') {
      throw SuperHeroApiException(
        _text(body['error']) ?? message,
        statusCode: res.statusCode,
      );
    }
    return body;
  }

  /// The search answers a list, the single-character endpoint a bare object.
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
    final int? id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    final String? name = _text(json['name']);
    if (name == null) return null;
    final String? publisher = _text(json['publisher']);
    return Character(
      id: id,
      source: DataSource.superHero,
      name: name,
      description: _text(json['description']),
      imageUrl: _text(json['image']),
      aliases: _aliases(json['aliases']),
      // The publisher names the universe, so it doubles as the franchise.
      franchise: publisher,
      firstAppearance: _text(json['first_appearance']),
      species: _text(json['race']),
      gender: _text(json['appearance']),
      affiliation: _text(json['group']),
      abilities: _abilities(json['abilities']),
      publisher: publisher,
      // The API has no public page per character, so the record points at the
      // API URL it came from — the user's token rides along in that path.
      externalUrl: '$_superHeroBaseUrl/api/${_token ?? ''}/$id',
      updatedAt: _now(),
    );
  }

  List<String>? _aliases(Object? value) {
    final List<String> aliases = _strings(value);
    return aliases.isEmpty ? null : aliases;
  }

  /// The powers come as a list; the model keeps them as one readable line.
  String? _abilities(Object? value) {
    final List<String> abilities = _strings(value);
    return abilities.isEmpty ? null : abilities.join(', ');
  }

  List<String> _strings(Object? value) {
    if (value is! List<dynamic>) return const <String>[];
    final List<String> texts = <String>[];
    for (final Object? item in value) {
      final String? text = _text(item);
      if (text != null) texts.add(text);
    }
    return texts;
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  SuperHeroApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 404) {
      message = 'Character not found';
    } else if (statusCode == 429) {
      message = 'SuperHero rate limit exceeded';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'SuperHero request failed';
    }
    return SuperHeroApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.superHero.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
