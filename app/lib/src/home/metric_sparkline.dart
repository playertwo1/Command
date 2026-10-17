import 'package:flutter/material.dart';

/// Componente visual leve de sparkline (60s) para métricas de hardware (Command v0.2 - S5).
class MetricSparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final double strokeWidth;
  final double minY;
  final double maxY;
  final double height;
  final double? width;
  final bool showLastDot;

  const MetricSparkline({
    super.key,
    required this.values,
    this.lineColor = const Color(0xFFA78BFA),
    this.strokeWidth = 2.0,
    this.minY = 0.0,
    this.maxY = 100.0,
    this.height = 36.0,
    this.width,
    this.showLastDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          lineColor: lineColor,
          strokeWidth: strokeWidth,
          minY: minY,
          maxY: maxY,
          showLastDot: showLastDot,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final double strokeWidth;
  final double minY;
  final double maxY;
  final bool showLastDot;

  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.strokeWidth,
    required this.minY,
    required this.maxY,
    required this.showLastDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double range = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    double getY(double val) {
      final clamped = val.clamp(minY, maxY);
      final normalized = (clamped - minY) / range;
      // Inverte o eixo Y: 100% no topo (y=0), 0% na base (y=size.height)
      return size.height - (normalized * (size.height - strokeWidth)) - (strokeWidth / 2);
    }

    if (values.length == 1) {
      final y = getY(values.first);
      final p1 = Offset(0, y);
      final p2 = Offset(size.width, y);
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
      return;
    }

    final double stepX = size.width / (values.length - 1);

    final linePath = Path();
    final fillPath = Path();

    final firstY = getY(values.first);
    linePath.moveTo(0, firstY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, firstY);

    for (int i = 1; i < values.length; i++) {
      final x = i * stepX;
      final y = getY(values[i]);
      linePath.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 1. Pinta o gradiente translúcido abaixo da curva
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Pinta a linha da métrica
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, strokePaint);

    // 3. Ponto no valor mais recente (última amostra)
    if (showLastDot) {
      final lastX = size.width;
      final lastY = getY(values.last);

      final dotGlow = Paint()
        ..color = lineColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 4.5, dotGlow);

      final dotSolid = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 2.5, dotSolid);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
  }
}
