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
  String? importFailure;
  String? recognitionFailure;
  Completer<String>? pendingTranscript;
  setUp(() {
    calls = [];
    modelReady = true;
    failure = null;
    importFailure = null;
    recognitionFailure = null;
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
              if (recognitionFailure != null) {
                throw PlatformException(
                  code: 'recognition',
                  message: recognitionFailure,
                );
              }
              if (pendingTranscript != null) {
                return {
                  'text': await pendingTranscript!.future,
                  'diagnostics': <String, dynamic>{},
                };
              }
              return {
                'text': 'രണ്ട് കിലോ അരി, half litre milk',
                'diagnostics': {'sampleRate': 16000, 'limitReached': true},
              };
            case 'importModel':
              if (importFailure != null) {
                throw PlatformException(code: 'model', message: importFailure);
              }
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
    'Manglish defaults to Malayalam recognition and discard preserves text',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'keep this');
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('Manglish - offline voice'), findsOneWidget);
      expect(find.textContaining('keyboard provider'), findsOneWidget);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.firstWhere((c) => c.method == 'start').arguments, {
        'language': 'ml',
      });
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this',
      );
      expect(find.text('Speech diagnostics (no audio)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Manglish capture stops at twenty seconds',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      expect(calls.firstWhere((c) => c.method == 'start').arguments, {
        'language': 'ml',
      });
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'stop'), hasLength(1));
      expect(find.text('Review speech transcript'), findsOneWidget);
      await tester.tap(find.text('Discard'));
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
    'import and inference failures visibly preserve manual text',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'keep this');
      importFailure = 'Choose a multilingual GGML .bin model without .en.';
      await tester.tap(find.text('Import model file'));
      await tester.pumpAndSettle();
      expect(find.text(importFailure!), findsOneWidget);
      expect(find.text('Speech error'), findsOneWidget);
      expect(calls.where((c) => c.method == 'start'), isEmpty);
      await tester.tap(find.text('Speak offline'));
      await tester.pumpAndSettle();
      recognitionFailure = 'Offline transcription failed. Try again.';
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pumpAndSettle();
      expect(find.text(recognitionFailure!), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this',
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

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
    'speech requires acceptance before appending and item review',
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
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1 kg sugar',
      );
      expect(find.text('Review speech transcript'), findsOneWidget);
      expect(
        find.textContaining('end of your list may be missing'),
        findsOneWidget,
      );
      await tester.tap(find.text('Add to grocery text'));
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
      expect(find.textContaining('Tap Import model file'), findsOneWidget);
      expect(calls.map((c) => c.method), ['hasModel']);
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
