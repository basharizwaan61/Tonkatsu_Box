import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../tmdb/tmdb_types.dart';
import 'igdb_http_client.dart';
import 'igdb_types.dart';

/// Video-game characters. The search endpoint is the only way in: it answers
/// ids and a type, so the records come from `/characters`.
class IgdbCharactersApi {
  IgdbCharactersApi(this._client);

  final IgdbHttpClient _client;

  static const String _characterFields = '''
    fields akas,character_gender,character_species,description,games,mug_shot,name,slug,url;
  ''';

  /// The search endpoint answers every endpoint at once, so the hits are cut
  /// down to the characters among them.
  Future<TmdbPagedResult<Character>> searchCharacters({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    _client.ensureCredentials();

    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return TmdbPagedResult<Character>(
        results: const <Character>[],
        page: page,
        totalPages: page,
        totalResults: 0,
      );
    }

    try {
      final String escapedQuery = trimmed.replaceAll('"', '\\"');
      final int offset = (page - 1) * limit;
      final (List<int> ids, bool hasMore) =
          await _searchCharacterIds(escapedQuery, limit, offset);
      final List<Character> characters = await _charactersByIds(ids);
      return TmdbPagedResult<Character>(
        results: characters,
        page: page,
        totalPages: hasMore ? page + 1 : page,
        totalResults: characters.length,
      );
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search characters');
    }
  }

  /// Full character record. Null when not found.
  Future<Character?> getCharacter(int id) async {
    _client.ensureCredentials();

    try {
      final Response<dynamic> response = await _client.post(
        '/characters',
        data: '$_characterFields where id = $id;',
      );

      if (response.statusCode != 200 || response.data == null) {
        throw IgdbApiException(
          'Failed to fetch character',
          statusCode: response.statusCode,
        );
      }

      final List<dynamic> data = response.data as List<dynamic>;
      if (data.isEmpty) return null;

      return _characterFrom(data.first as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to fetch character');
    }
  }

  /// Search answers hits from several endpoints, each tagged with its type;
  /// only the characters are wanted.
  Future<(List<int>, bool)> _searchCharacterIds(
    String query,
    int limit,
    int offset,
  ) async {
    final StringBuffer body = StringBuffer('fields name;');
    body.write(' search "$query"; limit $limit;');
    if (offset > 0) {
      body.write(' offset $offset;');
    }

    final Response<dynamic> response = await _client.post(
      '/search',
      data: body.toString(),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw IgdbApiException(
        'Failed to search characters',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> data = response.data as List<dynamic>;
    final List<int> ids = <int>[];
    for (final dynamic item in data) {
      if (item is! Map<String, dynamic>) continue;
      if (item['type'] != 'Character') continue;
      final int? id = (item['id'] as num?)?.toInt();
      if (id != null) ids.add(id);
    }
    return (ids, data.length >= limit);
  }

  /// The records behind the search hits, in one batched request.
  Future<List<Character>> _charactersByIds(List<int> ids) async {
    if (ids.isEmpty) return const <Character>[];

    final Response<dynamic> response = await _client.post(
      '/characters',
      data: '$_characterFields where id = (${ids.join(",")}); '
          'limit ${ids.length};',
    );

    if (response.statusCode != 200 || response.data == null) {
      throw IgdbApiException(
        'Failed to fetch characters',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> data = response.data as List<dynamic>;
    final List<Character> characters = <Character>[];
    for (final dynamic item in data) {
      if (item is! Map<String, dynamic>) continue;
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
    return Character(
      id: id,
      source: DataSource.igdb,
      name: name,
      description: _text(json['description']),
      imageUrl: _mugShot(json['mug_shot']),
      aliases: _aliases(json['akas']),
      gender: _enumName(json['character_gender']),
      species: _enumName(json['character_species']),
      appearsIn: _appearsIn(json['games']),
      externalUrl: _text(json['url']),
      updatedAt: _now(),
    );
  }

  /// The mug shot url is protocol-relative, so it needs the scheme.
  String? _mugShot(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final String? url = _text(value['url']);
    if (url == null) return null;
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  /// `character_gender` and `character_species` are enum tables: an id and a
  /// name.
  String? _enumName(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return _text(value['name']);
  }

  List<String>? _aliases(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> aliases = <String>[];
    for (final Object? alias in value) {
      final String? aliasText = _text(alias);
      if (aliasText != null) aliases.add(aliasText);
    }
    return aliases.isEmpty ? null : aliases;
  }

  /// The games carry no url here, so the value is empty.
  Map<String, String>? _appearsIn(Object? value) {
    if (value is! List<dynamic>) return null;
    final Map<String, String> games = <String, String>{};
    for (final Object? item in value) {
      if (item is! Map<String, dynamic>) continue;
      final String? title = _text(item['name']);
      if (title != null) games[title] = '';
    }
    return games.isEmpty ? null : games;
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
