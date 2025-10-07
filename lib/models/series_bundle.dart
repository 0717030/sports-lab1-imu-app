import 'dart:ui';

class SeriesBundle {
  final List<Offset> x;
  final List<Offset> y;
  final List<Offset> z;
  final String label;
  const SeriesBundle({
    required this.x,
    required this.y,
    required this.z,
    required this.label,
  });
}
