import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/models/shopping_item.dart';

void main() {
  sqfliteFfiInit();
  test(
    'completion and atomic restart persist without changing original',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kada_completion',
      );
      final path = '${directory.path}/test.db';
      var db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        var repo = ShoppingRepository(db);
        await repo.saveList('Trip', 25000);
        final id = (await repo.lists()).single.id;
        await repo.saveItem(
          id,
          'Spice',
          0.5,
          500,
          unit: ItemUnit.kg,
          category: ItemCategory.miscellaneous,
          estimatedPrice: 400,
        );
        await repo.purchaseWithTotal((await repo.items()).single.id, 375);
        await repo.setVoiceTips(false);
        await repo.finishList(id);
        final copy = await repo.restartList(id);
        await db.close();
        db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
        repo = ShoppingRepository(db);
        expect(await repo.showVoiceTips(), isFalse);
        final lists = await repo.lists();
        expect(lists.firstWhere((l) => l.id == id).completed, isTrue);
        expect(lists.firstWhere((l) => l.id == copy).completed, isFalse);
        expect(lists.firstWhere((l) => l.id == copy).budget, 25000);
        final items = await repo.items();
        final original = items.firstWhere((i) => i.listId == id);
        final restarted = items.firstWhere((i) => i.listId == copy);
        expect(original.actualTotal, 375);
        expect(original.purchased, isTrue);
        expect(restarted.name, original.name);
        expect(restarted.quantity, 0.5);
        expect(restarted.unit, ItemUnit.kg);
        expect(restarted.category, ItemCategory.miscellaneous);
        expect(restarted.actualTotal, isNull);
        expect(restarted.price, isNull);
        expect(restarted.purchased, isFalse);
        await expectLater(repo.restartList(copy), throwsStateError);
        expect(await repo.lists(), hasLength(2));
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'version 4 migration preserves prices and defaults existing lists to active',
    () async {
      final directory = await Directory.systemTemp.createTemp('kada_v4');
      final path = '${directory.path}/legacy.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE shopping_lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, budget INTEGER NOT NULL, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE shopping_items (id INTEGER PRIMARY KEY AUTOINCREMENT, list_id INTEGER NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE, name TEXT NOT NULL, quantity_millis INTEGER NOT NULL, actual_total INTEGER, price INTEGER, estimated_price INTEGER, unit TEXT NOT NULL DEFAULT 'piece', category TEXT NOT NULL DEFAULT 'essential', purchased INTEGER NOT NULL DEFAULT 0)",
            );
            await db.insert('shopping_lists', {
              'id': 7,
              'name': 'Existing',
              'budget': 9000,
              'created_at': 1234,
            });
            await db.insert('shopping_items', {
              'list_id': 7,
              'name': 'Egg',
              'quantity_millis': 2000,
              'actual_total': 1200,
              'purchased': 1,
            });
          },
        ),
      );
      await old.close();
      final db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        final repo = ShoppingRepository(db);
        expect((await repo.lists()).single.completed, isFalse);
        expect((await repo.lists()).single.id, 7);
        expect((await repo.items()).single.actualTotal, 1200);
        expect((await repo.items()).single.purchased, isTrue);
        await repo.finishList(7);
        expect((await repo.lists()).single.completed, isTrue);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
