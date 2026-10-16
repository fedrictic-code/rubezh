// Состояние боя и главный шаг симуляции (перенос 03_sim.js).
import 'dart:math' as math;
import 'dart:typed_data';

import 'ai.dart';
import 'combat.dart';
import 'core.dart';
import 'data.dart';
import 'fxcfg.dart';
import 'map.dart';

const double LIMIT = 720; // секунд боя
const double HOLD_NEED = 40; // секунд удержания обоих ключевых рубежей
const double ATK_INC = 1.5, ATK_PTS = 1.5;
// Всё, что зависит от карты, задаётся при её загрузке (см. mapdef.dart).
List<List<double>> BASE = [
  [2350, 740],
  [50, 740]
];
/// Точки для ИИ: сбор наступающих, позиция миномётов, узкое место и точка дыма у него.
List<double> AI_ASM = [880, 740], AI_POST = [760, 700], AI_CHOKE = [1150, 740], AI_SMOKE = [1230, 740];
/// Владелец рубежей в начале боя: -1 — ничей, 0 — ВСУ, 1 — ВС РФ.
List<int> OBJ_OWNER = [-1, 0, 0];
final List<double> BUDGET = [1000, 1400];
const int MAX_UNITS = 26;
final List<List<String>> PRESET = [
  ['ua_rifle', 'ua_rifle', 'ua_rifle', 'mg_pkm', 'at_javelin', 'at_nlaw', 'sniper_ua', 'mortar_82', 'bradley'],
  ['ru_rifle', 'ru_rifle', 'ru_rifle', 'ru_rifle', 'mg_pkm', 'at_kornet', 'at_rpg', 'bmp2', 'btr82', 'tank_t72b3', 'mortar_82', 'sniper_ru']
];
class Zone {
  final double x0, x1, y0, y1;
  const Zone(this.x0, this.x1, this.y0, this.y1);
}

List<Zone> ZONE = [const Zone(1380, 2360, 60, 1440), const Zone(50, 560, 60, 1440)];

Map<String, List<List<double>>> DEF_SLOTS = {
  'sniper': [[1815, 470], [1930, 470], [1990, 520], [1870, 530]],
  'mg': [[1512, 760], [1895, 590], [1600, 670], [1700, 640], [1830, 640]],
  'at': [[1556, 748], [1660, 742], [1620, 820], [1790, 790]],
  'inf': [
    [1512, 690], [1512, 832], [1950, 566], [1600, 750], [1700, 860], [1760, 700], [1700, 742], [1880, 700], [1990, 640], [1930, 520],
    [1620, 640], [1740, 800], [1840, 760], [1810, 580], [1570, 880], [1570, 610]
  ],
  'rear': [[1760, 850], [1700, 940], [1820, 880], [1900, 780], [2040, 742], [2000, 830], [2100, 700], [2100, 800], [2160, 900], [2160, 600]],
};

const Map<String, double> AB_CD = {'drone': 18, 'fpv': 10, 'smoke': 12, 'arty': 40};

/* ---------- обратные вызовы интерфейса ---------- */
class Hook {
  void Function(String text, String kind, double x, double y)? onLog;
  void Function(String kind, double x, double y, double vol)? onSfx;
  void Function(Over o)? onOver;
}

final Hook HOOK = Hook();

/* ---------- структуры состояния ---------- */
class WI {
  final String id;
  final Wpn w;
  final Map<String, int> am, init;
  double next;
  int burst = 0;
  WI(this.id, this.w, this.am, this.init, this.next);
}

class CrewM {
  String? kind; // кеш типа спрайта бойца
  final String job;
  final List<WI> ws;
  bool ok = true;
  final double dx, dy;
  final Map<String, int> spare;
  CrewM(this.job, this.ws, this.dx, this.dy, this.spare);
}

class Order {
  String kind;
  double x, y, repath, lost, deploy, next;
  int targetId, salvos;
  Order(this.kind, {this.x = 0, this.y = 0, this.targetId = 0, this.repath = 0, this.lost = 0, this.salvos = 0, this.deploy = 0, this.next = 0});
}

class Squad {
  final int id, side;
  final String type, vid, name;
  final Variant t;
  double x, y, fa, ta = 0;
  final List<CrewM> crew;
  int men, max;
  double hp, hpMax;
  bool mob = true, gunOut = false;
  double fireT = 0;
  double morale, supp = 0, ammo = 100;
  Order? order;
  List<Pt>? path;
  int pi = 0;
  Squad? tg;
  String role = '';
  Pt? post;
  double fort = 0;
  bool moving = false, rout = false, dead = false, smoking = false, hurtLog = false, sneak = false;
  double lastFire = -99, lastHit = -99, lastShot = -99, fxT = 0, lastAmmoCalc = -99;
  final List<double> seenAt = [-99, -99];
  final List<Pt?> lk = [null, null];
  double born = 0, orderT = 0;
  int no = 0;
  int cargo = 0, carried = 0;
  String stance = '';
  String? wave;
  int mountTo = 0;
  Squad(this.id, this.side, this.type, this.vid, this.t, this.name, this.x, this.y, this.fa, this.crew, this.hp, this.morale)
      : men = crew.length,
        max = crew.length,
        hpMax = hp;
}

class Smoke {
  double x, y, r, R, t0, t1;
  Smoke(this.x, this.y, this.r, this.R, this.t0, this.t1);
}

class Pending {
  final String kind;
  final double at;
  final int from, to;
  final String am;
  final bool hit;
  final double ax, ay, x1, y1, t0, d;
  Pending(this.kind, this.at, this.am, {this.from = 0, this.to = 0, this.hit = false, this.ax = 0, this.ay = 0, this.x1 = 0, this.y1 = 0, this.t0 = 0, this.d = 0});
}

class Drone {
  final int side;
  double x, y, tx, ty, t = 0;
  String state = 'in';
  double vision, life;
  Drone(this.side, this.x, this.y, this.tx, this.ty, this.vision, this.life);
}

class Fpv {
  final int side, tid, from;
  double x, y, t = 0;
  final bool jam;
  Fpv(this.side, this.x, this.y, this.tid, this.jam, this.from);
}

class Wreck {
  final double x, y, fa, t;
  final String type;
  final int side;
  final Variant vt;
  bool old = false;
  Wreck(this.x, this.y, this.fa, this.type, this.side, this.t, this.vt);
}

class Body {
  final double x, y, t;
  final int side;
  Body(this.x, this.y, this.side, this.t);
}

class ObjState {
  final Obj o;
  double ctrl;
  int owner;
  final List<double> w = [0, 0];
  bool contested = false;
  ObjState(this.o, this.ctrl, this.owner);
  int get id => o.id;
  String get name => o.name;
  double get x => o.x;
  double get y => o.y;
  double get r => o.r;
  bool get key => o.key;
}

class QItem {
  final int side;
  final String type;
  final double at, t0;
  QItem(this.side, this.type, this.at, this.t0);
}

class Ability {
  int ch;
  double cd = 0;
  Ability(this.ch);
}

class Over {
  final int winner;
  final String why;
  Over(this.winner, this.why);
}

class Tracer {
  bool on = false;
  double x0 = 0, y0 = 0, x1 = 0, y1 = 0, t0 = 0, life = .12;
  int side = 0;
}

class Expl {
  bool on = false;
  double x = 0, y = 0, r = 0, t0 = 0, life = 1;
  int kind = 0;
}

class Stats {
  final List<int> lost = [0, 0], kills = [0, 0], veh = [0, 0];
}

class Battle {
  double t = 0;
  final int player, aiSide;
  final int atk = 1, def = 0;
  final String diffKey;
  final Diff diff;
  List<Squad> squads = [];
  final Map<int, Squad> byId = {};
  int nextId = 1;
  final List<int> cnt = [0, 0];
  final List<Smoke> smokes = [];
  final List<Pending> pend = [];
  final List<Drone> drones = [];
  final List<Fpv> fpv = [];
  final List<Wreck> wrecks = [];
  final List<List<double>> craterQ = [];
  late final List<ObjState> objs;
  final List<double> pts = [140, 160], inc = [0, 0];
  final List<QItem> queue = [];
  final List<Map<String, Ability>> ab = [mkAb(), mkAb()];
  final Stats stats = Stats();
  Over? over;
  double speed = 1;
  final Set<int> sel = {};
  final Uint8List fog = Uint8List(GW * GH);
  bool fogDirty = true;
  int tickN = 0;
  double holdT = 0;
  bool autoplay = false;
  double lastSpotLog = -9;
  bool deploying = false;
  bool mountDone = false;
  final List<Body?> bodies = List<Body?>.filled(420, null);
  int bodyI = 0;
  final List<Tracer> tr = List.generate(256, (_) => Tracer());
  int trI = 0;
  final List<Expl> ex = List.generate(90, (_) => Expl());
  int exI = 0;

  Battle(this.player, this.diffKey) : aiSide = 1 - player, diff = DIFFS[diffKey]!;
}

Map<String, Ability> mkAb() => {'drone': Ability(3), 'fpv': Ability(5), 'smoke': Ability(3), 'arty': Ability(2)};

late Battle S;
bool hasBattle = false;

Battle newBattle(int player, String diffKey, [List<List<String>>? forces]) {
  S = Battle(player, diffKey);
  hasBattle = true;
  S.objs = [
    for (int i = 0; i < MAP.objs.length; i++)
      () {
        final ow = i < OBJ_OWNER.length ? OBJ_OWNER[i] : -1;
        return ObjState(MAP.objs[i], ow == -1 ? 0 : (ow == 0 ? -1 : 1), ow);
      }(),
  ];
  deploy(forces);
  perception();
  fogUpdate();
  return S;
}

/* ---------- подбор сил и расстановка ---------- */
List<String> autoForce(int side, double budget) {
  final mix = AI_MIX[side == 1 ? 0 : 1], all = variantsFor(side), out = <String>[];
  double left = budget;
  while (out.length < MAX_UNITS) {
    final ok = all.where((v) => v.cost <= left).toList();
    if (ok.isEmpty) break;
    double wt(Variant v) => mix[v.cls]! / all.where((x) => x.cls == v.cls).length;
    double tot = 0;
    for (final v in ok) {
      tot += wt(v);
    }
    double r = rnd() * tot;
    Variant pick = ok[0];
    for (final v in ok) {
      r -= wt(v);
      if (r <= 0) {
        pick = v;
        break;
      }
    }
    out.add(pick.id);
    left -= pick.cost;
  }
  return out;
}

/// Направление от своей базы к базе противника (единичный вектор).
List<double> baseDir(int side) {
  final a = BASE[side], b = BASE[1 - side];
  final dx = b[0] - a[0], dy = b[1] - a[1], l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
  return [dx / l, dy / l];
}

/// Точка у своей базы: d — вглубь к противнику, l — поперёк; прижата к зоне расстановки и проходимой клетке.
List<double> basePoint(int side, double d, double l) {
  final b = BASE[side], dir = baseDir(side);
  final z = ZONE[side];
  final x = clamp(b[0] + dir[0] * d - dir[1] * l, z.x0 + 10, z.x1 - 10), y = clamp(b[1] + dir[1] * d + dir[0] * l, z.y0 + 10, z.y1 - 10);
  final c = nearestPassable(cellIdx(x, y), T_MV_V);
  if (c == cellIdx(x, y)) return [x, y];
  return [(c % GW + .5) * CELL, (c ~/ GW + .5) * CELL];
}

void placeForce(int side, List<String> list) {
  final atk = side == S.atk;
  final used = <String, int>{};
  final order = list.toList()..sort((a, b) => TYPE_ORDER.indexOf(VARS[a]!.cls) - TYPE_ORDER.indexOf(VARS[b]!.cls));
  List<double> take(String key, List<List<double>> arr) {
    final k = used[key] ?? 0;
    used[key] = k + 1;
    if (k < arr.length) return arr[k];
    final b = arr[k % arr.length];
    return [b[0] + rand(-60, 60), b[1] + rand(-60, 60)];
  }

  for (final vid in order) {
    final v = VARS[vid]!, c = v.cls;
    double x, y;
    bool fort = false;
    if (!atk) {
      List<double> p;
      if (c == 'sniper') {
        p = take('sniper', DEF_SLOTS['sniper']!);
        fort = true;
      } else if (c == 'mg') {
        p = take('mg', DEF_SLOTS['mg']!);
        fort = true;
      } else if (c == 'at') {
        p = take('at', DEF_SLOTS['at']!);
        fort = true;
      } else if (c == 'rifle') {
        p = take('inf', DEF_SLOTS['inf']!);
        fort = true;
      } else {
        p = take('rear', DEF_SLOTS['rear']!);
      }
      x = p[0];
      y = p[1];
    } else {
      final k = used['a_$c'] ?? 0;
      used['a_$c'] = k + 1;
      // глубина d от базы в сторону противника и смещение l поперёк (для «Переправы» совпадает с прежними координатами)
      double d, l;
      if (c == 'tank') {
        d = 70;
        l = -120.0 + (k % 5) * 70;
      } else if (c == 'ifv') {
        d = 115;
        l = -140.0 + (k % 6) * 56;
      } else if (c == 'mortar') {
        d = 30;
        l = -40.0 + k * 40;
      } else if (c == 'sniper') {
        d = 280;
        l = -200.0 + k * 60;
      } else {
        d = 165.0 + (k % 3) * 30 + ((k ~/ 3) % 2) * 14;
        l = -140.0 + (((k ~/ 3) * 50) % 380) + (k % 3) * 8;
      }
      final p = basePoint(side, d, l);
      x = p[0];
      y = p[1];
    }
    final q = mkSquad(side, vid, x, y);
    if (fort) {
      q.order = Order('hold');
      q.fort = 1;
      q.post = Pt(q.x, q.y);
    }
    q.role = atk ? (q.t.veh ? 'escort' : 'assault') : 'post';
  }
}

void deploy(List<List<String>>? forces) {
  for (final side in [0, 1]) {
    final f = (forces != null && forces.length > side && forces[side].isNotEmpty) ? forces[side] : autoForce(side, BUDGET[side == S.atk ? 1 : 0]);
    placeForce(side, f);
  }
}

/* ---------- мелкие помощники ---------- */
double coverOf(Squad sq) {
  final tc = T_COVER[ter[cellIdx(sq.x, sq.y)]];
  if (sq.t.veh) return tc * .4;
  return math.min(.92, tc + .3 * sq.fort * (1 - tc * .6));
}

bool isSpotted(Squad e, int s) => e.side == s || S.t - e.seenAt[s] < 1;
double effOf(Squad sq) => sq.rout ? 0 : (sq.t.veh && sq.hp < 35 ? .8 : 1);
String sideName(int s) => SIDES[s].short;

/* ---------- события ---------- */
void ev(String text, String kind, double x, double y, [int? side]) {
  if (side == null || side == S.player || S.autoplay) HOOK.onLog?.call(text, kind, x, y);
}

/// Сторона для журнала: свои события всегда видны, чужие — только если отряд виден игроку.
int? evSide(Squad sq) => sq.side == S.player ? null : (vis4player(sq) ? S.player : -1);

bool vis4player(Squad sq) => sq.side == S.player || isSpotted(sq, S.player);

void addTracer(double x0, double y0, double x1, double y1, int side) {
  S.trI = (S.trI + 1) & 255;
  final t = S.tr[S.trI];
  t.on = true;
  t.x0 = x0;
  t.y0 = y0;
  t.x1 = x1;
  t.y1 = y1;
  t.t0 = S.t;
  t.life = (.1 + rnd() * .06) * FX.tracerLife;
  t.side = side;
}

void boom(double x, double y, double r, [int kind = 0]) {
  S.exI = (S.exI + 1) % 90;
  final e = S.ex[S.exI];
  e.on = true;
  e.x = x;
  e.y = y;
  e.r = r;
  e.t0 = S.t;
  e.life = kind == 2 ? 1.6 * FX.big.dur : (.7 + r / 60) * (kind == 0 ? FX.boom.dur : 1);
  e.kind = kind;
  HOOK.onSfx?.call('boom:$kind', x, y, math.min(1, r / 34));
}

/* ---------- приказы ---------- */
int issue(List<Squad> sqs, String kind0, double x, double y, [int targetId = 0]) {
  var kind = kind0;
  final sneak = kind == 'sneak';
  if (sneak) kind = 'move';
  final live = sqs.where((s) => !s.dead && (!s.rout || kind == 'retreat') && s.carried == 0).toList();
  int i = 0, failed = 0;
  final n = live.length;
  for (final sq in live) {
    double tx = x, ty = y;
    if (n > 1 && (kind == 'move' || kind == 'fight')) {
      final a = i * 2.4, r = math.sqrt(i) * 26;
      tx += math.cos(a) * r;
      ty += math.sin(a) * r;
    }
    i++;
    sq.orderT = S.t;
    sq.sneak = false;
    if (kind == 'mount') {
      if (sq.t.veh || sq.carried != 0) continue;
      sq.order = Order('mount', targetId: targetId);
      sq.path = null;
      continue;
    }
    if (kind == 'hold') {
      sq.order = Order('hold');
      sq.path = null;
      continue;
    }
    if (kind == 'retreat') {
      final b = BASE[sq.side];
      sq.path = findPath(sq.x, sq.y, b[0], b[1], sq.t.veh) ?? [Pt(b[0], b[1])];
      sq.pi = 0;
      sq.order = Order('retreat');
      continue;
    }
    if (kind == 'fire') {
      if (!sq.t.mortar) continue;
      sq.order = Order('fire', x: x, y: y, salvos: 4);
      sq.path = null;
      continue;
    }
    if (kind == 'attack') {
      sq.order = Order('attack', targetId: targetId);
      continue;
    }
    final p = findPath(sq.x, sq.y, tx, ty, sq.t.veh);
    if (p == null) {
      failed++;
      continue;
    }
    sq.path = p;
    sq.pi = 0;
    sq.order = Order(kind, x: tx, y: ty);
    sq.fort = 0;
    sq.sneak = sneak && kind == 'move';
  }
  return failed;
}

bool advance(Squad sq, double dt, double mult) {
  final path = sq.path;
  if (path == null || sq.pi >= path.length) return true;
  final wp = path[sq.pi], dx = wp.x - sq.x, dy = wp.y - sq.y, d = math.sqrt(dx * dx + dy * dy);
  double m = (sq.t.veh ? T_MV_V : T_MV_I)[ter[cellIdx(sq.x, sq.y)]];
  if (m == 0) m = .3;
  final double crewF;
  if (sq.t.veh) {
    crewF = (sq.mob && sq.crew.any((c) => c.ok && c.job == 'driver')) ? (sq.hp < 40 ? .7 : 1) : 0;
  } else {
    crewF = .5 + .5 * clamp(sq.men / sq.max + .3, 0, 1);
  }
  final sp = sq.t.speed * m * mult * ((sq.supp > 75 && !sq.t.veh) ? 0 : 1) * crewF;
  if (sp <= 0) return false;
  final st = sp * (sq.sneak ? .45 : 1) * dt;
  sq.moving = true;
  sq.fort = 0;
  final a = math.atan2(dy, dx);
  double da = a - sq.fa;
  while (da > math.pi) {
    da -= TAU;
  }
  while (da < -math.pi) {
    da += TAU;
  }
  sq.fa += da * math.min(1, dt * (sq.t.veh ? 4 : 8));
  if (d <= st) {
    sq.x = wp.x;
    sq.y = wp.y;
    sq.pi++;
    return sq.pi >= path.length;
  }
  sq.x += dx / d * st;
  sq.y += dy / d * st;
  return false;
}

/* ---------- обнаружение ---------- */
double viewerRange(Squad v) {
  double r = v.t.vision;
  if (hgt[cellIdx(v.x, v.y)] > .55) r *= 1.2;
  if (v.rout) r *= .8;
  if (v.supp > 60) r *= .85;
  return r;
}

double conceal(Squad e) {
  double m = 1;
  final tt = ter[cellIdx(e.x, e.y)];
  if (tt == Ter.FOREST) {
    m = .55;
  } else if (tt == Ter.BUILD) {
    m = .5;
  } else if (tt == Ter.TRENCH) {
    m = .65;
  } else if (tt == Ter.RUBBLE) {
    m = .85;
  }
  if (e.fort >= .9) m *= .85;
  if (e.sneak && e.moving) m *= .6;
  if (e.stance == 'ambush' && S.t - e.lastFire > 3) m *= .55;
  if (S.t - e.lastFire < 3) m = math.min(1.5, m * 1.5);
  if (e.moving) m *= 1.1;
  if (e.t.veh) m *= 1.25;
  if (e.t.stealth > 0) m *= e.t.stealth;
  return m;
}

void perception() {
  final sq = S.squads, now = S.t;
  for (int s = 0; s < 2; s++) {
    for (final e in sq) {
      if (e.dead || e.side == s || e.carried != 0) continue;
      bool sp = false;
      final cm = conceal(e);
      for (final v in sq) {
        if (v.dead || v.side != s || v.carried != 0) continue;
        final dx = e.x - v.x, dy = e.y - v.y, r = viewerRange(v) * cm;
        if (dx * dx + dy * dy > r * r) continue;
        if (los(v.x, v.y, e.x, e.y)) {
          sp = true;
          break;
        }
      }
      if (!sp) {
        for (final d in S.drones) {
          if (d.side != s || d.state == 'out') continue;
          final r = d.vision * (e.t.stealth > 0 ? e.t.stealth + .15 : 1) * (cm < .6 ? .8 : 1);
          if (dist(d.x, d.y, e.x, e.y) < r) {
            sp = true;
            break;
          }
        }
      }
      if (sp) {
        if (now - e.seenAt[s] > 4 && s == S.player && now - S.lastSpotLog > 2.5) {
          S.lastSpotLog = now;
          HOOK.onLog?.call('Контакт: ${NM(e)} (${sideName(e.side)})', 'info', e.x, e.y);
        }
        e.seenAt[s] = now;
        e.lk[s] = Pt(e.x, e.y);
      }
    }
  }
}

void castVision(double x, double y, double R, int rays) {
  final f = S.fog, c0 = cellIdx(x, y);
  f[c0] = 2;
  for (int k = 0; k < rays; k++) {
    final a = k / rays * TAU, ca = math.cos(a), sa = math.sin(a);
    double sum = 0;
    int last = c0;
    for (double d = 10; d <= R; d += 10) {
      final px = x + ca * d, py = y + sa * d;
      if (px < 0 || py < 0 || px >= W || py >= H) break;
      final c = cellIdx(px, py);
      if (c != last) {
        last = c;
        f[c] = 2;
        final o = T_OPAC[ter[c]];
        if (o > 0) {
          sum += o;
          if (sum >= 1) break;
        }
      }
    }
  }
}

void fogUpdate() {
  final f = S.fog, ps = S.player;
  for (int i = 0; i < f.length; i++) {
    if (f[i] == 2) f[i] = 1;
  }
  for (final v in S.squads) {
    if (!v.dead && v.carried == 0 && v.side == ps) castVision(v.x, v.y, viewerRange(v), 140);
  }
  for (final d in S.drones) {
    if (d.side == ps && d.state != 'out') {
      forCircle(d.x, d.y, d.vision, (c, _, __) {
        f[c] = 2;
      });
    }
  }
  S.fogDirty = true;
}

/* ---------- цели захвата, подкрепление ---------- */
void updateObjs(double dt) {
  const base = 2.0;
  final own = [0, 0];
  for (final o in S.objs) {
    o.w[0] = o.w[1] = 0;
    for (final sq in S.squads) {
      if (sq.dead || sq.rout || sq.carried != 0) continue;
      if (dist(sq.x, sq.y, o.x, o.y) <= o.r) o.w[sq.side] += sq.t.veh ? 1.2 : sq.men / sq.max;
    }
    final wu = o.w[0], wr = o.w[1];
    o.contested = wu > 0 && wr > 0;
    if (wu > 0 && wr == 0) {
      o.ctrl = math.max(-1, o.ctrl - dt / 12 * math.min(1.6, wu));
    } else if (wr > 0 && wu == 0) {
      o.ctrl = math.min(1, o.ctrl + dt / 12 * math.min(1.6, wr));
    } else if (o.contested) {
      o.ctrl = clamp(o.ctrl + clamp((wr - wu) * dt / 18, -dt / 8, dt / 8), -1, 1);
    }
    final prev = o.owner;
    o.owner = o.ctrl <= -.5 ? 0 : (o.ctrl >= .5 ? 1 : -1);
    if (prev != o.owner && o.owner != -1) {
      ev('${o.name} — под контролем: ${SIDES[o.owner].name}', o.owner == S.player ? 'good' : 'bad', o.x, o.y);
    } else if (prev != o.owner && prev != -1) {
      ev('${o.name} потерян стороной ${sideName(prev)}, рубеж оспаривается', prev == S.player ? 'bad' : 'info', o.x, o.y);
    }
    if (o.owner >= 0) own[o.owner]++;
  }
  for (int s = 0; s < 2; s++) {
    S.inc[s] = (base + own[s] * 1.4) * (s == S.atk ? ATK_INC : 1) * ((s == S.aiSide && !S.autoplay) ? S.diff.inc : 1);
    S.pts[s] += S.inc[s] * dt;
  }
  final keys = S.objs.where((o) => o.key);
  if (keys.every((o) => o.owner == S.atk)) {
    S.holdT += dt;
  } else {
    S.holdT = math.max(0, S.holdT - dt * 2);
  }
}

bool buyUnit(int side, String type) {
  final t = VARS[type];
  if (t == null || S.pts[side] < t.cost) return false;
  S.pts[side] -= t.cost;
  S.queue.add(QItem(side, type, S.t + t.delay, S.t));
  return true;
}

void processQueue() {
  for (int i = S.queue.length - 1; i >= 0; i--) {
    final q = S.queue[i];
    if (S.t < q.at) continue;
    S.queue.removeAt(i);
    final sq = mkSquad(q.side, q.type, BASE[q.side][0], BASE[q.side][1] + rand(-170, 170));
    sq.role = q.side == S.atk ? (sq.t.veh ? 'escort' : 'assault') : 'counter';
    ev('Подкрепление: ${sq.name} (${NM(sq)})', 'good', sq.x, sq.y, q.side);
  }
}

/* ---------- способности ---------- */
bool canUse(int side, String k) {
  final a = S.ab[side][k]!;
  return a.ch > 0 && a.cd <= 0;
}

Squad? nearestFriendly(int side, double x, double y, double maxD) {
  Squad? b;
  double bd = maxD;
  for (final s in S.squads) {
    if (s.dead || s.side != side) continue;
    final d = dist(s.x, s.y, x, y);
    if (d < bd) {
      bd = d;
      b = s;
    }
  }
  return b;
}

String? useDrone(int side, double x, double y) {
  if (!canUse(side, 'drone')) return 'Дрон ещё не готов';
  final a = S.ab[side]['drone']!;
  a.ch--;
  a.cd = AB_CD['drone']!;
  // старт у своего края карты, напротив цели
  final b = BASE[side], dir = baseDir(side), px = -dir[1], py = dir[0];
  final off = clamp((x - b[0]) * px + (y - b[1]) * py, -560, 560);
  final sx = clamp(b[0] + px * off, 0, W), sy = clamp(b[1] + py * off, 0, H);
  S.drones.add(Drone(side, sx, sy, x, y, 430, 26));
  return null;
}

String? useFpv(int side, int targetId) {
  if (!canUse(side, 'fpv')) return 'FPV ещё не готов';
  final tg = S.byId[targetId];
  if (tg == null || tg.dead || !isSpotted(tg, side)) return 'Цель не наблюдается';
  final op = nearestFriendly(side, tg.x, tg.y, 1000);
  if (op == null) return 'Нет оператора в радиусе 1000 м';
  final a = S.ab[side]['fpv']!;
  a.ch--;
  a.cd = AB_CD['fpv']!;
  S.fpv.add(Fpv(side, op.x, op.y, targetId, rnd() < .18, op.id));
  return null;
}

String? useSmoke(int side, double x, double y) {
  if (!canUse(side, 'smoke')) return 'Дымы ещё не готовы';
  if (nearestFriendly(side, x, y, 900) == null) return 'Слишком далеко от своих';
  final a = S.ab[side]['smoke']!;
  a.ch--;
  a.cd = AB_CD['smoke']!;
  S.smokes.add(Smoke(x, y, 1, 58, S.t, S.t + 24));
  HOOK.onSfx?.call('boom', x, y, .4);
  return null;
}

void updateAir(double dt) {
  for (int i = S.drones.length - 1; i >= 0; i--) {
    final d = S.drones[i];
    d.t += dt;
    if (d.state == 'in') {
      final dx = d.tx - d.x, dy = d.ty - d.y, L = math.sqrt(dx * dx + dy * dy), st = 70 * dt;
      if (L <= st) {
        d.state = 'loiter';
        d.t = 0;
      } else {
        d.x += dx / L * st;
        d.y += dy / L * st;
      }
    } else if (d.state == 'loiter') {
      d.x += math.cos(d.t * .8) * .6;
      d.y += math.sin(d.t * .8) * .6;
      if (d.t > d.life) d.state = 'out';
    } else {
      final b = BASE[d.side], dx = b[0] - d.x, dy = b[1] - d.y, L = math.sqrt(dx * dx + dy * dy), st = 80 * dt;
      if (L <= st) {
        S.drones.removeAt(i);
        continue;
      }
      d.x += dx / L * st;
      d.y += dy / L * st;
    }
    for (final e in S.squads) {
      if (e.dead || e.carried != 0 || e.side == d.side || !(e.type == 'mg' || e.type == 'ifv' || e.type == 'rifle')) continue;
      if (dist(e.x, e.y, d.x, d.y) < 320 &&
          rnd() < dt * (e.type == 'ifv' ? .05 : (e.type == 'mg' ? .04 : .012)) * (e.supp > 50 ? .3 : 1)) {
        boom(d.x, d.y, 12, 1);
        ev('БПЛА сбит', d.side == S.player ? 'warn' : 'good', d.x, d.y);
        S.drones.removeAt(i);
        break;
      }
    }
  }
  for (int i = S.fpv.length - 1; i >= 0; i--) {
    final f = S.fpv[i], tg = S.byId[f.tid];
    f.t += dt;
    if (tg == null || tg.dead) {
      S.fpv.removeAt(i);
      boom(f.x, f.y, 8, 1);
      continue;
    }
    final dx = tg.x - f.x, dy = tg.y - f.y, L = math.sqrt(dx * dx + dy * dy), st = 95 * dt;
    if (f.jam && f.t > 1.2 + rnd() * .1) {
      S.fpv.removeAt(i);
      boom(f.x, f.y, 8, 1);
      ev('FPV подавлен средствами РЭБ', f.side == S.player ? 'warn' : 'good', f.x, f.y);
      continue;
    }
    if (L <= math.max(st, 8)) {
      S.fpv.removeAt(i);
      boom(tg.x, tg.y, 26, 0);
      final a = AMMO['fpv']!;
      if (tg.t.veh) {
        resolveHitVeh(tg, a, f.x, f.y, f.side, 0, false);
      } else {
        blastAt(tg.x, tg.y, a.rad, a.kill, f.side, tg);
        tg.supp = math.min(100, tg.supp + 60);
      }
      tg.lastShot = S.t;
      continue;
    }
    f.x += dx / L * st;
    f.y += dy / L * st;
  }
  for (int i = S.smokes.length - 1; i >= 0; i--) {
    final s = S.smokes[i];
    if (S.t > s.t1 + 2) {
      S.smokes.removeAt(i);
      continue;
    }
    s.r = S.t > s.t1 ? s.R * (1 - (S.t - s.t1) / 2) : s.R * math.min(1, (S.t - s.t0) / 2.5);
  }
  for (int s = 0; s < 2; s++) {
    for (final a in S.ab[s].values) {
      if (a.cd > 0) a.cd -= dt;
    }
  }
}

/* ---------- шаг по отрядам ---------- */
void stepSquad(Squad sq, double dt) {
  final t = sq.t, now = S.t;
  sq.moving = false;
  if (sq.carried != 0) {
    final v = S.byId[sq.carried];
    if (v != null && !v.dead) {
      sq.x = v.x;
      sq.y = v.y;
      sq.fa = v.fa;
      sq.tg = null;
      return;
    }
    sq.carried = 0;
  }
  if (sq.order == null || sq.order!.kind != 'move') sq.sneak = false;
  // подавление, мораль
  if (now - sq.lastShot > 1.2) sq.supp = math.max(0, sq.supp - 7 * dt);
  if (sq.supp > 65) {
    sq.morale -= 1.2 * dt;
  } else if (now - sq.lastHit > 4 && sq.supp < 25) {
    sq.morale = math.min(100, sq.morale + (.5 + coverOf(sq) * .5) * dt);
  }
  if (!sq.rout && sq.morale < 22) {
    sq.rout = true;
    sq.order = Order('retreat');
    sq.path = null;
    ev('${sq.name} отступает: потеряна стойкость', sq.side == S.player ? 'warn' : 'good', sq.x, sq.y, evSide(sq));
  }
  if (sq.rout) {
    sq.morale = math.min(100, sq.morale + 1.1 * dt);
    if (sq.morale > 48 && now - sq.lastHit > 6) {
      sq.rout = false;
      sq.order = null;
      sq.path = null;
      ev('${sq.name} снова в строю', 'info', sq.x, sq.y, sq.side);
    }
  }
  if (sq.fireT != 0) vehicleFire(sq);
  final o = sq.order;
  if (sq.rout) {
    if (sq.path == null || sq.pi >= sq.path!.length) {
      final b = BASE[sq.side];
      sq.path = findPath(sq.x, sq.y, b[0], b[1], t.veh) ?? [Pt(b[0], b[1])];
      sq.pi = 0;
    }
    advance(sq, dt, 1.2);
  } else if (o != null) {
    switch (o.kind) {
      case 'move':
        if (advance(sq, dt, 1)) sq.order = null;
        break;
      case 'fight':
        {
          final tg = sq.tg;
          if (tg != null && !tg.dead && dist(sq.x, sq.y, tg.x, tg.y) <= (t.hasShot && tg.t.veh ? t.shotRange : t.range) * .98) {
            sq.fa += angDiff(sq.fa, math.atan2(tg.y - sq.y, tg.x - sq.x)) * math.min(1, dt * 8);
          } else if (advance(sq, dt, 1)) {
            sq.order = null;
          }
          break;
        }
      case 'attack':
        {
          final e = S.byId[o.targetId];
          if (e == null || e.dead) {
            sq.order = null;
            break;
          }
          if (!isSpotted(e, sq.side)) {
            o.lost += dt;
            if (o.lost > 6) {
              sq.order = null;
              break;
            }
          } else {
            o.lost = 0;
          }
          final d = dist(sq.x, sq.y, e.x, e.y), reach = (t.hasShot && e.t.veh ? t.shotRange : t.range) * .85;
          if (d > reach || !los(sq.x, sq.y, e.x, e.y)) {
            o.repath -= dt;
            if (o.repath <= 0 || sq.path == null) {
              final lk = e.lk[sq.side] ?? Pt(e.x, e.y);
              sq.path = findPath(sq.x, sq.y, lk.x, lk.y, t.veh);
              sq.pi = 0;
              o.repath = 2;
            }
            if (sq.path != null) advance(sq, dt, 1);
          } else {
            sq.fa += angDiff(sq.fa, math.atan2(e.y - sq.y, e.x - sq.x)) * math.min(1, dt * 8);
          }
          break;
        }
      case 'retreat':
        if (sq.path == null) {
          final b = BASE[sq.side];
          sq.path = findPath(sq.x, sq.y, b[0], b[1], t.veh) ?? [Pt(b[0], b[1])];
          sq.pi = 0;
        }
        if (advance(sq, dt, 1.15)) sq.order = null;
        break;
      case 'fire':
        mortarStep(sq, dt);
        break;
      case 'mount':
        {
          final v = S.byId[o.targetId];
          if (v == null || v.dead || v.cargo != 0 || v.t.cap == 0 || v.t.cap < sq.men || v.side != sq.side) {
            sq.order = null;
            break;
          }
          o.repath -= dt;
          if (o.repath <= 0 || sq.path == null) {
            sq.path = findPath(sq.x, sq.y, v.x, v.y, false);
            sq.pi = 0;
            o.repath = 1.5;
          }
          if (dist(sq.x, sq.y, v.x, v.y) < 26) {
            boardVeh(sq, v);
            break;
          }
          if (sq.path != null) advance(sq, dt, 1);
          break;
        }
    }
  }
  // окапывание
  final o2 = sq.order;
  if (!sq.moving && !t.veh && (o2 == null || o2.kind == 'hold' || o2.kind == 'fire' || o2.kind == 'fight')) {
    sq.fort = math.min(1, sq.fort + dt / (o2 != null && o2.kind == 'hold' ? 6 : 14));
  }
  // цель и огонь
  if ((S.tickN + sq.id) % 6 == 0 && !sq.rout) acquire(sq);
  final tg = sq.tg;
  if (tg != null && !sq.rout) {
    if (tg.dead || !isSpotted(tg, sq.side)) {
      sq.tg = null;
    } else {
      final d = dist(sq.x, sq.y, tg.x, tg.y);
      if (d > t.range * 1.05) {
        sq.tg = null;
      } else {
        if (!sq.moving) sq.fa += angDiff(sq.fa, math.atan2(tg.y - sq.y, tg.x - sq.x)) * math.min(1, dt * 8);
        sq.ta = math.atan2(tg.y - sq.y, tg.x - sq.x);
        fireControl(sq, tg, d, dt);
      }
    }
  }
  if (t.veh && sq.tg == null && !sq.moving) sq.ta += angDiff(sq.ta, sq.fa) * math.min(1, dt * 3);
}

void separate() {
  final sq = S.squads, n = sq.length;
  for (int i = 0; i < n; i++) {
    final a = sq[i];
    if (a.dead || !a.moving || a.carried != 0) continue;
    for (int j = 0; j < n; j++) {
      if (i == j) continue;
      final b = sq[j];
      if (b.dead || b.side != a.side || b.carried != 0) continue;
      final dx = a.x - b.x, dy = a.y - b.y;
      if (dx > 18 || dx < -18 || dy > 18 || dy < -18) continue;
      var d = math.sqrt(dx * dx + dy * dy);
      if (d == 0) d = .01;
      if (d < 16) {
        final p = (16 - d) * .25, nx = a.x + dx / d * p, ny = a.y + dy / d * p;
        if ((a.t.veh ? T_MV_V : T_MV_I)[ter[cellIdx(nx, ny)]] > 0) {
          a.x = nx;
          a.y = ny;
        }
      }
    }
  }
}

/* ---------- главный шаг ---------- */
void step() {
  if (S.over != null) return;
  const dt = TICK;
  S.t += dt;
  S.tickN++;
  if (S.tickN % 4 == 0) perception();
  if (S.tickN % 6 == 0) fogUpdate();
  if (S.tickN % 30 == 15) aiTick();
  final list = S.squads;
  for (int i = 0; i < list.length; i++) {
    final sq = list[i];
    if (!sq.dead) stepSquad(sq, dt);
  }
  separate();
  processPending();
  updateAir(dt);
  processQueue();
  updateObjs(dt);
  if (S.tickN % 20 == 0) {
    S.squads = S.squads.where((s) {
      if (s.dead) {
        S.byId.remove(s.id);
        return false;
      }
      return true;
    }).toList();
    checkEnd();
  }
  for (final w in S.wrecks) {
    if (S.t - w.t > 300) w.old = true;
  }
}

void checkEnd() {
  final atk = S.atk, def = S.def;
  final cnt = [0, 0];
  for (final s in S.squads) {
    if (!s.dead) cnt[s.side]++;
  }
  const cheapest = 60;
  int? win;
  String why = '';
  if (S.holdT >= HOLD_NEED) {
    win = atk;
    why = 'Оба рубежа удержаны ${HOLD_NEED.toInt()} секунд';
  } else if (S.t >= LIMIT) {
    win = def;
    why = 'Время боя истекло, рубежи удержаны';
  } else {
    for (final s in [atk, def]) {
      if (cnt[s] == 0 && !S.queue.any((q) => q.side == s) && S.pts[s] < cheapest) {
        win = 1 - s;
        why = 'У противника не осталось сил';
      }
    }
  }
  if (win != null) {
    S.over = Over(win, why);
    HOOK.onOver?.call(S.over!);
  }
}
