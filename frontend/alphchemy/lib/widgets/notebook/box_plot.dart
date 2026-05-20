import "package:alphchemy/main.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";

class BoxPlot extends StatelessWidget {
  final QueryResults? result;

  const BoxPlot({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox(
        height: 22.0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: NormalText("— no results —")
        )
      );
    }

    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 25.0,
      child: CustomPaint(
        size: Size.infinite,
        painter: BoxPlotPainter(result: result!, lineColor: colors.fgColor1, boxFill: colors.bgColor2, zeroColor: colors.bgColor3)
      )
    );
  }
}

class BoxPlotPainter extends CustomPainter {
  final QueryResults result;
  final Color lineColor;
  final Color boxFill;
  final Color zeroColor;

  const BoxPlotPainter({required this.result, required this.lineColor, required this.boxFill, required this.zeroColor});

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 4.0;
    final innerW = size.width - padX * 2.0;
    final span = (result.max - result.min);
    final scaleSpan = span == 0.0 ? 1.0 : span;
    final padding = scaleSpan * 0.05;
    final domainMin = result.min - padding;
    final domainMax = result.max + padding;
    final range = domainMax - domainMin;
    final scale = range == 0.0 ? 1.0 : range;
    double xFor(double value) {
      return padX + ((value - domainMin) / scale) * innerW;
    }

    final mid = size.height / 2.0;
    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final paintMedian = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final paintBox = Paint()
      ..color = boxFill
      ..style = PaintingStyle.fill;

    final xMin = xFor(result.min);
    final xQ1 = xFor(result.q1);
    final xMedian = xFor(result.median);
    final xQ3 = xFor(result.q3);
    final xMax = xFor(result.max);

    if (domainMin < 0.0 && domainMax > 0.0) {
      final zeroX = xFor(0.0);
      final paintZero = Paint()
        ..color = zeroColor
        ..strokeWidth = 1.0;
      _drawDashedLine(canvas, Offset(zeroX, 2.0), Offset(zeroX, size.height - 2.0), paintZero);
    }

    canvas.drawLine(Offset(xMin, mid), Offset(xQ1, mid), paintLine);
    canvas.drawLine(Offset(xQ3, mid), Offset(xMax, mid), paintLine);
    canvas.drawLine(Offset(xMin, mid - 5.0), Offset(xMin, mid + 5.0), paintLine);
    canvas.drawLine(Offset(xMax, mid - 5.0), Offset(xMax, mid + 5.0), paintLine);

    final boxRect = Rect.fromLTRB(xQ1, mid - 7.0, xQ3 < xQ1 + 1.0 ? xQ1 + 1.0 : xQ3, mid + 7.0);
    canvas.drawRect(boxRect, paintBox);
    canvas.drawRect(boxRect, paintLine);
    canvas.drawLine(Offset(xMedian, mid - 7.0), Offset(xMedian, mid + 7.0), paintMedian);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 2.0;
    const gapLength = 2.0;
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    var travelled = 0.0;
    while (travelled < totalLength) {
      final segmentEnd = travelled + dashLength;
      final clamped = segmentEnd > totalLength ? totalLength : segmentEnd;
      canvas.drawLine(start + direction * travelled, start + direction * clamped, paint);
      travelled = clamped + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant BoxPlotPainter old) {
    return old.result != result || old.lineColor != lineColor || old.boxFill != boxFill || old.zeroColor != zeroColor;
  }
}
