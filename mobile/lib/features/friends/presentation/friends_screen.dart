import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/album/hanko_stamp.dart';
import 'package:animal_locket/core/widgets/album/paper_button.dart';
import 'package:animal_locket/core/widgets/album/paper_list.dart';
import 'package:animal_locket/core/widgets/album/paper_tile_button.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/features/friends/domain/friends_repository.dart';
import 'package:animal_locket/features/friends/presentation/friends_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Xanh lá sẫm cho "Đang online" (đạt AA trên nền giấy).
const _onlineGreen = Color(0xFF2F6B3A);

/// Bạn bè và lời mời như một cuốn sổ địa chỉ: tab giấy + trang kẻ (spec §7.5).
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final value = ref.watch(friendsControllerProvider);
    return AppPage(
      title: 'Bạn bè và lời mời',
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: PaperButton(
            label: 'Không tải được · Thử lại',
            onPressed: ref.read(friendsControllerProvider.notifier).refresh,
          ),
        ),
        data: (data) => DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab giấy như mép sổ: tab đang chọn cùng màu trang giấy bên dưới.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.fold1,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: TabBar(
                  // Cuộn ngang khi chữ to để số đếm trên tab không bị mờ mất.
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: p.paper,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  labelColor: p.accent,
                  unselectedLabelColor: p.muted,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'Bạn bè ${data.friends.length}'),
                    Tab(text: 'Lời mời ${data.incoming.length}'),
                    Tab(text: 'Đã gửi ${data.outgoing.length}'),
                  ],
                ),
              ),
              Expanded(
                child: PaperSheet(
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    return _ListShell(
      empty: 'Chưa có bạn bè.',
      count: data.friends.length,
      builder: (index) {
        final person = data.friends[index];
        final online = data.online[person.publicId] == true;
        void open() => context.push('/user/${person.publicId}');
        return _PersonTile(
          person: person,
          index: index,
          subtitle: online ? 'Đang online' : 'Ngoại tuyến',
          subtitleColor: online ? _onlineGreen : p.muted,
          online: online,
          onTap: open,
          trailing: Semantics(
            label: 'Xem hồ sơ',
            button: true,
            excludeSemantics: true,
            onTap: open,
            child: IconButton(
              onPressed: open,
              icon: AlbumIcon(AlbumIcons.more, color: p.muted),
            ),
          ),
        );
      },
    );
  }
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final controller = ref.read(friendsControllerProvider.notifier);
    return _ListShell(
      empty: incoming ? 'Không có lời mời mới.' : 'Bạn chưa gửi lời mời nào.',
      count: items.length,
      builder: (index) {
        final request = items[index];
        final busy = busyId == request.id;
        return _PersonTile(
          person: request.user,
          index: index,
          subtitle: 'Không hiển thị khoảng cách để bảo vệ riêng tư',
          subtitleColor: p.muted,
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
                    HankoStamp(
                      stamped: true,
                      toggle: false,
                      mark: AlbumIcons.check,
                      tooltip: 'Chấp nhận',
                      size: 38,
                      onPressed: () => controller.accept(request.id),
                    ),
                    const SizedBox(width: 4),
                    PaperTileButton(
                      icon: AlbumIcons.close,
                      label: 'Từ chối',
                      size: 48,
                      onPressed: () => controller.decline(request.id),
                    ),
                  ],
                )
              : PaperButton.tape(
                  label: 'Huỷ',
                  onPressed: () => controller.cancel(request.id),
                ),
        );
      },
    );
  }
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
  Widget build(BuildContext context) {
    final p = context.album;
    return count == 0
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted),
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: count,
            // Trang kẻ: các dòng cách nhau bằng gạch đứt.
            separatorBuilder: (_, _) => const DashedDivider(),
            itemBuilder: (_, index) => builder(index),
          );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.index,
    required this.subtitle,
    required this.subtitleColor,
    required this.onTap,
    required this.trailing,
    this.online = false,
  });
  final PublicProfile person;
  final bool online;
  final int index;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onTap;
  final Widget trailing;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            MiniPolaroidAvatar(
              avatar: person.avatar,
              leadAnimal: person.leadAnimal,
              index: index,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayAlias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      if (online) ...[
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: _onlineGreen,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(dimension: 7),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(color: subtitleColor, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing,
          ],
        ),
      ),
    );
  }
}
