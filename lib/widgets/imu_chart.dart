import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui;

/// 三軸 IMU 折線圖（fl_chart）
/// 另外提供靜態的 `renderLinesToImage()` 供離屏輸出 PNG。
class ImuChart extends StatelessWidget {
  final List<Offset> seriesX;
  final List<Offset> seriesY;
  final List<Offset> seriesZ;
  final String yLabel;
  final double maxX;

  /// 三軸顏色
  final Color colorX;
  final Color colorY;
  final Color colorZ;

  const ImuChart({
    super.key,
    required this.seriesX,
    required this.seriesY,
    required this.seriesZ,
    required this.yLabel,
    required this.maxX,
    required this.colorX,
    required this.colorY,
    required this.colorZ,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: Theme.of(context).colorScheme.surface,
        minX: 0,
        maxX: maxX <= 0 ? 1 : maxX,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(
            axisNameWidget: Text('t (sec)'),
            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(yLabel),
            axisNameSize: 20,
            sideTitles: const SideTitles(showTitles: true, reservedSize: 44),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          _bar(seriesX, colorX),
          _bar(seriesY, colorY),
          _bar(seriesZ, colorZ),
        ],
      ),
    );
  }

  static LineChartBarData _bar(List<Offset> s, Color color) {
    final spots = s.map((o) => FlSpot(o.dx, o.dy)).toList(growable: false);
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      dotData: const FlDotData(show: false),
      barWidth: 2,
      color: color,
    );
  }

  /// 離屏繪圖：把三條 (t,value) 座標畫到一張 Image（用 Canvas，不依賴 fl_chart）
  ///
  /// series: 3 條 List<Offset>（可傳多於 3 條，會依序用 colors 著色）
  /// colors: 折線顏色（長度不足會循環使用）
  /// size:   圖片尺寸
  /// bgColor: 背景色
  /// xLabel/yLabel: 軸標籤
  static Future<ui.Image> renderLinesToImage({
    required List<List<Offset>> series,
    required List<Color> colors,
    required Size size,
    required Color bgColor,
    String? xLabel,
    String? yLabel,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintBg = Paint()..color = bgColor;
    canvas.drawRect(Offset.zero & size, paintBg);

    const double leftPad = 80, rightPad = 24, topPad = 24, bottomPad = 60;
    final chartRect = Rect.fromLTWH(
      leftPad, topPad, size.width - leftPad - rightPad, size.height - topPad - bottomPad,
    );

    // 掃描資料範圍
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final s in series) {
      for (final p in s) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (minX == double.infinity) {
      // 沒資料
      final picture = recorder.endRecording();
      return picture.toImage(size.width.toInt(), size.height.toInt());
    }
    if (minX == maxX) { minX -= 0.5; maxX += 0.5; }
    if (minY == maxY) { minY -= 0.5; maxY += 0.5; }

    // 留點邊界 padding
    final xPad = (maxX - minX) * 0.05;
    final yPad = (maxY - minY) * 0.10;
    minX -= xPad; maxX += xPad;
    minY -= yPad; maxY += yPad;

    double mapX(double x) => chartRect.left +
        (x - minX) / (maxX - minX) * chartRect.width;
    double mapY(double y) => chartRect.bottom -
        (y - minY) / (maxY - minY) * chartRect.height;

    // 格線 & 刻度
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = 1;
    const int xTicks = 6, yTicks = 5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= xTicks; i++) {
      final t = minX + (maxX - minX) * (i / xTicks);
      final x = mapX(t);
      canvas.drawLine(Offset(x, chartRect.top), Offset(x, chartRect.bottom), gridPaint);
      final label = t.toStringAsFixed(2);
      textPainter.text = TextSpan(style: const TextStyle(fontSize: 12, color: Colors.grey), text: label);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartRect.bottom + 6));
    }

    for (int i = 0; i <= yTicks; i++) {
      final v = minY + (maxY - minY) * (i / yTicks);
      final y = mapY(v);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final label = v.toStringAsFixed(2);
      textPainter.text = TextSpan(style: const TextStyle(fontSize: 12, color: Colors.grey), text: label);
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartRect.left - textPainter.width - 8, y - textPainter.height / 2));
    }

    // 邊框
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(chartRect, borderPaint);

    // 折線
    for (int k = 0; k < series.length; k++) {
      final s = series[k];
      if (s.isEmpty) continue;
      final path = Path();
      for (int i = 0; i < s.length; i++) {
        final dx = mapX(s[i].dx);
        final dy = mapY(s[i].dy);
        if (i == 0) path.moveTo(dx, dy);
        else path.lineTo(dx, dy);
      }
      final p = Paint()
        ..color = colors[k % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = true;
      canvas.drawPath(path, p);
    }

    // 軸標籤
    if (xLabel != null) {
      textPainter.text = TextSpan(style: const TextStyle(fontSize: 13, color: Colors.grey), text: xLabel);
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartRect.center.dx - textPainter.width / 2, size.height - textPainter.height - 6));
    }
    if (yLabel != null) {
      textPainter.text = TextSpan(style: const TextStyle(fontSize: 13, color: Colors.grey), text: yLabel);
      textPainter.layout();
      canvas.save();
      canvas.translate(12, chartRect.center.dy + textPainter.width / 2);
      canvas.rotate(-3.14159 / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }
}
