import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/direction.dart';
import '../../data/models/grid_point.dart';
import '../../data/models/level.dart';
import '../engine/game_controller.dart';
import 'board_geometry.dart';
import 'sprite_cache.dart';

/// Static board layer: asphalt, neon safe strips, grid, obstacles, start/finish
/// tile bases and the frame. Painted once per level and cached in a
/// [RepaintBoundary], so the expensive image/clip work never runs per frame.
class BoardBackgroundPainter extends CustomPainter {
  BoardBackgroundPainter(this.level);

  final Level level;
  SpriteCache get sprites => SpriteCache.instance;

  @override
  void paint(Canvas canvas, Size size) {
    final BoardGeometry geo = BoardGeometry(
      size: size,
      cols: level.width,
      rows: level.height,
    );
    final Rect full = Offset.zero & Size(size.width, geo.boardHeight);

    final Paint base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF3A4150), Color(0xFF2C313D)],
      ).createShader(full);
    canvas.drawRect(full, base);

    final ui.Image? lineImg = sprites.get(AssetPaths.bgLine(level.biome));
    if (lineImg != null) {
      final double tileH = size.width * lineImg.height / lineImg.width;
      for (double y = 0; y < geo.boardHeight; y += tileH) {
        _drawImageCover(canvas, lineImg, Rect.fromLTWH(0, y, size.width, tileH));
      }
    }

    final ui.Image? safe = sprites.get(AssetPaths.bgSafezone(level.biome));
    for (int row = 0; row < level.rowTypes.length; row++) {
      if (level.rowTypes[row] != RowType.safe) continue;
      final Rect r = geo.rowRect(row);
      if (safe != null) {
        _drawImageCover(canvas, safe, r);
      } else {
        canvas.drawRect(r, Paint()..color = AppColors.panelLight);
      }
    }

    _paintGrid(canvas, geo);
    _paintStartBase(canvas, geo);
    _paintFinishBase(canvas, geo);
    _paintObstacles(canvas, geo);
    _paintFrame(canvas, geo);
  }

  void _paintGrid(Canvas canvas, BoardGeometry geo) {
    final Paint line = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int x = 1; x < level.width; x++) {
      canvas.drawLine(Offset(x * geo.cell, 0),
          Offset(x * geo.cell, geo.boardHeight), line);
    }
    for (int y = 1; y < level.height; y++) {
      canvas.drawLine(Offset(0, y * geo.cell),
          Offset(geo.size.width, y * geo.cell), line);
    }
  }

  void _paintFrame(Canvas canvas, BoardGeometry geo) {
    final Rect r = Offset.zero & Size(geo.size.width, geo.boardHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(1.5), const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = const LinearGradient(
          colors: <Color>[AppColors.neon, AppColors.violet],
        ).createShader(r),
    );
  }

  void _paintStartBase(Canvas canvas, BoardGeometry geo) {
    final Rect cell = geo.cellRect(level.start).deflate(geo.cell * 0.1);
    final RRect pad =
        RRect.fromRectAndRadius(cell, Radius.circular(geo.cell * 0.22));
    canvas.drawRRect(
      pad,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF7FD9A8), Color(0xFF4FAE84)],
        ).createShader(cell),
    );
  }

  void _paintFinishBase(Canvas canvas, BoardGeometry geo) {
    final Rect cell = geo.cellRect(level.finish).deflate(geo.cell * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cell, Radius.circular(geo.cell * 0.22)),
      Paint()..color = const Color(0xFF1C3A2C),
    );
  }

  void _paintObstacles(Canvas canvas, BoardGeometry geo) {
    for (final GridPoint o in level.obstacles) {
      final Offset c = geo.center(o);
      final int seed = o.x * 73856093 ^ o.y * 19349663;
      _drawFlatShadow(canvas, c.translate(0, geo.cell * 0.16), geo.cell * 0.30,
          geo.cell * 0.12);
      if ((seed & 1) == 0) {
        _drawBush(canvas, c, geo.cell);
      } else {
        _drawTree(canvas, c, geo.cell);
      }
    }
  }

  void _drawBush(Canvas canvas, Offset c, double cell) {
    final double r = cell * 0.28;
    final List<Offset> blobs = <Offset>[
      Offset(c.dx - r * 0.7, c.dy + r * 0.2),
      Offset(c.dx + r * 0.7, c.dy + r * 0.2),
      Offset(c.dx, c.dy - r * 0.5),
      c,
    ];
    final Paint dark = Paint()..color = const Color(0xFF5FBF93);
    final Paint mid = Paint()..color = const Color(0xFF7FD9A8);
    for (final Offset b in blobs) {
      canvas.drawCircle(b, r, dark);
    }
    for (final Offset b in blobs) {
      canvas.drawCircle(b.translate(-r * 0.12, -r * 0.18), r * 0.7, mid);
    }
    canvas.drawCircle(Offset(c.dx - r * 0.2, c.dy - r * 0.45), r * 0.3,
        Paint()..color = const Color(0xFFAEE9CC));
  }

  void _drawTree(Canvas canvas, Offset c, double cell) {
    final double trunkW = cell * 0.1;
    final double trunkH = cell * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(c.dx, c.dy + cell * 0.22),
            width: trunkW,
            height: trunkH),
        Radius.circular(trunkW),
      ),
      Paint()..color = const Color(0xFF7A5A3A),
    );
    final double r = cell * 0.3;
    final Offset top = Offset(c.dx, c.dy - cell * 0.05);
    canvas.drawCircle(top, r, Paint()..color = const Color(0xFF4FAE84));
    canvas.drawCircle(top.translate(-r * 0.35, -r * 0.25), r * 0.7,
        Paint()..color = const Color(0xFF6FD0A0));
    canvas.drawCircle(top.translate(r * 0.2, -r * 0.4), r * 0.4,
        Paint()..color = const Color(0xFF9FE6C2));
  }

  void _drawFlatShadow(Canvas canvas, Offset c, double rx, double ry) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  void _drawImageCover(Canvas canvas, ui.Image img, Rect dst) {
    final double imgW = img.width.toDouble();
    final double imgH = img.height.toDouble();
    final double scale = math.max(dst.width / imgW, dst.height / imgH);
    final double srcW = dst.width / scale;
    final double srcH = dst.height / scale;
    final double srcX = (imgW - srcW) / 2;
    final double srcY = (imgH - srcH) / 2;
    canvas.save();
    canvas.clipRect(dst);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(srcX, srcY, srcW, srcH),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter old) =>
      !identical(old.level, level);
}

/// Dynamic layer: animated start/finish glow, optional corridor highlight,
/// cars and the chicken. Cheap vector + textured-quad draws only (no blur), so
/// it can repaint every frame without jank.
class BoardForegroundPainter extends CustomPainter {
  BoardForegroundPainter({
    required this.controller,
    required this.skinId,
    required this.moveAnim,
    required this.ambient,
    required this.path,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameController controller;
  final String skinId;
  final Animation<double> moveAnim; // move progress 0..1
  final Animation<double> ambient; // continuous 0..1
  final List<GridPoint>? path;

  Level get level => controller.level;
  SpriteCache get sprites => SpriteCache.instance;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = moveAnim.value;
    final BoardGeometry geo = BoardGeometry(
      size: size,
      cols: level.width,
      rows: level.height,
    );
    final double pulse = 0.5 + 0.5 * math.sin(ambient.value * math.pi * 2);

    if (path != null && path!.isNotEmpty) _paintCorridor(canvas, geo, pulse);
    _paintStartGlow(canvas, geo, pulse);
    _paintFinishGlow(canvas, geo, pulse);
    _paintCars(canvas, geo, t);
    _paintChicken(canvas, geo, t);
  }

  void _paintCorridor(Canvas canvas, BoardGeometry geo, double pulse) {
    final Paint dot = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.35 + 0.25 * pulse);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geo.cell * 0.05
      ..color = AppColors.goldLight.withValues(alpha: 0.5 + 0.3 * pulse);
    for (final GridPoint p in path!) {
      if (p == level.finish) continue;
      final Offset c = geo.center(p);
      final Rect r = Rect.fromCenter(
          center: c, width: geo.cell * 0.5, height: geo.cell * 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(geo.cell * 0.16)),
        dot,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(geo.cell * 0.16)),
        ring,
      );
    }
  }

  void _paintStartGlow(Canvas canvas, BoardGeometry geo, double pulse) {
    final Rect cell = geo.cellRect(level.start).deflate(geo.cell * 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cell, Radius.circular(geo.cell * 0.22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.cell * (0.04 + 0.03 * pulse)
        ..color = Colors.white.withValues(alpha: 0.4 + 0.4 * pulse),
    );
  }

  void _paintFinishGlow(Canvas canvas, BoardGeometry geo, double pulse) {
    final Offset c = geo.center(level.finish);
    final Rect cell = geo.cellRect(level.finish).deflate(geo.cell * 0.08);
    final RRect tile =
        RRect.fromRectAndRadius(cell, Radius.circular(geo.cell * 0.22));
    canvas.drawRRect(
      tile,
      Paint()
        ..color = AppColors.neonGreen.withValues(alpha: 0.12 + 0.16 * pulse),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.cell * 0.06
        ..color = AppColors.neonGreen.withValues(alpha: 0.85 + 0.15 * pulse),
    );
    // Expanding "beacon" ring.
    final double expand = geo.cell * (0.5 + 0.18 * pulse);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: expand * 2, height: expand * 2),
        Radius.circular(geo.cell * 0.3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.cell * 0.03
        ..color = AppColors.neonGreen.withValues(alpha: 0.4 * (1 - pulse)),
    );
    _drawFlag(canvas, c, geo.cell * 0.4);
  }

  void _drawFlag(Canvas canvas, Offset c, double s) {
    final Paint pole = Paint()
      ..color = AppColors.white
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - s * 0.35, c.dy + s * 0.6),
        Offset(c.dx - s * 0.35, c.dy - s * 0.6), pole);
    final double fw = s * 0.7;
    final double fh = s * 0.5;
    final Rect flag = Rect.fromLTWH(c.dx - s * 0.35, c.dy - s * 0.6, fw, fh);
    const int n = 3;
    final double cw = fw / n;
    final double ch = fh / 2;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < 2; j++) {
        final bool dark = (i + j).isEven;
        canvas.drawRect(
          Rect.fromLTWH(flag.left + i * cw, flag.top + j * ch, cw, ch),
          Paint()..color = dark ? AppColors.ink : AppColors.white,
        );
      }
    }
  }

  void _paintCars(Canvas canvas, BoardGeometry geo, double t) {
    for (int i = 0; i < controller.machineCount; i++) {
      final Offset pos = geo.lerpCenter(
          controller.machineFrom(i), controller.machineTo(i), t);
      final Direction facing = controller.machineFacing(i);
      final ui.Image? img = sprites.get(
          AssetPaths.cars[controller.machineCar(i) % AssetPaths.cars.length]);
      _drawFlatShadow(canvas, pos.translate(0, geo.cell * 0.06),
          geo.cell * 0.34, geo.cell * 0.18);
      if (img == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: pos, width: geo.cell * 0.7, height: geo.cell * 0.9),
            Radius.circular(geo.cell * 0.18),
          ),
          Paint()..color = AppColors.gold,
        );
        continue;
      }
      _drawSpriteRotated(canvas, img, pos,
          targetHeight: geo.cell * 1.02, angle: facing.spriteAngle);
    }
  }

  void _paintChicken(Canvas canvas, BoardGeometry geo, double t) {
    final bool lost = controller.status == GameStatus.lost;
    final bool won = controller.status == GameStatus.won;
    final Offset pos =
        geo.lerpCenter(controller.playerFrom, controller.playerTo, t);
    final double hop = controller.playerFrom == controller.playerTo
        ? 0
        : math.sin(t * math.pi) * geo.cell * 0.28;
    final Offset drawPos = pos.translate(0, -hop);

    _drawFlatShadow(canvas, pos.translate(0, geo.cell * 0.30),
        geo.cell * 0.26, geo.cell * 0.11);

    final ui.Image? img = lost
        ? sprites.get(AssetPaths.chickenSmash(skinId))
        : sprites.get(AssetPaths.chicken(skinId));
    if (img == null) {
      canvas.drawCircle(drawPos, geo.cell * 0.3, Paint()..color = Colors.white);
      return;
    }
    final bool flip = controller.playerFacing == Direction.right;
    double scale = 1.0;
    if (won) {
      scale = 1.0 + 0.12 * math.sin(t * math.pi);
    } else if (lost) {
      scale = 1.05;
    }
    _drawSprite(canvas, img, drawPos,
        targetHeight: geo.cell * (lost ? 0.95 : 1.12) * scale, flipX: flip);
  }

  void _drawFlatShadow(Canvas canvas, Offset c, double rx, double ry) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
  }

  void _drawSprite(Canvas canvas, ui.Image img, Offset center,
      {required double targetHeight, bool flipX = false}) {
    final double aspect = img.width / img.height;
    final double h = targetHeight;
    final double w = h * aspect;
    final Rect dst = Rect.fromCenter(center: center, width: w, height: h);
    canvas.save();
    if (flipX) {
      canvas.translate(center.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-center.dx, 0);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  void _drawSpriteRotated(Canvas canvas, ui.Image img, Offset center,
      {required double targetHeight, required double angle}) {
    final double aspect = img.width / img.height;
    final double h = targetHeight;
    final double w = h * aspect;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardForegroundPainter old) =>
      old.skinId != skinId ||
      !identical(old.path, path) ||
      !identical(old.controller, controller) ||
      !identical(old.moveAnim, moveAnim) ||
      !identical(old.ambient, ambient);
}
