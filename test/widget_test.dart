// Engine tests for the Koko Road Dash puzzle generator/solver.
import 'package:flutter_test/flutter_test.dart';
import 'package:koko_road_dash/data/levels/level_generator.dart';
import 'package:koko_road_dash/data/levels/level_solver.dart';
import 'package:koko_road_dash/data/models/level.dart';

void main() {
  test('every generated level is solvable', () {
    for (int i = 1; i <= 120; i++) {
      final Level level = LevelGenerator.generate(i);
      final SolveResult result = LevelSolver.solve(level);
      expect(result.solvable, isTrue, reason: 'Level $i should be solvable');
      expect(result.par, greaterThan(0));
    }
  });

  test('generation is deterministic per level', () {
    final Level a = LevelGenerator.generate(42);
    final Level b = LevelGenerator.generate(42);
    expect(a.width, b.width);
    expect(a.height, b.height);
    expect(a.machines.length, b.machines.length);
    expect(a.par, b.par);
    expect(a.start, b.start);
    expect(a.finish, b.finish);
  });

  test('difficulty ramps with level number', () {
    final Level early = LevelGenerator.generate(2);
    final Level late = LevelGenerator.generate(80);
    expect(late.machines.length, greaterThanOrEqualTo(early.machines.length));
  });

  test('levels past the tutorial cannot be cheesed by waiting then rushing',
      () {
    for (int i = 2; i <= 60; i++) {
      final Level level = LevelGenerator.generate(i);
      expect(LevelSolver.isRushable(level), isFalse,
          reason: 'Level $i should require dodging, not a straight rush');
    }
  });
}
