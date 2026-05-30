import 'dart:math' as math;

import '../models/grid_point.dart';
import '../models/level.dart';
import '../models/machine.dart';
import 'level_solver.dart';

/// Difficulty knobs derived from the level number.
class _Difficulty {
  _Difficulty({
    required this.width,
    required this.height,
    required this.machines,
    required this.obstacles,
    required this.patterns,
    required this.slowChance,
    required this.mirrored,
  });

  final int width;
  final int height;
  final int machines;
  final int obstacles;
  final List<_Pattern> patterns;
  final double slowChance;
  final bool mirrored;
}

enum _Pattern { hLine, vLine, rect, zigzag, eight }

/// Builds guaranteed-solvable puzzles deterministically from the level number.
///
/// Each car follows a perfectly periodic cycle. After placing obstacles and
/// cars at random, [LevelSolver] proves a safe route exists; otherwise the
/// layout is discarded and regenerated. This yields effectively unlimited,
/// always-fair levels with a smooth difficulty ramp (per `chicken.md`).
class LevelGenerator {
  static const int _maxAttempts = 260;

  /// Generate (or regenerate) the puzzle for [levelIndex] (1-based).
  static Level generate(int levelIndex) {
    final int biome = ((levelIndex - 1) ~/ 8) % 4 + 1;

    // Progressive relaxation: if a target difficulty resists generation, ease
    // it slightly so we always return a valid, solvable board.
    for (int relax = 0; relax < 6; relax++) {
      final _Difficulty diff = _difficultyFor(levelIndex, relax);
      for (int attempt = 0; attempt < _maxAttempts; attempt++) {
        final int seed = levelIndex * 100003 + relax * 1009 + attempt;
        final Level? level = _tryBuild(levelIndex, biome, diff, seed, relax);
        if (level != null) return level;
      }
    }
    // Absolute fallback — a tiny, trivially solvable board.
    return _fallback(levelIndex, biome);
  }

  static Level? _tryBuild(
      int index, int biome, _Difficulty diff, int seed, int relax) {
    final math.Random rng = math.Random(seed);
    final int w = diff.width;
    final int h = diff.height;

    final GridPoint start = GridPoint(w ~/ 2, h - 1);
    final GridPoint finish = GridPoint(rng.nextInt(w), 0);

    final List<RowType> rowTypes = _buildRowTypes(h);

    // --- Obstacles (trees / bushes / barriers) -----------------------------
    final Set<GridPoint> obstacles = <GridPoint>{};
    int guard = 0;
    while (obstacles.length < diff.obstacles && guard < diff.obstacles * 8) {
      guard++;
      final int x = rng.nextInt(w);
      final int y = 1 + rng.nextInt(h - 2); // never on start/finish rows
      final GridPoint p = GridPoint(x, y);
      if (p == start || p == finish) continue;
      // Keep the lane directly above the start clear so the player can leave.
      if (x == start.x && y == h - 2) continue;
      obstacles.add(p);
    }

    // --- Cars --------------------------------------------------------------
    final List<Machine> machines = <Machine>[];
    final int carCount = diff.machines;
    int built = 0;
    int carGuard = 0;
    while (built < carCount && carGuard < carCount * 12) {
      carGuard++;
      final _Pattern pattern = diff.patterns[rng.nextInt(diff.patterns.length)];
      final List<GridPoint>? path = _buildPattern(pattern, w, h, rng);
      if (path == null || path.length < 2) continue;

      // Cars must not occupy obstacles, the start or the finish cell.
      if (path.any((GridPoint c) =>
          obstacles.contains(c) || c == start || c == finish)) {
        continue;
      }

      final int speed = rng.nextDouble() < diff.slowChance ? 2 : 1;
      final int carIndex = rng.nextInt(4);
      final int offset = rng.nextInt(path.length);
      machines.add(Machine(
        path: path,
        carIndex: carIndex,
        speed: speed,
        startOffset: offset,
      ));
      built++;

      // Mirrored patrols: add the horizontally-flipped twin (level 30+).
      if (diff.mirrored && built < carCount) {
        final List<GridPoint> mirror = path
            .map((GridPoint c) => GridPoint(w - 1 - c.x, c.y))
            .toList();
        if (!mirror.any((GridPoint c) =>
            obstacles.contains(c) || c == start || c == finish)) {
          machines.add(Machine(
            path: mirror,
            carIndex: carIndex,
            speed: speed,
            startOffset: offset,
          ));
          built++;
        }
      }
    }

    if (machines.isEmpty) return null;

    final Level draft = Level(
      index: index,
      biome: biome,
      width: w,
      height: h,
      start: start,
      finish: finish,
      obstacles: obstacles,
      machines: machines,
      rowTypes: rowTypes,
    );

    final int? staticDist = LevelSolver.staticDistance(draft);
    if (staticDist == null) return null;
    final SolveResult result = LevelSolver.solve(draft);
    if (!result.solvable) return null;

    // Reject degenerate puzzles that need almost no thought.
    final int minPar = index <= 2 ? 3 : 5;
    if (result.par < minPar) return null;

    // The core fairness/challenge gate. From level 2 on, the puzzle must NOT
    // be beatable by idling then walking straight — the player has to weave
    // through traffic. We also want the optimal line to be longer than the
    // raw distance (a forced detour or wait) once past the tutorial.
    if (index >= 2 && relax < 4) {
      if (LevelSolver.isRushable(draft)) return null;
    }
    if (index >= 6 && relax < 3) {
      final int detour = index < 20 ? 1 : 2;
      if (result.par < staticDist + detour) return null;
    }

    return draft.copyWith(par: result.par);
  }

  // --- Difficulty curve ------------------------------------------------------
  static _Difficulty _difficultyFor(int level, int relax) {
    // Keep boards compact so traffic stays dense and crossings feel tense.
    final int w = (5 + level ~/ 22).clamp(5, 7);
    final int h = (8 + level ~/ 10).clamp(8, 12) - relax.clamp(0, 2);

    int machines;
    final List<_Pattern> patterns;
    bool mirrored = false;
    double slow = 0.0;
    int obstacles;

    if (level < 3) {
      // Tutorial: still needs timing, but gentle.
      machines = 2;
      patterns = <_Pattern>[_Pattern.hLine, _Pattern.vLine];
      obstacles = 1;
    } else if (level < 6) {
      machines = 3;
      patterns = <_Pattern>[_Pattern.hLine, _Pattern.vLine];
      obstacles = 2;
    } else if (level < 12) {
      machines = 4;
      slow = 0.2;
      patterns = <_Pattern>[_Pattern.hLine, _Pattern.vLine, _Pattern.rect];
      obstacles = 3;
    } else if (level < 20) {
      machines = 5;
      slow = 0.2;
      patterns = <_Pattern>[_Pattern.hLine, _Pattern.vLine, _Pattern.rect];
      obstacles = 3;
    } else if (level < 30) {
      machines = 5;
      slow = 0.2;
      patterns = <_Pattern>[_Pattern.rect, _Pattern.hLine, _Pattern.zigzag];
      obstacles = 4;
    } else if (level < 40) {
      machines = 6;
      slow = 0.2;
      mirrored = true;
      patterns = <_Pattern>[_Pattern.rect, _Pattern.vLine, _Pattern.hLine];
      obstacles = 4;
    } else if (level < 60) {
      machines = 6;
      slow = 0.25;
      patterns = <_Pattern>[_Pattern.rect, _Pattern.zigzag, _Pattern.eight];
      obstacles = 5;
    } else {
      machines = (6 + level ~/ 50).clamp(6, 8);
      slow = 0.3;
      mirrored = level.isEven;
      patterns = <_Pattern>[
        _Pattern.rect,
        _Pattern.zigzag,
        _Pattern.eight,
        _Pattern.hLine,
        _Pattern.vLine,
      ];
      obstacles = 5 + level ~/ 60;
    }

    // Relaxation eases the hardest knobs first.
    machines = (machines - relax).clamp(2, 9);
    obstacles = (obstacles - relax).clamp(0, w * h);

    return _Difficulty(
      width: w.clamp(4, 8),
      height: h.clamp(6, 12),
      machines: machines,
      obstacles: obstacles,
      patterns: patterns,
      slowChance: slow,
      mirrored: mirrored,
    );
  }

  static List<RowType> _buildRowTypes(int h) {
    final List<RowType> rows = List<RowType>.filled(h, RowType.road);
    rows[0] = RowType.finish;
    rows[h - 1] = RowType.start;
    // Neon safe strips break up the asphalt for visual rhythm.
    for (int y = 1; y < h - 1; y++) {
      if ((h - 1 - y) % 3 == 0) rows[y] = RowType.safe;
    }
    return rows;
  }

  // --- Pattern builders ------------------------------------------------------
  static List<GridPoint>? _buildPattern(
      _Pattern pattern, int w, int h, math.Random rng) {
    final int topRow = 1;
    final int bottomRow = h - 2;
    if (bottomRow < topRow) return null;

    switch (pattern) {
      case _Pattern.hLine:
        final int y = topRow + rng.nextInt(bottomRow - topRow + 1);
        final int len = math.min(w, 3 + rng.nextInt(w));
        final int x0 = rng.nextInt(math.max(1, w - len + 1));
        return _pingPong(_row(y, x0, x0 + len - 1));
      case _Pattern.vLine:
        final int x = rng.nextInt(w);
        final int len = math.min(bottomRow - topRow + 1, 2 + rng.nextInt(4));
        final int y0 = topRow + rng.nextInt(math.max(1, (bottomRow - topRow + 1) - len + 1));
        return _pingPong(_col(x, y0, y0 + len - 1));
      case _Pattern.rect:
        final int rw = 2 + rng.nextInt(math.max(1, w - 2));
        final int rh = 2 + rng.nextInt(math.max(1, bottomRow - topRow));
        final int x0 = rng.nextInt(math.max(1, w - rw));
        final int y0 = topRow + rng.nextInt(math.max(1, (bottomRow - topRow + 1) - rh));
        return _rect(x0, y0, x0 + rw, y0 + rh);
      case _Pattern.zigzag:
        return _zigzag(w, topRow, bottomRow, rng);
      case _Pattern.eight:
        return _eight(w, topRow, bottomRow, rng);
    }
  }

  static List<GridPoint> _row(int y, int x0, int x1) =>
      <GridPoint>[for (int x = x0; x <= x1; x++) GridPoint(x, y)];

  static List<GridPoint> _col(int x, int y0, int y1) =>
      <GridPoint>[for (int y = y0; y <= y1; y++) GridPoint(x, y)];

  /// Turns a straight segment into a there-and-back cycle.
  static List<GridPoint> _pingPong(List<GridPoint> seg) {
    if (seg.length < 2) return seg;
    final List<GridPoint> out = List<GridPoint>.of(seg);
    for (int i = seg.length - 2; i >= 1; i--) {
      out.add(seg[i]);
    }
    return out;
  }

  /// Clockwise closed rectangle loop (corners inclusive).
  static List<GridPoint> _rect(int x0, int y0, int x1, int y1) {
    final List<GridPoint> p = <GridPoint>[];
    for (int x = x0; x <= x1; x++) {
      p.add(GridPoint(x, y0));
    }
    for (int y = y0 + 1; y <= y1; y++) {
      p.add(GridPoint(x1, y));
    }
    for (int x = x1 - 1; x >= x0; x--) {
      p.add(GridPoint(x, y1));
    }
    for (int y = y1 - 1; y >= y0 + 1; y--) {
      p.add(GridPoint(x0, y));
    }
    return p;
  }

  /// A wide S-shaped patrol that ping-pongs across two rows.
  static List<GridPoint>? _zigzag(int w, int top, int bottom, math.Random rng) {
    if (bottom - top < 1 || w < 3) return null;
    final int y0 = top + rng.nextInt(bottom - top);
    final int y1 = y0 + 1;
    final int x0 = rng.nextInt(math.max(1, w - 2));
    final int x1 = (x0 + 2 + rng.nextInt(math.max(1, w - x0 - 2))).clamp(x0 + 2, w - 1);
    final List<GridPoint> seg = <GridPoint>[];
    for (int x = x0; x <= x1; x++) {
      seg.add(GridPoint(x, y0));
    }
    seg.add(GridPoint(x1, y1));
    for (int x = x1 - 1; x >= x0; x--) {
      seg.add(GridPoint(x, y1));
    }
    seg.add(GridPoint(x0, y0));
    return seg; // already a closed loop
  }

  /// A figure-eight built from two stacked rectangles sharing a centre cell.
  static List<GridPoint>? _eight(int w, int top, int bottom, math.Random rng) {
    if (bottom - top < 3 || w < 3) return null;
    final int cx = 1 + rng.nextInt(math.max(1, w - 2));
    final int yMid = top + 1 + rng.nextInt(math.max(1, bottom - top - 2));
    final int x0 = cx - 1;
    final int x1 = cx + 1;
    if (x0 < 0 || x1 >= w) return null;
    final int yTop = yMid - 1;
    final int yBot = yMid + 1;
    if (yTop < top || yBot > bottom) return null;

    // Trace: up loop clockwise, cross centre, down loop, back to centre.
    final List<GridPoint> p = <GridPoint>[
      GridPoint(cx, yMid),
      GridPoint(x1, yMid),
      GridPoint(x1, yTop),
      GridPoint(cx, yTop),
      GridPoint(x0, yTop),
      GridPoint(x0, yMid),
      GridPoint(cx, yMid),
      GridPoint(x1, yMid),
      GridPoint(x1, yBot),
      GridPoint(cx, yBot),
      GridPoint(x0, yBot),
      GridPoint(x0, yMid),
    ];
    // Validate adjacency (each step must be a single cell).
    for (int i = 0; i < p.length; i++) {
      final GridPoint a = p[i];
      final GridPoint b = p[(i + 1) % p.length];
      if (a.manhattanTo(b) != 1) return null;
    }
    return p;
  }

  static Level _fallback(int index, int biome) {
    const int w = 5;
    const int h = 7;
    return Level(
      index: index,
      biome: biome,
      width: w,
      height: h,
      start: const GridPoint(2, h - 1),
      finish: const GridPoint(2, 0),
      obstacles: <GridPoint>{},
      machines: <Machine>[
        Machine(path: <GridPoint>[
          const GridPoint(0, 3),
          const GridPoint(1, 3),
          const GridPoint(2, 3),
          const GridPoint(3, 3),
          const GridPoint(4, 3),
          const GridPoint(3, 3),
          const GridPoint(2, 3),
          const GridPoint(1, 3),
        ], carIndex: 0),
      ],
      rowTypes: _buildRowTypes(h),
      par: 6,
    );
  }
}
