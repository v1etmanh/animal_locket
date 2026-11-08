import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/features/feed/data/post_repository_impl.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserPostsState {
  const UserPostsState({
    this.items = const [],
    this.nextBefore,
    this.loadingMore = false,
  });
  final List<Post> items;
  final String? nextBefore;
  final bool loadingMore;
}

/// Bài của một người, phân trang theo `before`. Tham số family là publicId.
class UserPostsController extends AsyncNotifier<UserPostsState> {
  UserPostsController(this.publicId);
  final String publicId;

  @override
  Future<UserPostsState> build() async {
    final page = await ref.read(postRepositoryProvider).postsOf(publicId);
    return UserPostsState(items: page.items, nextBefore: page.nextBefore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.nextBefore == null || current.loadingMore) {
      return;
    }
    state = AsyncData(
      UserPostsState(
        items: current.items,
        nextBefore: current.nextBefore,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .postsOf(publicId, before: current.nextBefore);
      state = AsyncData(
        UserPostsState(
          items: [...current.items, ...page.items],
          nextBefore: page.nextBefore,
        ),
      );
    } catch (_) {
      state = AsyncData(current);
    }
  }
}

/// `ref.invalidate(userPostsProvider)` làm mới lưới ảnh của mọi người (sau khi đăng/xoá).
final userPostsProvider =
    AsyncNotifierProvider.family<UserPostsController, UserPostsState, String>(
      UserPostsController.new,
    );

/// Lưới 3 cột ảnh của một người. [mine]: hiện cả bài đang xử lý/bị từ chối và cho xoá.
class PostsGrid extends ConsumerWidget {
  const PostsGrid({
    super.key,
    required this.publicId,
    this.mine = false,
    this.emptyText = 'Chưa có ảnh nào.',
  });
  final String publicId;
  final bool mine;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(userPostsProvider(publicId));
    return posts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => error is ApiProblem && error.status == 404
          ? const _Note('Kết bạn để xem ảnh của người này.')
          : TextButton(
              onPressed: () => ref.invalidate(userPostsProvider(publicId)),
              child: const Text('Không tải được ảnh · Thử lại'),
            ),
      data: (data) {
        final visible = data.items
            .where((post) => post.status != PostStatus.deleted)
            .toList();
        if (visible.isEmpty) return _Note(emptyText);
        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) =>
                  _Thumbnail(post: visible[index], mine: mine),
            ),
            if (data.nextBefore != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: data.loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: ref
                            .read(userPostsProvider(publicId).notifier)
                            .loadMore,
                        child: const Text('Xem thêm ảnh'),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.post, required this.mine});
  final Post post;
  final bool mine;

  @override
  Widget build(BuildContext context) {
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
          builder: (_) => _PostDialog(post: post, mine: mine),
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

class _PostDialog extends ConsumerStatefulWidget {
  const _PostDialog({required this.post, required this.mine});
  final Post post;
  final bool mine;

  @override
  ConsumerState<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends ConsumerState<_PostDialog> {
  late bool _liked = widget.post.likedByMe;
  late int _likes = widget.post.likeCount;

  Post get post => widget.post;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: _liked ? 'Bỏ thích' : 'Thích',
                  onPressed: post.status == PostStatus.published
                      ? _toggleLike
                      : null,
                  icon: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? AppColors.danger : null,
                  ),
                ),
                Text('$_likes'),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline, size: 18),
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
                if (widget.mine)
                  IconButton(
                    tooltip: 'Xoá ảnh',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: _delete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    final liked = !_liked;
    setState(() {
      _liked = liked;
      _likes += liked ? 1 : -1;
    });
    try {
      await ref.read(postRepositoryProvider).setLiked(post.id, liked);
      ref
        ..invalidate(userPostsProvider(post.author.publicId))
        ..invalidate(feedControllerProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !liked;
        _likes += liked ? -1 : 1;
      });
    }
  }

  Future<void> _delete() async {
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
        ..invalidate(userPostsProvider)
        ..invalidate(feedControllerProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
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
