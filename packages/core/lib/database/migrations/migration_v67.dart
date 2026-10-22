import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// Characters join the collection as a first-class media type, cached in
/// their own table. `variant` narrows a provider to one of its sub-scopes —
/// the wiki a Fandom character came from — because a page id is only unique
/// inside one wiki.
class MigrationV67 extends Migration {
  @override
  int get version => 67;

  @override
  String get description =>
      'Characters: characters_cache table, source_variant column, '
      'source-aware unique indexes';

  @override
  Future<void> migrate(Database db) async {
    // The variant column comes first: the character indexes below read it.
    await Migration.addColumnIfAbsent(
      db,
      'collection_items',
      'source_variant',
      'source_variant TEXT',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS characters_cache (
        id INTEGER NOT NULL,
        source TEXT NOT NULL,
        variant TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        name_native TEXT,
        description TEXT,
        image_url TEXT,
        aliases TEXT,
        franchise TEXT,
        first_appearance TEXT,
        species TEXT,
        gender TEXT,
        affiliation TEXT,
        abilities TEXT,
        publisher TEXT,
        alignment TEXT,
        appears_in TEXT,
        external_url TEXT,
        popularity INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (id, source, variant)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_characters_cache_name
      ON characters_cache(name)
    ''');

    // A character needs its source in the key, so the same name from two
    // providers — or the same page id from two wikis — stays distinct.
    await db.execute('DROP INDEX IF EXISTS idx_ci_coll_other');
    await db.execute('DROP INDEX IF EXISTS idx_ci_uncat_other');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_coll_other
      ON collection_items(collection_id, media_type, external_id)
      WHERE collection_id IS NOT NULL
        AND media_type NOT IN (
          'game', 'manga', 'tv_show', 'book', 'anime', 'movie', 'character'
        )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_uncat_other
      ON collection_items(media_type, external_id)
      WHERE collection_id IS NULL
        AND media_type NOT IN (
          'game', 'manga', 'tv_show', 'book', 'anime', 'movie', 'character'
        )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_coll_character
      ON collection_items(
        collection_id, media_type, external_id,
        COALESCE(source, 'fandom'), COALESCE(source_variant, '')
      )
      WHERE collection_id IS NOT NULL AND media_type = 'character'
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_uncat_character
      ON collection_items(
        media_type, external_id,
        COALESCE(source, 'fandom'), COALESCE(source_variant, '')
      )
      WHERE collection_id IS NULL AND media_type = 'character'
    ''');
  }
}
