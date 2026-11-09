import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppBackground paints folded paper from the active palette', (
    tester,
  ) async {
    final yuzu = AlbumPalette.of(AlbumThemeId.yuzu);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(yuzu),
        home: const AppBackground(child: Text('x')),
      ),
    );
    final paints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter is FoldedPaperPainter);
    expect(paints, hasLength(1));
    expect((paints.single.painter! as FoldedPaperPainter).palette, yuzu);
    expect(find.text('x'), findsOneWidget);
  });

  test('FoldedPaperPainter repaints only when the palette changes', () {
    final shu = FoldedPaperPainter(AlbumPalette.of(AlbumThemeId.shu));
    expect(
      shu.shouldRepaint(FoldedPaperPainter(AlbumPalette.of(AlbumThemeId.sora))),
      isTrue,
    );
    expect(
      shu.shouldRepaint(FoldedPaperPainter(AlbumPalette.of(AlbumThemeId.shu))),
      isFalse,
    );
  });

  test('AlbumIcons asset names are snake_case file names', () {
    expect(AlbumIcons.emptyAlbum.asset, 'empty_album');
    expect(AlbumIcons.imageBroken.asset, 'image_broken');
    expect(AlbumIcons.photos.asset, 'photos');
  });

  testWidgets('every icon asset is a path-only svg', (tester) async {
    for (final icon in AlbumIcons.values) {
      final svg = await rootBundle.loadString('assets/icons/${icon.asset}.svg');
      expect(svg, contains('<svg'), reason: icon.name);
      expect(svg, isNot(contains('<text')), reason: icon.name);
    }
  });
}
