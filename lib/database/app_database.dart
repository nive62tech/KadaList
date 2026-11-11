import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({this.databasePath, DatabaseFactory? factory})
    : _factory = factory ?? databaseFactory;
  final String? databasePath;
  final DatabaseFactory _factory;
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        databasePath ??
            path.join(await _factory.getDatabasesPath(), 'kadalist.db'),
        options: OpenDatabaseOptions(
          version: 4,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE shopping_lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, budget INTEGER NOT NULL CHECK(budget >= 0), created_at INTEGER NOT NULL)',
            );
            await _createItems(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute(
                'ALTER TABLE shopping_items RENAME TO legacy_items',
              );
              await db.execute('DROP INDEX IF EXISTS items_list_id');
              await _createItems(db);
              await db.execute(
                'INSERT INTO shopping_items (id, list_id, name, quantity_millis, price, estimated_price, purchased) SELECT id, list_id, name, quantity * 1000, price, price, purchased FROM legacy_items',
              );
              await db.execute('DROP TABLE legacy_items');
            }
            if (oldVersion >= 2 && oldVersion < 3) {
              await db.execute(
                'ALTER TABLE shopping_items ADD COLUMN actual_total INTEGER CHECK(actual_total >= 0)',
              );
            }
            if (oldVersion >= 2 && oldVersion < 4) {
              await db.execute(
                'ALTER TABLE shopping_items RENAME TO previous_items',
              );
              await db.execute('DROP INDEX IF EXISTS items_list_id');
              await _createItems(db);
              await db.execute(
                'INSERT INTO shopping_items (id,list_id,name,quantity_millis,actual_total,price,estimated_price,unit,category,purchased) SELECT id,list_id,name,quantity_millis,actual_total,price,estimated_price,unit,category,purchased FROM previous_items',
              );
              await db.execute('DROP TABLE previous_items');
            }
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  static Future<void> _createItems(Database db) async {
    await db.execute(
      "CREATE TABLE shopping_items (id INTEGER PRIMARY KEY AUTOINCREMENT, list_id INTEGER NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE, name TEXT NOT NULL, quantity_millis INTEGER NOT NULL CHECK(quantity_millis > 0 AND quantity_millis <= 9999000), actual_total INTEGER CHECK(actual_total >= 0), price INTEGER CHECK(price >= 0), estimated_price INTEGER CHECK(estimated_price >= 0), unit TEXT NOT NULL DEFAULT 'piece' CHECK(unit IN ('kg','g','litre','ml','packet','piece','bunch')), category TEXT NOT NULL DEFAULT 'essential' CHECK(category IN ('essential','miscellaneous')), purchased INTEGER NOT NULL DEFAULT 0 CHECK(purchased IN (0,1)))",
    );
    await db.execute('CREATE INDEX items_list_id ON shopping_items(list_id)');
  }

  Future<void> close() async {
    if (_opening != null) {
      await (await _opening!).close();
      _opening = null;
    }
  }
}
