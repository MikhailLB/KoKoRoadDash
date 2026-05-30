// Standalone sanity check for the puzzle engine (no Flutter deps).
// Run: dart run tool/gen_check.dart
// ignore_for_file: avoid_print
import 'package:koko_road_dash/data/levels/level_generator.dart';
import 'package:koko_road_dash/data/levels/level_solver.dart';
import 'package:koko_road_dash/data/models/level.dart';

void main() {
  final List<int> levels = <int>[
    1, 2, 3, 4, 5, 8, 10, 15, 20, 25, 30, 35, 40, 50, 60, 80, 100, 150, 200,
  ];
  final Stopwatch sw = Stopwatch()..start();
  int rushableCount = 0;
  for (final int i in levels) {
    final Level lvl = LevelGenerator.generate(i);
    final SolveResult r = LevelSolver.solve(lvl);
    final int dist = LevelSolver.staticDistance(lvl) ?? -1;
    final bool rush = LevelSolver.isRushable(lvl);
    if (rush && i >= 2) rushableCount++;
    print('L$i  ${lvl.width}x${lvl.height}  cars=${lvl.machines.length}  '
        'period=${lvl.globalPeriod}  dist=$dist par=${lvl.par}  '
        'detour=${lvl.par - dist}  rushable=$rush  solvable=${r.solvable}');
    if (!r.solvable) print('  !!! UNSOLVABLE');
  }
  print('Rushable (lvl>=2): $rushableCount / ${levels.length}');
  sw.stop();
  print('Done in ${sw.elapsedMilliseconds} ms');
}
