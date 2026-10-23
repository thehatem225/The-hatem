import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DayTwoVideoBackground extends StatefulWidget {
  const DayTwoVideoBackground({
    required this.videoPath,
    required this.phase,
    required this.onCheckpoint,
    required this.onComplete,
    super.key,
  });

  final String videoPath;
  final int phase;
  final VoidCallback onCheckpoint;
  final VoidCallback onComplete;

  @override
  State<DayTwoVideoBackground> createState() => _DayTwoVideoBackgroundState();
}

class _DayTwoVideoBackgroundState extends State<DayTwoVideoBackground> {
  late final VideoPlayerController _controller;
  bool _failed = false;
  bool _checkpointSent = false;
  bool _completionSent = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      widget.videoPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_checkProgress);
    unawaited(_initializeVideo());
  }

  @override
  void didUpdateWidget(covariant DayTwoVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase && _failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCheckpoint();
      });
      return;
    }
    if (oldWidget.phase != widget.phase) {
      _checkpointSent = false;
      _completionSent = false;
      unawaited(_resumePhase());
    }
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setPlaybackSpeed(0.65);
      await _controller.setVolume(widget.phase == 1 ? 0 : 1);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Day two video failed: $error');
      _failed = true;
      if (mounted) {
        setState(() {});
        widget.onCheckpoint();
      }
    }
  }

  Future<void> _resumePhase() async {
    try {
      await _controller.setVolume(widget.phase == 1 ? 0 : 1);
      await _controller.play();
    } catch (error) {
      debugPrint('Day two video resume failed: $error');
      if (mounted) widget.onCheckpoint();
    }
  }

  void _checkProgress() {
    if (!_controller.value.isInitialized) return;
    final value = _controller.value;
    if (widget.phase < 3 &&
        !_checkpointSent &&
        value.position >= Duration(seconds: widget.phase * 10)) {
      _checkpointSent = true;
      unawaited(_controller.pause());
      widget.onCheckpoint();
      return;
    }

    if (widget.phase == 3 && value.isCompleted && !_completionSent) {
      _completionSent = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkProgress);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !_controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
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