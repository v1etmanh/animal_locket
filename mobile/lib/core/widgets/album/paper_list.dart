import 'dart:math' as math;

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:flutter/material.dart';

/// Gạch đứt ngăn các dòng trên trang giấy kẻ (sổ bạn bè, danh sách chat, từ điển).
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.fromHeight(1),
    painter: _DashedLinePainter(context.album.fold2),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 5, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Avatar polaroid nhỏ trong danh sách, nghiêng xen kẽ theo [index].
class MiniPolaroidAvatar extends StatelessWidget {
  const MiniPolaroidAvatar({
    super.key,
    required this.avatar,
    required this.leadAnimal,
    required this.index,
  });

  final String? avatar;
  final String? leadAnimal;
  final int index;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: (index.isEven ? -3 : 2.5) * math.pi / 180,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335A3C1E),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: context.album.fold1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 8),
        child: AnimalAvatar(
          avatar: avatar,
          leadAnimal: leadAnimal,
          size: 44,
          square: true,
        ),
      ),
    ),
  );
}

/// Tab giấy như mép sổ: tab đang chọn cùng màu trang giấy bên dưới.
/// Dùng trong một [DefaultTabController].
class PaperTabBar extends StatelessWidget {
  const PaperTabBar({super.key, required this.tabs});
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.fold1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: TabBar(
        // Cuộn ngang khi chữ to để chữ trên tab không bị cắt.
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: p.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        labelColor: p.accent,
        unselectedLabelColor: p.muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [for (final t in tabs) Tab(text: t)],
      ),
    );
  }
}

/// Trang giấy có bóng mềm làm nền cho một danh sách.
class PaperSheet extends StatelessWidget {
  const PaperSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.album.paper,
      boxShadow: const [
        BoxShadow(
          color: Color(0x225A3C1E),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}
