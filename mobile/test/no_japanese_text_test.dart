import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App chỉ hỗ trợ tiếng Việt và tiếng Anh: UI không có ký tự Nhật (spec §2).
void main() {
  test('no Japanese characters in app code or assets', () {
    final japanese = RegExp('[぀-ヿ一-鿿]');
    final hits = <String>[];
    for (final dir in ['lib', 'assets']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !RegExp(r'\.(dart|svg|arb|json)$').hasMatch(f.path)) {
          continue;
        }
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (japanese.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('no Japanese glyph drawings left in assets', () {
    expect(Directory('assets/deco').existsSync(), isFalse);
  });
}
