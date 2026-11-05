import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android source manifests have no network permission and disable backup',
    () {
      for (final variant in ['main', 'debug', 'profile']) {
        final manifest = File(
          'android/app/src/$variant/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, isNot(contains('android.permission.INTERNET')));
      }
      final main = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(main, contains('android:allowBackup="false"'));
      expect(
        main,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(main, contains('android:fullBackupContent="@xml/backup_rules"'));
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      expect(
        RegExp('<exclude domain="database" path="."').allMatches(rules).length,
        2,
      );
      final dependencies = File('pubspec.lock').readAsStringSync();
      expect(
        dependencies,
        isNot(
          matches(
            RegExp(
              'firebase|analytics|crashlytics|cloud_firestore',
              caseSensitive: false,
            ),
          ),
        ),
      );
    },
  );
}
