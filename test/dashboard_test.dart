import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kadalist/database/app_database.dart';
import 'package:kadalist/repositories/shopping_repository.dart';
import 'package:kadalist/screens/home_screen.dart';
import 'package:kadalist/services/shopping_store.dart';
import 'package:kadalist/services/offline_speech.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('persistent navigation, finish confirmation and restart', (
    tester,
  ) async {
    dashboardTab.value = 0;
    final db = AppDatabase(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    final repo = ShoppingRepository(db);
    final store = ShoppingStore(repo);
    await tester.runAsync(() async {
      await repo.saveList('Market', 5000);
      await store.load();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('Welcome to KadaList!'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Show Manglish voice tips'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No finished trips'), findsOneWidget);
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Finish shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.lists.single.completed, isFalse);
    await tester.tap(find.text('Finish shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (!store.busy) break;
    }
    await tester.pumpAndSettle();
    expect(store.lists.single.completed, isTrue);
    expect(find.text('Restart as new list'), findsOneWidget);
    await tester.tap(find.text('Restart as new list'));
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (!store.busy) break;
    }
    await tester.pumpAndSettle();
    expect(store.lists, hasLength(2));
    expect(store.lists.where((l) => l.completed), hasLength(1));
    expect(find.text('Finish shopping'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets(
    'bottom microphone records inline, imports missing model and reviews before adding',
    (tester) async {
      dashboardTab.value = 0;
      await tester.binding.setSurfaceSize(const Size(380, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calls = <MethodCall>[];
      var hasModel = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(OfflineSpeech.channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'hasModel':
                return hasModel;
              case 'importModel':
                hasModel = true;
                return true;
              case 'stop':
                return {
                  'text': '2 kg rice',
                  'diagnostics': <String, dynamic>{},
                };
              default:
                return null;
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(OfflineSpeech.channel, null),
      );
      final db = AppDatabase(
        databasePath: inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      final repo = ShoppingRepository(db);
      final store = ShoppingStore(repo);
      await tester.runAsync(() async {
        await repo.saveList('Voice trip', 5000);
        await store.load();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.ensureVisible(find.text('Voice trip'));
      await tester.tap(find.text('Voice trip'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('inline-microphone')));
      await tester.pumpAndSettle();
      expect(find.text('Voice trip'), findsOneWidget);
      expect(find.text('Model required'), findsOneWidget);
      expect(calls.where((c) => c.method == 'start'), isEmpty);
      await tester.ensureVisible(find.text('Import model file'));
      await tester.tap(find.text('Import model file'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Speak offline'));
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.firstWhere((c) => c.method == 'start').arguments, {
        'language': 'ml',
      });
      expect(find.text('Recording'), findsOneWidget);
      await tester.ensureVisible(find.text('Stop and transcribe'));
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Review speech transcript'), findsOneWidget);
      expect(store.itemsFor(store.lists.single.id), isEmpty);
      await tester.ensureVisible(find.text('Discard'));
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Review speech transcript'), findsNothing);
      await tester.ensureVisible(find.text('Speak offline'));
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Stop and transcribe'));
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accept transcript'));
      await tester.tap(find.text('Accept transcript'));
      await tester.pumpAndSettle();
      expect(find.text('Review grocery items'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await tester.runAsync(db.close);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
