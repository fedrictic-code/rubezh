// Отклик: звуки и вибрация. Звуки — короткие WAV из assets/sfx, сгенерированы tool/gen_sfx.py.
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../game/core.dart';
import '../game/fxcfg.dart';
import '../gfx/render.dart';
import 'model.dart';

class Fx {
  static const Map<String, String> _ui = {
    'tap': 'sfx/tap.wav', 'select': 'sfx/select.wav', 'order': 'sfx/order.wav', 'deny': 'sfx/deny.wav', 'ready': 'sfx/ready.wav', //
    'radio': 'sfx/radio.wav', 'capture': 'sfx/capture.wav', 'win': 'sfx/win.wav', 'lose': 'sfx/lose.wav',
  };
  static const Map<String, double> _vol = {
    'shot_rifle': .45, 'shot_mg': .5, 'shot_hmg': .6, 'shot_sniper': .6, 'shot_ugl': .5, 'shot_acan': .6, 'shot_cannon': .75, //
    'shot_rocket': .7, 'shot_atgm': .7, 'shot_mortar': .7, 'arty': .7, 'boom': .9, 'boom_small': .45, 'boom_big': 1,
  };
  static final Map<String, List<_Voice>> _pool = {};
  static final Map<String, int> _rr = {};
  static bool _ready = false;
  static int _winStart = 0, _winCnt = 0, _lastHeavy = 0;

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
    } catch (_) {}
    _ready = true;
  }

  /// Заранее загрузить все звуки (интерфейс и ячейки мода), чтобы в бою не было подгрузки.
  static void warm() {
    if (!_ready) return;
    for (final p in _ui.values) {
      _voices(p, 1);
    }
    for (final l in SOUNDS.values) {
      for (final p in l) {
        _voices(p, 2);
      }
    }
  }

  static List<_Voice> _voices(String path, int n) => _pool.putIfAbsent(path, () {
        final l = [for (int i = 0; i < n; i++) _Voice()];
        for (final v in l) {
          v.load(path);
        }
        return l;
      });

  /// Проиграть файл (путь внутри assets/). Каждый файл загружается один раз, дальше только запуск.
  static void playPath(String path, double vol) {
    if (!_ready || !APP.sound || vol < .02) return;
    final l = _voices(path, _ui.containsValue(path) ? 1 : 2);
    final i = _rr[path] ?? 0;
    _rr[path] = i + 1;
    l[i % l.length].play(math.min(1.0, vol));
  }

  /// Звук интерфейса по имени (tap, select, order…).
  static void play(String name, [double vol = 1]) {
    final path = _ui[name];
    if (path != null) playPath(path, vol);
  }

  /// Звук из ячейки мода (shot_mg, boom_big…): случайный файл из списка.
  static void slot(String slot, double vol) {
    final l = SOUNDS[slot];
    if (l == null || l.isEmpty) return;
    playPath(l[(rnd() * l.length).floor() % l.length], vol * (_vol[slot] ?? .6));
  }

  /// Звук боя: громкость падает с расстоянием от центра экрана и при отдалении камеры.
  static void world(String kind, double x, double y, double vol, {required bool paused}) {
    if (UI.menu || paused) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // не больше двух звуков боя за 0,16 с — иначе звуковая система телефона перегружается
    if (now - _winStart > 160) {
      _winStart = now;
      _winCnt = 0;
    }
    if (++_winCnt > 2) return;
    final d = dist(x, y, cam.x, cam.y);
    final reach = 1100 / math.max(.6, cam.z * 1.3);
    final g = vol * math.max(0, 1 - d / reach);
    if (g < .1) return;
    String s;
    if (kind.startsWith('boom:')) {
      s = switch (kind) { 'boom:1' => 'boom_small', 'boom:2' => 'boom_big', _ => 'boom' };
      if (kind != 'boom:1' && g > .55 && now - _lastHeavy > 900) {
        _lastHeavy = now;
        haptic(2);
      }
    } else if (kind.startsWith('shot:')) {
      s = 'shot_${kind.substring(5)}';
    } else {
      s = kind;
    }
    slot(s, g);
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

class _Voice {
  final AudioPlayer p = AudioPlayer();
  bool ready = false;
  double vol = -1;

  Future<void> load(String path) async {
    try {
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(path));
      ready = true;
    } catch (_) {}
  }

  void play(double v) {
    if (!ready) return;
    final q = (v * 10).roundToDouble() / 10;
    try {
      if (q != vol) {
        vol = q;
        p.setVolume(q).catchError((_) {});
      }
      p.stop().then((_) => p.resume()).catchError((_) {});
    } catch (_) {}
  }
}
