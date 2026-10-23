import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const dayThreeVideoPaths = [
  'gemini_generated_video_605edff7.mp4',
  'gemini_generated_video_42007b75.mp4',
  'gemini_generated_video_516c98f4.mp4',
];

String dayThreeSceneContext(int phase) => switch (phase) {
  1 => 'the traveler falls as rocks collapse and lights a candle',
  2 => 'the candle is thrown and the traveler picks up the flashlight',
  3 => 'the traveler explores the hidden corridors and asks which way to go',
  _ => 'the traveler is exploring the passage',
};

class StorySequencePlayer extends StatefulWidget {
  const StorySequencePlayer({
    required this.phase,
    required this.onComplete,
    super.key,
  });

  final int phase;
  final VoidCallback onComplete;

  @override
  State<StorySequencePlayer> createState() =>
      _DayThreeVideoBackgroundState();
}

class _DayThreeVideoBackgroundState extends State<StorySequencePlayer> {
  VideoPlayerController? _controller;
  VideoPlayerController? _nextController;
  int? _nextPhase;
  int _activation = 0;
  bool _failed = false;
  bool _completionSent = false;

  @override
  void initState() {
    super.initState();
    unawaited(_activatePhase(widget.phase));
  }

  @override
  void didUpdateWidget(covariant StorySequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _completionSent = false;
      _failed = false;
      unawaited(_activatePhase(widget.phase));
    }
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
      await controller.setPlaybackSpeed(0.65);
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
      if (!mounted ||
          activation != _activation ||
          widget.phase + 1 != phase) {
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
    if (value.position >= const Duration(seconds: 10) || value.isCompleted) {
      unawaited(controller.pause());
      _completeVideo();
    }
  }

  void _completeVideo() {
    if (_completionSent) return;
    _completionSent = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _activation++;
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
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}