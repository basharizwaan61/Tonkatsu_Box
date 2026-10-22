import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/utils/stable_id.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_key_initializer.dart';
import 'api_dio.dart';
import 'api_error_detail.dart';

/// ThePornDB API root.
const String _pornDbBaseUrl = 'https://api.theporndb.com';

/// The public site, which holds the page of a performer.
const String _pornDbSiteUrl = 'https://www.theporndb.com';

const Duration _pornDbTimeout = Duration(seconds: 15);

/// Typed ThePornDB error carrying a user-facing [message] and a redacted
/// debug [detail] (consumed by `extractApiError`).
class PornDbApiException implements Exception {
  const PornDbApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'PornDbApiException: $message (status: $statusCode)';
}

/// One page of performers plus the flag a pager needs.
class PornDbPagedResult<T> {
  const PornDbPagedResult({
    required this.results,
    required this.page,
    required this.totalPages,
  });

  final List<T> results;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Wires [PornDbApi] with the user's API token; there is no built-in one, so
/// requests throw [PornDbApiException] until a token is entered in Settings.
final Provider<PornDbApi> pornDbApiProvider = Provider<PornDbApi>((Ref ref) {
  final PornDbApi api = PornDbApi(
    createApiDio(
      baseUrl: _pornDbBaseUrl,
      connectTimeout: _pornDbTimeout,
      receiveTimeout: _pornDbTimeout,
    ),
  );
  final ApiKeys keys = ref.read(apiKeysProvider);
  final String? token = keys.pornDbApiToken;
  if (token != null && token.isNotEmpty) {
    api.setToken(token);
  }
  return api;
});

/// ThePornDB client — the performer catalog. The free token travels in the
/// Authorization header, so every request carries it.
class PornDbApi {
  PornDbApi(this._dio);

  final Dio _dio;
  String? _token;

  /// Sets the token the next requests sign with.
  void setToken(String token) => _token = token;

  /// Drops the token; requests fail until one is set again.
  void clearToken() => _token = null;

  /// True when a token is configured.
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Performers whose name matches [query].
  Future<PornDbPagedResult<Character>> searchPerformers({
    required String query,
    int page = 1,
    int limit = 25,
  }) async {
    final String token = _requireToken();
    final Object? body = await _get(
      '/performers',
      <String, dynamic>{
        'parse': query.trim(),
        'page': page,
        'per_page': limit,
      },
      token,
    );
    final List<Character> performers = _charactersFrom(body);
    return PornDbPagedResult<Character>(
      results: performers.length > limit
          ? performers.sublist(0, limit)
          : performers,
      page: page,
      totalPages: _totalPages(body, page),
    );
  }

  /// One performer by its native id. Null when not found.
  Future<Character?> getPerformer(String nativeId) async {
    final String token = _requireToken();
    try {
      final Object? body = await _get(
        '/performers/${Uri.encodeComponent(nativeId)}',
        const <String, dynamic>{},
        token,
      );
      final List<Character> performers = _charactersFrom(body);
      return performers.isEmpty ? null : performers.first;
    } on PornDbApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Lightweight token check for the Credentials "test" button. A bad token
  /// is refused with 401, a good one answers the request.
  Future<bool> validateToken(String token) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/performers',
        queryParameters: const <String, dynamic>{'page': 1, 'per_page': 1},
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  /// The token is the only way in; without one the request cannot be signed.
  String _requireToken() {
    final String? token = _token;
    if (token == null || token.isEmpty) {
      throw const PornDbApiException(
        'ThePornDB API token is not set — add it in Settings',
      );
    }
    return token;
  }

  Future<Object?> _get(
    String path,
    Map<String, dynamic> query,
    String token,
  ) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final Object? body = res.data;
      if (res.statusCode != 200 || body == null) {
        throw PornDbApiException(
          'ThePornDB request failed',
          statusCode: res.statusCode,
        );
      }
      return body;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// The answer is an object with a `performers` array; a bare array and a
  /// single performer object are read too, so no shape throws.
  List<Map<String, dynamic>> _performerMaps(Object? body) {
    if (body is List<dynamic>) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    if (body is! Map<String, dynamic>) return const <Map<String, dynamic>>[];
    for (final String key in <String>['performers', 'data']) {
      final Object? value = body[key];
      if (value is List<dynamic>) {
        return value.whereType<Map<String, dynamic>>().toList();
      }
    }
    for (final String key in <String>['performer', 'data']) {
      final Object? value = body[key];
      if (value is Map<String, dynamic>) {
        return <Map<String, dynamic>>[value];
      }
    }
    // A single performer answers with its fields at the top level.
    return <Map<String, dynamic>>[body];
  }

  List<Character> _charactersFrom(Object? body) {
    final List<Character> characters = <Character>[];
    for (final Map<String, dynamic> item in _performerMaps(body)) {
      final Character? character = _characterFrom(item);
      if (character != null) characters.add(character);
    }
    return characters;
  }

  Character? _characterFrom(Map<String, dynamic> json) {
    final String? nativeId = _idText(json['id']);
    if (nativeId == null) return null;
    final String? name = _text(json['name']);
    if (name == null) return null;
    return Character(
      // The performer id is a string, so the numeric id is a stable hash of it.
      id: fnv1a53(nativeId),
      nativeId: nativeId,
      source: DataSource.pornDb,
      name: name,
      imageUrl: _imageUrl(json),
      aliases: _aliases(json['aliases']),
      gender: _text(json['gender']),
      affiliation: _affiliation(json['sites']),
      externalUrl: _externalUrl(json, nativeId),
      updatedAt: _now(),
    );
  }

  /// The full picture lives in `image`, the small one in `thumb`.
  String? _imageUrl(Map<String, dynamic> json) {
    final String? image = _nestedUrl(json['image']);
    if (image != null) return image;
    return _nestedUrl(json['thumb']);
  }

  String? _nestedUrl(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return _text(value['url']);
  }

  /// Aliases come as one comma-separated string; a list is read too.
  List<String>? _aliases(Object? value) {
    final List<String> aliases = <String>[];
    if (value is List<dynamic>) {
      for (final Object? item in value) {
        final String? alias = _text(item);
        if (alias != null) aliases.add(alias);
      }
    } else {
      final String? raw = _text(value);
      if (raw != null) {
        for (final String part in raw.split(',')) {
          final String? alias = _text(part);
          if (alias != null) aliases.add(alias);
        }
      }
    }
    return aliases.isEmpty ? null : aliases;
  }

  /// The studios a performer works for.
  String? _affiliation(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> names = <String>[];
    for (final Object? site in value) {
      if (site is! Map<String, dynamic>) continue;
      final String? name = _text(site['name']);
      if (name != null) names.add(name);
    }
    return names.isEmpty ? null : names.join(', ');
  }

  /// The API's own `url` field points at the API, not at the public page, so
  /// the canonical performer page is built instead.
  String _externalUrl(Map<String, dynamic> json, String nativeId) {
    final String? url = _text(json['url']);
    if (url != null &&
        url.startsWith('http') &&
        url.contains('theporndb.com')) {
      return url;
    }
    return '$_pornDbSiteUrl/performers/$nativeId';
  }

  /// The performer id is a string, but a numeric one must not lose the record.
  String? _idText(Object? value) {
    if (value is String) return _text(value);
    if (value is num) return value.toInt().toString();
    return null;
  }

  /// The pagination block is not guaranteed, so a missing one leaves the
  /// result on a single page.
  int _totalPages(Object? body, int page) {
    if (body is! Map<String, dynamic>) return page;
    final Object? meta = body['meta'];
    final Map<String, dynamic> block =
        meta is Map<String, dynamic> ? meta : body;
    for (final String key in <String>['last_page', 'total_pages']) {
      final int? value = (block[key] as num?)?.toInt();
      if (value != null && value > 0) return value;
    }
    return page;
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  PornDbApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 401 || statusCode == 403) {
      message = 'ThePornDB refused the API token';
    } else if (statusCode == 404) {
      message = 'Performer not found';
    } else if (statusCode == 429) {
      message = 'ThePornDB rate limit exceeded';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'ThePornDB request failed';
    }
    return PornDbApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.pornDb.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
