import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/superhero_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

const int _characterPageSize = 25;

/// SearchSource backed by SuperHero API — the DC and Marvel hero catalog.
class SuperHeroCharactersSource extends SearchSource {
  @override
  String get id => 'superhero_characters';

  @override
  MediaType get outputMediaType => MediaType.character;

  @override
  DataSource get dataSource => DataSource.superHero;

  @override
  String label(S l) => l.mediaTypeCharacter;

  @override
  IconData get icon => Icons.shield_outlined;

  // No brand PNG for SuperHero — the Material icon stands in.
  @override
  String? get iconAsset => null;

  // The API answers queries only, there is no popular-heroes listing.
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

    final SuperHeroApi superHero = ref.read(superHeroApiProvider);

    // Without a token the API answers "access denied", so the source simply
    // contributes nothing until one is configured.
    if (!superHero.hasToken) {
      return const BrowseResult(
        items: <Object>[],
        mediaType: MediaType.character,
        hasMore: false,
      );
    }

    final SuperHeroPagedResult<Character> result =
        await superHero.searchCharacters(
      query: trimmed,
      page: page,
      limit: _characterPageSize,
    );

    return BrowseResult(
      items: result.results,
      mediaType: MediaType.character,
      hasMore: result.hasMore,
      currentPage: result.page,
      totalPages: result.totalPages,
    );
  }
}
