import 'dart:math' as math;

/// An immutable integer coordinate on the puzzle grid.
///
/// `x` is the column, `y` is the row. The origin (0,0) is the top-left cell;
/// `y` increases downward, matching screen space.
class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  GridPoint translate(int dx, int dy) => GridPoint(x + dx, y + dy);

  /// A stable integer id for use as a map/set key (needs the grid width).
  int packed(int width) => y * width + x;

  int manhattanTo(GridPoint other) =>
      (x - other.x).abs() + (y - other.y).abs();

  static GridPoint unpack(int id, int width) =>
      GridPoint(id % width, id ~/ width);

  static double distance(GridPoint a, GridPoint b) {
    final int dx = a.x - b.x;
    final int dy = a.y - b.y;
    return math.sqrt((dx * dx + dy * dy).toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}
