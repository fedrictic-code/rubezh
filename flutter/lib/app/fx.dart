// Отклик: звуки и вибрация. Звуки — короткие WAV из assets/sfx, сгенерированы tool/gen_sfx.py.
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../game/core.dart';
import '../gfx/render.dart';
import 'model.dart';

class Fx {
  static const Map<String, int> _voices = {
    'shot1': 3, 'shot2': 3, 'shot3': 3, 'cannon': 2, 'boom1': 2, 'boom2': 2, //
    'tap': 2, 'select': 1, 'order': 1, 'deny': 1, 'ready': 1, 'radio': 1, 'capture': 1, 'win': 1, 'lose': 1,
  };
  static final Map<String, List<AudioPlayer>> _pool = {};
  static final Map<String, int> _rr = {};
  static bool _ready = false;
  static int _winStart = 0, _winCnt = 0, _lastHeavy = 0;

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
    } catch (_) {}
    _voices.forEach((k, n) {
      _pool[k] = [for (int i = 0; i < n; i++) AudioPlayer()];
    });
    _ready = true;
  }

  static void play(String name, [double vol = 1]) {
    if (!_ready || !APP.sound || vol < .02) return;
    final l = _pool[name];
    if (l == null || l.isEmpty) return;
    final i = (_rr[name] ?? 0) % l.length;
    _rr[name] = i + 1;
    try {
      l[i].play(AssetSource('sfx/$name.wav'), volume: math.min(1.0, vol), mode: PlayerMode.lowLatency).catchError((_) {});
    } catch (_) {}
  }

  /// Звук боя: громкость падает с расстоянием от центра экрана и при отдалении камеры.
  static void world(String kind, double x, double y, double vol, {required bool paused}) {
    if (UI.menu || paused) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _winStart > 110) {
      _winStart = now;
      _winCnt = 0;
    }
    if (++_winCnt > 5) return;
    final d = dist(x, y, cam.x, cam.y);
    final reach = 1100 / math.max(.6, cam.z * 1.3);
    final g = vol * math.max(0, 1 - d / reach);
    if (g < .04) return;
    if (kind == 'boom') {
      play(rnd() < .5 ? 'boom1' : 'boom2', g * .9);
      if (g > .55 && now - _lastHeavy > 900) {
        _lastHeavy = now;
        haptic(2);
      }
    } else if (vol > 1.2) {
      play('cannon', g * .7);
    } else {
      play('shot${1 + (rnd() * 3).floor()}', g * .45);
    }
  }

  /// 0 — щелчок выбора, 1 — лёгкий удар, 2 — средний.
  static void haptic(int k) {
    if (!APP.haptics || kIsWeb) return;
    switch (k) {
      case 0:
        HapticFeedback.selectionClick();
      case 1:
        HapticFeedback.lightImpact();
      default:
        HapticFeedback.mediumImpact();
    }
  }

  static void tap() {
    play('tap', .5);
    haptic(0);
  }

  static void select() {
    play('select', .45);
    haptic(0);
  }

  static void order() {
    play('order', .5);
    haptic(1);
  }

  static void deny() {
    play('deny', .4);
    haptic(1);
  }
}
