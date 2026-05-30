import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/levels/level_generator.dart';
import '../../data/models/direction.dart';
import '../../data/models/grid_point.dart';
import '../../data/models/level.dart';
import '../../data/repositories/progress_repository.dart';
import '../../game/engine/game_controller.dart';
import '../../game/rendering/board_painter.dart';
import '../../widgets/koko_button.dart';
import 'widgets/dpad.dart';
import 'widgets/result_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Result { none, win, lose }

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  static const int _hintPackCount = 3;
  static const int _hintPackCost = 60;

  late GameController _controller;
  late AnimationController _anim; // per-move animation
  late AnimationController _ambient; // continuous glow
  late final Listenable _boardRepaint; // stable merge to avoid per-frame churn
  late int _levelIndex;

  _Result _result = _Result.none;
  int _earnedStars = 0;
  int _earnedCoins = 0;

  bool _hintActive = false;
  List<GridPoint>? _path;

  Offset _drag = Offset.zero;

  bool get _tutorial => _controller.level.index <= 2;

  @override
  void initState() {
    super.initState();
    _levelIndex = widget.levelIndex;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _controller = GameController(LevelGenerator.generate(_levelIndex));
    _boardRepaint =
        Listenable.merge(<Listenable>[_anim, _ambient, _controller]);
    _refreshPath();
  }

  @override
  void dispose() {
    _anim.dispose();
    _ambient.dispose();
    _controller.dispose();
    super.dispose();
  }

  ProgressRepository get _progress => AppScope.progressOf(context);

  void _refreshPath() {
    _path = (_tutorial || _hintActive) && _controller.isPlaying
        ? _controller.solutionPath()
        : null;
  }

  // --- Turn handling ---------------------------------------------------------
  void _move(Direction dir) {
    if (_anim.isAnimating || !_controller.isPlaying || _result != _Result.none) {
      return;
    }
    final MoveResult res = _controller.applyMove(dir);
    if (!res.applied) {
      HapticFeedback.lightImpact();
      return;
    }
    _anim.forward(from: 0).whenComplete(_afterMove);
  }

  void _afterMove() {
    if (!mounted) return;
    if (_controller.status == GameStatus.won) {
      _handleWin();
    } else if (_controller.status == GameStatus.lost) {
      HapticFeedback.heavyImpact();
      setState(() {
        _path = null;
        _result = _Result.lose;
      });
    } else {
      setState(_refreshPath);
    }
  }

  Future<void> _handleWin() async {
    HapticFeedback.mediumImpact();
    final ProgressRepository progress = _progress;
    final bool firstClear = _levelIndex >= progress.highestLevel;
    final int stars = _controller.starsForMoves();
    final int coins = firstClear ? 14 + stars * 6 : 5;
    _earnedStars = stars;
    _earnedCoins = coins;
    await progress.completeLevel(_levelIndex, stars, coins);
    if (!mounted) return;
    setState(() {
      _path = null;
      _result = _Result.win;
    });
  }

  void _retry() {
    _controller.restart();
    _anim.value = 1;
    setState(() {
      _result = _Result.none;
      _refreshPath();
    });
  }

  void _loadLevel(int index) {
    setState(() {
      _levelIndex = index;
      _controller.loadLevel(LevelGenerator.generate(index));
      _anim.value = 1;
      _result = _Result.none;
      _hintActive = false;
      _refreshPath();
    });
  }

  void _menu() => Navigator.of(context).pop();

  Future<void> _onHintPressed() async {
    if (_hintActive || !_controller.isPlaying) return;
    if (_progress.hints > 0) {
      await _progress.useHint();
      _activateHint();
    } else {
      await _showBuyHintsDialog();
    }
  }

  void _activateHint() {
    if (!mounted) return;
    setState(() {
      _hintActive = true;
      _refreshPath();
    });
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() {
        _hintActive = false;
        _refreshPath();
      });
    });
  }

  Future<void> _showBuyHintsDialog() async {
    final bool? buy = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Out of hints', style: AppText.title(size: 20)),
        content: Text(
          'Buy $_hintPackCount more hints for $_hintPackCost coins '
          '(you have ${_progress.coins}).',
          style: AppText.body(size: 14),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: AppText.body(size: 15, color: AppColors.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Buy',
                style: AppText.button(size: 15, color: AppColors.goldLight)),
          ),
        ],
      ),
    );
    if (buy != true || !mounted) return;
    final bool ok = await _progress.buyHints(_hintPackCount, _hintPackCost);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          content: Text(
              'Need ${_hintPackCost - _progress.coins} more coins'),
        ),
      );
      return;
    }
    // Use one of the freshly-bought hints right away.
    await _progress.useHint();
    _activateHint();
  }

  // --- Swipe -----------------------------------------------------------------
  void _onPanStart(DragStartDetails _) => _drag = Offset.zero;
  void _onPanUpdate(DragUpdateDetails d) => _drag += d.delta;
  void _onPanEnd(DragEndDetails _) {
    const double threshold = 14;
    if (_drag.distance < threshold) return;
    if (_drag.dx.abs() > _drag.dy.abs()) {
      _move(_drag.dx > 0 ? Direction.right : Direction.left);
    } else {
      _move(_drag.dy > 0 ? Direction.down : Direction.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Level level = _controller.level;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.menuSky),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _buildHud(level),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Center(
                        child: GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: _Board(
                            controller: _controller,
                            moveAnim: _anim,
                            ambient: _ambient,
                            repaint: _boardRepaint,
                            skinId: _progress.selectedSkin,
                            path: _path,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildControls(),
                  const SizedBox(height: 10),
                ],
              ),
              if (_result != _Result.none) _buildResult(level),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud(Level level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: <Widget>[
          KokoIconButton(icon: Icons.arrow_back_rounded, onPressed: _menu),
          Expanded(
            child: Column(
              children: <Widget>[
                Text('LEVEL ${level.index}', style: AppText.title(size: 22)),
                const SizedBox(height: 2),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (BuildContext context, _) => Text(
                    'Moves left ${_controller.movesLeft}   •   3★ in ≤${_controller.threeStarMoves}',
                    style: AppText.label(size: 11, color: AppColors.steel),
                  ),
                ),
              ],
            ),
          ),
          if (!_tutorial) ...<Widget>[
            ListenableBuilder(
              listenable: _progress,
              builder: (BuildContext context, _) => _HintButton(
                active: _hintActive,
                count: _progress.hints,
                onPressed: _onHintPressed,
              ),
            ),
            const SizedBox(width: 8),
          ],
          KokoIconButton(icon: Icons.refresh_rounded, onPressed: _retry),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) {
        return DPad(
          enabled: _controller.isPlaying && _result == _Result.none,
          onMove: _move,
        );
      },
    );
  }

  Widget _buildResult(Level level) {
    if (_result == _Result.win) {
      return ResultOverlay(
        child: WinPanel(
          level: level.index,
          stars: _earnedStars,
          coins: _earnedCoins,
          movesUsed: _controller.moves,
          threeStarMoves: _controller.threeStarMoves,
          onNext: () => _loadLevel(_levelIndex + 1),
          onReplay: _retry,
          onMenu: _menu,
        ),
      );
    }
    return ResultOverlay(
      child: LosePanel(
        message: _loseMessage(),
        onRetry: _retry,
        onMenu: _menu,
      ),
    );
  }

  String _loseMessage() {
    switch (_controller.deathCause) {
      case DeathCause.outOfMoves:
        return 'Out of moves! Plan a tighter route.';
      case DeathCause.hitCar:
        return 'You stepped right into traffic!';
      case DeathCause.carHitChicken:
      case DeathCause.none:
        return 'A car caught you mid-crossing!';
    }
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.active,
    required this.count,
    required this.onPressed,
  });

  final bool active;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool empty = count <= 0;
    return Opacity(
      opacity: active ? 0.5 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          KokoIconButton(
            icon: Icons.lightbulb_rounded,
            style: KokoButtonStyle.gold,
            onPressed: active ? null : onPressed,
          ),
          // Count badge (or a "+" when the player needs to buy more).
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: empty ? AppColors.orange : AppColors.neonGreen,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.nightDeep, width: 1.5),
              ),
              child: Text(
                empty ? '+' : '$count',
                textAlign: TextAlign.center,
                style: AppText.button(size: 12, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.controller,
    required this.moveAnim,
    required this.ambient,
    required this.repaint,
    required this.skinId,
    required this.path,
  });

  final GameController controller;
  final Animation<double> moveAnim;
  final Animation<double> ambient;
  final Listenable repaint;
  final String skinId;
  final List<GridPoint>? path;

  @override
  Widget build(BuildContext context) {
    final double aspect = controller.level.width / controller.level.height;
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                painter: BoardBackgroundPainter(controller.level),
                isComplex: true,
                willChange: false,
                size: Size.infinite,
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: BoardForegroundPainter(
                  controller: controller,
                  skinId: skinId,
                  moveAnim: moveAnim,
                  ambient: ambient,
                  path: path,
                  repaint: repaint,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
