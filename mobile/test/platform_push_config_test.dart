import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android enables Firebase Installation ID messaging', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      matches(
        RegExp(
          r'android:name="firebase_messaging_installation_id_enabled"\s+'
          r'android:value="true"',
        ),
      ),
    );
  });

  test('iOS enables Firebase Installation ID messaging', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      infoPlist,
      contains('<key>FirebaseMessagingInstallationIdEnabled</key>'),
    );
    expect(
      infoPlist,
      matches(
        RegExp(
          r'<key>FirebaseMessagingInstallationIdEnabled</key>\s*<true/>',
        ),
      ),
    );
  });
}
