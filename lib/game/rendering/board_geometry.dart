import 'dart:ui';

import '../../data/models/grid_point.dart';

/// Maps grid cells to pixel space for a board that fills [size] horizontally.
class BoardGeometry {
  BoardGeometry({required this.size, required this.cols, required this.rows})
      : cell = size.width / cols;

  final Size size;
  final int cols;
  final int rows;
  final double cell;

  double get boardHeight => cell * rows;

  Offset center(GridPoint p) =>
      Offset((p.x + 0.5) * cell, (p.y + 0.5) * cell);

  Offset lerpCenter(GridPoint a, GridPoint b, double t) {
    final Offset ca = center(a);
    final Offset cb = center(b);
    return Offset(lerpDouble(ca.dx, cb.dx, t)!, lerpDouble(ca.dy, cb.dy, t)!);
  }

  Rect cellRect(GridPoint p) =>
      Rect.fromLTWH(p.x * cell, p.y * cell, cell, cell);

  Rect rowRect(int row, {double heightInCells = 1}) =>
      Rect.fromLTWH(0, row * cell, size.width, cell * heightInCells);

  /// Convert a local tap position to the grid cell it falls in.
  GridPoint? hitTest(Offset local) {
    if (local.dx < 0 || local.dy < 0) return null;
    final int x = (local.dx / cell).floor();
    final int y = (local.dy / cell).floor();
    if (x < 0 || y < 0 || x >= cols || y >= rows) return null;
    return GridPoint(x, y);
  }
}
