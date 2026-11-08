import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/features/feed/data/post_repository_impl.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ảnh tôi đã đăng (gồm cả bài đang xử lý / bị từ chối), mới nhất trước.
final myPostsProvider = FutureProvider<List<Post>>(
  (ref) => ref.watch(postRepositoryProvider).mine(limit: 50),
);

/// Lưới 3 cột các ảnh tôi đã đăng; chạm vào một ảnh để xem lớn và xoá.
class MyPostsGrid extends ConsumerWidget {
  const MyPostsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myPostsProvider);
    return posts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(myPostsProvider),
        child: const Text('Không tải được ảnh · Thử lại'),
      ),
      data: (items) {
        final visible = items
            .where((post) => post.status != PostStatus.deleted)
            .toList();
        if (visible.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Bạn chưa đăng ảnh nào.',
              style: TextStyle(color: AppColors.muted),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) => _Thumbnail(post: visible[index]),
        );
      },
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = switch (post.status) {
      PostStatus.pendingMedia => (Icons.hourglass_top, 'Đang xử lý'),
      PostStatus.rejected => (Icons.block, 'Bị từ chối'),
      _ => null,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _PostDialog(post: post),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            post.status == PostStatus.published
                ? _PostImage(mediaId: post.mediaId)
                : const ColoredBox(color: AppColors.border),
            if (overlay != null)
              ColoredBox(
                color: Colors.black.withValues(alpha: .35),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(overlay.$1, color: Colors.white, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      overlay.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostImage extends ConsumerWidget {
  const _PostImage({required this.mediaId});
  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(mediaUrlProvider(mediaId));
    return url.when(
      loading: () => const ColoredBox(
        color: AppColors.border,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const ColoredBox(
        color: AppColors.border,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
      data: (value) => value == null
          ? const ColoredBox(
              color: AppColors.border,
              child: Center(child: Icon(Icons.image_outlined)),
            )
          : Image.network(
              value,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
    );
  }
}

class _PostDialog extends ConsumerWidget {
  const _PostDialog({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = (post.publishedAt ?? post.createdAt).toLocal();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: post.status == PostStatus.published
                ? _PostImage(mediaId: post.mediaId)
                : ColoredBox(
                    color: AppColors.border,
                    child: Center(
                      child: Text(
                        post.status == PostStatus.rejected
                            ? 'Ảnh bị từ chối'
                            : 'Ảnh đang được xử lý',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 16, color: AppColors.danger),
                const SizedBox(width: 4),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline, size: 16),
                const SizedBox(width: 4),
                Text('${post.commentCount}'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formatPostDay(time),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Xoá ảnh',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá ảnh này?'),
        content: const Text('Bạn bè sẽ không còn thấy ảnh này nữa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(postRepositoryProvider).deletePost(post.id);
      ref
        ..invalidate(myPostsProvider)
        ..invalidate(feedControllerProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xoá được ảnh. Thử lại sau.')),
        );
      }
    }
  }
}

/// "Hôm nay", "Hôm qua" hoặc "dd/MM/yyyy" theo giờ máy.
String formatPostDay(DateTime local) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
