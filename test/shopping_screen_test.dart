import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/main.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/services/shopping_store.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('sections, pending price, fractional editing and shared budget', (
    tester,
  ) async {
    final db = AppDatabase(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    final repo = ShoppingRepository(db);
    late int listId;
    await tester.runAsync(() async {
      await repo.saveList('Weekly', 10000);
      listId = (await repo.lists()).single.id;
      await repo.saveItem(
        listId,
        'Rice',
        0.5,
        null,
        estimatedPrice: 8000,
        unit: ItemUnit.kg,
      );
      await repo.saveItem(
        listId,
        'Treat',
        0.25,
        20000,
        unit: ItemUnit.packet,
        category: ItemCategory.miscellaneous,
      );
      for (final item in await repo.items()) {
        await repo.setPurchased(item.id, true);
      }
      await tester.pumpWidget(KadaListApp(repository: repo));
    });
    Future<void> settleData() async {
      final store = tester.element(find.text('KadaList')).read<ShoppingStore>();
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (store.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Shopping data did not load');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    }

    await settleData();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(find.text('Actual spent ₹50.00'), findsOneWidget);
    expect(find.text('Remaining ₹50.00'), findsOneWidget);
    expect(find.text('Projected balance ₹10.00'), findsOneWidget);
    // Scroll through sections on small screens.
    await tester.scrollUntilVisible(
      find.text('Rice'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('0.5 kg'), findsOneWidget);
    expect(find.textContaining('Price pending'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Treat'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Miscellaneous'), findsOneWidget);
    expect(find.textContaining('0.25 packet'), findsOneWidget);
    await tester.tap(find.text('Treat'));
    await tester.pumpAndSettle();
    expect(find.text('Miscellaneous'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).at(1), '0.5');
    await tester.ensureVisible(find.text('Save'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while ((await repo.items()).last.quantity != 0.5) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Item not saved');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Actual spent ₹100.00'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Actual spent ₹100.00'), findsOneWidget);
    expect(find.text('Planned items exceed budget by ₹40.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
