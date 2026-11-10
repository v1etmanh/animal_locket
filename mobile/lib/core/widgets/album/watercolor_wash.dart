import 'dart:math' as math;

import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:flutter/material.dart';

/// Giọt màu nước: mép tròn không đều, tâm nhạt, viền đọng sắc như màu khô lại. Màu lấy hoàn toàn từ palette đang chọn nên đổi theme
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
        painter: _WashPainter(base: p.tape1, pigment: p.accent, seed: seed),
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  const _WashPainter({
    required this.base,
    required this.pigment,
    required this.seed,
  });
  final Color base;
  final Color pigment;
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
    final r = Size(size.width / 2 - 1, size.height / 2 - 1);
    // Một giọt màu nước: tâm nhạt, sắc tố dạt ra và đọng thành viền đậm
    // (hiệu ứng "backrun"), mép ngoài tan dần vào giấy.
    canvas.drawPath(
      _blob(c, r, rnd, .14),
      Paint()
        ..shader = RadialGradient(
          colors: [
            base.withValues(alpha: .25),
            base.withValues(alpha: .55),
            pigment.withValues(alpha: .28),
            base.withValues(alpha: 0),
          ],
          stops: const [0, .72, .92, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WashPainter o) =>
      o.base != base || o.pigment != pigment || o.seed != seed;
}
