import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/album/paper_button.dart';
import 'package:animal_locket/core/widgets/album/paper_list.dart';
import 'package:animal_locket/core/widgets/album/paper_tile_button.dart';
import 'package:animal_locket/core/widgets/album/polaroid.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/text_input_dialog.dart';
import 'package:animal_locket/features/feed/presentation/posts_grid.dart';
import 'package:animal_locket/features/friends/presentation/friends_controller.dart';
import 'package:animal_locket/features/profile/presentation/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animal_locket/core/l10n/tr.dart';

/// Hồ sơ của tôi như một trang album (spec §7.7).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(profileControllerProvider);
    return AppPage(
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: PaperButton(
            label: context.l10n.loadFailedRetry,
            onPressed: ref.read(profileControllerProvider.notifier).refresh,
          ),
        ),
        data: (data) => _ProfileContent(data: data),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.data});
  final ProfileData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final heading = Theme.of(context).textTheme.headlineMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PaperTileButton(
            icon: AlbumIcons.settings,
            label: context.l10n.settings,
            size: 48,
            onPressed: () => context.push('/settings'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Polaroid(
              width: 124,
              tiltDegrees: -4,
              caption: '',
              child: AnimalAvatar(
                avatar: data.profile.avatar,
                leadAnimal: data.profile.leadAnimal,
                size: 124,
                square: true,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.profile.displayAlias,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PaperTileButton(
                        icon: AlbumIcons.edit,
                        label: context.l10n.changeNickname,
                        size: 48,
                        onPressed: () => _editAlias(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.profile.plan == AccountPlan.pro
                        ? context.l10n.memberPro
                        : context.l10n.memberFree,
                    style: TextStyle(color: p.muted),
                  ),
                  const SizedBox(height: 16),
                  TapedNote(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${data.avatars.length}',
                            style: TextStyle(
                              color: p.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          TextSpan(
                            text: '  ${context.l10n.ownedAvatars}',
                            style: TextStyle(color: p.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _FriendsStrip(),
        const SizedBox(height: 24),
        Text(context.l10n.myPhotos, style: heading),
        const SizedBox(height: 12),
        PostsGrid(
          publicId: data.profile.publicId,
          mine: true,
          emptyText: context.l10n.noMyPhotos,
        ),
        const SizedBox(height: 24),
        Text(context.l10n.collection, style: heading),
        const SizedBox(height: 6),
        Text(
          context.l10n.collectionNote,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        // Album sticker: mỗi avatar là một polaroid nhỏ có tên con vật.
        Wrap(
          spacing: 14,
          runSpacing: 18,
          children: [
            for (final (i, owned) in data.avatars.indexed)
              Polaroid(
                width: 92,
                tiltDegrees: i.isEven ? -2.5 : 2,
                caption:
                    AvatarLibraries.instance.animalName(owned.avatar) ?? '',
                child: AnimalAvatar(
                  avatar: owned.avatar,
                  size: 92,
                  square: true,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (data.profile.ageGroup == AgeGroup.adult &&
            data.profile.plan != AccountPlan.pro)
          PaperButton(
            label: context.l10n.discoverPro,
            icon: AlbumIcons.bolt,
            onPressed: () => context.push('/pro'),
          ),
      ],
    );
  }

  Future<void> _editAlias(BuildContext context, WidgetRef ref) async {
    final alias = await showDialog<String>(
      context: context,
      builder: (_) => TextInputDialog(
        title: context.l10n.changeNickname,
        label: context.l10n.nicknameLabel,
        confirmLabel: context.l10n.save,
        initialText: data.profile.alias ?? '',
        maxLength: 20, // server: 3–20 ký tự
      ),
    );
    if (alias == null ||
        alias.trim().isEmpty ||
        alias.trim() == data.profile.alias) {
      return;
    }
    try {
      await ref.read(profileControllerProvider.notifier).updateAlias(alias);
    } on ApiProblem catch (problem) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messageForApiCode(problem.code, status: problem.status),
            ),
          ),
        );
      }
    }
  }
}

/// Hàng polaroid bạn bè cuộn ngang; chạm một người để mở trang của họ.
class _FriendsStrip extends ConsumerWidget {
  const _FriendsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final friends = ref.watch(friendsControllerProvider);
    final count = friends.value?.friends.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                count == null
                    ? context.l10n.friendsLabel
                    : context.l10n.friendsCount(count),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            PaperButton.tape(
              label: context.l10n.seeAll,
              onPressed: () => context.push('/friends'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        friends.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => PaperButton.tape(
            label: context.l10n.friendsLoadFailed,
            onPressed: () => ref.invalidate(friendsControllerProvider),
          ),
          data: (data) => data.friends.isEmpty
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.noFriendsYet,
                        style: TextStyle(color: p.muted),
                      ),
                    ),
                    PaperButton.tape(
                      label: context.l10n.findFriends,
                      onPressed: () => context.go('/discover'),
                    ),
                  ],
                )
              : SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: data.friends.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final person = data.friends[index];
                      return Semantics(
                        button: true,
                        label: context.l10n.openProfileOf(person.displayAlias),
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => context.push('/user/${person.publicId}'),
                          child: SizedBox(
                            width: 72,
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    MiniPolaroidAvatar(
                                      avatar: person.avatar,
                                      leadAnimal: person.leadAnimal,
                                      index: index,
                                    ),
                                    if (data.online[person.publicId] == true)
                                      Positioned(
                                        right: -3,
                                        bottom: 4,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: onlineGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: p.paper,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  person.displayAlias,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
