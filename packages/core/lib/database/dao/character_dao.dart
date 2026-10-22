import '../query_chunk.dart';
import '../../models/character.dart';
import '../../models/data_source.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// DAO for `characters_cache`. Row identity is the pair `(id, source)`, where
/// `source` is the provider plus the wiki for Fandom — see
/// [Character.sourceKey].
class CharacterDao {
  const CharacterDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  Future<void> upsertCharacter(Character character) async {
    final Database db = await _getDatabase();
    await db.insert(
      'characters_cache',
      character.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCharacters(List<Character> characters) async {
    if (characters.isEmpty) return;
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    for (final Character character in characters) {
      batch.insert(
        'characters_cache',
        character.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Row identity is the triple `(id, source, variant)` — a Fandom page id
  /// belongs to one wiki only.
  Future<Character?> getCharacter(
    int id, {
    required DataSource source,
    String? variant,
  }) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      'characters_cache',
      where: 'id = ? AND source = ? AND variant = ?',
      whereArgs: <Object?>[id, source.name, variant ?? ''],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Character.fromDb(rows.first);
  }

  /// Matches across all sources; callers disambiguate by
  /// [Character.sourceKey] (two providers can share a numeric id).
  Future<List<Character>> getCharactersByIds(List<int> ids) async {
    if (ids.isEmpty) return const <Character>[];
    final Database db = await _getDatabase();
    return queryByIdsInChunks(ids, (List<int> chunk) async {
      final String placeholders =
          List<String>.filled(chunk.length, '?').join(',');
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        'SELECT * FROM characters_cache WHERE id IN ($placeholders)',
        chunk,
      );
      return rows.map(Character.fromDb).toList();
    });
  }

  Future<void> clearCharacters() async {
    final Database db = await _getDatabase();
    await db.delete('characters_cache');
  }
}
