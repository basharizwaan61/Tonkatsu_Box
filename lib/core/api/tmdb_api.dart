import 'package:core/models/character.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/movie.dart';
import 'package:core/models/tmdb_review.dart';
import 'package:core/models/tv_episode.dart';
import 'package:core/models/tv_season.dart';
import 'package:core/models/tv_show.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_key_initializer.dart';
import 'tmdb/tmdb_find_api.dart';
import 'tmdb/tmdb_genres_api.dart';
import 'tmdb/tmdb_http_client.dart';
import 'tmdb/tmdb_movies_api.dart';
import 'tmdb/tmdb_reviews_api.dart';
import 'tmdb/tmdb_tv_api.dart';
import 'tmdb/tmdb_types.dart';
export 'tmdb/tmdb_types.dart';

final Provider<TmdbApi> tmdbApiProvider = Provider<TmdbApi>((Ref ref) {
  final TmdbApi api = TmdbApi();
  final ApiKeys keys = ref.read(apiKeysProvider);
  if (keys.tmdbApiKey != null && keys.tmdbApiKey!.isNotEmpty) {
    api.setApiKey(keys.tmdbApiKey!);
  }
  return api;
});

/// TMDB v3 facade over the sub-APIs in `tmdb/`; see `tmdb/README.md`
/// for the layer breakdown.
class TmdbApi {
  TmdbApi({Dio? dio, String language = 'ru-RU'})
      : _client = TmdbHttpClient(dio: dio, language: language) {
    _genres = TmdbGenresApi(_client);
    _movies = TmdbMoviesApi(_client, _genres);
    _tv = TmdbTvApi(_client, _genres);
    _reviews = TmdbReviewsApi(_client);
    _find = TmdbFindApi(_client, _genres);
  }

  final TmdbHttpClient _client;
  late final TmdbGenresApi _genres;
  late final TmdbMoviesApi _movies;
  late final TmdbTvApi _tv;
  late final TmdbReviewsApi _reviews;
  late final TmdbFindApi _find;

  String get language => _client.language;

  void setLanguage(String language) {
    if (_client.language != language) {
      // Genre names are language-dependent — drop the cache so the next
      // request refetches them in the new language.
      _genres.clearCache();
    }
    _client.setLanguage(language);
  }

  bool get hasApiKey => _client.hasApiKey;

  void setApiKey(String apiKey) => _client.setApiKey(apiKey);

  void clearApiKey() {
    _client.clearApiKey();
    _genres.clearCache();
  }

  @visibleForTesting
  void setGenreCacheForTesting({
    Map<int, String>? movieGenres,
    Map<int, String>? tvGenres,
  }) =>
      _genres.setCacheForTesting(
        movieGenres: movieGenres,
        tvGenres: tvGenres,
      );

  Future<bool> validateApiKey(String apiKey) => _client.validateApiKey(apiKey);

  Future<List<Movie>> searchMovies(
    String query, {
    int page = 1,
    int? year,
  }) =>
      _movies.searchMovies(query, page: page, year: year);

  Future<TmdbPagedResult<Movie>> searchMoviesPaged(
    String query, {
    int page = 1,
    int? year,
  }) =>
      _movies.searchMoviesPaged(query, page: page, year: year);

  Future<Movie?> getMovie(int tmdbId) => _movies.getMovie(tmdbId);

  Future<List<Movie>> getPopularMovies({int page = 1}) =>
      _movies.getPopularMovies(page: page);

  Future<List<Movie>> getMovieRecommendations(int tmdbId, {int page = 1}) =>
      _movies.getMovieRecommendations(tmdbId, page: page);

  Future<List<Movie>> getSimilarMovies(int tmdbId, {int page = 1}) =>
      _movies.getSimilarMovies(tmdbId, page: page);

  Future<List<Movie>> getTrendingMovies({
    String timeWindow = 'week',
    int page = 1,
  }) =>
      _movies.getTrendingMovies(timeWindow: timeWindow, page: page);

  Future<List<Movie>> getTopRatedMovies({int page = 1}) =>
      _movies.getTopRatedMovies(page: page);

  Future<List<(Movie, String? releaseDate)>> getUpcomingMovieReleases({
    int page = 1,
    String? region,
  }) =>
      _movies.getUpcomingMovieReleases(page: page, region: region);

  Future<List<(Movie, String? releaseDate)>> getNowPlayingMovieReleases({
    int page = 1,
    String? region,
  }) =>
      _movies.getNowPlayingMovieReleases(page: page, region: region);

  Future<List<Movie>> discoverMovies({
    int? genreId,
    String? genreIds,
    int? year,
    String? releaseDateGte,
    String? releaseDateLte,
    int? voteCountGte,
    double? voteAverageGte,
    String? originalLanguage,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) =>
      _movies.discoverMovies(
        genreId: genreId,
        genreIds: genreIds,
        year: year,
        releaseDateGte: releaseDateGte,
        releaseDateLte: releaseDateLte,
        voteCountGte: voteCountGte,
        voteAverageGte: voteAverageGte,
        originalLanguage: originalLanguage,
        sortBy: sortBy,
        page: page,
      );

  Future<List<TvShow>> searchTvShows(
    String query, {
    int page = 1,
    int? firstAirDateYear,
  }) =>
      _tv.searchTvShows(query, page: page, firstAirDateYear: firstAirDateYear);

  Future<TmdbPagedResult<TvShow>> searchTvShowsPaged(
    String query, {
    int page = 1,
    int? firstAirDateYear,
  }) =>
      _tv.searchTvShowsPaged(
        query,
        page: page,
        firstAirDateYear: firstAirDateYear,
      );

  Future<TvShow?> getTvShow(int tmdbId) => _tv.getTvShow(tmdbId);

  Future<TmdbNextEpisode?> getNextEpisodeToAir(int tmdbId) =>
      _tv.getNextEpisodeToAir(tmdbId);

  Future<(TvShow, List<TvSeason>)?> getTvShowWithSeasons(int tmdbId) =>
      _tv.getTvShowWithSeasons(tmdbId);

  Future<List<TvSeason>> getTvSeasons(int tmdbId) =>
      _tv.getTvSeasons(tmdbId);

  Future<List<TvEpisode>> getSeasonEpisodes(
    int tmdbShowId,
    int seasonNumber,
  ) =>
      _tv.getSeasonEpisodes(tmdbShowId, seasonNumber);

  Future<List<TvShow>> getTvRecommendations(int tmdbId, {int page = 1}) =>
      _tv.getTvRecommendations(tmdbId, page: page);

  Future<List<TvShow>> getSimilarTvShows(int tmdbId, {int page = 1}) =>
      _tv.getSimilarTvShows(tmdbId, page: page);

  Future<List<TvShow>> getTrendingTvShows({
    String timeWindow = 'week',
    int page = 1,
  }) =>
      _tv.getTrendingTvShows(timeWindow: timeWindow, page: page);

  Future<List<TvShow>> getTopRatedTvShows({int page = 1}) =>
      _tv.getTopRatedTvShows(page: page);

  Future<List<TvShow>> discoverTvShows({
    int? genreId,
    String? genreIds,
    int? year,
    String? firstAirDateGte,
    String? firstAirDateLte,
    String? airDateGte,
    String? airDateLte,
    int? voteCountGte,
    double? voteAverageGte,
    String? originalLanguage,
    List<int>? withoutGenreIds,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) =>
      _tv.discoverTvShows(
        genreId: genreId,
        genreIds: genreIds,
        year: year,
        firstAirDateGte: firstAirDateGte,
        firstAirDateLte: firstAirDateLte,
        airDateGte: airDateGte,
        airDateLte: airDateLte,
        voteCountGte: voteCountGte,
        voteAverageGte: voteAverageGte,
        originalLanguage: originalLanguage,
        withoutGenreIds: withoutGenreIds,
        sortBy: sortBy,
        page: page,
      );

  /// Page of people matching [query]. [page] is 1-based.
  ///
  /// The search rows carry neither picture nor biography, so every person is
  /// fetched as well; a person whose detail call fails keeps its name.
  Future<TmdbPagedResult<Character>> searchPeople({
    required String query,
    int page = 1,
  }) async {
    _client.ensureApiKey();

    if (query.trim().isEmpty) {
      return const TmdbPagedResult<Character>(
        results: <Character>[],
        page: 1,
        totalPages: 0,
        totalResults: 0,
      );
    }

    try {
      final Response<dynamic> response = await _client.get(
        '/search/person',
        queryParameters: <String, dynamic>{
          'query': query.trim(),
          'page': page,
          // TMDB hides adult titles and people unless they are asked for.
          'include_adult': true,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TmdbApiException(
          'Failed to search people',
          statusCode: response.statusCode,
        );
      }

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? const <dynamic>[];
      final List<(int, String)> rows = <(int, String)>[];
      for (final dynamic item in results) {
        if (item is! Map<String, dynamic>) continue;
        final int? id = (item['id'] as num?)?.toInt();
        final String? name = _text(item['name']);
        if (id == null || name == null) continue;
        rows.add((id, name));
      }

      final List<Character> people = await Future.wait(
        rows.map(((int, String) row) => _person(row.$1, row.$2)),
      );

      return TmdbPagedResult<Character>(
        results: people,
        page: (data['page'] as int?) ?? page,
        totalPages: (data['total_pages'] as int?) ?? 0,
        totalResults: (data['total_results'] as int?) ?? 0,
      );
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search people');
    }
  }

  /// Full person record. Null when not found.
  Future<Character?> getPerson(int id) async {
    _client.ensureApiKey();

    try {
      final Response<dynamic> response = await _client.get(
        '/person/$id',
        queryParameters: <String, dynamic>{
          'append_to_response': 'images',
          // TMDB hides adult titles and people unless they are asked for.
          'include_adult': true,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TmdbApiException(
          'Failed to fetch person',
          statusCode: response.statusCode,
        );
      }

      return _personFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _client.handleDioException(e, 'Failed to fetch person');
    }
  }

  Future<TmdbFindResult> findByImdbId(String imdbId) =>
      _find.findByImdbId(imdbId);

  Future<TmdbFindResult> findByTvdbId(int tvdbId) =>
      _find.findByTvdbId(tvdbId);

  Future<List<MultiSearchResult>> multiSearch(String query, {int page = 1}) =>
      _find.multiSearch(query, page: page);

  Future<List<TmdbReview>> getMovieReviews(int tmdbId, {int page = 1}) =>
      _reviews.getMovieReviews(tmdbId, page: page);

  Future<List<TmdbReview>> getTvReviews(int tmdbId, {int page = 1}) =>
      _reviews.getTvReviews(tmdbId, page: page);

  Future<List<TmdbGenre>> getMovieGenres() => _genres.getMovieGenres();

  Future<List<TmdbGenre>> getTvGenres() => _genres.getTvGenres();

  /// The person behind one search row. The row itself is kept when the
  /// detail call fails, so a flaky person does not vanish from the list.
  Future<Character> _person(int id, String name) async {
    try {
      final Character? person = await getPerson(id);
      return person ?? _barePerson(id, name);
    } on TmdbApiException {
      return _barePerson(id, name);
    }
  }

  Character? _personFromJson(Map<String, dynamic> json) {
    final int? id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    final String? name = _text(json['name']);
    if (name == null) return null;
    return Character(
      id: id,
      source: DataSource.tmdb,
      name: name,
      description: _text(json['biography']),
      imageUrl: _personImage(json),
      aliases: _alsoKnownAs(json['also_known_as']),
      gender: _personGender(json['gender']),
      affiliation: _text(json['known_for_department']),
      externalUrl: 'https://www.themoviedb.org/person/$id',
      popularity: (json['popularity'] as num?)?.round(),
      updatedAt: _now(),
    );
  }

  /// The person without the detail call — a name and a link, nothing more.
  Character _barePerson(int id, String name) {
    return Character(
      id: id,
      source: DataSource.tmdb,
      name: name,
      externalUrl: 'https://www.themoviedb.org/person/$id',
      updatedAt: _now(),
    );
  }

  /// The profile picture. The uploaded profile is more detailed than the
  /// flat one the person carries.
  String? _personImage(Map<String, dynamic> json) {
    String? path = _text(json['profile_path']);
    final Object? images = json['images'];
    if (images is Map<String, dynamic>) {
      final Object? profiles = images['profiles'];
      if (profiles is List<dynamic> && profiles.isNotEmpty) {
        final Object? first = profiles.first;
        if (first is Map<String, dynamic>) {
          path = _text(first['file_path']) ?? path;
        }
      }
    }
    if (path == null) return null;
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  List<String>? _alsoKnownAs(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> names = <String>[];
    for (final Object? item in value) {
      final String? name = _text(item);
      if (name != null) names.add(name);
    }
    return names.isEmpty ? null : names;
  }

  /// TMDB's gender code: 1 female, 2 male, 0 unknown.
  String? _personGender(Object? value) {
    final int? code = (value as num?)?.toInt();
    if (code == 1) return 'Female';
    if (code == 2) return 'Male';
    return null;
  }

  /// Null for anything that is not a non-empty string.
  String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  void dispose() => _client.dispose();
}
