/// A work a character appears in — the series they show up in.
///
/// [sourceId] is the provider's own id for that work (Jikan hands out
/// MyAnimeList ids), and [mediaId] is the id the same work has in the app's
/// own catalogue, so a character can link straight into a title the user
/// already has.
class CharacterAppearance {
  const CharacterAppearance({
    required this.title,
    this.url,
    this.sourceId,
    this.mediaId,
  });

  factory CharacterAppearance.fromJson(Map<String, dynamic> json) {
    return CharacterAppearance(
      title: json['title'] as String? ?? '',
      url: json['url'] as String?,
      sourceId: (json['sourceId'] as num?)?.toInt(),
      mediaId: (json['mediaId'] as num?)?.toInt(),
    );
  }

  /// Title of the work.
  final String title;

  /// Link to the work at the provider.
  final String? url;

  /// The provider's own id for the work, used to look it up in the app's
  /// catalogue.
  final int? sourceId;

  /// The work's id in the app's own catalogue, when it could be resolved.
  final int? mediaId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        if (url != null) 'url': url,
        if (sourceId != null) 'sourceId': sourceId,
        if (mediaId != null) 'mediaId': mediaId,
      };

  CharacterAppearance copyWith({
    String? title,
    String? url,
    int? sourceId,
    int? mediaId,
  }) {
    return CharacterAppearance(
      title: title ?? this.title,
      url: url ?? this.url,
      sourceId: sourceId ?? this.sourceId,
      mediaId: mediaId ?? this.mediaId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterAppearance &&
          other.title == title &&
          other.sourceId == sourceId &&
          other.mediaId == mediaId;

  @override
  int get hashCode => Object.hash(title, sourceId, mediaId);

  @override
  String toString() => 'CharacterAppearance($title)';
}
