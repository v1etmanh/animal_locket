import 'dart:math' as math;

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:flutter/material.dart';

/// Vệt màu nước: vài lớp trong mờ chồng lên nhau, mép không đều như màu thấm
/// giấy, đậm dần về tâm. Màu lấy hoàn toàn từ palette đang chọn nên đổi theme
/// là đổi màu theo; không dùng blur hay bóng. [seed] cố định hình dạng.
class WatercolorWash extends StatelessWidget {
  const WatercolorWash({super.key, required this.size, this.seed = 0});
  final Size size;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _WashPainter(
          base: p.tape1,
          pigment: p.accent,
          highlight: p.accentSoft,
          seed: seed,
        ),
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  const _WashPainter({
    required this.base,
    required this.pigment,
    required this.highlight,
    required this.seed,
  });
  final Color base;
  final Color pigment;
  final Color highlight;
  final int seed;

  /// Đường cong mượt khép kín quanh [center]; bán kính mỗi điểm lệch ngẫu nhiên
  /// trong [jitter] để mép nham nhở tự nhiên.
  Path _blob(Offset center, Size radius, math.Random rnd, double jitter) {
    const n = 11;
    final pts = [
      for (var i = 0; i < n; i++)
        center +
            Offset(
              math.cos(i * 2 * math.pi / n) *
                  radius.width *
                  (1 - jitter * rnd.nextDouble()),
              math.sin(i * 2 * math.pi / n) *
                  radius.height *
                  (1 - jitter * rnd.nextDouble()),
            ),
    ];
    Offset mid(int a) => (pts[a % n] + pts[(a + 1) % n]) / 2;
    final path = Path()..moveTo(mid(0).dx, mid(0).dy);
    for (var i = 1; i <= n; i++) {
      path.quadraticBezierTo(
        pts[i % n].dx,
        pts[i % n].dy,
        mid(i).dx,
        mid(i).dy,
      );
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed * 97 + 13);
    final c = size.center(Offset.zero);
    final r = Size(size.width / 2 - 2, size.height / 2 - 2);

    // Lớp nền rộng: màu washi nhạt dần ra mép.
    final main = _blob(c, r, rnd, .32);
    canvas.drawPath(
      main,
      Paint()
        ..shader = RadialGradient(
          colors: [base.withValues(alpha: .62), base.withValues(alpha: .2)],
        ).createShader(Offset.zero & size),
    );
    // Mép đọng sắc tố: viền mảnh hơi đậm hơn như màu nước khô lại.
    canvas.drawPath(
      main,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base.withValues(alpha: .35),
    );
    // Lớp sắc tố nhỏ lệch tâm, chồng lên để tạo chuyển màu.
    canvas.drawPath(
      _blob(
        c + Offset(size.width * .08, -size.height * .06),
        Size(r.width * .62, r.height * .6),
        rnd,
        .4,
      ),
      Paint()..color = pigment.withValues(alpha: .13),
    );
    // Lớp sáng ở góc đối diện cho cảm giác loang chồng.
    canvas.drawPath(
      _blob(
        c - Offset(size.width * .14, -size.height * .1),
        Size(r.width * .45, r.height * .5),
        rnd,
        .45,
      ),
      Paint()..color = highlight.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(_WashPainter o) =>
      o.base != base ||
      o.pigment != pigment ||
      o.highlight != highlight ||
      o.seed != seed;
}
