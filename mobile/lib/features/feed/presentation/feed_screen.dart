import 'dart:math' as math;

import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:animal_locket/core/widgets/album/hanko_stamp.dart';
import 'package:animal_locket/core/widgets/album/washi_photo_card.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:animal_locket/features/feed/presentation/posts_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    return AppPage(
      title: 'Khoảnh khắc',
      // Danh sách tự cuộn; AppPage cuộn thêm một lớp sẽ nuốt thao tác vuốt.
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actions: [
        IconButton(
          tooltip: 'Bạn bè',
          onPressed: () => context.push('/friends'),
          icon: const AlbumIcon(AlbumIcons.friends),
        ),
      ],
      child: Stack(
        children: [
          // Chữ Nhật dọc trang trí ở lề phải, nằm dưới các thẻ ảnh.
          Positioned(
            right: -16,
            top: 4,
            child: DecoSvg(
              KanjiDeco.vertical(ref.watch(albumThemeProvider)),
              height: 140,
            ),
          ),
          feed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _FeedError(error: error),
            data: (data) => RefreshIndicator(
              onRefresh: ref.read(feedControllerProvider.notifier).refresh,
              child: data.items.isEmpty
                  ? const _EmptyFeed()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter < 500) {
                          ref.read(feedControllerProvider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Chừa chỗ cho thanh điều hướng nổi ở đáy (extendBody).
                        padding: const EdgeInsets.only(top: 14, bottom: 110),
                        itemCount:
                            data.items.length + (data.loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 26),
                        itemBuilder: (context, index) {
                          if (index == data.items.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final day = _dayLabel(data.items[index]);
                          final newDay =
                              index == 0 ||
                              day != _dayLabel(data.items[index - 1]);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (index == 0 && data.degraded)
                                const _DegradedBanner(),
                              if (newDay) _DayLabel(day),
                              Padding(
                                // Chừa lề cho góc nghiêng và băng washi.
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  12,
                                  10,
                                  0,
                                ),
                                child: _PostCard(
                                  post: data.items[index],
                                  index: index,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.title,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: context.album.muted,
      ),
    ),
  );
}

class _FeedError extends ConsumerWidget {
  const _FeedError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = error is ApiProblem
        ? messageForApiCode(
            (error as ApiProblem).code,
            status: (error as ApiProblem).status,
          )
        : 'Không thể tải feed. Vui lòng kiểm tra mạng.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AlbumIcon(AlbumIcons.cloudOff, size: 46, color: context.album.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ref.read(feedControllerProvider.notifier).refresh,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 140),
      Center(
        child: AlbumIcon(
          AlbumIcons.emptyAlbum,
          size: 58,
          color: context.album.muted,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Chưa có khoảnh khắc nào\nHãy chụp ảnh hoặc kết bạn để bắt đầu.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _DegradedBanner extends StatelessWidget {
  const _DegradedBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.fold1),
      ),
      child: const Text(
        'Một phần dịch vụ đang chậm. Feed có thể chưa đầy đủ.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post, required this.index});
  final Post post;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final image = ref.watch(mediaUrlProvider(post.mediaId));
    final tilt = WashiPhotoCard.tiltFor(index);
    Widget placeholder(Widget child) => ColoredBox(
      color: p.fold2,
      child: Center(child: child),
    );
    final caption = post.caption?.trim();
    Widget card(double t) => WashiPhotoCard(
      tiltDegrees: tilt * t,
      photo: image.when(
        loading: () => placeholder(const CircularProgressIndicator()),
        error: (_, _) =>
            placeholder(AlbumIcon(AlbumIcons.imageBroken, color: p.muted)),
        data: (url) => url == null
            ? placeholder(AlbumIcon(AlbumIcons.image, color: p.muted))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(
                  AlbumIcon(AlbumIcons.imageBroken, color: p.muted),
                ),
              ),
      ),
      header: InkWell(
        onTap: () => context.push('/user/${post.author.publicId}'),
        child: Row(
          children: [
            AnimalAvatar(
              avatar: post.author.avatar,
              leadAnimal: post.author.leadAnimal,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.displayAlias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _relativeTime(post.createdAt),
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      caption: caption?.isNotEmpty == true
          ? Text(
              post.caption!,
              style: TextStyle(
                fontFamily: AppFonts.hand,
                fontSize: 19,
                height: 1.25,
                color: p.ink,
              ),
            )
          : null,
      footer: Row(
        children: [
          HankoStamp(
            stamped: post.likedByMe,
            tooltip: post.likedByMe ? 'Bỏ thích' : 'Thích',
            onPressed: () =>
                ref.read(feedControllerProvider.notifier).toggleLike(post.id),
          ),
          Text('${post.likeCount}', style: TextStyle(color: p.muted)),
          const SizedBox(width: 16),
          AlbumIcon(AlbumIcons.comment, size: 21, color: p.muted),
          const SizedBox(width: 6),
          Text('${post.commentCount}', style: TextStyle(color: p.muted)),
        ],
      ),
    );

    // Thẻ hiện ra: trượt lên và nghiêng dần về góc của nó.
    if (MediaQuery.disableAnimationsOf(context)) return card(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Transform.translate(
        offset: Offset(0, 12 * (1 - t)),
        child: Opacity(opacity: math.min(1, .4 + t), child: card(t)),
      ),
    );
  }
}

String _dayLabel(Post post) =>
    formatPostDay((post.publishedAt ?? post.createdAt).toLocal());

String _relativeTime(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
  if (difference.inDays < 1) return '${difference.inHours} giờ trước';
  return '${difference.inDays} ngày trước';
}
