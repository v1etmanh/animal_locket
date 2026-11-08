import 'dart:math' as math;

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/widgets/album/hanko_stamp.dart';
import 'package:animal_locket/core/widgets/album/washi_photo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: AppTheme.forPalette(AlbumPalette.of(AlbumThemeId.shu)),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('WashiPhotoCard', () {
    testWidgets('tilts, tapes and frames the photo at 4:5', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            child: WashiPhotoCard(
              header: Text('Cáo Lém Lỉnh 042'),
              photo: ColoredBox(color: Colors.grey),
              caption: Text('Đèn lồng'),
              footer: Text('24'),
            ),
          ),
        ),
      );

      final rotated = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(WashiPhotoCard),
              matching: find.byType(Transform),
            ),
          )
          .map(
            (t) => math.atan2(t.transform.entry(1, 0), t.transform.entry(0, 0)),
          );
      expect(
        rotated.any((a) => (a - (-1.4 * math.pi / 180)).abs() < 1e-6),
        isTrue,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is WashiTapePainter,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is AspectRatio && w.aspectRatio == 0.8),
        findsOneWidget,
      );
      expect(find.text('Đèn lồng'), findsOneWidget);
    });

    test('alternates tilt by index', () {
      expect(WashiPhotoCard.tiltFor(0), -1.4);
      expect(WashiPhotoCard.tiltFor(1), 1.2);
      expect(WashiPhotoCard.tiltFor(2), -1.4);
    });
  });

  group('HankoStamp', () {
    testWidgets('is a 44pt toggle button that reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          HankoStamp(stamped: false, tooltip: 'Thích', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(HankoStamp));
      expect(taps, 1);

      final size = tester.getSize(find.byType(HankoStamp));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      expect(
        tester.getSemantics(find.byType(HankoStamp)),
        matchesSemantics(
          label: 'Thích',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('stamps without animating when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          HankoStamp(stamped: false, tooltip: 'Thích', onPressed: () {}),
          disableAnimations: true,
        ),
      );
      await tester.pumpWidget(
        _app(
          HankoStamp(stamped: true, tooltip: 'Bỏ thích', onPressed: () {}),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animates the stamp when it is pressed down', (tester) async {
      await tester.pumpWidget(
        _app(HankoStamp(stamped: false, tooltip: 'Thích', onPressed: () {})),
      );
      await tester.pumpWidget(
        _app(HankoStamp(stamped: true, tooltip: 'Bỏ thích', onPressed: () {})),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('card content sits on a transparent Material so taps show ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: WashiPhotoCard(
            header: InkWell(onTap: () {}, child: const Text('Cáo')),
            photo: const ColoredBox(color: Colors.grey),
            footer: const Text('24'),
          ),
        ),
      ),
    );
    final inkHost = find.ancestor(
      of: find.byType(InkWell),
      matching: find.byWidgetPredicate(
        (w) => w is Material && w.type == MaterialType.transparency,
      ),
    );
    // The Material must sit inside the card (above its paper decoration).
    expect(
      find.descendant(of: find.byType(WashiPhotoCard), matching: inkHost),
      findsOneWidget,
    );
  });
}
