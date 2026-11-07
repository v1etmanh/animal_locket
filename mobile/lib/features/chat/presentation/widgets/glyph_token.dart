import 'package:animal_locket/features/chat/domain/glyph.dart';
import 'package:animal_locket/features/chat/presentation/widgets/glyph_drawing_pad.dart';
import 'package:flutter/material.dart';

class GlyphToken extends StatelessWidget {
  const GlyphToken({
    super.key,
    required this.glyph,
    required this.removeLabel,
    this.onRemove,
  });

  final GlyphDefinition glyph;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    label: glyph.meaning,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: Color(glyph.colorArgb).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(glyph.colorArgb).withValues(alpha: .4)),
      ),
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphIcon(glyph: glyph, size: 30, strokeWidth: 3.5),
          if (onRemove != null)
            Semantics(
              button: true,
              label: removeLabel,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                tooltip: removeLabel,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
      ),
    ),
  );
}
