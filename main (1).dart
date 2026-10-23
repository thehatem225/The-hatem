import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Day1Intro(),
    ));

/* ========== الإعدادات: غيّر أسماء الملفات والمدد من هنا ========== */
class Config {
  static const birds = 'audio/birds.mp3';
  static const branch = 'audio/branch-crack.mp3';
  static const heartbeat = 'audio/heartbeat.mp3';
  static const wind = 'audio/wind.mp3';
  static const whispers = 'audio/whispers.mp3';
  static const image = 'assets/scene.jpg';

  // مدة كل مرحلة بالثواني
  static const tBirds = 6.0, tBranch = 2.5, tHeart = 8.0, tWind = 10.0;
  static const tWhispers = 8.0, tToDay2 = 3.0;
  static const day2Title = 'اليوم الثاني';
}

class _Leaf {
  double x, y, s, vx, vy, r, vr;
  Color c;
  _Leaf(this.x, this.y, this.s, this.vx, this.vy, this.r, this.vr, this.c);
}

class Day1Intro extends StatefulWidget {
  const Day1Intro({super.key});
  @override
  State<Day1Intro> createState() => _Day1IntroState();
}

class _Day1IntroState extends State<Day1Intro> with TickerProviderStateMixin {
  final _rand = Random();
  final _players = <String, AudioPlayer>{};

  late final AnimationController _zoom, _shake, _pulse, _sway, _flash, _vigDark, _leafTick;

  bool _started = false, _pulsing = false, _leafRunning = false;
  double _fadeOpacity = 0, _titleOpacity = 0, _leafPower = 0;
  Size _size = Size.zero;
  final List<_Leaf> _leaves = [];

  @override
  void initState() {
    super.initState();
    const total = Config.tBirds + Config.tBranch + Config.tHeart + Config.tWind + Config.tWhispers;
    _zoom = AnimationController(vsync: this, duration: Duration(milliseconds: ((total + 2) * 1000).round()));
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400), value: .5);
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _vigDark = AnimationController(vsync: this, duration: Duration(milliseconds: (Config.tWhispers * 1000).round()));
    _leafTick = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_updateLeaves);
  }

  @override
  void dispose() {
    for (final c in [_zoom, _shake, _pulse, _sway, _flash, _vigDark, _leafTick]) {
      c.dispose();
    }
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }

  /* ========== الصوت ========== */
  Future<AudioPlayer> _play(String file, {double volume = 1, bool loop = false}) async {
    final p = _players.putIfAbsent(file, () => AudioPlayer());
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await p.setVolume(volume);
    await p.play(AssetSource(file));
    return p;
  }

  Future<void> _fadeVol(AudioPlayer p, double from, double to, double sec, {bool stop = false}) async {
    const steps = 30;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: (sec * 1000 / steps).round()));
      await p.setVolume((from + (to - from) * i / steps).clamp(0.0, 1.0));
    }
    if (stop) await p.stop();
  }

  Future<void> _sleep(double s) => Future.delayed(Duration(milliseconds: (s * 1000).round()));

  /* ========== أوراق الشجر ========== */
  void _updateLeaves() {
    if (!_leafRunning) return;
    if (_rand.nextDouble() < _leafPower) {
      _leaves.add(_Leaf(
        -30,
        _rand.nextDouble() * _size.height,
        6 + _rand.nextDouble() * 12,
        6 + _rand.nextDouble() * 10,
        (_rand.nextDouble() - .5) * 3,
        _rand.nextDouble() * 6,
        (_rand.nextDouble() - .5) * .3,
        HSLColor.fromAHSL(1, 20 + _rand.nextDouble() * 30, .6, .15 + _rand.nextDouble() * .2).toColor(),
      ));
    }
    _leaves.removeWhere((l) => l.x > _size.width + 40);
    for (final l in _leaves) {
      l.x += l.vx * (1 + _leafPower * 2);
      l.y += l.vy + sin(l.x / 40) * 1.5;
      l.r += l.vr;
    }
  }

  /* ========== الأنيميشنات ========== */
  void _cameraShake() {
    _shake.forward(from: 0);
    _flash.forward(from: 0);
  }

  Future<void> _heartPulse(double sec) async {
    _pulsing = true;
    var gap = .95;
    final end = DateTime.now().add(Duration(milliseconds: (sec * 1000).round()));
    while (_pulsing && mounted && DateTime.now().isBefore(end)) {
      _pulse.duration = Duration(milliseconds: (gap * 1000).round());
      _pulse.forward(from: 0);
      await _sleep(gap);
      gap = max(.55, gap - .05); // النبض يسرّع تدريجياً
    }
    _pulsing = false;
  }

  // نبضتين في الدورة الواحدة (لب-دب)
  double _beat(double v) {
    final b1 = max(0.0, 1 - (v - .10).abs() / .10);
    final b2 = max(0.0, 1 - (v - .45).abs() / .10) * .7;
    return b1 + b2;
  }

  /* ========== التسلسل الرئيسي ========== */
  Future<void> _runDay1() async {
    _zoom.forward();

    // 1) أصوات العصافير
    final birds = await _play(Config.birds, volume: .8, loop: true);
    await _sleep(Config.tBirds);

    // 2) كسر أغصان (العصافير تسكت فجأة)
    await birds.stop();
    _play(Config.branch);
    _cameraShake();
    await _sleep(Config.tBranch);

    // 3) نبضات القلب
    final heart = await _play(Config.heartbeat, volume: .9, loop: true);
    _heartPulse(Config.tHeart);
    await _sleep(Config.tHeart);

    // 4) هوا شديد + تطاير الأوراق
    final wind = await _play(Config.wind, volume: .1, loop: true);
    _fadeVol(wind, .1, 1, 2.5);
    _leafRunning = true;
    _leafPower = .05;
    _leafTick.repeat();
    _sway.repeat(reverse: true);
    final ramp = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _leafPower = min(.6, _leafPower + .03);
    });
    await _sleep(Config.tWind);
    ramp.cancel();

    // 5) همسات بعيدة (الهوا والقلب يهدوا)
    _pulsing = false;
    _fadeVol(heart, .9, 0, 2, stop: true);
    _fadeVol(wind, 1, 0, 3, stop: true);
    _sway.stop();
    final whisp = await _play(Config.whispers, volume: .05, loop: true);
    _fadeVol(whisp, .05, .7, 4);
    _vigDark.forward();
    final calm = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _leafPower = max(0, _leafPower - .05);
    });
    await _sleep(Config.tWhispers);
    calm.cancel();

    // انتقال لليوم التاني
    await _toDay2(whisp);
  }

  Future<void> _toDay2(AudioPlayer whisp) async {
    setState(() => _fadeOpacity = 1);
    _fadeVol(whisp, .7, 0, 1.5, stop: true);
    await _sleep(1.6);
    _leafRunning = false;
    _leafTick.stop();
    _leaves.clear();
    setState(() => _titleOpacity = 1);
    await _sleep(Config.tToDay2 - .6);
    setState(() => _titleOpacity = 0);
    await _sleep(.6);
    onDayTwoStart();
  }

  // ← هنا تكمّل اللعبة: ابدأ مشهد اليوم الثاني
  void onDayTwoStart() {
    debugPrint('Day 2 starts');
    // مثال: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Day2()));
  }

  /* ========== الواجهة ========== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, c) {
        _size = c.biggest;
        return Stack(fit: StackFit.expand, children: [
          // الصورة: زووم + اهتزاز + تمايل
          AnimatedBuilder(
            animation: Listenable.merge([_zoom, _shake, _sway]),
            builder: (_, child) {
              final scale = 1.1 + .08 * Curves.easeInOut.transform(_zoom.value);
              final sv = _shake.value;
              final dx = sin(sv * 60) * 30 * (1 - sv);
              final dy = cos(sv * 47) * 22 * (1 - sv);
              final skew = (_sway.value - .5) * .07;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(scale)
                    ..multiply(Matrix4.skewX(skew)),
                  child: child,
                ),
              );
            },
            child: Image.asset(Config.image, fit: BoxFit.cover),
          ),

          // أوراق الشجر
          IgnorePointer(
            child: CustomPaint(painter: _LeavesPainter(_leaves, _leafTick)),
          ),

          // الفينييت (ينبض مع القلب ويغمّق مع الهمسات)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulse, _vigDark]),
              builder: (_, __) {
                final b = _pulsing ? _beat(_pulse.value) : 0.0;
                final op = (.35 + .5 * _vigDark.value + .4 * b).clamp(0.0, 1.0);
                return Opacity(
                  opacity: op,
                  child: Transform.scale(
                    scale: 1 + .06 * b,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          radius: .9,
                          colors: [Colors.transparent, Color(0xD9000000)],
                          stops: [.35, 1],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // وميض كسر الغصن
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, __) => Opacity(
                opacity: .55 * (1 - _flash.value) * (_flash.isAnimating ? 1 : 0),
                child: Container(color: Colors.white),
              ),
            ),
          ),

          // تغمّق الانتقال
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _fadeOpacity,
              duration: const Duration(milliseconds: 1500),
              child: Container(color: Colors.black),
            ),
          ),

          // كارت اليوم التاني
          IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _titleOpacity,
                duration: const Duration(milliseconds: 600),
                child: const Text(Config.day2Title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 48, letterSpacing: 2)),
              ),
            ),
          ),

          // شاشة البداية (المتصفح/الموبايل محتاج لمسة قبل تشغيل الصوت)
          if (!_started)
            GestureDetector(
              onTap: () {
                setState(() => _started = true);
                _runDay1();
              },
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Text('اضغط للبدء 🎧 (يفضل سماعات)',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 22)),
              ),
            ),
        ]);
      }),
    );
  }
}

class _LeavesPainter extends CustomPainter {
  final List<_Leaf> leaves;
  _LeavesPainter(this.leaves, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in leaves) {
      canvas.save();
      canvas.translate(l.x, l.y);
      canvas.rotate(l.r);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: l.s * 2, height: l.s),
        Paint()..color = l.c,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeavesPainter old) => true;
}
