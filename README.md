# KadaList
A local-first, privacy-first grocery shopping and budget management Flutter Android app.

Create multiple lists with individual budgets, rename lists, edit budgets, and delete lists with confirmation. Items support fractional quantities from 0.001 to 9999 (up to three decimal places), selectable kg, g, litre, ml, packet and piece units, and Essential or Miscellaneous categories. Both sections use the list's single budget. Unit prices are per selected unit; changing a unit does not automatically convert quantity or price.

Actual and estimated unit prices are independently optional. Blank actual prices remain unknown; a purchased item displays **Price pending** until a price is entered. Enter 0 explicitly for a free item. Actual spent includes only purchased items with known actual prices. Remaining budget is budget minus known actual spent; pending prices are clearly flagged as incomplete. Estimated essential costs cover essential items still to buy. Projected balance subtracts purchased actual costs (falling back to estimates) and remaining item estimates (falling back to entered prices), across both categories. Unknown projections are flagged; projections appear when estimates exist. Actual and projected overspending show warnings.

Money uses integer paise throughout calculation and formatting. Quantities are stored as integer thousandths; extended item costs round half up to the nearest paise once per line. SQLite schema v2 migrates existing v1 items without losing list IDs, budgets, dates, purchase flags or prices; old prices are preserved as both actual prices and estimates, with default Essential / piece values.

All shopping data stays in the local SQLite database (`kadalist.db`) and survives app restarts. Deleting a list also deletes its items. Uninstalling the app or clearing its storage removes local data.

Android cloud backup is disabled, and database files are excluded from legacy backup and Android 12+ cloud backup/device transfer rules. Main, debug and profile source manifests have no INTERNET permission. There are no analytics, Firebase or cloud service dependencies. Removing debug network permission can limit Flutter hot reload/debugger connectivity. Voice recognition is not implemented.

Open a shopping list and tap the toolbar's **Paste or type grocery list** action to import text. Paste/type Malayalam, English, Manglish or mixed-language text, then choose **Review extracted items**. Edit names, quantities, units and categories, uncheck unwanted items, and explicitly **Confirm and save**. Leaving the review does not save anything. Imported items have unknown actual/estimated prices and are not purchased. A confirmed batch is saved atomically through the existing SQLite repository; the schema stays at v2.

The parser is a deterministic, entirely offline rule engine with a bundled grocery vocabulary (`grocery_lexicon.dart`). It returns `GroceryCandidate` records with a canonical name (or the original unknown name), nullable quantity/unit, original source text, `high`/`needsReview` confidence and explicit ambiguity notes. Confidence describes rule recognition, not a statistical probability. Malayalam and English number words, common Manglish number words, decimal quantities, half/quarter notation and prefix/suffix quantities are supported. Units are never guessed. Vague, ranged and unsupported quantities stay unresolved instead of defaulting to 1. Currency amounts, pack multiplication and people counts are flagged for manual confirmation.

Examples:

| Input | Candidates |
| --- | --- |
| `രണ്ട് കിലോ അരി, അര കിലോ പരിപ്പ്` | Rice: 2 kg; Dal: 0.5 kg |
| `oru kg ari, kaal kg uzhunnu` | Rice: 1 kg; Urad dal: 0.25 kg |
| `രണ്ട് kg ari and half litre പാൽ` | Rice: 2 kg; Milk: 0.5 litre |
| `0.5 kg Dragon Fruit` | Dragon Fruit: 0.5 kg; unknown name retained for review |
| `some rice` | Rice: quantity and unit unresolved; user must confirm |

This is not a general natural-language model. Spelling variants, regional number forms and inflections outside the finite vocabulary require review. Use commas/new lines to separate unfamiliar multiword names; unseparated unknown phrases may remain one candidate. Quantities use the app's existing three-decimal precision. Unsupported fractions (such as 1/3), implied/shared amounts and complex pack sizes require manual editing. The interface/canonical recognized names currently use English while preserving the original Malayalam/Manglish input alongside them. No microphone recording or speech recognition is included.

Code organization:

- `lib/models`: shopping records, parser candidates and confirmed imports.
- `lib/database`: versioned SQLite schema, connection, and foreign keys.
- `lib/repositories`: validated persistence operations.
- `lib/services`: Provider/ChangeNotifier state, money/quantity parsing, grocery lexicon and text parser.
- `lib/screens`: list overview and shopping detail screens.
- `lib/widgets`: reusable editing, deletion, and loading/error UI.

Run with `flutter pub get` and `flutter run` on an Android device/emulator. Validate with `dart format lib test`, `flutter analyze` and `flutter test`. Tests verify SQLite persistence/migration, budgets, privacy settings, multilingual parsing, ambiguity, atomic confirmed imports and the manual-entry/review shopping UI.
