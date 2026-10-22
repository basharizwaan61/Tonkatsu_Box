import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'api_error_detail.dart';

/// Wikidata's MediaWiki API root.
const String _wikidataApiUrl = 'https://www.wikidata.org/w/api.php';

/// The English Wikipedia API — it carries the picture and the lead text.
const String _wikipediaApiUrl = 'https://en.wikipedia.org/w/api.php';

const Duration _wikidataTimeout = Duration(seconds: 15);

/// The languages a label is read in. Wikidata answers every language
/// otherwise, which bloats the batched reply.
const List<String> _entityLanguages = <String>[
  'en', 'ja', 'zh', 'ko', 'ru', 'ar', 'he', 'fa', 'hi', 'el', 'th', 'vi', 'uk',
  'de', 'fr', 'es', 'it', 'pt', 'nl', 'pl', 'sv', 'da', 'fi', 'cs', 'hu', 'ro',
  'bg', 'hr', 'sr', 'id', 'ms',
];

/// The gender values Wikidata states for a person.
const Map<String, String> _genders = <String, String>{
  'Q6581097': 'Male',
  'Q6581072': 'Female',
  'Q1052281': 'Non-binary',
};

/// Typed Wikidata error carrying a user-facing [message] and a redacted
/// debug [detail] (consumed by `extractApiError`).
class WikidataApiException implements Exception {
  const WikidataApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'WikidataApiException: $message (status: $statusCode)';
}

/// One search hit, before the entity details fill it in.
class _Hit {
  const _Hit({required this.id, required this.label, this.conceptUri});

  /// The entity id, e.g. `Q1740`.
  final String id;

  final String label;

  final String? conceptUri;
}

/// The Wikipedia answers of one search, both keyed by article title.
class _WikipediaPages {
  const _WikipediaPages(this.images, this.extracts);

  final Map<String, String> images;
  final Map<String, String> extracts;
}

/// Wikidata — the open entity database. Keyless, and Wikimedia asks every
/// client to name itself.
final Provider<WikidataApi> wikidataApiProvider = Provider<WikidataApi>((
  Ref ref,
) {
  return WikidataApi(
    createApiDio(
      connectTimeout: _wikidataTimeout,
      receiveTimeout: _wikidataTimeout,
      // MediaWiki asks every client to name itself.
      headers: const <String, String>{'User-Agent': kAppUserAgent},
    ),
  );
});

/// Wikidata client. A character is an entity: Wikidata carries the label,
/// the description and the gender, while the picture and the biography come
/// from the English Wikipedia article the entity links to.
class WikidataApi {
  const WikidataApi(this._dio);

  final Dio _dio;

  /// Characters whose label matches [query]. [limit] caps the hits.
  Future<List<Character>> searchCharacters({
    required String query,
    int limit = 25,
  }) async {
    final Map<String, dynamic> body = await _get(
      _wikidataApiUrl,
      <String, dynamic>{
        'action': 'wbsearchentities',
        'search': query,
        'language': 'en',
        'type': 'item',
        'limit': limit,
        'format': 'json',
      },
    );
    final Object? found = body['search'];
    if (found is! List<dynamic>) return const <Character>[];
    final List<_Hit> hits = <_Hit>[];
    for (final Object? item in found) {
      if (item is! Map<String, dynamic>) continue;
      final String? id = _text(item['id']);
      if (id == null || !id.startsWith('Q')) continue;
      final String? label = _text(item['label']);
      if (label == null) continue;
      hits.add(
        _Hit(id: id, label: label, conceptUri: _text(item['concepturi'])),
      );
    }
    if (hits.isEmpty) return const <Character>[];

    final Map<String, Map<String, dynamic>> entities = await _entities(
      hits.map((_Hit hit) => hit.id).toList(),
    );
    final Map<String, String> articles = <String, String>{};
    for (final _Hit hit in hits) {
      final String? title = _articleTitle(entities[hit.id]);
      if (title != null) articles[hit.id] = title;
    }
    final _WikipediaPages pages = await _wikipediaPages(
      articles.values.toList(),
    );

    final List<Character> characters = <Character>[];
    for (final _Hit hit in hits) {
      final String? article = articles[hit.id];
      final Character? character = _characterFrom(
        hit: hit,
        entity: entities[hit.id],
        article: article,
        imageUrl: article == null ? null : pages.images[article],
        extract: article == null ? null : pages.extracts[article],
      );
      if (character != null) characters.add(character);
    }
    return characters;
  }

  /// The entities behind [ids], in one batched request.
  Future<Map<String, Map<String, dynamic>>> _entities(List<String> ids) async {
    final Map<String, dynamic> body = await _get(
      _wikidataApiUrl,
      <String, dynamic>{
        'action': 'wbgetentities',
        // MediaWiki separates ids with a pipe.
        'ids': ids.join('|'),
        'props': 'labels|descriptions|claims|sitelinks',
        'languages': _entityLanguages.join('|'),
        'format': 'json',
      },
    );
    final Object? entities = body['entities'];
    if (entities is! Map<String, dynamic>) {
      return <String, Map<String, dynamic>>{};
    }
    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{};
    for (final Object? entity in entities.values) {
      if (entity is! Map<String, dynamic>) continue;
      final String? id = _text(entity['id']);
      if (id != null) byId[id] = entity;
    }
    return byId;
  }

  /// The picture and the lead paragraph of the given Wikipedia articles. One
  /// request each — Wikipedia takes a pipe-separated title list, so a search
  /// costs two calls and not one per character.
  Future<_WikipediaPages> _wikipediaPages(List<String> articles) async {
    if (articles.isEmpty) {
      return const _WikipediaPages(<String, String>{}, <String, String>{});
    }
    final String titles = articles.join('|');
    return _WikipediaPages(
      await _wikipediaImages(titles),
      await _wikipediaExtracts(titles),
    );
  }

  /// The picture of every article. Wikipedia leaves out the articles whose
  /// lead picture is not free, so an article may have none.
  Future<Map<String, String>> _wikipediaImages(String titles) async {
    try {
      final Map<String, dynamic> body = await _get(
        _wikipediaApiUrl,
        <String, dynamic>{
          'action': 'query',
          'prop': 'pageimages',
          'piprop': 'thumbnail',
          'pithumbsize': 400,
          'titles': titles,
          'format': 'json',
        },
      );
      return _pageValues(body, _thumbnail);
    } on WikidataApiException {
      // Wikipedia is a second host: when it is down the Wikidata data still
      // stands, without a picture.
      return const <String, String>{};
    }
  }

  /// The lead paragraph of every article.
  Future<Map<String, String>> _wikipediaExtracts(String titles) async {
    try {
      final Map<String, dynamic> body = await _get(
        _wikipediaApiUrl,
        <String, dynamic>{
          'action': 'query',
          'prop': 'extracts',
          'exintro': 1,
          'explaintext': 1,
          'titles': titles,
          'format': 'json',
        },
      );
      return _pageValues(body, _extract);
    } on WikidataApiException {
      // Wikipedia is a second host: when it is down the Wikidata data still
      // stands, without a lead paragraph.
      return const <String, String>{};
    }
  }

  /// The pages of a `query` answer, keyed by article title.
  Map<String, Map<String, dynamic>> _pages(Map<String, dynamic> body) {
    final Object? query = body['query'];
    if (query is! Map<String, dynamic>) {
      return <String, Map<String, dynamic>>{};
    }
    final Object? pages = query['pages'];
    if (pages is! Map<String, dynamic>) {
      return <String, Map<String, dynamic>>{};
    }
    final Map<String, Map<String, dynamic>> byTitle =
        <String, Map<String, dynamic>>{};
    for (final Object? page in pages.values) {
      if (page is! Map<String, dynamic>) continue;
      final String? title = _text(page['title']);
      if (title != null) byTitle[_title(title)] = page;
    }
    return byTitle;
  }

  /// One value per page, for the pages that have it.
  Map<String, String> _pageValues(
    Map<String, dynamic> body,
    String? Function(Map<String, dynamic> page) value,
  ) {
    final Map<String, Map<String, dynamic>> pages = _pages(body);
    final Map<String, String> values = <String, String>{};
    for (final MapEntry<String, Map<String, dynamic>> entry in pages.entries) {
      final String? text = value(entry.value);
      if (text != null) values[entry.key] = text;
    }
    return values;
  }

  String? _thumbnail(Map<String, dynamic> page) {
    final Object? thumbnail = page['thumbnail'];
    if (thumbnail is! Map<String, dynamic>) return null;
    return _text(thumbnail['source']);
  }

  String? _extract(Map<String, dynamic> page) => _text(page['extract']);

  /// The title of the English Wikipedia article of the entity.
  String? _articleTitle(Map<String, dynamic>? entity) {
    final Object? sitelinks = entity?['sitelinks'];
    if (sitelinks is! Map<String, dynamic>) return null;
    final Object? enwiki = sitelinks['enwiki'];
    if (enwiki is! Map<String, dynamic>) return null;
    final String? title = _text(enwiki['title']);
    if (title == null) return null;
    return _title(title);
  }

  Character? _characterFrom({
    required _Hit hit,
    required Map<String, dynamic>? entity,
    required String? article,
    required String? imageUrl,
    required String? extract,
  }) {
    // The numeric part of the Q-id is the id the app stores; the Q-id itself
    // stays in the link to the entity.
    final int? id = int.tryParse(hit.id.substring(1));
    if (id == null) return null;
    return Character(
      id: id,
      source: DataSource.wikidata,
      name: hit.label,
      nameNative: _nativeName(entity, hit.label),
      description: extract ?? _description(entity),
      imageUrl: imageUrl,
      gender: _gender(entity),
      externalUrl: article == null
          ? hit.conceptUri
          : 'https://en.wikipedia.org/wiki/${article.replaceAll(' ', '_')}',
      updatedAt: _now(),
    );
  }

  /// The Wikidata description in English.
  String? _description(Map<String, dynamic>? entity) {
    final Object? descriptions = entity?['descriptions'];
    if (descriptions is! Map<String, dynamic>) return null;
    return _languageText(descriptions['en']);
  }

  /// The label in another language. A label that only repeats the English
  /// name carries no native script, so it is skipped.
  String? _nativeName(Map<String, dynamic>? entity, String englishName) {
    final Object? labels = entity?['labels'];
    if (labels is! Map<String, dynamic>) return null;
    for (final MapEntry<String, dynamic> entry in labels.entries) {
      if (entry.key == 'en') continue;
      final String? value = _languageText(entry.value);
      if (value == null || value == englishName) continue;
      return value;
    }
    return null;
  }

  /// The gender the entity states, when it states one of the three.
  String? _gender(Map<String, dynamic>? entity) {
    final Object? claims = entity?['claims'];
    if (claims is! Map<String, dynamic>) return null;
    final Object? statements = claims['P21'];
    if (statements is! List<dynamic>) return null;
    for (final Object? statement in statements) {
      if (statement is! Map<String, dynamic>) continue;
      final Object? main = statement['mainsnak'];
      if (main is! Map<String, dynamic>) continue;
      final Object? data = main['datavalue'];
      if (data is! Map<String, dynamic>) continue;
      final Object? value = data['value'];
      if (value is! Map<String, dynamic>) continue;
      final String? id = _text(value['id']);
      if (id == null) continue;
      return _genders[id];
    }
    return null;
  }

  /// The value of a label or description object.
  String? _languageText(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return _text(value['value']);
  }

  /// MediaWiki answers a title with spaces, whatever it was asked with.
  String _title(String title) => title.replaceAll('_', ' ').trim();

  Future<Map<String, dynamic>> _get(
    String url,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        url,
        queryParameters: parameters,
      );
      final Object? body = res.data;
      if (res.statusCode != 200 || body is! Map<String, dynamic>) {
        throw WikidataApiException(
          'Wikidata request failed',
          statusCode: res.statusCode,
        );
      }
      // MediaWiki answers a bad parameter with 200 and an error object.
      final Object? error = body['error'];
      if (error is Map<String, dynamic>) {
        throw WikidataApiException(
          _text(error['info']) ?? 'Wikidata request failed',
        );
      }
      return body;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  WikidataApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 404) {
      message = 'Character not found';
    } else if (statusCode == 429) {
      message = 'Wikidata rate limit exceeded';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'Wikidata request failed';
    }
    return WikidataApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.wikidata.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
