import 'dart:convert';

import 'data_source.dart';

/// Character metadata — a person, creature or android a fan collects.
///
/// Cache identity is the pair `(id, source)`. Fandom characters additionally
/// carry the wiki they came from in [variant], so the pair becomes
/// `(8190, 'fandom:marvel')` — page ids are only unique inside one wiki.
class Character {
  const Character({
    required this.id,
    required this.source,
    required this.name,
    this.variant,
    this.nameNative,
    this.description,
    this.imageUrl,
    this.aliases,
    this.franchise,
    this.firstAppearance,
    this.species,
    this.gender,
    this.affiliation,
    this.abilities,
    this.publisher,
    this.alignment,
    this.appearsIn,
    this.externalUrl,
    this.popularity,
    this.updatedAt,
  });

  factory Character.fromDb(Map<String, dynamic> row) {
    List<String>? aliases;
    if (row['aliases'] != null && (row['aliases'] as String).isNotEmpty) {
      try {
        aliases = (jsonDecode(row['aliases'] as String) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList();
      } on FormatException {
        aliases = null;
      }
    }

    Map<String, String>? appearsIn;
    if (row['appears_in'] != null &&
        (row['appears_in'] as String).isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(row['appears_in'] as String) as Map<String, dynamic>;
        appearsIn = decoded.map(
          (String key, dynamic value) => MapEntry<String, String>(key, '$value'),
        );
      } on FormatException {
        appearsIn = null;
      }
    }

    return Character(
      id: row['id'] as int,
      source: DataSource.fromNameOr(row['source'] as String?, DataSource.fandom),
      variant: _variantOf(row['variant'] as String?),
      name: row['name'] as String,
      nameNative: row['name_native'] as String?,
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      aliases: aliases,
      franchise: row['franchise'] as String?,
      firstAppearance: row['first_appearance'] as String?,
      species: row['species'] as String?,
      gender: row['gender'] as String?,
      affiliation: row['affiliation'] as String?,
      abilities: row['abilities'] as String?,
      publisher: row['publisher'] as String?,
      alignment: row['alignment'] as String?,
      appearsIn: appearsIn,
      externalUrl: row['external_url'] as String?,
      popularity: row['popularity'] as int?,
      updatedAt: row['updated_at'] as int?,
    );
  }

  /// Provider-side id. Unique inside [source] only.
  final int id;

  /// Provider this record came from.
  final DataSource source;

  /// Fandom wiki slug; `null` for every other provider.
  final String? variant;

  /// Display name.
  final String name;

  /// Native script name (Jikan's kanji) or the wiki's own title.
  final String? nameNative;

  final String? description;

  final String? imageUrl;

  /// Other names the character is known by — Jikan nicknames, a wiki alias.
  final List<String>? aliases;

  /// Universe or series the character belongs to.
  final String? franchise;

  /// First work the character appeared in.
  final String? firstAppearance;

  final String? species;
  final String? gender;

  /// Group, team or organisation the character belongs to.
  final String? affiliation;

  /// Powers or notable capabilities, as a readable list.
  final String? abilities;

  /// Studio, publisher or wiki behind the character.
  final String? publisher;

  /// Hero / villain / neutral, where the source states it.
  final String? alignment;

  /// Works the character appears in, keyed by title. The value is a link to
  /// that work when the source gives one, otherwise empty.
  final Map<String, String>? appearsIn;

  final String? externalUrl;

  /// Provider-side popularity (Jikan's favourites count).
  final int? popularity;

  /// Unix timestamp of the last successful fetch.
  final int? updatedAt;

  /// Key this row is stored under: the provider, plus the wiki for Fandom.
  String get sourceKey => DataSource.sourceKey(source, variant);

  /// An empty variant means "the provider's default scope".
  static String? _variantOf(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Aliases joined for display.
  String? get aliasesString {
    if (aliases == null || aliases!.isEmpty) return null;
    return aliases!.join(', ');
  }

  /// Titles of the works the character appears in.
  List<String> get appearsInTitles => appearsIn?.keys.toList() ?? const <String>[];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Character && other.id == id && other.sourceKey == sourceKey;
  }

  @override
  int get hashCode => Object.hash(id, sourceKey);

  @override
  String toString() => 'Character(id: $id, name: $name, source: $sourceKey)';

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      'id': id,
      'source': source.name,
      'variant': variant ?? '',
      'name': name,
      'name_native': nameNative,
      'description': description,
      'image_url': imageUrl,
      'aliases': aliases != null ? jsonEncode(aliases) : null,
      'franchise': franchise,
      'first_appearance': firstAppearance,
      'species': species,
      'gender': gender,
      'affiliation': affiliation,
      'abilities': abilities,
      'publisher': publisher,
      'alignment': alignment,
      'appears_in': appearsIn != null ? jsonEncode(appearsIn) : null,
      'external_url': externalUrl,
      'popularity': popularity,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// `toDb` minus the cache timestamp, for `.xcoll` / `.xcollx` payloads.
  Map<String, dynamic> toExport() {
    final Map<String, dynamic> data = toDb();
    data.remove('updated_at');
    return data;
  }

  Character copyWith({
    int? id,
    DataSource? source,
    String? variant,
    String? name,
    String? nameNative,
    String? description,
    String? imageUrl,
    List<String>? aliases,
    String? franchise,
    String? firstAppearance,
    String? species,
    String? gender,
    String? affiliation,
    String? abilities,
    String? publisher,
    String? alignment,
    Map<String, String>? appearsIn,
    String? externalUrl,
    int? popularity,
    int? updatedAt,
  }) {
    return Character(
      id: id ?? this.id,
      source: source ?? this.source,
      variant: variant ?? this.variant,
      name: name ?? this.name,
      nameNative: nameNative ?? this.nameNative,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      aliases: aliases ?? this.aliases,
      franchise: franchise ?? this.franchise,
      firstAppearance: firstAppearance ?? this.firstAppearance,
      species: species ?? this.species,
      gender: gender ?? this.gender,
      affiliation: affiliation ?? this.affiliation,
      abilities: abilities ?? this.abilities,
      publisher: publisher ?? this.publisher,
      alignment: alignment ?? this.alignment,
      appearsIn: appearsIn ?? this.appearsIn,
      externalUrl: externalUrl ?? this.externalUrl,
      popularity: popularity ?? this.popularity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
