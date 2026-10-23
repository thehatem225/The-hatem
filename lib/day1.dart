import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class DayOneAudioController {
  final AudioPlayer _backgroundPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  Completer<void> _stopRequested = Completer<void>();
  Completer<void> _shadowAppeared = Completer<void>();
  bool _whispersSelected = false;

  Future<void> playMorningBirds() async {
    try {
      await _playOnce(
        player: _backgroundPlayer,
        assetPath: 'audio/forest_birds.mp3',
        volume: 0.1,
        rampTo: 0.85,
        rampDuration: const Duration(seconds: 10),
        maxPlaybackDuration: const Duration(seconds: 14),
        fadeOutDuration: const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint('Day one birds playback failed: $error');
    }
  }

  Future<void> playTension({required bool Function() canContinue}) async {
    try {
      await _backgroundPlayer.stop();
      if (!canContinue()) return;

      await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundPlayer.setVolume(0.48);
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.setPlaybackRate(0.94);
      await _effectPlayer.setBalance(-0.18);
      await _effectPlayer.setVolume(0.82);
      final firstBranchComplete = _effectPlayer.onPlayerComplete.first;
      await _effectPlayer.play(
        AssetSource(
          'audio/day1/freesound_community-breaking-a-branch-100172.mp3',
        ),
      );
      await _backgroundPlayer.play(
        AssetSource('audio/day1/tbsfx-heartbeat-415837.mp3'),
      );
      await firstBranchComplete;
      if (!canContinue()) return;
      await Future.delayed(const Duration(milliseconds: 900));
    } catch (error) {
      debugPrint('Day one tension audio failed: $error');
    }
  }

  Future<void> playFear({required bool Function() canContinue}) async {
    try {
      _whispersSelected = true;
      _shadowAppeared = Completer<void>();
      await _backgroundPlayer.stop();
      await _effectPlayer.stop();

      final windPlayback = _playOnce(
        player: _backgroundPlayer,
        assetPath: 'audio/day1/storegraphic-soft-wind-sound-314943.mp3',
        volume: 0.72,
      ).catchError((Object error) {
        debugPrint('Day one wind playback failed: $error');
      });
      unawaited(windPlayback);

      await _effectPlayer.setPlaybackRate(1);
      await _effectPlayer.setBalance(0);
      await _effectPlayer.setReleaseMode(ReleaseMode.loop);
      await _effectPlayer.setVolume(0.04);
      await _effectPlayer.play(
        AssetSource('audio/day1/u_5hx6qi66bg-strange-whispers-415245.mp3'),
      );
      await _rampVolume(
        player: _effectPlayer,
        from: 0.04,
        to: 0.42,
        duration: const Duration(milliseconds: 2800),
        canContinue: canContinue,
      );
      await Future.any<void>([
        _shadowAppeared.future,
        _stopRequested.future,
      ]);
      if (!canContinue()) return;

      await _rampVolume(
        player: _effectPlayer,
        from: 0.42,
        to: 0,
        duration: const Duration(milliseconds: 350),
        canContinue: canContinue,
      );
      await _effectPlayer.stop();
      if (!canContinue()) return;

      await _playOnce(
        player: _effectPlayer,
        assetPath: 'audio/day1/u_5hx6qi66bg-strange-whispers-415245.mp3',
        volume: 0.95,
        playbackRate: 0.88,
        balance: 0.12,
      );
      if (!canContinue()) return;

      await _effectPlayer.setReleaseMode(ReleaseMode.loop);
      await _effectPlayer.setVolume(0.16);
      await _effectPlayer.play(
        AssetSource('audio/day1/u_5hx6qi66bg-strange-whispers-415245.mp3'),
      );
    } catch (error) {
      debugPrint('Day one fear audio failed: $error');
    }
  }

  void shadowAppeared() {
    if (!_shadowAppeared.isCompleted) _shadowAppeared.complete();
  }

  Future<void> _rampVolume({
    required AudioPlayer player,
    required double from,
    required double to,
    required Duration duration,
    required bool Function() canContinue,
  }) async {
    const steps = 20;
    final interval = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );
    for (var step = 1; step <= steps; step++) {
      await Future.delayed(interval);
      if (!canContinue()) return;
      final progress = step / steps;
      await player.setVolume(from + ((to - from) * progress));
    }
  }

  Future<void> stop() async {
    try {
      if (!_stopRequested.isCompleted) _stopRequested.complete();
      shadowAppeared();
      _stopRequested = Completer<void>();
      await Future.wait([
        _backgroundPlayer.stop(),
        _effectPlayer.stop(),
      ]);
      _whispersSelected = false;
    } catch (error) {
      debugPrint('Day one audio stop failed: $error');
    }
  }

  Future<void> continueFearAudioIntoDayTwo() async {
    try {
      await _backgroundPlayer.stop();
      if (!_whispersSelected) {
        await _effectPlayer.stop();
        return;
      }
      await _effectPlayer.setVolume(0.75);
    } catch (error) {
      debugPrint('Day two audio transition failed: $error');
    }
  }

  Future<void> stopFearAudio() async {
    try {
      await _effectPlayer.stop();
      _whispersSelected = false;
    } catch (error) {
      debugPrint('Day two audio stop failed: $error');
    }
  }

  Future<void> dispose() async {
    await Future.wait([
      _backgroundPlayer.dispose(),
      _effectPlayer.dispose(),
    ]);
  }

  Future<void> _playOnce({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
    double playbackRate = 1,
    double balance = 0,
    double? rampTo,
    Duration rampDuration = Duration.zero,
    Duration? maxPlaybackDuration,
    Duration fadeOutDuration = Duration.zero,
  }) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlaybackRate(playbackRate);
    await player.setBalance(balance);
    await player.setVolume(volume);
    final completion = player.onPlayerComplete.first;
    final stopRequested = _stopRequested.future;
    final playbackClock = Stopwatch()..start();
    await player.play(AssetSource(assetPath));
    var currentVolume = volume;
    if (rampTo != null && rampDuration > Duration.zero) {
      const steps = 10;
      final interval = Duration(
        milliseconds: rampDuration.inMilliseconds ~/ steps,
      );
      var playbackFinished = false;
      unawaited(completion.then((_) => playbackFinished = true));
      for (var step = 1; step <= steps; step++) {
        final shouldStop = await Future.any<bool>([
          Future.delayed(interval, () => false),
          completion.then((_) => true),
          stopRequested.then((_) => true),
        ]);
        if (shouldStop || playbackFinished) break;
        final progress = step / steps;
        currentVolume = volume + ((rampTo - volume) * progress);
        await player.setVolume(currentVolume);
      }
    }

    if (maxPlaybackDuration != null) {
      final fadeStartsIn =
          maxPlaybackDuration - fadeOutDuration - playbackClock.elapsed;
      if (fadeStartsIn > Duration.zero) {
        final playbackEnded = await Future.any<bool>([
          completion.then((_) => true),
          stopRequested.then((_) => true),
          Future.delayed(fadeStartsIn, () => false),
        ]);
        if (playbackEnded) return;
      }

      if (fadeOutDuration > Duration.zero) {
        final interval = Duration(
          milliseconds: fadeOutDuration.inMilliseconds ~/ 10,
        );
        for (var step = 1; step <= 10; step++) {
          final playbackEnded = await Future.any<bool>([
            completion.then((_) => true),
            stopRequested.then((_) => true),
            Future.delayed(interval, () => false),
          ]);
          if (playbackEnded) return;
          await player.setVolume(currentVolume * (1 - step / 10));
        }
      }
      await player.stop();
      return;
    }

    await Future.any<void>([completion, stopRequested]);
  }
}