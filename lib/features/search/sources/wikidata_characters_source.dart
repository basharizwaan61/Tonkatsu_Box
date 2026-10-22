import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/wikidata_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

const int _characterPageSize = 25;

/// SearchSource backed by Wikidata — the open entity database.
class WikidataCharactersSource extends SearchSource {
  @override
  String get id => 'wikidata_characters';

  @override
  MediaType get outputMediaType => MediaType.character;

  @override
  DataSource get dataSource => DataSource.wikidata;

  @override
  String label(S l) => l.mediaTypeCharacter;

  @override
  IconData get icon => Icons.hub_outlined;

  // No brand PNG for Wikidata — the Material icon stands in.
  @override
  String? get iconAsset => null;

  // Wikidata answers queries only, there is no popular-characters listing.
  @override
  bool get supportsBrowse => false;

  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'name_asc', apiValue: 'name'),
      ];

  @override
  String searchHint(S l) => l.searchHintCharacters;

  @override
  Future<BrowseResult> fetch(
    Ref ref, {
    String? query,
    required Map<String, Object?> filterValues,
    required String sortBy,
    required int page,
  }) async {
    final String? trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const BrowseResult(
        items: <Object>[],
        mediaType: MediaType.character,
        hasMore: false,
      );
    }

    final WikidataApi wikidata = ref.read(wikidataApiProvider);

    final List<Character> characters = await wikidata.searchCharacters(
      query: trimmed,
      limit: _characterPageSize,
    );

    return BrowseResult(
      items: characters,
      mediaType: MediaType.character,
      hasMore: false,
    );
  }
}
