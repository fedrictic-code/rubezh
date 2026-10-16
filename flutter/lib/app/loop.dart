// Главный цикл: фиксированный шаг симуляции 20 Гц + перерисовка по кадрам.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../game/battle.dart';
import '../game/core.dart';
import '../gfx/render.dart';
import 'controller.dart';
import 'tutorial.dart';

class Tick extends ChangeNotifier {
  void fire() => notifyListeners();
}

class Perf {
  double sim = 0, render = 0, fps = 60;
}

class Loop {
  final Tick frame = Tick(), hud = Tick();
  final Perf perf = Perf();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  int _lastHud = 0;

  void start(TickerProvider vsync) {
    _ticker ??= vsync.createTicker(_onTick)..start();
  }

  void dispose() => _ticker?.dispose();

  void _onTick(Duration el) {
    final dt = math.min(.1, (el - _last).inMicroseconds / 1e6);
    _last = el;
    if (dt > 0) perf.fps = lerp(perf.fps, 1 / math.max(dt, .001), .08);
    final tms = el.inMilliseconds.toDouble();
    if (UI.menu) {
      cam.x = 1200 + math.sin(tms / 9000) * 500;
      cam.y = 750 + math.cos(tms / 11000) * 200;
      cam.z = math.max(View.w / W, View.h / H) * 1.06;
      clampCam();
    } else if (hasBattle && S.over == null && !CTL.paused) {
      CTL.acc += dt * S.speed;
      int n = 0;
      final sw = Stopwatch()..start();
      while (CTL.acc >= TICK && n < 12) {
        step();
        CTL.acc -= TICK;
        n++;
      }
      if (n == 12) CTL.acc = 0;
      if (n > 0) perf.sim = lerp(perf.sim, sw.elapsedMicroseconds / 1000 / n, .1);
    }
    frame.fire();
    final now = nowMs();
    if (now - _lastHud > 100) {
      _lastHud = now;
      CTL.watch();
      TUT.tick();
      hud.fire();
    }
  }
}

final Loop LOOP = Loop();
