import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/services/money.dart';
import 'package:kadalist/services/shopping_store.dart';

void main() {
  sqfliteFfiInit();
  test('money parsing is exact and rejects invalid values', () {
    expect(parseMoney('12.01'), 1201);
    expect(parseMoney('0.1'), 10);
    for (final value in ['-1', 'NaN', '1.001', '', '1e5']) {
      expect(parseMoney(value), isNull);
    }
  });
  test(
    'SQLite persists lists and items, isolates lists and cascades deletes',
    () async {
      final directory = await Directory.systemTemp.createTemp('kadalist_test');
      final path = '${directory.path}/test.db';
      var db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
      try {
        var repository = ShoppingRepository(db);
        await repository.saveList('Groceries', 10000);
        await repository.saveList('Party', 20000);
        final lists = await repository.lists();
        final groceries = lists.firstWhere((list) => list.name == 'Groceries');
        final party = lists.firstWhere((list) => list.name == 'Party');
        await repository.saveItem(groceries.id, 'Milk', 2, 3050);
        await repository.saveItem(party.id, 'Cake', 1, 15000);
        var milk = (await repository.items()).firstWhere(
          (item) => item.name == 'Milk',
        );
        await repository.setPurchased(milk.id, true);
        await repository.saveItem(groceries.id, 'Milk', 3, 3050, id: milk.id);
        await repository.saveList('Weekly groceries', 12000, id: groceries.id);
        await db.close();
        db = AppDatabase(databasePath: path, factory: databaseFactoryFfi);
        repository = ShoppingRepository(db);
        final store = ShoppingStore(repository);
        await store.load();
        expect(store.error, isNull);
        expect(
          store.lists.firstWhere((list) => list.id == groceries.id).createdAt,
          groceries.createdAt,
        );
        expect(
          store.lists.firstWhere((list) => list.id == groceries.id).budget,
          12000,
        );
        milk = store.itemsFor(groceries.id).single;
        expect(milk.total, 9150);
        expect(milk.purchased, isTrue);
        expect(store.itemsFor(party.id).single.name, 'Cake');
        await repository.deleteList(groceries.id);
        expect((await repository.items()).single.listId, party.id);
        await repository.deleteItem((await repository.items()).single.id);
        expect(await repository.items(), isEmpty);
        await expectLater(repository.saveList(' ', 0), throwsArgumentError);
        await expectLater(
          repository.saveItem(party.id, 'Bad', 0, 1),
          throwsArgumentError,
        );
        store.dispose();
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
