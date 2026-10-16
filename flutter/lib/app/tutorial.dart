// Обучение в процессе первого боя: короткие шаги с подсветкой нужного места.
import 'package:flutter/widgets.dart';

import '../game/battle.dart';
import '../game/core.dart';
import '../gfx/render.dart';
import 'controller.dart';
import 'fx.dart';
import 'model.dart';

class TutStep {
  final String text, target; // target: squad, enemy, begin, strip, drone, reserve, ''
  final bool deploy; // шаг этапа расстановки
  final double timeout; // секунд игрового времени, 0 — без ограничения
  const TutStep(this.text, this.target, {this.deploy = false, this.timeout = 0});
}

class Tutorial extends ChangeNotifier {
  static const List<TutStep> steps = [
    TutStep('Коснитесь своего отряда', 'squad', deploy: true),
    TutStep('Коснитесь светлой зоны — отряд встанет туда', '', deploy: true),
    TutStep('Расставили? Нажмите «В бой»', 'begin', deploy: true),
    TutStep('Выберите отряд — на карте или в полосе внизу', 'strip'),
    TutStep('Коснитесь земли — отряд пойдёт туда', ''),
    TutStep('Не видно врага? Запустите разведывательный БПЛА', 'drone', timeout: 40),
    TutStep('Коснитесь замеченного врага — выбранные отряды откроют по нему огонь', 'enemy', timeout: 60),
    TutStep('Рубежи приносят очки. Тратьте их на подкрепление', 'reserve', timeout: 30),
  ];

  final Map<String, GlobalKey> keys = {for (final k in const ['begin', 'strip', 'drone', 'reserve']) k: GlobalKey(debugLabel: k)};
  bool active = false;
  int i = 0;
  double _t0 = 0;
  int _base = 0;

  TutStep? get step => active && i < steps.length ? steps[i] : null;

  void start() {
    active = APP.tutorial;
    i = 0;
    _enter();
    notifyListeners();
  }

  void skip() {
    active = false;
    APP.tutorial = false;
    APP.changed();
    notifyListeners();
  }

  void _enter() {
    _t0 = hasBattle ? S.t : 0;
    _base = switch (i) {
      1 => CTL.nDeployMoves,
      4 => CTL.nOrders,
      5 => S.ab[S.player]['drone']!.ch,
      6 => CTL.nAttacks,
      7 => CTL.nDeckOpen,
      _ => 0,
    };
  }

  void _next() {
    i++;
    Fx.play('select', .35);
    if (i >= steps.length) {
      active = false;
      APP.tutorial = false;
      APP.changed();
      CTL.toast('Обучение пройдено. Удачи в бою!', 3000);
    } else {
      _enter();
    }
    notifyListeners();
  }

  /// Проверка выполнения шага; вызывается ~10 раз в секунду.
  void tick() {
    if (!active || !hasBattle) return;
    final st = steps[i];
    if (st.deploy && !S.deploying) {
      // игрок начал бой раньше — переходим к шагам боя
      i = 3;
      _enter();
      notifyListeners();
      return;
    }
    if (st.timeout > 0 && S.t - _t0 > st.timeout) {
      _next();
      return;
    }
    final done = switch (i) {
      0 => S.sel.isNotEmpty,
      1 => CTL.nDeployMoves > _base,
      2 => !S.deploying,
      3 => S.sel.isNotEmpty,
      4 => CTL.nOrders > _base,
      5 => S.ab[S.player]['drone']!.ch < _base,
      6 => CTL.nAttacks > _base,
      7 => CTL.nDeckOpen > _base,
      _ => true,
    };
    if (done) _next();
  }

  /// Шаг атаки показываем, только когда враг замечен.
  bool get waiting => step?.target == 'enemy' && enemyTarget() == null;

  Squad? squadTarget() {
    Squad? b;
    for (final q in S.squads) {
      if (q.side == S.player && !q.dead && q.carried == 0 && (b == null || q.no < b.no)) b = q;
    }
    return b;
  }

  Squad? enemyTarget() {
    Squad? b;
    double bd = 1e9;
    for (final q in S.squads) {
      if (q.side == S.player || q.dead || q.carried != 0 || !isSpotted(q, S.player)) continue;
      final d = dist(q.x, q.y, cam.x, cam.y);
      if (d < bd) {
        bd = d;
        b = q;
      }
    }
    return b;
  }
}

final Tutorial TUT = Tutorial();
