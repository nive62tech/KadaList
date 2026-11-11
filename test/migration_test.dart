import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/repositories/shopping_repository.dart';

void main() {
  sqfliteFfiInit();
  test(
    'v3 migration retains purchase totals and budgets and allows bunches',
    () async {
      final dir = await Directory.systemTemp.createTemp('kadalist_v3');
      final path = '${dir.path}/test.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE shopping_lists (id INTEGER PRIMARY KEY, name TEXT, budget INTEGER, created_at INTEGER)',
            );
            await db.execute(
              "CREATE TABLE shopping_items (id INTEGER PRIMARY KEY, list_id INTEGER, name TEXT, quantity_millis INTEGER, actual_total INTEGER, price INTEGER, estimated_price INTEGER, unit TEXT CHECK(unit IN ('kg','g','litre','ml','packet','piece')), category TEXT, purchased INTEGER)",
            );
            await db.execute(
              "INSERT INTO shopping_lists VALUES (1,'Weekly',10000,1)",
            );
            await db.execute(
              "INSERT INTO shopping_items VALUES (7,1,'Rice',2000,3500,2000,4000,'kg','essential',1)",
            );
          },
        ),
      );
      final before = await old.query('shopping_items');
      await old.close();
      final app = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        final db = await app.database;
        expect(await db.query('shopping_items'), before);
        expect((await db.query('shopping_lists')).single['budget'], 10000);
        await db.update('shopping_items', {'unit': 'bunch'});
        expect((await db.query('shopping_items')).single['unit'], 'bunch');
      } finally {
        await app.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'v2 migration preserves unit prices and persists exact purchase totals',
    () async {
      final dir = await Directory.systemTemp.createTemp('kadalist_v2');
      final path = '${dir.path}/test.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE shopping_lists (id INTEGER PRIMARY KEY, name TEXT, budget INTEGER, created_at INTEGER)',
            );
            await db.execute(
              "CREATE TABLE shopping_items (id INTEGER PRIMARY KEY, list_id INTEGER, name TEXT, quantity_millis INTEGER, price INTEGER, estimated_price INTEGER, unit TEXT, category TEXT, purchased INTEGER)",
            );
            await db.insert('shopping_lists', {
              'id': 1,
              'name': 'Weekly',
              'budget': 1000,
              'created_at': 1,
            });
            await db.insert('shopping_items', {
              'id': 1,
              'list_id': 1,
              'name': 'Rice',
              'quantity_millis': 3,
              'price': 10000,
              'estimated_price': 20000,
              'unit': 'kg',
              'category': 'essential',
              'purchased': 1,
            });
          },
        ),
      );
      await legacy.close();
      final db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        final repo = ShoppingRepository(db);
        expect((await repo.items()).single.total, 30);
        await repo.purchaseWithTotal(1, 1235);
        expect((await repo.items()).single.total, 1235);
        await db.close();
        expect((await repo.items()).single.actualTotal, 1235);
        await repo.purchaseWithTotal(1, null);
        final pending = (await repo.items()).single;
        expect(pending.purchased, isTrue);
        expect(pending.total, isNull);
        expect(pending.estimatedTotal, 60);
        await expectLater(repo.purchaseWithTotal(1, -1), throwsArgumentError);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'v1 migration preserves lists, quantities, prices and purchase states',
    () async {
      final dir = await Directory.systemTemp.createTemp('kadalist_migration');
      final path = '${dir.path}/test.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE shopping_lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, budget INTEGER NOT NULL, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE shopping_items (id INTEGER PRIMARY KEY AUTOINCREMENT, list_id INTEGER NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE, name TEXT NOT NULL, quantity INTEGER NOT NULL, price INTEGER NOT NULL, purchased INTEGER NOT NULL DEFAULT 0)',
            );
            await db.execute(
              'CREATE INDEX items_list_id ON shopping_items(list_id)',
            );
            await db.insert('shopping_lists', {
              'id': 1,
              'name': 'Legacy',
              'budget': 10000,
              'created_at': 123456,
            });
            await db.insert('shopping_items', {
              'id': 5,
              'list_id': 1,
              'name': 'Rice',
              'quantity': 2,
              'price': 1000,
              'purchased': 1,
            });
          },
        ),
      );
      await legacy.close();
      final db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        final repo = ShoppingRepository(db);
        final list = (await repo.lists()).single;
        expect(list.createdAt.millisecondsSinceEpoch, 123456);
        final rice = (await repo.items()).single;
        expect(rice.id, 5);
        expect(rice.quantity, 2);
        expect(rice.total, 2000);
        expect(rice.estimatedTotal, 2000);
        expect(rice.purchased, isTrue);
        expect(rice.unit, ItemUnit.piece);
        expect(rice.category, ItemCategory.essential);
        await repo.saveItem(
          1,
          'Oil',
          0.25,
          null,
          estimatedPrice: 15000,
          unit: ItemUnit.litre,
          category: ItemCategory.miscellaneous,
        );
        final oil = (await repo.items()).last;
        expect(oil.id, greaterThan(5));
        expect(oil.quantity, 0.25);
        expect(oil.price, isNull);
        expect(oil.estimatedTotal, 3750);
        expect(oil.unit, ItemUnit.litre);
        expect(oil.category, ItemCategory.miscellaneous);
        await repo.setPurchased(oil.id, true);
        await repo.saveItem(
          1,
          'Oil',
          0.5,
          12000,
          id: oil.id,
          unit: ItemUnit.litre,
          category: ItemCategory.miscellaneous,
        );
        expect((await repo.items()).last.total, 6000);
        expect((await repo.items()).last.purchased, isTrue);
        await repo.deleteList(1);
        expect(await repo.items(), isEmpty);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'all units persist and invalid fractional quantities are rejected',
    () async {
      final db = AppDatabase(
        databasePath: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      try {
        final repo = ShoppingRepository(db);
        await repo.saveList('Units', 0);
        final id = (await repo.lists()).single.id;
        for (final unit in ItemUnit.values) {
          await repo.saveItem(id, unit.name, 0.5, null, unit: unit);
        }
        expect(
          (await repo.items()).map((i) => i.unit).toList(),
          ItemUnit.values,
        );
        for (final quantity in [0, -1, double.nan, double.infinity, 0.0001]) {
          await expectLater(
            repo.saveItem(id, 'Invalid', quantity, null),
            throwsArgumentError,
          );
        }
      } finally {
        await db.close();
      }
    },
  );
}
