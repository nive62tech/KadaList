import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/services/shopping_store.dart';
import 'package:kadalist/screens/list_screen.dart';

void main() {
  sqfliteFfiInit();
  testWidgets(
    'purchase dialog cancels, saves exact totals, edits and clears price',
    (tester) async {
      final db = AppDatabase(
        databasePath: inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      final repo = ShoppingRepository(db);
      final store = ShoppingStore(repo);
      late int listId;
      await tester.runAsync(() async {
        await repo.saveList('Weekly', 1000);
        listId = (await repo.lists()).single.id;
        await repo.saveItem(listId, 'Rice', 0.003, 10000);
        await store.load();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(home: ListScreen(listId: listId)),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (store.busy) {
            if (DateTime.now().isAfter(deadline)) {
              throw StateError('Save timed out');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
      }

      Future<void> check() async {
        await tester.scrollUntilVisible(
          find.byType(Checkbox),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byType(Checkbox));
        });
        await settle();
      }

      Future<void> action(String label) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
        });
        await settle();
      }

      await check();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0.30'), findsOneWidget);
      expect(store.itemsFor(listId).single.purchased, isFalse);
      await action('Cancel');
      expect(store.itemsFor(listId).single.purchased, isFalse);
      await check();
      await tester.enterText(find.byType(TextFormField), 'bad');
      await action('Save price');
      expect(
        find.text('Enter a non-negative amount, up to 2 decimals'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '12.35');
      await action('Save price');
      expect(store.itemsFor(listId).single.actualTotal, 1235);
      expect(store.itemsFor(listId).single.total, 1235);
      expect(store.itemsFor(listId).single.purchased, isTrue);
      await tester.scrollUntilVisible(
        find.text('\u20b912.35'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('-\u20b92.35'), findsOneWidget);
      expect(find.text('Over budget by ₹2.35'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Edit actual price for Rice'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Edit actual price for Rice'));
      await tester.tap(find.byTooltip('Edit actual price for Rice'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '12.35'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0');
      await action('Save price');
      expect(store.itemsFor(listId).single.total, 0);
      await tester.scrollUntilVisible(
        find.byTooltip('Edit actual price for Rice'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Edit actual price for Rice'));
      await tester.tap(find.byTooltip('Edit actual price for Rice'));
      await tester.pumpAndSettle();
      await action('Price pending');
      final pending = store.itemsFor(listId).single;
      expect(pending.purchased, isTrue);
      expect(pending.total, isNull);
      expect(pending.price, isNull);
      expect(pending.actualTotal, isNull);
      await tester.scrollUntilVisible(
        find.textContaining('Actual spent and remaining are incomplete.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Over budget by ₹2.35'), findsNothing);
      await check(); // Unchecking retains the pending value.
      expect(store.itemsFor(listId).single.purchased, isFalse);
      await check();
      await action('Price pending');
      expect(store.itemsFor(listId).single.purchased, isTrue);
      expect(store.itemsFor(listId).single.total, isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await tester.runAsync(db.close);
    },
  );
}
