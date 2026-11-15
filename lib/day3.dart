import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

const int dayThreeStartingPhase = 1;

const dayThreeVideoPaths = [
  'assets/videos/day3/day3_04_first_corridor.mp4',
  'assets/videos/day3/day3_02_light_candle.mp4',
  'assets/videos/day3/day3_03_what_way.mp4',
  'assets/videos/day3/day3_01_door_fall.mp4',
  'assets/videos/day3/day3_05_mirror.mp4',
  'assets/videos/day3/day3_06_second_corridor.mp4',
  'assets/videos/day3/day3_07_narrow_corridor_dark.mp4',
  'assets/videos/day3/clean-1.mp4',
  'assets/videos/day3/clean.mp4',
  'assets/videos/day3/gemini_generated_video_6b557083.mp4',
];

String dayThreeSceneContext(int phase) => switch (phase) {
  1 => 'the traveler falls as the door collapses',
  2 => 'the traveler lights a candle and picks up the flashlight',
  3 => 'the traveler asks which way to go',
  4 => 'the traveler enters the mirror corridor and hears someone nearby',
  5 => 'the traveler faces their reflection in the mirror',
  6 => 'the traveler enters the second corridor',
  7 => 'the light goes out in the narrow corridor',
  8 => 'the traveler enters the inner conflict corridor',
  9 => 'the traveler confronts their inner conflict at the corridor end',
  10 => 'the traveler checks the alarm on their phone in the final corridor',
  _ => 'the traveler is exploring the passage',
};

class StorySequencePlayer extends StatefulWidget {
  const StorySequencePlayer({
    required this.phase,
    required this.onPhaseChanged,
    required this.onInteractionChanged,
    required this.onComplete,
    super.key,
  });

  final int phase;
  final ValueChanged<int> onPhaseChanged;
  final ValueChanged<bool> onInteractionChanged;
  final VoidCallback onComplete;

  @override
  State<StorySequencePlayer> createState() => _DayThreeVideoBackgroundState();
}

class _DayThreeVideoBackgroundState extends State<StorySequencePlayer> {
  VideoPlayerController? _controller;
  VideoPlayerController? _nextController;
  Timer? _phoneHapticsTimer;
  Timer? _rageChargeTimer;
  int? _nextPhase;
  int _activation = 0;
  int _phase = 1;
  int _crawlTapsLeft = 3;
  int _phoneStep = 0;
  int _bubblesLeftToSmash = 5;
  double _rageProgress = 0;
  bool _failed = false;
  bool _completionSent = false;
  bool _actionCompleted = false;
  bool _showActionOverlay = false;
  bool _showCorridorSelection = false;
  bool _showCrawlStruggle = false;
  bool _crawlCompleted = false;
  bool _showFinalDecision = false;
  bool _showPhoneInteraction = false;
  bool _isHoldingRage = false;

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
    unawaited(_activatePhase(_phase));
  }

  @override
  void didUpdateWidget(covariant StorySequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase && widget.phase != _phase) {
      _phase = widget.phase;
      _completionSent = false;
      _failed = false;
      _resetInteractions();
      unawaited(_activatePhase(_phase));
    }
  }

  void _resetInteractions() {
    _stopPhoneHaptics();
    _rageChargeTimer?.cancel();
    _rageChargeTimer = null;
    _actionCompleted = false;
    _showActionOverlay = false;
    _showCorridorSelection = false;
    _showCrawlStruggle = false;
    _crawlCompleted = false;
    _crawlTapsLeft = 3;
    _showFinalDecision = false;
    _phoneStep = 0;
    _bubblesLeftToSmash = 5;
    _rageProgress = 0;
    _showPhoneInteraction = false;
    _isHoldingRage = false;
  }

  Future<void> _activatePhase(int phase) async {
    final activation = ++_activation;
    final previousController = _controller;
    previousController?.removeListener(_checkProgress);
    VideoPlayerController? controller;

    try {
      if (_nextPhase == phase) {
        controller = _nextController;
        _nextController = null;
        _nextPhase = null;
      } else {
        await _disposeController(_nextController);
        _nextController = null;
        _nextPhase = null;
        controller = VideoPlayerController.asset(
          dayThreeVideoPaths[phase - 1],
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await controller.initialize();
      }

      if (!mounted || activation != _activation) {
        await _disposeController(controller);
        return;
      }

      _controller = controller;
      controller!.addListener(_checkProgress);
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(phase == 10 ? 1.0 : 0.65);
      await controller.setVolume(1);
      await controller.play();
      if (mounted && activation == _activation) setState(() {});
      await _disposeController(previousController);

      if (phase < dayThreeVideoPaths.length) {
        unawaited(_preloadNext(phase + 1, activation));
      }
    } catch (error) {
      debugPrint('Day three video failed: $error');
      await _disposeController(controller);
      if (!mounted || activation != _activation) return;
      _failed = true;
      setState(() {});
      _completeVideo();
    }
  }

  Future<void> _preloadNext(int phase, int activation) async {
    final controller = VideoPlayerController.asset(
      dayThreeVideoPaths[phase - 1],
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted || activation != _activation || _phase + 1 != phase) {
        await _disposeController(controller);
        return;
      }

      _nextController = controller;
      _nextPhase = phase;
    } catch (error) {
      debugPrint('Day three next video preload failed: $error');
      await _disposeController(controller);
    }
  }

  Future<void> _disposeController(VideoPlayerController? controller) async {
    if (controller == null) return;
    controller.removeListener(_checkProgress);
    await controller.dispose();
  }

  void _checkProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final position = value.position.inMilliseconds;
    final duration = value.duration.inMilliseconds;

    if (_phase <= 2) {
      final actionPosition = _phase == 1 ? 5500 : 6000;
      if (!_actionCompleted &&
          (position >= actionPosition || value.isCompleted) &&
          !_showActionOverlay) {
        _pauseForAction();
      } else if (_actionCompleted && (position >= 10000 || value.isCompleted)) {
        unawaited(controller.pause());
        _completeVideo();
      }
      return;
    }

    switch (_phase) {
      case 3:
        if (value.isCompleted || (duration > 0 && position >= duration)) {
          if (!_showCorridorSelection) {
            unawaited(controller.pause());
            HapticFeedback.heavyImpact();
            setState(() => _showCorridorSelection = true);
            widget.onInteractionChanged(true);
          }
        }
        break;
      case 4:
        if ((position >= 4200 || value.isCompleted) && !_showActionOverlay) {
          _pauseForAction();
        }
        break;
      case 8:
        if ((position >= 8500 || value.isCompleted) && !_showActionOverlay) {
          _pauseForAction();
        }
        break;
      case 6:
        if ((position >= 8500 || value.isCompleted) && !_showActionOverlay) {
          _pauseForAction();
        }
        break;
      case 5:
        if (position >= 6500 || value.isCompleted) {
          if (!_showFinalDecision) {
            HapticFeedback.heavyImpact();
            setState(() => _showFinalDecision = true);
          }
          if (duration > 6750 && position >= duration - 250) {
            unawaited(controller.seekTo(const Duration(milliseconds: 6500)));
          }
        }
        break;
      case 7:
        if (!_crawlCompleted && (position >= 5200 || value.isCompleted)) {
          if (!_showCrawlStruggle) {
            unawaited(controller.pause());
            HapticFeedback.heavyImpact();
            setState(() => _showCrawlStruggle = true);
          }
          return;
        }
        if (_crawlCompleted && (position >= 8000 || value.isCompleted)) {
          if (!_showFinalDecision) {
            HapticFeedback.heavyImpact();
            setState(() => _showFinalDecision = true);
          }
          if (duration > 8250 && position >= duration - 250) {
            unawaited(controller.seekTo(const Duration(milliseconds: 8000)));
          }
        }
        break;
      case 9:
        if (position >= 6500 || value.isCompleted) {
          if (!_showFinalDecision) {
            HapticFeedback.heavyImpact();
            setState(() => _showFinalDecision = true);
          }
          if (duration > 6750 && position >= duration - 250) {
            unawaited(controller.seekTo(const Duration(milliseconds: 6500)));
          }
        }
        break;
      case 10:
        if (_phoneStep == 0 && position >= 2500) {
          if (!_showPhoneInteraction) {
            unawaited(controller.pause());
            _startPhoneHaptics(const Duration(milliseconds: 600));
            setState(() => _showPhoneInteraction = true);
          }
          return;
        }
        if (_phoneStep == 1 && position >= 9500) {
          if (!_showPhoneInteraction) {
            unawaited(controller.pause());
            _startPhoneHaptics(const Duration(milliseconds: 500));
            setState(() => _showPhoneInteraction = true);
          }
          return;
        }
        if (_phoneStep == 2 && position >= 13000 && position < 17000) {
          if (!_showPhoneInteraction) {
            unawaited(controller.setPlaybackSpeed(0.6));
            _startPhoneHaptics(const Duration(milliseconds: 450));
            setState(() => _showPhoneInteraction = true);
          }
          return;
        }
        if (_phoneStep == 2 && position >= 17000) {
          unawaited(controller.setPlaybackSpeed(1.0));
          _stopPhoneHaptics();
          setState(() {
            _showPhoneInteraction = false;
            _phoneStep = 3;
          });
        }
        if (_phoneStep == 3 && position >= 18200) {
          if (!_showPhoneInteraction) {
            unawaited(controller.pause());
            _startPhoneHaptics(const Duration(milliseconds: 350));
            setState(() => _showPhoneInteraction = true);
          }
          return;
        }
        if (_phoneStep == 4 && position >= duration - 350) {
          if (!_showFinalDecision) {
            unawaited(controller.pause());
            _startPhoneHaptics();
            setState(() => _showFinalDecision = true);
          }
        }
        break;
    }
  }

  void _startPhoneHaptics([
    Duration interval = const Duration(milliseconds: 800),
  ]) {
    _phoneHapticsTimer?.cancel();
    HapticFeedback.heavyImpact();
    _phoneHapticsTimer = Timer.periodic(interval, (_) {
      HapticFeedback.mediumImpact();
    });
  }

  void _stopPhoneHaptics() {
    _phoneHapticsTimer?.cancel();
    _phoneHapticsTimer = null;
  }

  void _onPhoneSwipeUp() {
    if (_phoneStep != 0) return;
    _stopPhoneHaptics();
    HapticFeedback.heavyImpact();
    setState(() {
      _showPhoneInteraction = false;
      _phoneStep = 1;
    });
    unawaited(_controller?.play());
  }

  void _onPhoneScreenTap() {
    if (_phoneStep != 1) return;
    _stopPhoneHaptics();
    HapticFeedback.selectionClick();
    setState(() {
      _showPhoneInteraction = false;
      _phoneStep = 2;
    });
    unawaited(_controller?.play());
  }

  void _onBubbleSmashTap() {
    if (_phoneStep != 2) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _bubblesLeftToSmash--;
      if (_bubblesLeftToSmash <= 0) {
        _showPhoneInteraction = false;
        _phoneStep = 3;
        _stopPhoneHaptics();
        unawaited(_controller?.setPlaybackSpeed(1.0));
      }
    });
  }

  void _onRageHoldStart() {
    if (_phoneStep != 3 || _isHoldingRage) return;
    setState(() => _isHoldingRage = true);
    _rageChargeTimer?.cancel();
    _rageChargeTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      var charged = false;
      setState(() {
        _rageProgress += 0.04;
        if (_rageProgress >= 1) {
          _rageProgress = 1;
          timer.cancel();
          charged = true;
        }
      });
      if (charged) _completeRageCharge();
    });
  }

  void _onRageHoldEnd() {
    if (_phoneStep != 3 || _rageProgress >= 1) return;
    _rageChargeTimer?.cancel();
    _rageChargeTimer = null;
    setState(() {
      _isHoldingRage = false;
      _rageProgress = 0;
    });
  }

  void _completeRageCharge() {
    _rageChargeTimer?.cancel();
    _rageChargeTimer = null;
    _stopPhoneHaptics();
    HapticFeedback.vibrate();
    setState(() {
      _isHoldingRage = false;
      _showPhoneInteraction = false;
      _phoneStep = 4;
    });
    unawaited(_controller?.play());
  }

  void _pauseForAction() {
    unawaited(_controller?.pause());
    HapticFeedback.heavyImpact();
    setState(() => _showActionOverlay = true);
    widget.onInteractionChanged(true);
  }

  void _handleActionPressed() {
    if (!_showActionOverlay) return;
    HapticFeedback.lightImpact();

    if (_phase == 1 || _phase == 2) {
      final controller = _controller;
      setState(() {
        _showActionOverlay = false;
        _actionCompleted = true;
      });
      widget.onInteractionChanged(false);
      if (controller?.value.isCompleted ?? false) {
        _completeVideo();
      } else {
        unawaited(controller?.play());
      }
    } else if (_phase == 4) {
      _loadPhase(5);
    } else if (_phase == 6) {
      _loadPhase(7);
    } else if (_phase == 8) {
      _loadPhase(9);
    }
  }

  void _loadPhase(int phase) {
    if (!mounted || phase < 1 || phase > dayThreeVideoPaths.length) return;
    setState(() {
      _phase = phase;
      _failed = false;
      _completionSent = false;
      _resetInteractions();
    });
    widget.onInteractionChanged(true);
    widget.onPhaseChanged(phase);
    unawaited(_activatePhase(phase));
  }

  void _handleCrawlTap() {
    HapticFeedback.heavyImpact();
    setState(() {
      _crawlTapsLeft--;
      if (_crawlTapsLeft <= 0) {
        _showCrawlStruggle = false;
        _crawlCompleted = true;
        unawaited(_controller?.play());
      }
    });
  }

  void _completeVideo() {
    if (_completionSent) return;
    _stopPhoneHaptics();
    _rageChargeTimer?.cancel();
    _rageChargeTimer = null;
    _completionSent = true;
    unawaited(_controller?.pause());
    widget.onInteractionChanged(false);
    widget.onComplete();
  }

  void _returnToJunction() => _loadPhase(3);

  @override
  void dispose() {
    _activation++;
    _stopPhoneHaptics();
    _rageChargeTimer?.cancel();
    unawaited(_disposeController(_controller));
    unawaited(_disposeController(_nextController));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final videoSize = controller.value.size;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Center(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoSize.width,
                  height: videoSize.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
          if (_showActionOverlay) _buildActionOverlay(),
          if (_phase >= 3 && _showCorridorSelection)
            _buildCorridorSelectionOverlay(),
          if (_phase >= 4 && _showCrawlStruggle) _buildCrawlStruggleOverlay(),
          if (_phase == 10 && _showPhoneInteraction)
            _buildPhoneInteractionOverlay(),
          if (_phase >= 4 && _showFinalDecision) _buildFinalDecisionOverlay(),
        ],
      ),
    );
  }

  Widget _buildActionOverlay() {
    final (title, buttonText, icon) = switch (_phase) {
      1 => (
        'المكان مظلم تماماً.. وهناك شمعة بجانبك',
        'إشعال الشمعة بعود الثقاب',
        Icons.local_fire_department_outlined,
      ),
      2 => (
        'انطفأت الشمعة! يوجد مصباح يدوي على الأرض',
        'التقاط الكشاف وتشغيله بسرعة',
        Icons.flashlight_on_outlined,
      ),
      4 => (
        'صوت الهمس يناديك.. تابع ممر المرآة بحذر.',
        'التقدم نحو المرآة',
        Icons.visibility_outlined,
      ),
      8 => (
        'ممر الصراع الداخلي يمتد أمامك.',
        'دخول الممر ومتابعة الطريق',
        Icons.explore_outlined,
      ),
      _ => (
        'الجدران الحجرية تبدأ في الاقتراب من بعضها!',
        'الاندفاع للأمام قبل انسداد الممر',
        Icons.directions_run_outlined,
      ),
    };

    return ColoredBox(
      color: Colors.black.withOpacity(0.55),
      child: Align(
        alignment: const Alignment(0, 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 230,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_phase),
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(seconds: 5),
                  onEnd: _handleActionPressed,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      value > 0.3 ? Colors.greenAccent : Colors.redAccent,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _handleActionPressed,
                icon: Icon(icon),
                label: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorridorSelectionOverlay() {
    return ColoredBox(
      color: Colors.black.withOpacity(0.58),
      child: Align(
        alignment: const Alignment(0, 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أي طريق ستسلك؟ (Which way?)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('day-three-mirror-corridor'),
                  onPressed: () => _loadPhase(4),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('ممر المرآة'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('day-three-narrow-corridor'),
                  onPressed: () => _loadPhase(6),
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: const Text('السرداب الضيق'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('day-three-clean-corridor'),
                  onPressed: () => _loadPhase(8),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('ممر الصراع الداخلي'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('day-three-final-alarm-corridor'),
                  onPressed: () => _loadPhase(10),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('ممر الإنذار الأخير'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrawlStruggleOverlay() {
    return ColoredBox(
      color: Colors.black.withOpacity(0.6),
      child: Align(
        alignment: const Alignment(0, 0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'الجدران تطبق عليك والسقف ينخفض!',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط بسرعة للزحف للأمام ($_crawlTapsLeft ضغطات متبقية)',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            IconButton.filled(
              onPressed: _handleCrawlTap,
              icon: const Icon(Icons.touch_app_outlined),
              iconSize: 42,
              padding: const EdgeInsets.all(18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInteractionOverlay() {
    final title = switch (_phoneStep) {
      0 => 'اسحب الشاشة لأعلى لتفتح هاتفك',
      1 => 'المس شاشة الهاتف',
      2 => 'حطّم الرسائل قبل أن تختفي',
      _ => 'اشحن غضبك بالضغط المطوّل',
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: _phoneStep == 0
            ? (details) {
                if ((details.primaryVelocity ?? 0) < -100) {
                  _onPhoneSwipeUp();
                }
              }
            : null,
        child: Align(
          alignment: const Alignment(0, 0.42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                if (_phoneStep == 0)
                  const Icon(
                    Icons.swipe_up_alt,
                    color: Colors.lightBlueAccent,
                    size: 60,
                  )
                else if (_phoneStep == 1)
                  IconButton.filled(
                    key: const ValueKey('day-three-phone-screen-tap'),
                    onPressed: _onPhoneScreenTap,
                    icon: const Icon(Icons.touch_app),
                    iconSize: 48,
                    padding: const EdgeInsets.all(22),
                  )
                else if (_phoneStep == 2)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                      _bubblesLeftToSmash,
                      (index) => ActionChip(
                        key: ValueKey('day-three-message-bubble-$index'),
                        avatar: const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text('اكسر الرسالة'),
                        labelStyle: const TextStyle(color: Colors.white),
                        backgroundColor: Colors.redAccent,
                        onPressed: _onBubbleSmashTap,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    key: const ValueKey('day-three-rage-charge'),
                    onLongPressStart: (_) => _onRageHoldStart(),
                    onLongPressEnd: (_) => _onRageHoldEnd(),
                    child: SizedBox(
                      width: 116,
                      height: 116,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(
                              value: _rageProgress,
                              strokeWidth: 7,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.redAccent,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _isHoldingRage ? 92 : 82,
                            height: _isHoldingRage ? 92 : 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isHoldingRage
                                  ? Colors.redAccent.withValues(alpha: 0.85)
                                  : const Color(0xFF0A0F0D),
                              border: Border.all(
                                color: Colors.redAccent,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.flash_on,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalDecisionOverlay() {
    final isMirrorPath = _phase == 5;
    final isCleanPath = _phase == 9;
    final isPhonePath = _phase == 10;
    final question = isMirrorPath
        ? 'انعكاسك يسألك: "أنا اخترت البقاء.. هل سوف تكون كذلك؟"'
        : isCleanPath
        ? 'وصلت إلى نهاية ممر الصراع الداخلي. هل ستكمل رحلتك؟'
        : isPhonePath
        ? 'انتهى إنذار الهاتف. هل تتابع رحلتك؟'
        : 'انطفأ الكشاف وأطبقت الجدران حولك في الظلام.. ماذا ستفعل؟';
    final firstChoice = isMirrorPath
        ? 'تحطيم المرآة ورفض الاستسلام لهذا المصير'
        : isCleanPath
        ? 'المتابعة إلى اليوم الرابع'
        : isPhonePath
        ? 'المتابعة إلى اليوم الرابع'
        : 'تنظيم الأنفاس والزحف بهدوء نحو تيار الهواء';

    return ColoredBox(
      color: Colors.black.withOpacity(0.65),
      child: Align(
        alignment: const Alignment(0, 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _completeVideo,
                  child: Text(firstChoice),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _phase == 7 || _phase == 9 || isPhonePath
                      ? _returnToJunction
                      : _completeVideo,
                  child: Text(
                    _phase == 9 || isPhonePath
                        ? 'العودة لاختيار ممر آخر'
                        : _phase == 5
                        ? 'الاستسلام للصوت'
                        : 'التراجع إلى تقاطع المتاهة',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
