import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AnimalAvatar extends StatelessWidget {
  const AnimalAvatar({
    super.key,
    required this.emoji,
    this.size = 64,
    this.colorIndex = 0,
    this.locked = false,
  });

  final String emoji;
  final double size;
  final int colorIndex;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: !locked,
      label: locked ? 'Con vật chưa mở khóa' : 'Ảnh đại diện con vật',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: locked
              ? Colors.transparent
              : AppColors.pastels[colorIndex % AppColors.pastels.length],
          border: locked ? Border.all(color: AppColors.border, width: 2) : null,
        ),
        child: Text(
          locked ? '?' : emoji,
          style: TextStyle(fontSize: size * .52, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
