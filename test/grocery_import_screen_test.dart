import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/main.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/services/shopping_store.dart';

void main() {
  sqfliteFfiInit();
  testWidgets(
    'text import requires review and saves only edited confirmed items',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase(
        databasePath: inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(db.close);
      final repo = ShoppingRepository(db);
      await tester.runAsync(() async {
        await repo.saveList('Weekly', 10000);
        await tester.pumpWidget(KadaListApp(repository: repo));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      final initialStore = tester
          .element(find.text('KadaList'))
          .read<ShoppingStore>();
      await tester.runAsync(() async {
        while (initialStore.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste or type grocery list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review extracted items'));
      await tester.pumpAndSettle();
      expect(find.text('Type at least one grocery item.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '0.5kg ari, some sugar');
      await tester.tap(find.text('Review extracted items'));
      await tester.pumpAndSettle();
      expect(find.text('Review grocery items'), findsOneWidget);
      expect(find.text('Needs review'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await repo.items(), isEmpty);
      });
      await tester.tap(find.text('Confirm and save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Item 2: confirm a name, quantity and unit before saving.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rice'),
        'Matta rice',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '0.25');
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      final store = tester
          .element(find.text('Review grocery items'))
          .read<ShoppingStore>();
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm and save'));
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (store.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Save timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Review grocery items'), findsNothing);
      expect(find.text('Weekly'), findsOneWidget);
      await tester.runAsync(() async {
        final items = await repo.items();
        expect(items.single.name, 'Matta rice');
        expect(items.single.quantity, 0.25);
        expect(items.single.price, isNull);
      });
      // Leaving the review without confirmation must not add anything.
      await tester.tap(find.text('Paste or type grocery list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1kg rice');
      await tester.tap(find.text('Review extracted items'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Grocery text'), findsOneWidget);
      await tester.runAsync(() async {
        expect((await repo.items()).length, 1);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
