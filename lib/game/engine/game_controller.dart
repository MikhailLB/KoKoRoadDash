import 'package:flutter/foundation.dart';

import '../../data/levels/level_solver.dart';
import '../../data/models/direction.dart';
import '../../data/models/grid_point.dart';
import '../../data/models/level.dart';

enum GameStatus { playing, won, lost }

/// The kind of fatal event, so the view can pick the right reaction.
enum DeathCause { none, hitCar, carHitChicken, outOfMoves }

/// Result returned to the view after attempting a move.
class MoveResult {
  const MoveResult({
    required this.applied,
    this.won = false,
    this.lost = false,
  });

  /// False when the move was illegal (wall/obstacle/out-of-bounds) and the
  /// turn did NOT advance.
  final bool applied;
  final bool won;
  final bool lost;

  static const MoveResult rejected = MoveResult(applied: false);
}

/// Pure turn-based game logic for a single [Level].
///
/// Holds only logical state plus the "from -> to" cells of the current
/// transition; the view interpolates between them for smooth animation.
class GameController extends ChangeNotifier {
  GameController(this.level) {
    _reset();
  }

  Level level;

  late int turn;
  late GameStatus status;
  late int moves;
  late DeathCause deathCause;

  late GridPoint _playerFrom;
  late GridPoint _playerTo;
  late Direction _playerFacing;
  late List<GridPoint> _machineFrom;
  late List<GridPoint> _machineTo;

  // --- Public accessors for the renderer ------------------------------------
  GridPoint get playerFrom => _playerFrom;
  GridPoint get playerTo => _playerTo;
  Direction get playerFacing => _playerFacing;
  int get machineCount => level.machines.length;
  GridPoint machineFrom(int i) => _machineFrom[i];
  GridPoint machineTo(int i) => _machineTo[i];
  Direction machineFacing(int i) => level.machines[i].facingAtTurn(turn - 1);
  int machineCar(int i) => level.machines[i].carIndex;

  bool get isPlaying => status == GameStatus.playing;
  GridPoint get collisionCell => _playerTo;

  void loadLevel(Level next) {
    level = next;
    _reset();
    notifyListeners();
  }

  void restart() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    turn = 0;
    moves = 0;
    status = GameStatus.playing;
    deathCause = DeathCause.none;
    _playerFrom = level.start;
    _playerTo = level.start;
    _playerFacing = Direction.up;
    _machineFrom = List<GridPoint>.generate(
        level.machines.length, (int i) => level.machines[i].positionAtTurn(0));
    _machineTo = List<GridPoint>.of(_machineFrom);
  }

  /// Attempt to move (or wait with [Direction.none]). Advances all cars on a
  /// successful action and resolves collisions / win.
  MoveResult applyMove(Direction dir) {
    if (status != GameStatus.playing) return MoveResult.rejected;

    final GridPoint target =
        dir.isMove ? _playerTo.translate(dir.dx, dir.dy) : _playerTo;

    if (dir.isMove && !level.isWalkable(target)) {
      return MoveResult.rejected;
    }

    final int width = level.width;
    final int current = turn;
    final int next = turn + 1;

    // Car cells before and after they advance this turn.
    final Set<int> occNow = <int>{};
    final Set<int> occNext = <int>{};
    _machineFrom = List<GridPoint>.generate(level.machines.length, (int i) {
      final GridPoint p = level.machines[i].positionAtTurn(current);
      occNow.add(p.packed(width));
      return p;
    });
    _machineTo = List<GridPoint>.generate(level.machines.length, (int i) {
      final GridPoint p = level.machines[i].positionAtTurn(next);
      occNext.add(p.packed(width));
      return p;
    });

    _playerFrom = _playerTo;
    _playerTo = target;
    if (dir.isMove) _playerFacing = dir;

    final int targetCell = target.packed(width);
    final bool steppedIntoCar = occNow.contains(targetCell);
    final bool carRanOver = occNext.contains(targetCell);

    turn = next;
    moves += 1;

    if (steppedIntoCar || carRanOver) {
      status = GameStatus.lost;
      deathCause =
          steppedIntoCar ? DeathCause.hitCar : DeathCause.carHitChicken;
      notifyListeners();
      return const MoveResult(applied: true, lost: true);
    }

    if (target == level.finish) {
      status = GameStatus.won;
      notifyListeners();
      return const MoveResult(applied: true, won: true);
    }

    // Ran out of the move budget without reaching the finish.
    if (moves >= level.moveLimit) {
      status = GameStatus.lost;
      deathCause = DeathCause.outOfMoves;
      notifyListeners();
      return const MoveResult(applied: true, lost: true);
    }

    notifyListeners();
    return const MoveResult(applied: true);
  }

  int get movesLeft => (level.moveLimit - moves).clamp(0, level.moveLimit);

  /// Optimal remaining route (cells) for corridor highlighting.
  List<GridPoint> solutionPath() =>
      LevelSolver.solvePathFrom(level, _playerTo, turn);

  /// Move budget to still earn 3 / 2 stars. Anything more is 1 star.
  /// Surfaced to the UI so the scoring is transparent to the player.
  int get threeStarMoves => level.par <= 0 ? 999 : level.par + 1;
  int get twoStarMoves => level.par <= 0 ? 999 : level.par + 4;

  /// Stars awarded based on how efficient the solution was.
  int starsForMoves() {
    if (level.par <= 0) return 3;
    if (moves <= threeStarMoves) return 3;
    if (moves <= twoStarMoves) return 2;
    return 1;
  }
}
