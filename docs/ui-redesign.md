# KadaList redesign

Implemented a warm ivory and leafy green dashboard with a bundled Flutter grocery illustration, Manglish microcopy, and persistent Lists / Completed / Profile navigation.

Lists retain the shared budget, actual spending, remaining balance, price dialogs, manual item entry, multilingual paste/type parser, rename/share/delete menu and local Whisper integration. The camera action is a labelled upcoming feature.

Voice capture now starts directly in the list. Missing models expose local import inline. Recording, stop, processing, transcript review, accept and discard stay inline; accepting opens the existing editable grocery-item review before anything is saved. Manglish remains the default user-facing mode and recognition uses ml. No accuracy improvements are claimed.

SQLite version 5 adds explicit completion and local preferences without removing old rows. Finish shopping asks for confirmation. Restart duplicates a completed trip in one transaction, retains names, quantities, units, categories, budget and estimates, clears actual totals and legacy actual unit prices, and makes all copied items unpurchased. The completed original remains intact and its items are read-only.

## Files changed for this redesign

- lib/main.dart
- lib/database/app_database.dart
- lib/models/shopping_list.dart
- lib/repositories/shopping_repository.dart
- lib/services/shopping_store.dart
- lib/screens/home_screen.dart
- lib/screens/list_screen.dart
- lib/widgets/grocery_art.dart (new)
- lib/widgets/offline_speech_input.dart
- lib/widgets/shopping_item_tile.dart
- test/completion_test.dart (new)
- test/dashboard_test.dart (new)
- test/grocery_import_screen_test.dart
- test/purchase_price_test.dart
- test/shopping_screen_test.dart
- test/widget_test.dart
- docs/ui-redesign.md (this report)

Pre-existing edits in Android speech integration, speech documentation, grocery text input, speech tests and list sharing were preserved.

## Validation

- Dart format on lib and test: passed; final run changed zero files.
- flutter analyze --no-pub: no issues found.
- flutter test --no-pub: all 61 tests passed.
- Coverage includes v1-v4 database upgrades, completion confirmation, restart and preferences persistence after reopening SQLite, original-trip preservation, navigation, missing-model import, direct inline recording using ml, transcript acceptance/discard, budget/price regressions, parser behavior, privacy checks, narrow screens and simulated keyboard insets.

## Limitations

The camera is a placeholder for future image import. Real microphone capture, Whisper model import/inference and Android 12 system interactions were not manually validated on a device in this task; speech widget tests use mocked platform channels. No APK was built, no model was downloaded, and nothing was committed or pushed. Storage and recognition remain local with no new backend, tracking, sync or runtime downloads.
