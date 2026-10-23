import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DayOneAnimationOverlay extends StatefulWidget {
  const DayOneAnimationOverlay({
    required this.imagePath,
    required this.walkingActive,
    required this.heartbeatActive,
    required this.windActive,
    this.videoPath,
    this.onShadowAppear,
    this.onVideoComplete,
    super.key,
  });

  final String? imagePath;
  final String? videoPath;
  final bool walkingActive;
  final bool heartbeatActive;
  final bool windActive;
  final VoidCallback? onShadowAppear;
  final VoidCallback? onVideoComplete;

  @override
  State<DayOneAnimationOverlay> createState() => _DayOneAnimationOverlayState();
}

class _DayOneAnimationOverlayState extends State<DayOneAnimationOverlay>
    with TickerProviderStateMixin {
  final Random _random = Random();
  final List<_FlyingLeaf> _leaves = [];
  Size _sceneSize = Size.zero;
  bool _isPulsing = false;
  int _pulseGeneration = 0;

  late final AnimationController _zoomController;
  late final AnimationController _walkingController;
  late final AnimationController _entryZoomController;
  late final AnimationController _shakeController;
  late final AnimationController _pulseController;
  late final AnimationController _swayController;
  late final AnimationController _flashController;
  late final AnimationController _windController;
  late final AnimationController _darknessController;
  late final AnimationController _leafController;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat(reverse: true);
    _walkingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
      value: 0.5,
    );
    _entryZoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 0.5,
    );
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _windController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _darknessController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateLeaves);
    if (widget.walkingActive) {
      _walkingController.repeat(reverse: true);
      _entryZoomController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DayOneAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walkingActive != widget.walkingActive) {
      if (widget.walkingActive) {
        _walkingController.repeat(reverse: true);
        _entryZoomController.forward(from: 0);
      } else {
        _walkingController
          ..stop()
          ..value = 0.5;
      }
    }
    if (oldWidget.heartbeatActive != widget.heartbeatActive) {
      _isPulsing = widget.heartbeatActive;
      if (_isPulsing) _runHeartPulse(++_pulseGeneration);
    }
    if (oldWidget.windActive != widget.windActive) {
      if (widget.windActive) {
        _windController.forward();
        _darknessController.forward();
        _swayController.repeat(reverse: true);
        _leafController.repeat();
      } else {
        _windController.reverse();
        _darknessController.reverse();
        _swayController
          ..stop()
          ..value = 0.5;
        _leafController.stop();
        _leaves.clear();
      }
    }
    if (oldWidget.imagePath != widget.imagePath &&
        widget.heartbeatActive &&
        !oldWidget.heartbeatActive) {
      _shakeController.forward(from: 0);
      _flashController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _walkingController.dispose();
    _entryZoomController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    _swayController.dispose();
    _flashController.dispose();
    _windController.dispose();
    _darknessController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  Future<void> _runHeartPulse(int generation) async {
    var interval = 0.95;
    while (mounted && _isPulsing && generation == _pulseGeneration) {
      _pulseController.duration = Duration(
        milliseconds: (interval * 1000).round(),
      );
      await _pulseController.forward(from: 0);
      interval = max(0.55, interval - 0.025);
    }
  }

  void _updateLeaves() {
    final leafPower = _windController.value * 0.6;
    if (_random.nextDouble() < leafPower * 0.18) {
      _leaves.add(
        _FlyingLeaf(
          x: -30,
          y: _random.nextDouble() * _sceneSize.height,
          size: 6 + _random.nextDouble() * 12,
          velocityX: 6 + _random.nextDouble() * 10,
          velocityY: (_random.nextDouble() - 0.5) * 3,
          rotation: _random.nextDouble() * 6,
          rotationVelocity: (_random.nextDouble() - 0.5) * 0.3,
          color: HSLColor.fromAHSL(
            1,
            20 + _random.nextDouble() * 30,
            0.6,
            0.15 + _random.nextDouble() * 0.2,
          ).toColor(),
        ),
      );
    }
    _leaves.removeWhere((leaf) => leaf.x > _sceneSize.width + 40);
    for (final leaf in _leaves) {
      leaf.x += leaf.velocityX * (1 + leafPower * 2);
      leaf.y += leaf.velocityY + sin(leaf.x / 40) * 1.5;
      leaf.rotation += leaf.rotationVelocity;
    }
  }

  double _heartbeatBeat(double value) {
    final firstBeat = max(0.0, 1 - (value - 0.10).abs() / 0.10);
    final secondBeat = max(0.0, 1 - (value - 0.45).abs() / 0.10) * 0.7;
    return firstBeat + secondBeat;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sceneSize = constraints.biggest;
        final imageCacheWidth = (constraints.maxWidth *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(720, 1920)
            .toInt();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _zoomController,
                  _walkingController,
                  _entryZoomController,
                  _shakeController,
                  _swayController,
                ]),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 2400),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    final eased = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    );
                    return FadeTransition(
                      opacity: eased,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 1.045, end: 1).animate(eased),
                        child: child,
                      ),
                    );
                  },
                  child: widget.videoPath != null
                      ? _DayOneVideoBackground(
                          key: ValueKey('video:${widget.videoPath}'),
                          videoPath: widget.videoPath!,
                          posterPath: widget.videoPath!
                              .replaceFirst(
                                'assets/videos/day1/',
                                'assets/videos/day1/posters/',
                              )
                              .replaceFirst('.mp4', '.jpg'),
                          onShadowAppear: widget.onShadowAppear,
                          onVideoComplete: widget.onVideoComplete,
                        )
                      : widget.imagePath != null
                          ? Image.asset(
                              widget.imagePath!,
                              key: ValueKey('image:${widget.imagePath}'),
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              cacheWidth: imageCacheWidth,
                              fit: BoxFit.cover,
                            )
                          : const ColoredBox(
                              color: Colors.black,
                              key: ValueKey('empty-background'),
                            ),
                ),
                builder: (context, image) {
                  final shakeProgress = _shakeController.value;
                  final shakeOffset = Offset(
                    sin(shakeProgress * 60) * 30 * (1 - shakeProgress),
                    cos(shakeProgress * 47) * 22 * (1 - shakeProgress),
                  );
                  final walkPhase = _walkingController.value * 2 * pi;
                  final walkingOffset = widget.walkingActive
                      ? Offset(sin(walkPhase) * 2.4, cos(walkPhase * 2) * 1.3)
                      : Offset.zero;
                  final scale = 1.025 +
                      0.035 * _zoomController.value +
                      0.025 * _entryZoomController.value;
                  final skew = (_swayController.value - 0.5) * 0.07;
                  return Transform.translate(
                    offset: shakeOffset + walkingOffset,
                    child: Transform.scale(
                      scale: scale,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.skewX(skew),
                        child: image,
                      ),
                    ),
                  );
                },
              ),

            ),
            if (widget.walkingActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _walkingController,
                    builder: (context, child) => CustomPaint(
                      painter: _BirdsPainter(_walkingController.value),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LeavesPainter(_leaves, _leafController),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseController,
                    _darknessController,
                  ]),
                  builder: (context, child) {
                    final beat = _isPulsing
                        ? _heartbeatBeat(_pulseController.value)
                        : 0.0;
                    final darkness = (0.12 +
                            0.28 * _darknessController.value +
                            0.22 * beat)
                        .clamp(0.0, 0.75);
                    return Opacity(
                      opacity: darkness,
                      child: Transform.scale(
                        scale: 1 + 0.035 * beat,
                        child: child,
                      ),
                    );
                  },
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Colors.transparent, Color(0xD9000000)],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flashController,
                  builder: (context, child) => Opacity(
                    opacity: 0.55 *
                        (1 - _flashController.value) *
                        (_flashController.isAnimating ? 1 : 0),
                    child: child,
                  ),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayOneVideoBackground extends StatefulWidget {
  const _DayOneVideoBackground({
    required this.videoPath,
    required this.posterPath,
    this.onShadowAppear,
    this.onVideoComplete,
    super.key,
  });

  final String videoPath;
  final String posterPath;
  final VoidCallback? onShadowAppear;
  final VoidCallback? onVideoComplete;

  @override
  State<_DayOneVideoBackground> createState() =>
      _DayOneVideoBackgroundState();
}

class _DayOneVideoBackgroundState extends State<_DayOneVideoBackground> {
  late final VideoPlayerController _controller;
  bool _failed = false;
  bool _didSignalShadow = false;
  bool _didSignalVideoComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      widget.videoPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_checkShadowAppearance);
    unawaited(_initializeVideo());
  }

  void _checkShadowAppearance() {
    final value = _controller.value;
    if (!_didSignalShadow &&
        (value.position >= const Duration(seconds: 2) || value.isCompleted)) {
      _didSignalShadow = true;
      widget.onShadowAppear?.call();
    }
    if (value.isCompleted) _holdFinalFrame();
  }

  void _holdFinalFrame() {
    if (_didSignalVideoComplete) return;
    _didSignalVideoComplete = true;
    widget.onVideoComplete?.call();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setPlaybackSpeed(0.65);
      await _controller.setVolume(0);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Day one background video failed: $error');
      _didSignalVideoComplete = true;
      widget.onVideoComplete?.call();
      if (!_didSignalShadow) {
        _didSignalShadow = true;
        widget.onShadowAppear?.call();
      }
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkShadowAppearance);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !_controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Image.asset(
          widget.posterPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    }

    final videoSize = _controller.value.size;
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}

class _BirdsPainter extends CustomPainter {
  const _BirdsPainter(this.progress);

  final double progress;

  static const List<_MovingBird> _birds = [
    _MovingBird(0.26, 0.2, 0.0, 8),
    _MovingBird(0.53, 0.28, 1.7, 10),
    _MovingBird(0.74, 0.18, 3.1, 7),
    _MovingBird(0.4, 0.38, 4.4, 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final bird in _birds) {
      final phase = progress * 2 * pi + bird.phase;
      final x = bird.x * size.width + sin(phase) * 7;
      final y = bird.y * size.height + cos(phase * 0.6) * 4;
      final wingLift = sin(phase * 2) * bird.span * 0.45;
      final path = Path()
        ..moveTo(x - bird.span, y)
        ..quadraticBezierTo(
          x - bird.span * 0.42,
          y - wingLift,
          x,
          y + 1,
        )
        ..quadraticBezierTo(
          x + bird.span * 0.42,
          y - wingLift,
          x + bird.span,
          y,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BirdsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MovingBird {
  const _MovingBird(this.x, this.y, this.phase, this.span);

  final double x;
  final double y;
  final double phase;
  final double span;
}

class _FlyingLeaf {
  _FlyingLeaf({
    required this.x,
    required this.y,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationVelocity,
    required this.color,
  });

  double x;
  double y;
  double size;
  double velocityX;
  double velocityY;
  double rotation;
  double rotationVelocity;
  Color color;
}

class _LeavesPainter extends CustomPainter {
  const _LeavesPainter(this.leaves, Listenable repaint) : super(repaint: repaint);

  final List<_FlyingLeaf> leaves;

  @override
  void paint(Canvas canvas, Size size) {
    for (final leaf in leaves) {
      canvas
        ..save()
        ..translate(leaf.x, leaf.y)
        ..rotate(leaf.rotation)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: leaf.size * 2,
            height: leaf.size,
          ),
          Paint()..color = leaf.color,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeavesPainter oldDelegate) => true;
}