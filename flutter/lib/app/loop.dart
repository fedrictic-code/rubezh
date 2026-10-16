// Главный цикл: фиксированный шаг симуляции 20 Гц + перерисовка по кадрам.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../game/battle.dart';
import '../game/core.dart';
import '../gfx/render.dart';
import 'controller.dart';
import 'model.dart';
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
  int _lastUs = -1;
  int _lastHud = 0, _lastInput = 0, _lastIdle = 0;

  void start(TickerProvider vsync) {
    _ticker ??= vsync.createTicker(_onTick)..start();
  }

  void dispose() => _ticker?.dispose();

  /// Было касание или изменение — карту нужно перерисовывать ещё немного.
  void poke() => _lastInput = nowMs();

  void _onTick(Duration el) {
    final us = el.inMicroseconds;
    // ограничение частоты кадров: 60 (или 30 в экономном режиме и в меню);
    // на экранах 90–120 Гц лишние кадры пропускаем
    final target = (UI.menu || APP.lite) ? 30 : 60;
    if (_lastUs >= 0 && us - _lastUs < 1e6 / target - 2500) return;
    final dt = _lastUs < 0 ? 0.0 : math.min(.1, (us - _lastUs) / 1e6);
    _lastUs = us;
    if (dt > 0) perf.fps = lerp(perf.fps, 1 / math.max(dt, .001), .08);
    final tms = el.inMilliseconds.toDouble();
    bool moved = false;
    if (UI.menu) {
      cam.x = 1200 + math.sin(tms / 9000) * 500;
      cam.y = 750 + math.cos(tms / 11000) * 200;
      cam.z = math.max(View.w / W, View.h / H) * 1.06;
      clampCam();
      moved = true;
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
      moved = true; // идёт бой: эффекты и движение
    }
    final now = nowMs();
    // на паузе, при расстановке и после конца боя без касаний карта рисуется реже (10 кадров/с), но не замирает
    final idle = !(moved || TUT.active || now - _lastInput < 2500);
    if (!idle) {
      frame.fire();
    } else if (now - _lastIdle >= 100) {
      _lastIdle = now;
      frame.fire();
    }
    if (now - _lastHud > 100) {
      _lastHud = now;
      CTL.watch();
      TUT.tick();
      hud.fire();
    }
  }
}

final Loop LOOP = Loop();
