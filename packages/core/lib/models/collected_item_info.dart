import 'data_source.dart';
import 'media_type.dart';

/// Where a collected item lives; used to mark and remove search results.
class CollectedItemInfo {
  const CollectedItemInfo({
    required this.recordId,
    required this.collectionId,
    required this.collectionName,
    this.platformId,
    this.source = DataSource.tmdb,
    this.sourceVariant,
  });

  /// Row id in the collection_items table.
  final int recordId;

  /// Collection id (null for uncollected items).
  final int? collectionId;

  /// Collection name (null for uncollected items).
  final String? collectionName;

  /// Platform id (for games). Distinguishes versions on different platforms.
  final int? platformId;

  /// Provider the item came from (disambiguates a shared external_id).
  final DataSource source;

  /// Narrows [source] to one of its sub-scopes — the wiki a Fandom character
  /// came from. Null for every other type.
  final String? sourceVariant;

  @override
  String toString() =>
      'CollectedItemInfo(recordId: $recordId, '
      'collectionId: $collectionId, '
      'collectionName: $collectionName)';
}

extension CollectedPlacementIndex on Map<int, List<CollectedItemInfo>> {
  /// `(source, externalId)` of every placement — the identity a multi-source
  /// card has to match on, since providers reuse numeric ids.
  Set<(DataSource, int)> get sourceKeys => <(DataSource, int)>{
        for (final MapEntry<int, List<CollectedItemInfo>> entry in entries)
          for (final CollectedItemInfo info in entry.value)
            (info.source, entry.key),
      };

  /// External ids holding at least one placement from [source]. For rows that
  /// come from a single provider, where the key alone is enough downstream.
  Set<int> idsFromSource(DataSource source) => <int>{
        for (final MapEntry<int, List<CollectedItemInfo>> entry in entries)
          if (entry.value.any((CollectedItemInfo i) => i.source == source))
            entry.key,
      };
}

extension CollectedVariantIndex on Map<int, List<CollectedItemInfo>> {
  /// `(sourceKey, externalId)` of every placement. The source key carries a
  /// variant, so a Fandom page id stays distinct across wikis.
  Set<(String, int)> get variantSourceKeys => <(String, int)>{
        for (final MapEntry<int, List<CollectedItemInfo>> entry in entries)
          for (final CollectedItemInfo info in entry.value)
            (DataSource.sourceKey(info.source, info.sourceVariant), entry.key),
      };
}

extension CollectedPlacements on List<CollectedItemInfo> {
  /// Keeps only the placements of [source]. Providers reuse numeric ids, so a
  /// multi-source lookup by id alone also returns another title's placements.
  ///
  /// [sourceVariant] narrows further, for a provider whose ids repeat inside
  /// a sub-scope — a Fandom page id belongs to one wiki only.
  List<CollectedItemInfo> forSource(
    MediaType mediaType,
    DataSource? source, [
    String? sourceVariant,
  ]) {
    if (!mediaType.isMultiSource || source == null) return this;
    return where(
      (CollectedItemInfo info) =>
          info.source == source &&
          (sourceVariant == null || info.sourceVariant == sourceVariant),
    ).toList();
  }
}
