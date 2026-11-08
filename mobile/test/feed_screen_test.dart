import 'dart:async';
import 'dart:math' as math;

import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:animal_locket/core/widgets/album/hanko_stamp.dart';
import 'package:animal_locket/core/widgets/album/washi_photo_card.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:animal_locket/features/feed/presentation/feed_screen.dart';
import 'package:animal_locket/features/feed/presentation/posts_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.now().toUtc();

Post _post(
  String id, {
  DateTime? at,
  String alias = 'Cáo Lém Lỉnh 042',
  String? caption = 'Chiều nay ở Hội An 🏮',
  bool liked = false,
}) => Post(
  id: id,
  author: PublicProfile(publicId: 'u$id', alias: alias, leadAnimal: 'fox'),
  mediaId: 'm$id',
  status: PostStatus.published,
  likeCount: 24,
  commentCount: 5,
  likedByMe: liked,
  createdAt: at ?? _now,
  publishedAt: at ?? _now,
  caption: caption,
);

class _FakeFeed extends FeedController {
  _FakeFeed(this.initial);
  final FeedState initial;
  final liked = <String>[];

  @override
  Future<FeedState> build() async => initial;

  @override
  Future<void> toggleLike(String postId) async => liked.add(postId);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

final _loading = Completer<String?>();

Future<_FakeFeed> _pump(
  WidgetTester tester,
  FeedState state, {
  double width = 400,
}) async {
  // Tall enough that the lazy ListView builds every card.
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeFeed(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        feedControllerProvider.overrideWith(() => fake),
        mediaUrlProvider.overrideWith((ref, mediaId) {
          return switch (mediaId) {
            'm1' => Future<String?>.value(null),
            'm2' => Future<String?>.error(StateError('no url')),
            _ => _loading.future,
          };
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.forPalette(AlbumPalette.of(AlbumThemeId.shu)),
        home: const FeedScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return fake;
}

void main() {
  final yesterday = _now.subtract(const Duration(days: 1));
  final three = FeedState(
    items: [
      _post('1', liked: true),
      _post('2'),
      _post('3', at: yesterday),
    ],
  );

  testWidgets('keeps the existing copy and day labels', (tester) async {
    await _pump(tester, three);
    expect(find.text('Khoảnh khắc'), findsOneWidget);
    expect(find.text(formatPostDay(_now.toLocal())), findsOneWidget);
    expect(find.text(formatPostDay(yesterday.toLocal())), findsOneWidget);
    expect(find.text('Chiều nay ở Hội An 🏮'), findsNWidgets(3));
    expect(find.text('24'), findsNWidgets(3));
    expect(find.text('5'), findsNWidgets(3));
  });

  testWidgets('uses only album widgets, no glass or Material icons', (
    tester,
  ) async {
    await _pump(tester, three);
    final feed = find.byType(FeedScreen);
    expect(
      find.descendant(of: feed, matching: find.byType(GlassContainer)),
      findsNothing,
    );
    expect(
      find.descendant(of: feed, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('vertical kanji sits fully on screen, beside the cards', (
    tester,
  ) async {
    await _pump(tester, three);
    // First DecoSvg in the tree is the vertical kanji (hanko stamps follow).
    final deco = tester.getRect(find.byType(DecoSvg).first);
    expect(deco.left, greaterThanOrEqualTo(0));
    expect(deco.right, lessThanOrEqualTo(400));
    // Not clipped by the page content box (20pt padding each side).
    expect(deco.right, lessThanOrEqualTo(400 - 20));
    final firstCard = tester.getRect(find.byType(WashiPhotoCard).first);
    expect(deco.left, greaterThanOrEqualTo(firstCard.right));
  });

  testWidgets('tilts cards alternately', (tester) async {
    await _pump(tester, three);
    final cards = tester.widgetList<WashiPhotoCard>(
      find.byType(WashiPhotoCard),
    );
    expect(cards.map((c) => c.tiltDegrees).toList(), [-1.4, 1.2, -1.4]);
  });

  testWidgets('pressing the hanko likes that post', (tester) async {
    final fake = await _pump(tester, three);
    final stamps = tester.widgetList<HankoStamp>(find.byType(HankoStamp));
    expect(stamps.first.stamped, isTrue);
    expect(stamps.elementAt(1).stamped, isFalse);
    await tester.tap(find.byType(HankoStamp).first);
    expect(fake.liked, ['1']);
  });

  testWidgets('photo frames keep 4:5 while empty, failed or loading', (
    tester,
  ) async {
    await _pump(tester, three);
    expect(
      find.byWidgetPredicate((w) => w is AspectRatio && w.aspectRatio == 0.8),
      findsNWidgets(3),
    );
    bool hasIcon(AlbumIcons icon) => tester
        .widgetList<AlbumIcon>(find.byType(AlbumIcon))
        .any((w) => w.icon == icon);
    expect(hasIcon(AlbumIcons.image), isTrue);
    expect(hasIcon(AlbumIcons.imageBroken), isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('long alias and multi-line caption do not overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      FeedState(
        items: [
          _post(
            '1',
            alias: 'Cáo ${'Lém Lỉnh ' * 7}',
            caption: 'Dòng một 🌸\nDòng hai\nDòng ba ${'rất dài ' * 12}\n4\n5',
          ),
        ],
      ),
      width: 360,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state keeps its copy', (tester) async {
    await _pump(tester, const FeedState());
    expect(
      find.text(
        'Chưa có khoảnh khắc nào\nHãy chụp ảnh hoặc kết bạn để bắt đầu.',
      ),
      findsOneWidget,
    );
    final feed = find.byType(FeedScreen);
    expect(
      find.descendant(of: feed, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('degraded banner keeps its copy', (tester) async {
    await _pump(tester, FeedState(items: [_post('1')], degraded: true));
    expect(
      find.text('Một phần dịch vụ đang chậm. Feed có thể chưa đầy đủ.'),
      findsOneWidget,
    );
  });

  test('tilt angles in degrees convert as expected', () {
    expect(WashiPhotoCard.tiltFor(1) * math.pi / 180, closeTo(.0209, .0001));
  });
}
