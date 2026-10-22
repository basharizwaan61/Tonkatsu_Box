import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/jikan_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

const int _characterPageSize = 25;

/// SearchSource backed by Jikan — the MyAnimeList character catalog.
class JikanCharactersSource extends SearchSource {
  @override
  String get id => 'jikan_characters';

  @override
  MediaType get outputMediaType => MediaType.character;

  @override
  DataSource get dataSource => DataSource.jikan;

  @override
  String label(S l) => l.mediaTypeCharacter;

  @override
  IconData get icon => Icons.face_outlined;

  // No brand PNG for Jikan — the Material icon stands in.
  @override
  String? get iconAsset => null;

  // Jikan has no "popular characters" endpoint, only search.
  @override
  bool get supportsBrowse => false;

  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'popular', apiValue: 'favorites'),
        BrowseSortOption(id: 'name_asc', apiValue: 'name'),
      ];

  // The search endpoint honours order_by / sort, so the dropdown stays live.
  @override
  bool get supportsSortDuringSearch => true;

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

    final JikanApi jikan = ref.read(jikanApiProvider);

    final (String orderBy, String sort) = _jikanSort(sortBy);

    final JikanPagedResult<Character> result = await jikan.searchCharacters(
      query: trimmed,
      page: page,
      limit: _characterPageSize,
      orderBy: orderBy,
      sort: sort,
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

/// Jikan sorts by field plus direction. `sortBy` carries the sort option's
/// apiValue ('favorites' / 'name'); the option id is accepted as well.
(String, String) _jikanSort(String sortBy) {
  return switch (sortBy) {
    'name' || 'name_asc' => ('name', 'asc'),
    _ => ('favorites', 'desc'),
  };
}
