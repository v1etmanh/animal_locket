import 'dart:math' as math;

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _themeNames = {
  AlbumThemeId.shu: 'Shu · Son đỏ',
  AlbumThemeId.yuzu: 'Yuzu · Vàng thanh yên',
  AlbumThemeId.sakura: 'Sakura · Hồng anh đào',
  AlbumThemeId.sora: 'Sora · Trời xanh',
};

/// Chọn một trong bốn bảng màu; bấm là áp dụng ngay và lưu trên máy.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(albumThemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Màu giao diện'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            for (final id in AlbumThemeId.values)
              _ThemeTile(
                id: id,
                selected: id == current,
                onTap: () => ref.read(albumThemeProvider.notifier).select(id),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final AlbumThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final own = AlbumPalette.of(id);
    final active = context.album;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? active.accent : active.fold1,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        for (final c in [
                          own.background,
                          own.fold1,
                          own.tape1,
                          own.accent,
                        ])
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: active.fold1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _themeNames[id]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: -8,
                  right: 14,
                  child: Transform.rotate(
                    angle: 6 * math.pi / 180,
                    child: Opacity(
                      opacity: .8,
                      child: Container(width: 34, height: 14, color: own.tape1),
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
