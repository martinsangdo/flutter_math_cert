import 'package:flutter/material.dart';

/// Freehand drawing layer for working out calculations. Strokes stay visible
/// when [enabled] is false but no longer capture touches. Key it per question
/// to start with a blank sheet.
class ScratchPad extends StatefulWidget {
  const ScratchPad({super.key, required this.enabled});

  final bool enabled;

  @override
  State<ScratchPad> createState() => _ScratchPadState();
}

class _ScratchPadState extends State<ScratchPad> {
  final _strokes = <List<Offset>>[];
  final _repaint = ValueNotifier<int>(0);

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  void _touch() => _repaint.value++;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.enabled,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                _strokes.add([d.localPosition]);
                _touch();
              },
              onPanUpdate: (d) {
                _strokes.last.add(d.localPosition);
                _touch();
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _StrokePainter(_strokes, _repaint, color.primary),
                  child: widget.enabled
                      ? ColoredBox(color: color.primary.withValues(alpha: 0.05))
                      : null,
                ),
              ),
            ),
          ),
        ),
        if (widget.enabled)
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonalIcon(
              onPressed: () {
                _strokes.clear();
                _touch();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear'),
            ),
          ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes, Listenable repaint, Color color)
      : _line = Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
        super(repaint: repaint);

  final List<List<Offset>> strokes;
  final Paint _line;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.5, _line..style = PaintingStyle.fill);
        _line.style = PaintingStyle.stroke;
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final p in s.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, _line);
      }
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => old._line.color != _line.color;
}
