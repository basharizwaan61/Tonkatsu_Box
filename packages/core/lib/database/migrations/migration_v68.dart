import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// Pictures the user attached to a character live on the collection item, next
/// to `override_cover_url` — they are the user's own images, not provider
/// data, and one character may have several.
class MigrationV68 extends Migration {
  @override
  int get version => 68;

  @override
  String get description =>
      'Characters: character_images column on collection_items';

  @override
  Future<void> migrate(Database db) async {
    await Migration.addColumnIfAbsent(
      db,
      'collection_items',
      'character_images',
      'character_images TEXT',
    );
  }
}
