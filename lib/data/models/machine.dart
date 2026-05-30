import 'direction.dart';
import 'grid_point.dart';

/// A car that moves along a fixed, cyclic path — fully deterministic so the
/// solver can simulate the future perfectly.
///
/// [path] is the cycle expanded to one cell per step (consecutive entries are
/// always adjacent, and the last entry is adjacent to the first). [speed] is
/// the number of player-turns between car steps (1 = every turn, 2 = slow).
class Machine {
  Machine({
    required this.path,
    required this.carIndex,
    this.speed = 1,
    this.startOffset = 0,
  }) : assert(path.length >= 2, 'A machine needs at least two path cells'),
       assert(speed >= 1);

  final List<GridPoint> path;
  final int carIndex;
  final int speed;
  final int startOffset;

  /// Number of turns for the whole motion to repeat.
  int get period => path.length * speed;

  int _indexAtTurn(int turn) {
    final int steps = startOffset + (turn ~/ speed);
    return steps % path.length;
  }

  /// Cell occupied at the given (0-based) turn.
  GridPoint positionAtTurn(int turn) => path[_indexAtTurn(turn)];

  /// The direction the car is travelling as it transitions from [turn] to the
  /// next turn — used to rotate the sprite. Falls back to the last real move
  /// (or [Direction.down]) when the car is idling this turn.
  Direction facingAtTurn(int turn) {
    final GridPoint here = positionAtTurn(turn);
    final GridPoint next = positionAtTurn(turn + 1);
    final Direction d = _dirBetween(here, next);
    if (d != Direction.none) return d;

    // Idling (slow car between steps): reuse the previous heading.
    for (int back = 1; back <= speed + 1; back++) {
      final Direction prev =
          _dirBetween(positionAtTurn(turn - back), positionAtTurn(turn - back + 1));
      if (prev != Direction.none) return prev;
    }
    return Direction.down;
  }

  static Direction _dirBetween(GridPoint a, GridPoint b) {
    final int dx = b.x - a.x;
    final int dy = b.y - a.y;
    for (final Direction d in Direction.moves) {
      if (d.dx == dx && d.dy == dy) return d;
    }
    return Direction.none;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'p': path.map((GridPoint g) => <int>[g.x, g.y]).toList(),
        'c': carIndex,
        's': speed,
        'o': startOffset,
      };

  factory Machine.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['p'] as List<dynamic>;
    return Machine(
      path: raw
          .map((dynamic e) => GridPoint((e[0] as num).toInt(), (e[1] as num).toInt()))
          .toList(),
      carIndex: (json['c'] as num).toInt(),
      speed: (json['s'] as num?)?.toInt() ?? 1,
      startOffset: (json['o'] as num?)?.toInt() ?? 0,
    );
  }
}
