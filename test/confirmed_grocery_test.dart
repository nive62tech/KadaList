import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/models/confirmed_grocery.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/repositories/shopping_repository.dart';

void main() {
  sqfliteFfiInit();
  test(
    'confirmed batches preserve existing items and have unknown prices',
    () async {
      final db = AppDatabase(
        databasePath: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      try {
        final repo = ShoppingRepository(db);
        await repo.saveList('Weekly', 10000);
        final listId = (await repo.lists()).single.id;
        await repo.saveItem(listId, 'Existing', 1, 100);
        await repo.addConfirmedItems(listId, const [
          ConfirmedGrocery(name: 'Rice', quantity: 0.5, unit: ItemUnit.kg),
          ConfirmedGrocery(
            name: 'Unknown name',
            quantity: 0.25,
            unit: ItemUnit.packet,
            category: ItemCategory.miscellaneous,
          ),
        ]);
        final items = await repo.items();
        expect(items.map((i) => i.name), ['Existing', 'Rice', 'Unknown name']);
        expect(items.last.quantity, 0.25);
        expect(items.last.category, ItemCategory.miscellaneous);
        expect(
          items
              .skip(1)
              .every(
                (i) =>
                    i.price == null && i.estimatedPrice == null && !i.purchased,
              ),
          isTrue,
        );
        expect((await repo.lists()).single.budget, 10000);
        await expectLater(
          repo.addConfirmedItems(listId, const [
            ConfirmedGrocery(name: 'Valid', quantity: 1, unit: ItemUnit.kg),
            ConfirmedGrocery(name: 'Invalid', quantity: 0, unit: ItemUnit.kg),
          ]),
          throwsArgumentError,
        );
        expect((await repo.items()).length, 3);
        await expectLater(
          repo.addConfirmedItems(-1, const [
            ConfirmedGrocery(name: 'No list', quantity: 1, unit: ItemUnit.kg),
          ]),
          throwsA(isA<DatabaseException>()),
        );
        expect((await repo.items()).length, 3);
      } finally {
        await db.close();
      }
    },
  );
}
