import 'package:animal_locket/core/assets/animal_asset_resolver.dart';
import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Avatar con vật. Có [avatar] ("v:animal:palette:accessory") thì vẽ SVG từ thư viện;
/// không có hoặc chưa tải được thư viện thì dùng emoji của [leadAnimal] / [emoji].
class AnimalAvatar extends StatelessWidget {
  const AnimalAvatar({
    super.key,
    this.emoji,
    this.avatar,
    this.leadAnimal,
    this.size = 64,
    this.colorIndex = 0,
    this.locked = false,
    this.square = false,
  });

  final String? emoji;
  final String? avatar;
  final String? leadAnimal;
  final double size;
  final int colorIndex;
  final bool locked;

  /// Vẽ vuông (trong khung polaroid) thay vì cắt tròn.
  final bool square;

  @override
  Widget build(BuildContext context) {
    if (locked || avatar == null) return _fallback();
    final libs = AvatarLibraries.instance;
    return ValueListenableBuilder<int>(
      valueListenable: libs.revision,
      builder: (context, _, _) {
        final svg = libs.svgFor(avatar);
        if (svg == null) return _fallback();
        final name = libs.animalName(avatar);
        return Semantics(
          image: true,
          label: name == null ? 'Ảnh đại diện con vật' : 'Ảnh đại diện: $name',
          child: square
              ? SvgPicture.string(svg, width: size, height: size)
              : ClipOval(
                  child: SvgPicture.string(
                    svg,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                ),
        );
      },
    );
  }

  Widget _fallback() {
    final glyph =
        emoji ??
        AnimalAssetResolver.emoji(
          leadAnimal ?? AvatarCode.tryParse(avatar)?.animal,
        );
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
          locked ? '?' : glyph,
          style: TextStyle(fontSize: size * .52, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
