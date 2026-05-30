import 'dart:math' as math;

/// The five actions a chicken can take on its turn.
///
/// [none] is an explicit "wait" — a legal move that still advances the cars.
enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0),
  none(0, 0);

  const Direction(this.dx, this.dy);

  final int dx;
  final int dy;

  bool get isMove => this != Direction.none;

  /// Rotation (radians, clockwise) that orients a sprite whose neutral facing
  /// is "down" (+y) toward this direction. Used to point cars along their path.
  double get spriteAngle => math.atan2(-dx.toDouble(), dy.toDouble());

  Direction get opposite {
    switch (this) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
      case Direction.none:
        return Direction.none;
    }
  }

  static const List<Direction> moves = <Direction>[
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
  ];
}
