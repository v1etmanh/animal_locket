import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/features/shell/presentation/app_shell.dart';
import 'package:animal_locket/features/shell/presentation/washi_nav_bar.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _palette = AlbumPalette.of(AlbumThemeId.shu);

/// Router giống app thật: 5 nhánh của AppShell, mỗi nhánh một màn giả.
GoRouter _router() => GoRouter(
  initialLocation: '/feed',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        for (final path in [
          '/camera',
          '/feed',
          '/discover',
          '/chat',
          '/profile',
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(path: path, builder: (_, _) => Text('screen $path')),
            ],
          ),
      ],
    ),
  ],
);

Widget _material(Widget home, {MediaQueryData? media}) => MaterialApp(
  theme: AppTheme.forPalette(_palette),
  locale: const Locale('vi'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: media == null ? home : MediaQuery(data: media, child: home),
);

const _items = [
  WashiNavItem(icon: AlbumIcons.photos, label: 'Ảnh'),
  WashiNavItem(icon: AlbumIcons.feed, label: 'Bảng tin'),
  WashiNavItem(icon: AlbumIcons.discover, label: 'Khám phá'),
  WashiNavItem(icon: AlbumIcons.chat, label: 'Chat'),
  WashiNavItem(icon: AlbumIcons.profile, label: 'Hồ sơ'),
];

Widget _bar(int index, {ValueChanged<int>? onSelected}) => Scaffold(
  bottomNavigationBar: WashiNavBar(
    items: _items,
    currentIndex: index,
    onSelected: onSelected ?? (_) {},
  ),
);

void main() {
  testWidgets('AppShell keeps the five tabs in order and routes them', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.forPalette(_palette),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    const labels = ['Ảnh', 'Bảng tin', 'Khám phá', 'Chat', 'Hồ sơ'];
    final xs = [for (final l in labels) tester.getCenter(find.text(l)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]), reason: labels[i]);
    }
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/discover');
    expect(find.text('screen /discover'), findsOneWidget);

    await tester.tap(find.text('Ảnh'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/camera');
  });

  testWidgets('marks only the current tab as selected, in the accent', (
    tester,
  ) async {
    await tester.pumpWidget(_material(_bar(2)));
    for (var i = 0; i < _items.length; i++) {
      expect(
        tester.getSemantics(find.text(_items[i].label)),
        isSemantics(isButton: true, isSelected: i == 2),
        reason: _items[i].label,
      );
    }
    final label = tester.widget<Text>(find.text('Khám phá'));
    expect(label.style?.color, _palette.accent);
  });

  testWidgets('reports taps with the tab index', (tester) async {
    int? picked;
    await tester.pumpWidget(_material(_bar(1, onSelected: (i) => picked = i)));
    await tester.tap(find.text('Chat'));
    expect(picked, 3);
  });

  testWidgets('labels fit at 1.5x text scale on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _material(
        _bar(2),
        media: const MediaQueryData(
          size: Size(360, 720),
          textScaler: TextScaler.linear(1.5),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('slides the washi to the new tab by default', (tester) async {
    const media = MediaQueryData(size: Size(400, 800));
    await tester.pumpWidget(_material(_bar(1), media: media));
    await tester.pumpWidget(_material(_bar(3), media: media));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('moves the washi without animating when motion is reduced', (
    tester,
  ) async {
    const media = MediaQueryData(size: Size(400, 800), disableAnimations: true);
    await tester.pumpWidget(_material(_bar(1), media: media));
    await tester.pumpWidget(_material(_bar(3), media: media));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
