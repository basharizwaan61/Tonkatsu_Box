/// A picture the user attached to a character — a still, a wallpaper, a
/// portrait from anywhere online.
///
/// Unlike the provider's own image, this is the user's own data: it lives on
/// the collection item, not on the cached character.
class CharacterImage {
  const CharacterImage({required this.url, this.caption});

  factory CharacterImage.fromJson(Map<String, dynamic> json) {
    return CharacterImage(
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String?,
    );
  }

  /// Link to the picture. Only http(s) links are accepted.
  final String url;

  /// Optional note — what the picture shows ("best look", "movie scene 3").
  final String? caption;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        if (caption != null) 'caption': caption,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterImage && other.url == url && other.caption == caption;

  @override
  int get hashCode => Object.hash(url, caption);

  @override
  String toString() => 'CharacterImage($url)';
}
