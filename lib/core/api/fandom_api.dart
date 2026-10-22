import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'api_error_detail.dart';

const Duration _fandomTimeout = Duration(seconds: 15);

/// Page source is markup, and the model stores a sentence a reader can show.
final RegExp _htmlComment = RegExp('<!--.*?-->', dotAll: true);

final RegExp _refTag = RegExp(
  r'<ref\b[^>]*?/>|<ref\b[^>]*?>.*?</ref>',
  dotAll: true,
  caseSensitive: false,
);

final RegExp _htmlTag = RegExp('</?[a-zA-Z][^>]*>');

/// `[[Target|Label]]` first, `[[Target]]` second — the label is what a reader
/// sees.
final RegExp _wikiLink = RegExp(
  r'\[\[[^\[\]|]*\|([^\[\]]*)\]\]|\[\[([^\[\]]*)\]\]',
);

final RegExp _templateCall = RegExp(r'\{\{.*?\}\}', dotAll: true);

/// Language links (`[[de:Spider-Man]]`) are navigation, not prose.
final RegExp _interwikiLink = RegExp(
  r'\[\[[a-zA-Z]{2,3}(?:-[a-zA-Z]{2,4})?:[^\]]*\]\]',
);

/// Category links are navigation too.
final RegExp _categoryLink = RegExp(
  r'\[\[Category:[^\]]*\]\]',
  caseSensitive: false,
);

final RegExp _heading = RegExp('^==', multiLine: true);

final RegExp _blankLine = RegExp(r'\n\s*\n');

final RegExp _whitespace = RegExp(r'\s+');

/// Typed Fandom error carrying a user-facing [message] and a redacted debug
/// [detail] (consumed by `extractApiError`).
class FandomApiException implements Exception {
  const FandomApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'FandomApiException: $message (status: $statusCode)';
}

/// A `{{...}}` call from a page source.
class _Template {
  const _Template(this.body);

  final String body;
}

/// Fandom — the MediaWiki API of one wiki. Keyless, and the wiki is a
/// parameter: Fandom has no cross-wiki character search.
final Provider<FandomApi> fandomApiProvider = Provider<FandomApi>((Ref ref) {
  return FandomApi(
    createApiDio(
      connectTimeout: _fandomTimeout,
      receiveTimeout: _fandomTimeout,
      // MediaWiki asks every client to name itself.
      headers: const <String, String>{'User-Agent': kAppUserAgent},
    ),
  );
});

/// Fandom client. A character is a wiki page, so a record is built from the
/// page title plus what the page's own infobox and lead paragraph say.
class FandomApi {
  const FandomApi(this._dio);

  final Dio _dio;

  /// Characters on [wiki] whose title matches [query]. Returns full records
  /// (description and image included).
  Future<List<Character>> searchCharacters({
    required String wiki,
    required String query,
    int limit = 25,
  }) async {
    final String slug = _slug(wiki);
    final Map<String, dynamic> body = await _query(slug, <String, dynamic>{
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': limit,
      'srnamespace': 0,
      'format': 'json',
    });
    final Object? hits = _queryBlock(body)['search'];
    if (hits is! List<dynamic>) return const <Character>[];
    final List<int> pageIds = <int>[];
    for (final Object? hit in hits) {
      if (hit is! Map<String, dynamic>) continue;
      final int? pageId = (hit['pageid'] as num?)?.toInt();
      if (pageId != null) pageIds.add(pageId);
    }
    if (pageIds.isEmpty) return const <Character>[];
    // One batched details request instead of one request per hit.
    final Map<int, Character> byId = await _charactersById(slug, pageIds);
    final List<Character> characters = <Character>[];
    for (final int pageId in pageIds) {
      final Character? character = byId[pageId];
      if (character != null) characters.add(character);
    }
    return characters;
  }

  /// One character by page id on [wiki].
  Future<Character?> getCharacter({
    required String wiki,
    required int pageId,
  }) async {
    final String slug = _slug(wiki);
    final Map<int, Character> byId = await _charactersById(slug, <int>[pageId]);
    return byId[pageId];
  }

  Future<Map<int, Character>> _charactersById(
    String wiki,
    List<int> pageIds,
  ) async {
    final Map<String, dynamic> body = await _query(wiki, <String, dynamic>{
      'action': 'query',
      'prop': 'revisions|pageimages',
      'rvprop': 'content',
      'rvslots': 'main',
      'piprop': 'thumbnail',
      'pithumbsize': 400,
      // MediaWiki separates page ids with a pipe; a comma is refused.
      'pageids': pageIds.join('|'),
      'format': 'json',
    });
    final Object? pages = _queryBlock(body)['pages'];
    if (pages is! Map<String, dynamic>) return const <int, Character>{};
    final Map<int, Character> characters = <int, Character>{};
    for (final Object? page in pages.values) {
      if (page is! Map<String, dynamic>) continue;
      final Character? character = _characterFrom(page, wiki);
      if (character != null) characters[character.id] = character;
    }
    return characters;
  }

  Future<Map<String, dynamic>> _query(
    String wiki,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        'https://$wiki.fandom.com/api.php',
        queryParameters: parameters,
      );
      final Object? body = res.data;
      if (res.statusCode != 200 || body is! Map<String, dynamic>) {
        throw FandomApiException(
          'Fandom request failed',
          statusCode: res.statusCode,
        );
      }
      // MediaWiki answers a bad parameter with 200 and an error object.
      final Object? error = body['error'];
      if (error is Map<String, dynamic>) {
        throw FandomApiException(
          _text(error['info']) ?? 'Fandom request failed',
        );
      }
      return body;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _queryBlock(Map<String, dynamic> body) {
    final Object? query = body['query'];
    if (query is! Map<String, dynamic>) return const <String, dynamic>{};
    return query;
  }

  Character? _characterFrom(Map<String, dynamic> page, String wiki) {
    final int? id = (page['pageid'] as num?)?.toInt();
    if (id == null) return null;
    final String title = _text(page['title']) ?? '';
    if (title.isEmpty) return null;
    // Comments carry braces of their own, so they go before the scan.
    final String wikitext = _wikitext(page).replaceAll(_htmlComment, ' ');
    final List<_Template> templates = _templates(wikitext);
    final String? name = _clean(_field(templates, 'name'));
    final String? description =
        _clean(_field(templates, 'description')) ?? _leadParagraph(wikitext);
    final String pageUrl =
        'https://$wiki.fandom.com/wiki/${title.replaceAll(' ', '_')}';
    return Character(
      id: id,
      source: DataSource.fandom,
      variant: wiki,
      name: name ?? title,
      description: description,
      imageUrl: _thumbnail(page),
      aliases: _aliases(templates),
      franchise: _wikiName(wiki),
      externalUrl: pageUrl,
      updatedAt: _now(),
    );
  }

  String _wikitext(Map<String, dynamic> page) {
    final Object? revisions = page['revisions'];
    if (revisions is! List<dynamic>) return '';
    for (final Object? revision in revisions) {
      if (revision is! Map<String, dynamic>) continue;
      final Object? slots = revision['slots'];
      if (slots is! Map<String, dynamic>) continue;
      final Object? main = slots['main'];
      if (main is! Map<String, dynamic>) continue;
      final String? text = _text(main['*']);
      if (text != null) return text;
    }
    return '';
  }

  String? _thumbnail(Map<String, dynamic> page) {
    final Object? thumbnail = page['thumbnail'];
    if (thumbnail is! Map<String, dynamic>) return null;
    return _text(thumbnail['source']);
  }

  List<String>? _aliases(List<_Template> templates) {
    final String? raw = _field(templates, 'currentalias');
    if (raw == null) return null;
    final List<String> aliases = <String>[];
    for (final String part in raw.split(',')) {
      final String? alias = _clean(part);
      if (alias != null) aliases.add(alias);
    }
    return aliases.isEmpty ? null : aliases;
  }

  /// The first template that carries the field. Fandom puts a disambiguation
  /// or a nav box ahead of the character infobox, so the first template of
  /// the page is not always the infobox.
  String? _field(List<_Template> templates, String field) {
    for (final _Template template in templates) {
      final String? value = _fieldIn(template.body, field);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// MediaWiki infobox fields are one per line: `| name = value`.
  String? _fieldIn(String body, String field) {
    for (final String line in body.split('\n')) {
      final String trimmed = line.trim();
      if (!trimmed.startsWith('|')) continue;
      final String rest = trimmed.substring(1).trim();
      final int equals = rest.indexOf('=');
      if (equals < 0) continue;
      if (rest.substring(0, equals).trim().toLowerCase() != field) continue;
      return rest.substring(equals + 1).trim();
    }
    return null;
  }

  /// The prose that follows the leading infobox, when it says something.
  String? _leadParagraph(String wikitext) {
    final int start = wikitext.indexOf('{{');
    final int end = start < 0 ? 0 : _templateEnd(wikitext, start);
    if (end < 0) return null;
    final String region = _upToHeading(wikitext.substring(end));
    final String prose = _removeTemplates(region);
    final String paragraph = _firstParagraph(
      prose.replaceAll(_interwikiLink, ' ').replaceAll(_categoryLink, ' '),
    );
    return _clean(paragraph);
  }

  List<_Template> _templates(String wikitext) {
    final List<_Template> templates = <_Template>[];
    int index = 0;
    while (index < wikitext.length) {
      final int start = wikitext.indexOf('{{', index);
      if (start < 0) break;
      final int end = _templateEnd(wikitext, start);
      if (end < 0) break;
      templates.add(_Template(wikitext.substring(start + 2, end - 2)));
      index = end;
    }
    return templates;
  }

  /// Index just past the `}}` that closes the `{{` at [start], or -1 when the
  /// page never closes it. Braces are counted so a nested template does not
  /// end its parent.
  int _templateEnd(String text, int start) {
    int depth = 0;
    int index = start;
    while (index < text.length) {
      if (text.startsWith('{{', index)) {
        depth++;
        index += 2;
      } else if (text.startsWith('}}', index)) {
        depth--;
        index += 2;
        if (depth == 0) return index;
      } else {
        index++;
      }
    }
    return -1;
  }

  String _removeTemplates(String text) {
    final StringBuffer buffer = StringBuffer();
    int index = 0;
    while (index < text.length) {
      final int start = text.indexOf('{{', index);
      if (start < 0) {
        buffer.write(text.substring(index));
        break;
      }
      buffer.write(text.substring(index, start));
      final int end = _templateEnd(text, start);
      if (end < 0) {
        buffer.write(text.substring(start));
        break;
      }
      index = end;
    }
    return buffer.toString();
  }

  String _upToHeading(String text) {
    final Match? match = _heading.firstMatch(text);
    return match == null ? text : text.substring(0, match.start);
  }

  String _firstParagraph(String text) {
    for (final String chunk in text.split(_blankLine)) {
      if (chunk.trim().isNotEmpty) return chunk;
    }
    return '';
  }

  /// A readable name for the wiki: `dragon-ball` reads as `Dragon Ball`.
  String _wikiName(String wiki) {
    return wiki
        .split('-')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _slug(String wiki) => wiki.trim().toLowerCase();

  /// Wikitext to plain text.
  String? _clean(String? text) {
    if (text == null) return null;
    String clean = text;
    clean = clean.replaceAll(_htmlComment, ' ');
    clean = clean.replaceAll(_refTag, ' ');
    clean = clean.replaceAll(_htmlTag, ' ');
    clean = clean.replaceAllMapped(
      _wikiLink,
      (Match m) => m.group(1) ?? m.group(2) ?? '',
    );
    clean = clean.replaceAll("'''", '').replaceAll("''", '');
    clean = clean.replaceAll(_templateCall, ' ');
    clean = clean.replaceAll('&nbsp;', ' ');
    clean = clean
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    final String collapsed = clean.replaceAll(_whitespace, ' ').trim();
    return collapsed.isEmpty ? null : collapsed;
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  FandomApiException _mapDioError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    final String message;
    if (statusCode == 404) {
      message = 'Wiki page not found';
    } else if (statusCode == 429) {
      message = 'Fandom rate limit exceeded';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else {
      message = 'Fandom request failed';
    }
    return FandomApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.fandom.label,
        exception: e,
        userMessage: message,
      ),
    );
  }
}
