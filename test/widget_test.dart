import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/main.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/repositories/shopping_repository.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('create, open, budget, purchase and rename shopping list', (
    tester,
  ) async {
    final db = AppDatabase(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(db.close);
    await tester.runAsync(() async {
      await db.database;
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(KadaListApp(repository: ShoppingRepository(db)));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Local First. Privacy First.'), findsOneWidget);
    await tester.tap(find.text('Create Shopping List'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Weekly');
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Rice');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.enterText(find.byType(TextFormField).at(2), '60');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Planned items exceed budget by ₹20.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byType(Checkbox));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save price'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save price'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Over budget by ₹20.00'), findsOneWidget);
    await tester.tap(find.byTooltip('List actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename / edit budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Renamed');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
