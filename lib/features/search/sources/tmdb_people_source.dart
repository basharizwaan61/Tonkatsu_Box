import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/tmdb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// SearchSource backed by TMDB — the people behind the movies and shows.
class TmdbPeopleSource extends SearchSource {
  @override
  String get id => 'tmdb_people';

  @override
  MediaType get outputMediaType => MediaType.character;

  @override
  DataSource get dataSource => DataSource.tmdb;

  @override
  String label(S l) => l.mediaTypeCharacter;

  @override
  IconData get icon => Icons.person_outline;

  // The TMDB logo stands for movies, not for a person.
  @override
  String? get iconAsset => null;

  // TMDB has no "popular people" endpoint, only search.
  @override
  bool get supportsBrowse => false;

  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'popular', apiValue: 'popularity.desc'),
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

    final TmdbApi tmdb = ref.read(tmdbApiProvider);

    final TmdbPagedResult<Character> result = await tmdb.searchPeople(
      query: trimmed,
      page: page,
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
