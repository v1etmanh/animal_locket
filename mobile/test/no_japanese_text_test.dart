import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App chỉ hỗ trợ tiếng Việt và tiếng Anh. Chữ Nhật chỉ được dùng để trang trí
/// ở vài chỗ chủ dự án chốt (spec §2, sửa 2026-11-10), và chỉ gồm các ký tự có
/// trong font subset `ShipporiMincho-Accents.ttf`.
const _allowedDecorative = '朱柚桜空瞬思い出をそっと';

void main() {
  test(
    'no Japanese characters in app code or assets except decorative ones',
    () {
      final japanese = RegExp('[぀-ヿ一-鿿]');
      final hits = <String>[];
      for (final dir in ['lib', 'assets']) {
        for (final f in Directory(dir).listSync(recursive: true)) {
          if (f is! File ||
              !RegExp(r'\.(dart|svg|arb|json)$').hasMatch(f.path)) {
            continue;
          }
          final lines = f.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            for (final m in japanese.allMatches(lines[i])) {
              if (!_allowedDecorative.contains(m[0]!)) {
                hits.add('${f.path}:${i + 1} ${m[0]}');
              }
            }
          }
        }
      }
      expect(hits, isEmpty);
    },
  );

  test('no Japanese glyph drawings left in assets', () {
    expect(Directory('assets/deco').existsSync(), isFalse);
  });
}
