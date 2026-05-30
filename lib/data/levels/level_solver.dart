import 'dart:collection';

import '../models/direction.dart';
import '../models/grid_point.dart';
import '../models/level.dart';

/// Outcome of analysing a level by full forward simulation.
class SolveResult {
  const SolveResult({required this.solvable, this.par = 0, this.firstMove});

  final bool solvable;

  /// Fewest turns to reach the finish safely (0 if unsolvable).
  final int par;

  /// The optimal next move from the start state — powers the hint button.
  final Direction? firstMove;

  static const SolveResult unsolvable = SolveResult(solvable: false);
}

/// Solves a [Level] via breadth-first search over the *time-expanded* state
/// space `(playerCell, turn mod globalPeriod)`.
///
/// Because every car is perfectly periodic, the whole board repeats every
/// `globalPeriod` turns, so this finite graph captures all reachable futures.
/// BFS therefore yields both solvability and the minimum-move solution.
class LevelSolver {
  /// Hard ceiling on explored states; protects generation from pathological
  /// periods. Returns [SolveResult.unsolvable] if exceeded.
  static const int _maxStates = 400000;

  static SolveResult solve(Level level) =>
      solveFrom(level, level.start, 0);

  /// Like [solve] but begins from an arbitrary [from] cell at global turn
  /// [startTurn]. Used for the in-game hint button mid-puzzle.
  static SolveResult solveFrom(Level level, GridPoint from, int startTurn) {
    final int period = level.globalPeriod;
    final int width = level.width;
    final List<Set<int>> occupancy = _buildOccupancy(level, period, width);

    final int startCell = from.packed(width);
    final int finishCell = level.finish.packed(width);
    final int startMod = startTurn % period;

    // Standing on the start cell at this turn must be safe.
    if (occupancy[startMod].contains(startCell)) return SolveResult.unsolvable;

    final Queue<int> queue = Queue<int>();
    // Encode a state as ((cell * period) + turnMod). Track the first move that
    // led into each state to reconstruct the opening of the optimal line.
    final Map<int, int> dist = <int, int>{};
    final Map<int, Direction> openingMove = <int, Direction>{};

    final int startState = startCell * period + startMod;
    dist[startState] = 0;
    queue.add(startState);

    int explored = 0;
    while (queue.isNotEmpty) {
      if (++explored > _maxStates) return SolveResult.unsolvable;

      final int state = queue.removeFirst();
      final int turnMod = state % period;
      final int cell = state ~/ period;
      final int d = dist[state]!;

      if (cell == finishCell) {
        return SolveResult(
          solvable: true,
          par: d,
          firstMove: openingMove[state],
        );
      }

      final GridPoint here = GridPoint.unpack(cell, width);
      final int nextMod = (turnMod + 1) % period;
      final Set<int> occNow = occupancy[turnMod];
      final Set<int> occNext = occupancy[nextMod];

      for (final Direction action in _actions) {
        final GridPoint target =
            action.isMove ? here.translate(action.dx, action.dy) : here;

        if (action.isMove && !level.isWalkable(target)) continue;

        final int targetCell = target.packed(width);

        // Stepping onto a car, or a car arriving on us, is a crash.
        if (occNow.contains(targetCell) || occNext.contains(targetCell)) {
          continue;
        }

        final int next = targetCell * period + nextMod;
        if (dist.containsKey(next)) continue;

        dist[next] = d + 1;
        openingMove[next] = openingMove[state] ?? action;
        queue.add(next);
      }
    }

    return SolveResult.unsolvable;
  }

  /// The optimal safe route as a list of cells the chicken steps on, from just
  /// after [from] through the finish. Consecutive duplicates (waits) are
  /// collapsed so the highlight reads as a clean corridor. Empty if no route.
  static List<GridPoint> solvePathFrom(Level level, GridPoint from, int startTurn) {
    final int period = level.globalPeriod;
    final int width = level.width;
    final List<Set<int>> occupancy = _buildOccupancy(level, period, width);
    final int startCell = from.packed(width);
    final int finishCell = level.finish.packed(width);
    final int startMod = startTurn % period;
    if (occupancy[startMod].contains(startCell)) return const <GridPoint>[];

    final Queue<int> queue = Queue<int>();
    final Map<int, int> parent = <int, int>{};
    final Set<int> visited = <int>{};
    final int startState = startCell * period + startMod;
    visited.add(startState);
    queue.add(startState);

    int explored = 0;
    int? goalState;
    while (queue.isNotEmpty) {
      if (++explored > _maxStates) break;
      final int state = queue.removeFirst();
      final int turnMod = state % period;
      final int cell = state ~/ period;
      if (cell == finishCell) {
        goalState = state;
        break;
      }
      final GridPoint here = GridPoint.unpack(cell, width);
      final int nextMod = (turnMod + 1) % period;
      final Set<int> occNow = occupancy[turnMod];
      final Set<int> occNext = occupancy[nextMod];
      for (final Direction action in _actions) {
        final GridPoint target =
            action.isMove ? here.translate(action.dx, action.dy) : here;
        if (action.isMove && !level.isWalkable(target)) continue;
        final int targetCell = target.packed(width);
        if (occNow.contains(targetCell) || occNext.contains(targetCell)) {
          continue;
        }
        final int next = targetCell * period + nextMod;
        if (!visited.add(next)) continue;
        parent[next] = state;
        queue.add(next);
      }
    }

    if (goalState == null) return const <GridPoint>[];
    // Reconstruct, then map to cells and collapse waits.
    final List<int> states = <int>[];
    int? cur = goalState;
    while (cur != null) {
      states.add(cur);
      cur = parent[cur];
    }
    states.removeLast(); // drop the start state itself
    final List<GridPoint> cells = <GridPoint>[];
    for (final int s in states.reversed) {
      final GridPoint p = GridPoint.unpack(s ~/ period, width);
      if (cells.isEmpty || cells.last != p) cells.add(p);
    }
    return cells;
  }

  /// Quick reachability ignoring cars — a cheap pre-filter before the full
  /// time-expanded search.
  static bool hasStaticPath(Level level) => staticDistance(level) != null;

  /// Shortest path length from start to finish ignoring cars, or null if the
  /// obstacles wall it off.
  static int? staticDistance(Level level) {
    final int width = level.width;
    final Map<int, int> dist = <int, int>{level.start.packed(width): 0};
    final Queue<GridPoint> queue = Queue<GridPoint>()..add(level.start);
    while (queue.isNotEmpty) {
      final GridPoint p = queue.removeFirst();
      final int d = dist[p.packed(width)]!;
      if (p == level.finish) return d;
      for (final Direction dir in Direction.moves) {
        final GridPoint n = p.translate(dir.dx, dir.dy);
        if (!level.isWalkable(n)) continue;
        if (dist.containsKey(n.packed(width))) continue;
        dist[n.packed(width)] = d + 1;
        queue.add(n);
      }
    }
    return null;
  }

  /// True if the level can be beaten by the cheap "wait, then walk straight"
  /// strategy the player complained about: idle at the start for some number
  /// of turns, then take a monotone shortest path to the finish without ever
  /// stopping or backtracking.
  ///
  /// We sweep every possible start delay and run a set-based monotone search,
  /// so this covers *all* shortest paths at once. If it returns false, the
  /// player is forced to dodge mid-crossing — i.e. a real puzzle.
  static bool isRushable(Level level) {
    final int period = level.globalPeriod;
    if (period > 600) return false; // complex timing; not trivially rushable
    final int? d = staticDistance(level);
    if (d == null) return false;
    final int width = level.width;
    final List<Set<int>> occ = _buildOccupancy(level, period, width);
    final int startCell = level.start.packed(width);
    final int finishCell = level.finish.packed(width);

    for (int delay = 0; delay < period; delay++) {
      // Surviving the idle phase: start cell must be clear while we wait.
      bool safeIdle = true;
      for (int w = 1; w <= delay; w++) {
        if (occ[w % period].contains(startCell)) {
          safeIdle = false;
          break;
        }
      }
      if (!safeIdle) continue;
      if (occ[delay % period].contains(startCell)) continue;

      Set<int> frontier = <int>{startCell};
      for (int k = 0; k < d; k++) {
        final Set<int> next = <int>{};
        final int turnNow = (delay + k) % period;
        final int turnNext = (delay + k + 1) % period;
        for (final int cell in frontier) {
          final GridPoint here = GridPoint.unpack(cell, width);
          final int hereDist = here.manhattanTo(level.finish);
          for (final Direction dir in Direction.moves) {
            final GridPoint n = here.translate(dir.dx, dir.dy);
            if (!level.isWalkable(n)) continue;
            if (n.manhattanTo(level.finish) != hereDist - 1) continue; // monotone
            final int nc = n.packed(width);
            if (occ[turnNow].contains(nc) || occ[turnNext].contains(nc)) {
              continue;
            }
            next.add(nc);
          }
        }
        if (next.isEmpty) break;
        frontier = next;
      }
      if (frontier.contains(finishCell)) return true;
    }
    return false;
  }

  static List<Set<int>> _buildOccupancy(Level level, int period, int width) {
    return List<Set<int>>.generate(period, (int t) {
      final Set<int> occ = <int>{};
      for (final machine in level.machines) {
        occ.add(machine.positionAtTurn(t).packed(width));
      }
      return occ;
    });
  }

  // Wait is considered last so the solver prefers progress over idling when
  // distances tie.
  static const List<Direction> _actions = <Direction>[
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
    Direction.none,
  ];
}
