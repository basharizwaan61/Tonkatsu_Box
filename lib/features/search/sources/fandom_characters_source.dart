import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/fandom_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/fandom_wiki_provider.dart';
import '../models/search_source.dart';

const int _characterPageSize = 25;

/// SearchSource backed by Fandom — the character pages of one wiki.
class FandomCharactersSource extends SearchSource {
  @override
  String get id => 'fandom_characters';

  @override
  MediaType get outputMediaType => MediaType.character;

  @override
  DataSource get dataSource => DataSource.fandom;

  @override
  String label(S l) => l.mediaTypeCharacter;

  @override
  IconData get icon => Icons.groups_outlined;

  // No brand PNG for Fandom — the Material icon stands in.
  @override
  String? get iconAsset => null;

  // A wiki answers queries only, there is no popular-characters listing.
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

    // The wiki is a setting: Fandom has no cross-wiki character search.
    final String wiki = await ref.read(fandomWikiProvider.future);

    final FandomApi fandom = ref.read(fandomApiProvider);

    final List<Character> characters = await fandom.searchCharacters(
      wiki: wiki,
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
