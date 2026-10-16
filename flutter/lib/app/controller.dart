// Управление боем: выбор, приказы, режимы, журнал, подсказки (перенос логики 06_ui.js).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/battle.dart';
import '../game/combat.dart';
import '../game/core.dart';
import '../game/data.dart';
import '../gfx/render.dart';
import 'model.dart';

class LogItem {
  final String text, kind;
  final double x, y;
  final int born;
  LogItem(this.text, this.kind, this.x, this.y, this.born);
}

class Hit {
  final Squad sq;
  final bool enemy;
  Hit(this.sq, this.enemy);
}

class Ptr {
  double x, y, sx, sy;
  final String kind; // touch, mouse
  final int btn;
  bool moved = false;
  Ptr(this.x, this.y, this.kind, this.btn)
      : sx = x,
        sy = y;
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

class GameCtl extends ChangeNotifier {
  bool paused = false, multi = false, deckOpen = false, gestShift = false;
  String toastMsg = '';
  int toastUntil = 0;
  bool toastIsMode = false;
  final List<LogItem> log = [];
  double acc = 0;
  Timer? endTimer;
  bool infoOpen = false;

  void changed() => notifyListeners();

  /* ---------- журнал и подсказки ---------- */
  void addLog(String text, String kind, double x, double y) {
    if (UI.menu) return;
    log.add(LogItem(text, kind, x, y, nowMs()));
    while (log.length > 5) {
      log.removeAt(0);
    }
  }

  void toast(String msg, [int ms = 2600]) {
    toastMsg = msg;
    toastUntil = nowMs() + ms;
    toastIsMode = false;
    notifyListeners();
  }

  static const Map<String, String> _modeText = {
    'sneak': 'Коснитесь точки: отряды двинутся скрытно, медленно и тихо',
    'mount': 'Коснитесь своего БМП или БТР, чтобы пехота села на технику',
    'arty': 'Коснитесь точки для артиллерийского удара. С наблюдателем точнее',
    'fight': 'Коснитесь точки: отряды пойдут туда и вступят в бой',
    'fire': 'Коснитесь цели для миномёта. Без наблюдателя огонь неточный',
    'drone': 'Коснитесь точки разведки',
    'smoke': 'Коснитесь точки для дымовой завесы',
    'fpv': 'Коснитесь видимого противника',
  };

  void setMode(String? m) {
    UI.mode = m;
    if (m != null) {
      toastMsg = _modeText[m] ?? '';
      toastUntil = nowMs() + 600000;
      toastIsMode = true;
    } else if (toastIsMode) {
      toastMsg = '';
      toastIsMode = false;
    }
    notifyListeners();
  }

  /* ---------- выбор и приказы ---------- */
  List<Squad> selSquads() {
    if (!hasBattle) return const [];
    final out = <Squad>[];
    for (final id in S.sel) {
      final q = S.byId[id];
      if (q != null && !q.dead && q.carried == 0 && q.side == S.player) out.add(q);
    }
    return out;
  }

  Hit? pick(double sx, double sy, bool touch) {
    Hit? best;
    double bd = touch ? 34 : 24;
    for (final q in S.squads) {
      if (q.dead || q.carried != 0) continue;
      final enemy = q.side != S.player;
      if (enemy && !isSpotted(q, S.player)) continue;
      final x = wsx(q.x), y = wsy(q.y);
      final d = math.min(math.sqrt((sx - x) * (sx - x) + (sy - y) * (sy - y)), math.sqrt((sx - x) * (sx - x) + (sy - (y - 20)) * (sy - (y - 20))) + 2) - (enemy ? 0 : 3);
      if (d < bd) {
        bd = d;
        best = Hit(q, enemy);
      }
    }
    return best;
  }

  void selectOnly(Squad? q) {
    S.sel.clear();
    if (q != null) S.sel.add(q.id);
    onSel();
  }

  void onSel() {
    if (UI.mode == 'fire' && !selSquads().any((q) => q.t.mortar)) setMode(null);
    notifyListeners();
  }

  void ping(double x, double y, String kind) {
    UI.pings.add(Ping(x, y, kind, nowMs()));
    if (UI.pings.length > 8) UI.pings.removeAt(0);
  }

  void orderAt(double wx, double wy, Hit? hit) {
    final sel = selSquads();
    if (sel.isEmpty) return;
    if (hit != null && hit.enemy) {
      issue(sel, 'attack', wx, wy, hit.sq.id);
      ping(hit.sq.x, hit.sq.y, 'atk');
      setMode(null);
      return;
    }
    final kind = UI.mode == 'fight' ? 'fight' : (UI.mode == 'fire' ? 'fire' : (UI.mode == 'sneak' ? 'sneak' : 'move'));
    if (kind == 'fire') {
      final mq = sel.where((q) => q.t.mortar).toList();
      if (mq.isEmpty) {
        toast('Выберите миномётный расчёт');
        return;
      }
      if (S.fog[cellIdx(wx, wy)] == 0) {
        toast('Нет данных о цели: сначала разведайте район');
        return;
      }
      issue(mq, 'fire', wx, wy);
      ping(wx, wy, 'fire');
      setMode(null);
      return;
    }
    final failed = issue(sel, kind, wx, wy);
    ping(wx, wy, kind);
    if (failed > 0) toast('Путь не найден для $failed отр.');
    setMode(null);
  }

  void commandBtn(String c) {
    if (!hasBattle) return;
    final sel = selSquads();
    if (c == 'deck') {
      toggleDeck();
      return;
    }
    if (c == 'ambush' || c == 'cease') {
      if (sel.isEmpty) {
        toast('Сначала выберите отряд');
        return;
      }
      final all = sel.every((q) => q.stance == c);
      setStance(sel, all ? 'free' : c);
      toast(all ? 'Огонь по готовности' : (c == 'ambush' ? 'Засада: огонь откроют на 110 м или при обстреле' : 'Отряды не открывают огонь'), 2000);
      return;
    }
    if (c == 'dismount') {
      final vs = sel.where((q) => q.cargo != 0).toList();
      if (vs.isEmpty) {
        toast('Нет пехоты на броне у выбранных машин');
        return;
      }
      for (final v in vs) {
        dismountVeh(v);
      }
      notifyListeners();
      return;
    }
    if (c == 'hold' || c == 'retreat') {
      if (sel.isEmpty) {
        toast('Сначала выберите отряд');
        return;
      }
      issue(sel, c, 0, 0);
      setMode(null);
      return;
    }
    if (sel.isEmpty) {
      toast('Сначала выберите отряд');
      return;
    }
    if (c == 'fire' && !sel.any((q) => q.t.mortar)) return;
    if (c == 'mount' && !sel.any((q) => !q.t.veh)) {
      toast('Выберите пехотный отряд');
      return;
    }
    setMode(UI.mode == c ? null : (c == 'move' ? null : c));
    if (c == 'move') toast('Коснитесь земли, чтобы отдать приказ о движении', 2200);
  }

  void abilityBtn(String k) {
    if (!hasBattle) return;
    if (!canUse(S.player, k)) {
      final a = S.ab[S.player][k]!;
      toast(a.ch <= 0 ? 'Запас исчерпан' : 'Перезарядка: ${a.cd.ceil()} с');
      return;
    }
    setMode(UI.mode == k ? null : k);
  }

  void applyMode(double wx, double wy, Hit? hit) {
    final m = UI.mode;
    String? err;
    if (m == 'drone') {
      err = useDrone(S.player, wx, wy);
    } else if (m == 'smoke') {
      err = useSmoke(S.player, wx, wy);
    } else if (m == 'fpv') {
      if (hit == null || !hit.enemy) {
        toast('Нужна видимая цель');
        return;
      }
      err = useFpv(S.player, hit.sq.id);
    } else if (m == 'arty') {
      err = useArty(S.player, wx, wy);
    } else if (m == 'mount') {
      if (hit == null || hit.enemy || hit.sq.t.cap == 0) {
        toast('Нужна своя бронированная машина с десантом');
        return;
      }
      final inf = selSquads().where((q) => !q.t.veh).toList();
      if (inf.any((q) => q.men > hit.sq.t.cap)) {
        toast('Отряд не поместится');
      } else if (hit.sq.cargo != 0) {
        toast('Машина уже занята');
      } else {
        issue(inf.take(1).toList(), 'mount', hit.sq.x, hit.sq.y, hit.sq.id);
        ping(hit.sq.x, hit.sq.y, 'move');
        setMode(null);
      }
      return;
    } else if (m == 'fight' || m == 'fire') {
      orderAt(wx, wy, hit);
      return;
    }
    if (err != null) {
      toast(err);
    } else {
      ping(wx, wy, m ?? 'move');
      setMode(null);
    }
  }

  void tap(Ptr p) {
    if (!hasBattle) return;
    final w = s2w(p.x, p.y);
    final wx = w.x, wy = w.y;
    final mouse = p.kind == 'mouse', right = mouse && p.btn == 2;
    final hit = pick(p.x, p.y, !mouse);
    if (S.deploying) {
      deployTap(wx, wy, hit);
      return;
    }
    final mode = UI.mode;
    if (mode != null && mode != 'move') {
      if (mode == 'sneak' && !right) {
        orderAt(wx, wy, (hit != null && hit.enemy) ? null : hit);
        return;
      }
      if (right) {
        setMode(null);
        return;
      }
      applyMode(wx, wy, hit);
      return;
    }
    if (right) {
      orderAt(wx, wy, hit);
      return;
    }
    if (hit != null && !hit.enemy) {
      if (mouse ? gestShift : multi) {
        if (S.sel.contains(hit.sq.id)) {
          S.sel.remove(hit.sq.id);
        } else {
          S.sel.add(hit.sq.id);
        }
        onSel();
      } else {
        selectOnly(hit.sq);
      }
      return;
    }
    if (hit != null && hit.enemy) {
      if (selSquads().isNotEmpty) orderAt(wx, wy, hit);
      return;
    }
    if (selSquads().isNotEmpty && !mouse) {
      orderAt(wx, wy, null);
      return;
    }
    if (mouse && !gestShift) selectOnly(null);
  }

  void finishBox(List<double> b) {
    final x0 = math.min(b[0], b[2]), x1 = math.max(b[0], b[2]), y0 = math.min(b[1], b[3]), y1 = math.max(b[1], b[3]);
    if ((x1 - x0) * (y1 - y0) < 60) return;
    if (!gestShift) S.sel.clear();
    for (final q in S.squads) {
      if (q.dead || q.side != S.player) continue;
      final x = wsx(q.x), y = wsy(q.y);
      if (x >= x0 && x <= x1 && y >= y0 && y <= y1) S.sel.add(q.id);
    }
    onSel();
  }

  void selectAll() {
    if (!hasBattle) return;
    S.sel.clear();
    for (final q in S.squads) {
      if (!q.dead && q.side == S.player) S.sel.add(q.id);
    }
    onSel();
  }

  void togglePause() {
    if (!hasBattle || S.deploying) return;
    paused = !paused;
    if (paused) toast('Пауза: приказы можно отдавать', 1800);
    notifyListeners();
  }

  void setSpeed(int n) {
    if (!hasBattle) return;
    S.speed = n.toDouble();
    notifyListeners();
  }

  void toggleDeck() {
    deckOpen = !deckOpen;
    notifyListeners();
  }

  void sqTap(int no) {
    Squad? q;
    for (final s in S.squads) {
      if (s.side == S.player && s.no == no && !s.dead && s.carried == 0) {
        q = s;
        break;
      }
    }
    if (q == null) return;
    if (multi || gestShift) {
      if (S.sel.contains(q.id)) {
        S.sel.remove(q.id);
      } else {
        S.sel.add(q.id);
      }
      onSel();
      return;
    }
    if (S.sel.length == 1 && S.sel.contains(q.id)) {
      cam.x = q.x;
      cam.y = q.y;
      clampCam();
      return;
    }
    selectOnly(q);
  }

  /* ---------- старт, расстановка, финиш ---------- */
  void startBattle() {
    final fc = <List<String>>[[], []];
    fc[APP.side] = APP.forceList(APP.side);
    newBattle(APP.side, APP.diff, fc);
    Assets.fog?.dispose();
    Assets.fog = null;
    Assets.craters.clear();
    paused = true;
    S.speed = 1;
    UI.mode = null;
    UI.menu = false;
    UI.pings.clear();
    log.clear();
    deckOpen = false;
    toastMsg = '';
    toastIsMode = false;
    multi = false;
    S.deploying = true;
    cam.z = clamp(View.w / 1300, .2, .85);
    cam.x = APP.side == 0 ? 1740 : 330;
    cam.y = 740;
    clampCam();
    acc = 0;
    APP.endInfo = null;
    APP.endShown = false;
    endTimer?.cancel();
    APP.go(Screen.game);
    notifyListeners();
  }

  void beginBattle() {
    if (!hasBattle || !S.deploying) return;
    S.deploying = false;
    paused = false;
    S.sel.clear();
    toast(
        APP.side == S.atk
            ? 'Возьмите село Дубки и высоту 112 и держите их ${HOLD_NEED.toInt()} с. Выберите отряд и коснитесь карты.'
            : 'Продержитесь ${(LIMIT / 60).toInt()} минут. Не отдавайте село Дубки и высоту 112.',
        6000);
  }

  void deployTap(double wx, double wy, Hit? hit) {
    final z = ZONE[S.player];
    if (hit != null && !hit.enemy) {
      selectOnly(hit.sq);
      return;
    }
    final sel = selSquads();
    if (sel.length != 1) {
      toast('Сначала коснитесь своего отряда');
      return;
    }
    if (wx < z.x0 || wx > z.x1 || wy < z.y0 || wy > z.y1) {
      toast('Отряды ставятся только в подсвеченной зоне');
      return;
    }
    final q = sel[0], mv = q.t.veh ? T_MV_V : T_MV_I;
    if (mv[ter[cellIdx(wx, wy)]] == 0) {
      toast('Сюда нельзя встать');
      return;
    }
    q.x = wx;
    q.y = wy;
    q.path = null;
    if (q.order != null && q.order!.kind == 'hold') q.post = Pt(wx, wy);
    ping(wx, wy, 'move');
    perception();
    fogUpdate();
  }

  void onOver(Over o) {
    endTimer?.cancel();
    endTimer = Timer(const Duration(milliseconds: 1400), () {
      APP.endInfo = o;
      APP.endShown = true;
      APP.changed();
    });
  }

  void toMenu() {
    APP.endShown = false;
    UI.menu = true;
    hasBattle = false;
    APP.go(Screen.menu);
  }

  /// Проверка нагрузки: добавить n отрядов, ИИ ведёт обе стороны.
  void stress(int n) {
    if (!hasBattle) return;
    S.autoplay = true;
    for (int i = 0; i < n; i++) {
      final s = i % 2;
      final vs = variantsFor(s).where((v) => v.cls != 'tank' && v.cls != 'mortar').toList();
      final t = vs[(rnd() * vs.length).toInt()].id;
      final x = s == 1 ? rand(150, 1000) : rand(1400, 2300), y = rand(150, 1350);
      final q = mkSquad(s, t, x, y);
      q.role = s == S.atk ? 'assault' : 'counter';
    }
    toast('Добавлено отрядов: $n. ИИ управляет обеими сторонами', 4000);
  }
}

final GameCtl CTL = GameCtl();

void wireHooks() {
  HOOK.onLog = (t, k, x, y) => CTL.addLog(t, k, x, y);
  HOOK.onOver = (o) => CTL.onOver(o);
}
