import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/friends/domain/friends_repository.dart';
import 'package:animal_locket/features/friends/presentation/friends_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(friendsControllerProvider);
    return AppPage(
      title: 'Bạn bè và lời mời',
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: ref.read(friendsControllerProvider.notifier).refresh,
            child: const Text('Không tải được · Thử lại'),
          ),
        ),
        data: (data) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: 'Bạn bè ${data.friends.length}'),
                  Tab(text: 'Lời mời ${data.incoming.length}'),
                  Tab(text: 'Đã gửi ${data.outgoing.length}'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.sizeOf(context).height - 220,
                child: TabBarView(
                  children: [
                    _FriendList(data: data),
                    _RequestList(
                      items: data.incoming,
                      incoming: true,
                      busyId: data.busyId,
                    ),
                    _RequestList(
                      items: data.outgoing,
                      incoming: false,
                      busyId: data.busyId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendList extends ConsumerWidget {
  const _FriendList({required this.data});
  final FriendsState data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ListShell(
    empty: 'Chưa có bạn bè.',
    count: data.friends.length,
    builder: (index) {
      final person = data.friends[index];
      return _PersonTile(
        person: person,
        subtitle: data.online[person.publicId] == true
            ? 'Đang online'
            : 'Ngoại tuyến',
        onTap: () => context.push('/user/${person.publicId}'),
        trailing: IconButton(
          onPressed: () => context.push('/user/${person.publicId}'),
          icon: const Icon(Icons.more_horiz),
        ),
      );
    },
  );
}

class _RequestList extends ConsumerWidget {
  const _RequestList({
    required this.items,
    required this.incoming,
    required this.busyId,
  });
  final List<FriendRequest> items;
  final bool incoming;
  final String? busyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ListShell(
    empty: incoming ? 'Không có lời mời mới.' : 'Bạn chưa gửi lời mời nào.',
    count: items.length,
    builder: (index) {
      final request = items[index];
      final busy = busyId == request.id;
      return _PersonTile(
        person: request.user,
        subtitle: 'Không hiển thị khoảng cách để bảo vệ riêng tư',
        onTap: () => context.push('/user/${request.user.publicId}'),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(),
              )
            : incoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Chấp nhận',
                    onPressed: () => ref
                        .read(friendsControllerProvider.notifier)
                        .accept(request.id),
                    icon: const Icon(Icons.check),
                  ),
                  IconButton(
                    tooltip: 'Từ chối',
                    onPressed: () => ref
                        .read(friendsControllerProvider.notifier)
                        .decline(request.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            : TextButton(
                onPressed: () => ref
                    .read(friendsControllerProvider.notifier)
                    .cancel(request.id),
                child: const Text('Huỷ'),
              ),
      );
    },
  );
}

class _ListShell extends StatelessWidget {
  const _ListShell({
    required this.empty,
    required this.count,
    required this.builder,
  });
  final String empty;
  final int count;
  final Widget Function(int) builder;
  @override
  Widget build(BuildContext context) => count == 0
      ? Center(
          child: Text(empty, style: const TextStyle(color: AppColors.muted)),
        )
      : ListView.separated(
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => builder(index),
        );
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });
  final PublicProfile person;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => GlassContainer(
    onTap: onTap,
    child: Row(
      children: [
        AnimalAvatar(
          avatar: person.avatar,
          leadAnimal: person.leadAnimal,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.displayAlias,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
