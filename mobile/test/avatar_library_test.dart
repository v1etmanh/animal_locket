import 'dart:convert';
import 'dart:io';

import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libJson =
      jsonDecode(File('assets/avatar/avatar-lib.v1.json').readAsStringSync())
          as Map<String, dynamic>;
  final lib = AvatarLibraryData.fromJson(libJson);

  test('thư viện v1 có 50 × 10 × 6 = 3000 tổ hợp', () {
    expect(lib.version, 1);
    expect(
      lib.animals.length * lib.palettes.length * lib.accessories.length,
      3000,
    );
  });

  test('vẽ ra đúng chuỗi SVG như hàm chuẩn trong build-lib.mjs', () {
    final samples =
        jsonDecode(
              File(
                'test/fixtures/avatar-lib.v1.samples.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(samples, isNotEmpty);
    samples.forEach((key, expected) {
      expect(lib.render(AvatarCode.tryParse('1:$key')!), expected, reason: key);
    });
  });

  test('mã avatar: parse và từ chối mã sai', () {
    final c = AvatarCode.tryParse('1:fox:0:glasses')!;
    expect(c.version, 1);
    expect(c.key, 'fox:0:glasses');
    expect(c.toString(), '1:fox:0:glasses');
    expect(AvatarCode.tryParse(null), isNull);
    expect(AvatarCode.tryParse('fox:0:none'), isNull);
    expect(AvatarCode.tryParse('x:fox:0:none'), isNull);
    expect(lib.render(AvatarCode.tryParse('1:nope:0:none')!), isNull);
    expect(lib.render(AvatarCode.tryParse('1:fox:10:none')!), isNull);
  });

  group('AnimalAvatar', () {
    setUp(() {
      AvatarLibraries.instance.resetForTest();
      AvatarLibraries.instance.register(libJson);
    });

    testWidgets('có mã avatar thì vẽ SVG', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimalAvatar(avatar: '1:fox:0:glasses')),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.bySemanticsLabel('Ảnh đại diện: Cáo'), findsOneWidget);
    });

    testWidgets('chưa có thư viện của phiên bản thì dùng emoji', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimalAvatar(avatar: '9:fox:0:none')),
      );
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('🦊'), findsOneWidget);
    });
  });
}
