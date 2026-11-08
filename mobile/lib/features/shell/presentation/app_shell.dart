import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/features/shell/presentation/washi_nav_bar.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: WashiNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          WashiNavItem(icon: AlbumIcons.photos, label: l10n.photosTab),
          WashiNavItem(icon: AlbumIcons.feed, label: l10n.feedTab),
          WashiNavItem(icon: AlbumIcons.discover, label: l10n.discoverTab),
          WashiNavItem(icon: AlbumIcons.chat, label: l10n.chatTab),
          WashiNavItem(icon: AlbumIcons.profile, label: l10n.profileTab),
        ],
      ),
    );
  }
}
