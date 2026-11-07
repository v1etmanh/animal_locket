import 'package:animal_locket/features/chat/domain/glyph.dart';
import 'package:flutter/material.dart';

class GlyphDrawingPad extends StatefulWidget {
  const GlyphDrawingPad({
    super.key,
    required this.semanticsLabel,
    required this.hint,
    required this.clearLabel,
    required this.onStrokeComplete,
    this.color = const Color(0xFF818CF8),
    this.initialPoints = const [],
    this.height = 170,
  });

  final String semanticsLabel;
  final String hint;
  final String clearLabel;
  final ValueChanged<List<GlyphPoint>> onStrokeComplete;
  final Color color;
  final List<GlyphPoint> initialPoints;
  final double height;

  @override
  State<GlyphDrawingPad> createState() => _GlyphDrawingPadState();
}

class _GlyphDrawingPadState extends State<GlyphDrawingPad> {
  late List<GlyphPoint> _points = [...widget.initialPoints];

  void _start(DragStartDetails details) {
    setState(
      () => _points = [
        GlyphPoint(details.localPosition.dx, details.localPosition.dy),
      ],
    );
  }

  void _update(DragUpdateDetails details) {
    final point = GlyphPoint(
      details.localPosition.dx,
      details.localPosition.dy,
    );
    if (_points.isNotEmpty && _points.last.distanceTo(point) < 2) return;
    setState(() => _points = [..._points, point]);
  }

  void _end(DragEndDetails _) {
    if (_points.length >= 2) {
      widget.onStrokeComplete(List.unmodifiable(_points));
    }
  }

  void _clear() {
    setState(() => _points = []);
    widget.onStrokeComplete(const []);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticsLabel,
    container: true,
    explicitChildNodes: true,
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.4,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _start,
                onPanUpdate: _update,
                onPanEnd: _end,
                child: CustomPaint(
                  painter: GlyphStrokePainter(_points, widget.color),
                  child: _points.isEmpty
                      ? Center(
                          child: Text(
                            widget.hint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Semantics(
                button: true,
                label: widget.clearLabel,
                child: IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  tooltip: widget.clearLabel,
                  onPressed: _points.isEmpty ? null : _clear,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GlyphStrokePainter extends CustomPainter {
  const GlyphStrokePainter(this.points, this.color);

  final List<GlyphPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GlyphStrokePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class GlyphIcon extends StatelessWidget {
  const GlyphIcon({
    super.key,
    required this.glyph,
    this.size = 36,
    this.strokeWidth = 4,
  });

  final GlyphDefinition glyph;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => Semantics(
    label: glyph.meaning,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _NormalizedGlyphPainter(
          glyph.points,
          Color(glyph.colorArgb),
          strokeWidth,
        ),
      ),
    ),
  );
}

class _NormalizedGlyphPainter extends CustomPainter {
  const _NormalizedGlyphPainter(this.points, this.color, this.strokeWidth);

  final List<GlyphPoint> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final padding = size.shortestSide * .14;
    final usable = size.shortestSide - padding * 2;
    Offset map(GlyphPoint point) => Offset(
      padding + ((point.x + 1) / 2) * usable,
      padding + ((point.y + 1) / 2) * usable,
    );

    final first = map(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final mapped = map(point);
      path.lineTo(mapped.dx, mapped.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_NormalizedGlyphPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
