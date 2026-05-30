import 'grid_point.dart';
import 'machine.dart';

/// Visual/logical classification of a grid row.
enum RowType {
  /// Greenery terrain where the chicken starts.
  start,

  /// Greenery terrain that holds the finish.
  finish,

  /// A road lane (cars drive here).
  road,

  /// A neon "safe" strip between roads.
  safe,
}

/// A fully specified, solvable puzzle.
class Level {
  Level({
    required this.index,
    required this.biome,
    required this.width,
    required this.height,
    required this.start,
    required this.finish,
    required this.obstacles,
    required this.machines,
    required this.rowTypes,
    this.par = 0,
  });

  /// 1-based level number.
  final int index;

  /// Background biome (1..4).
  final int biome;

  final int width;
  final int height;

  final GridPoint start;
  final GridPoint finish;

  /// Cells the chicken cannot enter (trees / bushes / barriers).
  final Set<GridPoint> obstacles;

  final List<Machine> machines;

  /// Render hint for each row (length == [height]).
  final List<RowType> rowTypes;

  /// Minimum number of moves found by the solver (for star scoring).
  final int par;

  /// Hard cap on actions (moves + waits) before the run fails. Generous enough
  /// to still earn a star, but tight enough that endless waiting isn't viable.
  int get moveLimit => par <= 0 ? 9999 : par + 8;

  bool inBounds(GridPoint p) =>
      p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  bool isObstacle(GridPoint p) => obstacles.contains(p);

  bool isWalkable(GridPoint p) => inBounds(p) && !isObstacle(p);

  /// Smallest period over which the whole board state repeats.
  int get globalPeriod {
    int lcm = 1;
    for (final Machine m in machines) {
      lcm = _lcm(lcm, m.period);
    }
    return lcm;
  }

  Level copyWith({int? par}) => Level(
        index: index,
        biome: biome,
        width: width,
        height: height,
        start: start,
        finish: finish,
        obstacles: obstacles,
        machines: machines,
        rowTypes: rowTypes,
        par: par ?? this.par,
      );

  static int _gcd(int a, int b) {
    while (b != 0) {
      final int t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  static int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;
}
