import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:animal_locket/features/feed/presentation/my_posts_grid.dart';
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
      actions: [
        IconButton(
          tooltip: 'Bạn bè',
          onPressed: () => context.push('/friends'),
          icon: const Icon(Icons.group_outlined),
        ),
      ],
      child: feed.when(
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
                    shrinkWrap: true,
                    itemCount: data.items.length + (data.loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == data.items.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final day = _dayLabel(data.items[index]);
                      final newDay =
                          index == 0 || day != _dayLabel(data.items[index - 1]);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0 && data.degraded)
                            const _DegradedBanner(),
                          if (newDay)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 10,
                                left: 4,
                              ),
                              child: Text(
                                day,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          _PostCard(post: data.items[index]),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
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
          const Icon(Icons.cloud_off_outlined, size: 46),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
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
    children: const [
      SizedBox(height: 140),
      Icon(Icons.photo_library_outlined, size: 58, color: AppColors.muted),
      SizedBox(height: 14),
      Text(
        'Chưa có khoảnh khắc nào\nHãy chụp ảnh hoặc kết bạn để bắt đầu.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _DegradedBanner extends StatelessWidget {
  const _DegradedBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.orangeLight.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Một phần dịch vụ đang chậm. Feed có thể chưa đầy đủ.',
      textAlign: TextAlign.center,
    ),
  );
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(mediaUrlProvider(post.mediaId));
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: AnimalAvatar(
              avatar: post.author.avatar,
              leadAnimal: post.author.leadAnimal,
              size: 40,
            ),
            title: Text(post.author.displayAlias),
            subtitle: Text(_relativeTime(post.createdAt)),
            onTap: () => context.push('/user/${post.author.publicId}'),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: image.when(
              loading: () => const ColoredBox(
                color: AppColors.border,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const ColoredBox(
                color: AppColors.border,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
              data: (url) => url == null
                  ? const ColoredBox(
                      color: AppColors.border,
                      child: Center(child: Icon(Icons.image_outlined)),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          if (post.caption?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(post.caption!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: post.likedByMe ? 'Bỏ thích' : 'Thích',
                  onPressed: () => ref
                      .read(feedControllerProvider.notifier)
                      .toggleLike(post.id),
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe ? AppColors.danger : null,
                  ),
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline, size: 21),
                const SizedBox(width: 6),
                Text('${post.commentCount}'),
              ],
            ),
          ),
        ],
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
