import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// ThePornDB performer ids are opaque strings, but the cache keys a character
/// by a number — `native_id` keeps the provider's own id for a refetch.
class MigrationV69 extends Migration {
  @override
  int get version => 69;

  @override
  String get description => 'Characters: native_id column on characters_cache';

  @override
  Future<void> migrate(Database db) async {
    await Migration.addColumnIfAbsent(
      db,
      'characters_cache',
      'native_id',
      'native_id TEXT',
    );
  }
}
