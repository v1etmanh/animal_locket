import 'dart:io';

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/widgets/album/paper_tile_button.dart';
import 'package:animal_locket/core/widgets/album/photo_corners_frame.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.forPalette(AlbumPalette.of(AlbumThemeId.shu)),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PhotoCornersFrame', () {
    testWidgets('a white print with four album corners around its child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            height: 400,
            child: PhotoCornersFrame(
              child: ColoredBox(key: Key('pic'), color: Colors.blue),
            ),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is PhotoCornersPainter,
        ),
        findsOneWidget,
      );
      final pic = tester.getRect(find.byKey(const Key('pic')));
      final frame = tester.getRect(find.byType(PhotoCornersFrame));
      // The print border shows on every side.
      expect(pic.left - frame.left, greaterThan(4));
      expect(frame.bottom - pic.bottom, greaterThan(4));
    });
  });

  group('PaperTileButton', () {
    testWidgets('an icon tile named for screen readers, ≥ 48pt', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          PaperTileButton(
            icon: AlbumIcons.gallery,
            label: 'Chọn từ thư viện',
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(PaperTileButton)),
        isSemantics(
          isButton: true,
          label: 'Chọn từ thư viện',
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final size = tester.getSize(find.byType(PaperTileButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(PaperTileButton));
      expect(taps, 1);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('disabled tile has no tap action', (tester) async {
      await tester.pumpWidget(
        _app(
          const PaperTileButton(
            icon: AlbumIcons.flipCamera,
            label: 'Lật camera',
            onPressed: null,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(PaperTileButton)),
        isSemantics(
          isButton: true,
          label: 'Lật camera',
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
    });
  });

  test('new camera icons exist', () {
    for (final icon in [
      AlbumIcons.flashAuto,
      AlbumIcons.flashOn,
      AlbumIcons.flashOff,
      AlbumIcons.gallery,
      AlbumIcons.flipCamera,
      AlbumIcons.camera,
      AlbumIcons.send,
      AlbumIcons.close,
      AlbumIcons.alert,
    ]) {
      expect(
        File('assets/icons/${icon.asset}.svg').existsSync(),
        isTrue,
        reason: icon.name,
      );
    }
  });
}
