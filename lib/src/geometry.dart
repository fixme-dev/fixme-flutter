// Geometry in logical pixels and a helper for JSON maps. Pure: no Flutter imports, so it is unit tested without a device.

import 'dart:math' as math;

/// Geometry in logical pixels (iOS points, Android dp), origin top-left.
class FxRect {
  const FxRect(this.x, this.y, this.width, this.height);
  final double x, y, width, height;

  double get maxX => x + width;
  double get maxY => y + height;
  double get area => math.max(0, width) * math.max(0, height);
  bool get isEmpty => width <= 0 || height <= 0;

  FxRect intersection(FxRect o) {
    final x0 = math.max(x, o.x), y0 = math.max(y, o.y);
    final x1 = math.min(maxX, o.maxX), y1 = math.min(maxY, o.maxY);
    if (x1 <= x0 || y1 <= y0) return const FxRect(0, 0, 0, 0);
    return FxRect(x0, y0, x1 - x0, y1 - y0);
  }

  FxRect union(FxRect o) {
    if (isEmpty) return o;
    if (o.isEmpty) return this;
    final x0 = math.min(x, o.x), y0 = math.min(y, o.y);
    return FxRect(x0, y0, math.max(maxX, o.maxX) - x0, math.max(maxY, o.maxY) - y0);
  }

  static FxRect bounding(List<FxPoint> pts) {
    if (pts.isEmpty) return const FxRect(0, 0, 0, 0);
    var x0 = pts.first.x, y0 = pts.first.y, x1 = x0, y1 = y0;
    for (final p in pts) {
      x0 = math.min(x0, p.x);
      y0 = math.min(y0, p.y);
      x1 = math.max(x1, p.x);
      y1 = math.max(y1, p.y);
    }
    return FxRect(x0, y0, x1 - x0, y1 - y0);
  }

  Map<String, Object?> toJson() => {'x': _r(x), 'y': _r(y), 'width': _r(width), 'height': _r(height)};

  @override
  bool operator ==(Object other) =>
      other is FxRect && other.x == x && other.y == y && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(x, y, width, height);
  @override
  String toString() => 'FxRect($x, $y, $width, $height)';
}

class FxPoint {
  const FxPoint(this.x, this.y);
  final double x, y;
  Map<String, Object?> toJson() => {'x': _r(x), 'y': _r(y)};
  @override
  bool operator ==(Object other) => other is FxPoint && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

double _r(double v) => (v * 10).roundToDouble() / 10;

/// Drops null values (optional fields are omitted on the wire).
Map<String, Object?> compact(Map<String, Object?> m) => {
      for (final e in m.entries)
        if (e.value != null) e.key: e.value,
    };
