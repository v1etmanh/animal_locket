import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:flutter/material.dart';

/// Tờ ảnh trắng có 4 góc dán ảnh như album cũ (spec §7.4). Không bo góc.
class PhotoCornersFrame extends StatelessWidget {
  const PhotoCornersFrame({super.key, required this.child, this.border = 10});

  final Widget child;
  final double border;

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return CustomPaint(
      foregroundPainter: PhotoCornersPainter(p.ink),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.paper,
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E5A3C1E),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(border),
          child: ClipRect(child: child),
        ),
      ),
    );
  }
}

/// Góc dán ảnh: tam giác mực ở mỗi góc, tràn ra ngoài mép một chút.
class PhotoCornersPainter extends CustomPainter {
  const PhotoCornersPainter(this.color);
  final Color color;

  static const _size = 24.0;
  static const _out = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .86);
    final w = size.width, h = size.height;
    const s = _size, o = _out;
    for (final corner in [
      [const Offset(-o, -o), const Offset(s - o, -o), const Offset(-o, s - o)],
      [Offset(w + o, -o), Offset(w + o, s - o), Offset(w - s + o, -o)],
      [Offset(-o, h + o), Offset(-o, h - s + o), Offset(s - o, h + o)],
      [
        Offset(w + o, h + o),
        Offset(w - s + o, h + o),
        Offset(w + o, h - s + o),
      ],
    ]) {
      canvas.drawPath(Path()..addPolygon(corner, true), paint);
    }
  }

  @override
  bool shouldRepaint(PhotoCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}
