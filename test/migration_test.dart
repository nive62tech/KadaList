import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/repositories/shopping_repository.dart';

void main() {
  sqfliteFfiInit();
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
