import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kadalist/services/list_share.dart';
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
    expect(find.text('Actual spent'), findsOneWidget);
    expect(find.text('Remaining budget'), findsOneWidget);
    expect(find.text('\u20b950.00'), findsNWidgets(2));
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Projected balance ₹10.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('inline-microphone')), findsOneWidget);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(DropdownButtonFormField<ItemCategory>, 'Category'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List actions'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.text('Rename / edit budget'));
    await tester.pumpAndSettle();
    expect(find.text('Edit shopping list'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Weekly"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Treat'));
    await tester.pumpAndSettle();
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
      find.text('Actual spent'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Actual spent'), findsOneWidget);
    expect(find.text('\u20b9100.00'), findsOneWidget);
    expect(find.text('Planned items exceed budget by ₹40.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
  testWidgets('rename, local share, miscellaneous entry and confirmed deletion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    final repo = ShoppingRepository(db);
    await tester.runAsync(() async {
      await repo.saveList('Weekend', 25000);
      await tester.pumpWidget(KadaListApp(repository: repo));
    });
    await tester.pump();
    final store = tester.element(find.text('KadaList')).read<ShoppingStore>();
    Future<void> settled() async {
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (store.busy) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Store did not settle');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    }

    await settled();
    final id = store.lists.single.id;
    Future<void> action(String label) async {
      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
      });
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await action('Rename / edit budget');
    await tester.enterText(find.byType(TextFormField).first, 'Family');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
    });
    await settled();
    expect(store.lists.single.name, 'Family');
    expect(store.lists.single.id, id);
    expect(store.lists.single.budget, 25000);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Soap');
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<ItemCategory>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<ItemCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miscellaneous').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
    });
    await settled();
    expect(store.itemsFor(id).single.category, ItemCategory.miscellaneous);
    expect(store.itemsFor(id).single.name, 'Soap');
    MethodCall? shared;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ListShare.channel, (call) async {
          shared = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ListShare.channel, null),
    );
    await action('Share');
    expect(shared!.method, 'shareText');
    expect(
      (shared!.arguments as Map)['text'],
      'Family\nBudget \u20b9250.00\nEssentials\nMiscellaneous\n[ ] Soap - 1 piece',
    );
    await action('Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.itemsFor(id), hasLength(1));
    await action('Delete');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    });
    for (
      var attempt = 0;
      attempt < 100 && (store.lists.isNotEmpty || store.busy);
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await settled();
    expect(find.text('KadaList'), findsOneWidget);
    expect(store.lists, isEmpty);
    await tester.runAsync(() async {
      expect(await repo.items(), isEmpty);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
