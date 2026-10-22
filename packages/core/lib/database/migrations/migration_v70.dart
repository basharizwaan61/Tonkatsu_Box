import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// A mood-grid cell points at a character by page id, and a Fandom page id
/// repeats across wikis. The variant column keeps the cell on the wiki it was
/// picked from.
class MigrationV70 extends Migration {
  @override
  int get version => 70;

  @override
  String get description =>
      'Mood grids: source_variant column on mood_grid_cells';

  @override
  Future<void> migrate(Database db) async {
    await Migration.addColumnIfAbsent(
      db,
      'mood_grid_cells',
      'source_variant',
      'source_variant TEXT',
    );
  }
}
