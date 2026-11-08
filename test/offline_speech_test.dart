import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadalist/screens/grocery_text_screen.dart';
import 'package:kadalist/services/offline_speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  var modelReady = true;
  String? failure;
  Completer<String>? pendingTranscript;
  setUp(() {
    calls = [];
    modelReady = true;
    failure = null;
    pendingTranscript = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineSpeech.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'hasModel':
              return modelReady;
            case 'start':
              if (failure != null) {
                throw PlatformException(code: 'permission', message: failure);
              }
              return null;
            case 'stop':
              if (pendingTranscript != null) return pendingTranscript!.future;
              return 'രണ്ട് കിലോ അരി, half litre milk';
            case 'importModel':
              modelReady = true;
              return true;
            default:
              return null;
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineSpeech.channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GroceryTextScreen(listId: 1)),
    );
  }

  testWidgets(
    'voice screen and model import do not initiate microphone permission flow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GroceryTextScreen(listId: 1, voiceFirst: true)),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Import model file'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['importModel']);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), [
        'importModel',
        'hasModel',
        'start',
      ]);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'speech appends editable multilingual text and requires item review',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '1 kg sugar');
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.firstWhere((c) => c.method == 'start').arguments, {
        'language': 'ml',
      });
      expect(find.text('Recording'), findsOneWidget);
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.controller!.text,
        '1 kg sugar\nരണ്ട് കിലോ അരി, half litre milk',
      );
      await tester.tap(find.text('Review extracted items'));
      await tester.pumpAndSettle();
      expect(find.text('Review grocery items'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Rice'), findsOneWidget);
      expect(find.text('Confirm and save'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'missing model never starts microphone and permission error keeps text',
    (tester) async {
      modelReady = false;
      await open(tester);
      await tester.enterText(find.byType(TextField), 'keep this');
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'start'), isEmpty);
      expect(find.text('Model required'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this',
      );
      expect(
        find.textContaining('Import a multilingual ggml-tiny'),
        findsOneWidget,
      );
      await tester.tap(find.text('Import model file'));
      await tester.pumpAndSettle();
      expect(find.text('Model required'), findsNothing);
      failure = 'Microphone permission denied';
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(find.text('Microphone permission denied'), findsOneWidget);
      expect(find.textContaining('Android Settings'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this',
      );
      failure = null;
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(find.text('Recording'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'late transcription after background cancellation is discarded',
    (tester) async {
      pendingTranscript = Completer<String>();
      await open(tester);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pump();
      expect(find.text('Processing on device'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      pendingTranscript!.complete('must be discarded');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'leaving foreground cancels capture without adding a transcript',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'cancel'), isNotEmpty);
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
