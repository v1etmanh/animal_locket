import 'dart:convert';
import 'dart:io';

import 'package:animal_locket/core/l10n/tr.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/features/chat/data/system_glyphs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name.arb').readAsStringSync())
        as Map<String, dynamic>;

final _vietnamese = RegExp(r'[À-ÖØ-ỹ]');
final _placeholder = RegExp(r'\{(\w+)[,}]');

void main() {
  tearDown(() => setTrLocale(const Locale('vi')));

  test('English has exactly the same keys as Vietnamese', () {
    final vi = _arb('app_vi').keys.where((k) => !k.startsWith('@'));
    final en = _arb('app_en').keys.where((k) => !k.startsWith('@'));
    expect(en.toSet(), vi.toSet());
  });

  test('no English string contains Vietnamese letters', () {
    final en = _arb('app_en');
    final leaked = [
      for (final e in en.entries)
        if (!e.key.startsWith('@') &&
            e.key != 'languageSection' &&
            _vietnamese.hasMatch(e.value as String))
          e.key,
    ];
    expect(leaked, isEmpty);
  });

  test('English uses the same placeholders as Vietnamese', () {
    final vi = _arb('app_vi');
    final en = _arb('app_en');
    for (final key in vi.keys.where((k) => !k.startsWith('@'))) {
      Set<String> names(Map<String, dynamic> arb) => {
        for (final m in _placeholder.allMatches(arb[key] as String)) m[1]!,
      };
      expect(names(en), names(vi), reason: key);
    }
  });

  test('code without a BuildContext follows the selected language', () {
    expect(
      messageForApiCode('PRO_REQUIRED'),
      'Tính năng này dành cho thành viên Pro.',
    );
    setTrLocale(const Locale('en'));
    expect(
      messageForApiCode('PRO_REQUIRED'),
      'This feature is for Pro members.',
    );
    expect(messageForApiCode(null, status: 429), tr.errTooFast);
    expect(tr.timeMinutesAgo(1), '1 minute ago');
    expect(tr.timeMinutesAgo(5), '5 minutes ago');
  });

  test('system symbols are translated when read, not when stored', () {
    final coffee = buildSystemGlyphs().firstWhere((g) => g.id == 'sys-coffee');
    expect(localizeSystemGlyph(coffee).meaning, 'Đi cà phê không?');
    setTrLocale(const Locale('en'));
    expect(localizeSystemGlyph(coffee).meaning, 'Coffee?');
  });
}
