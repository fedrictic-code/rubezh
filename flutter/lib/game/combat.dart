// Боевая модель: бойцы, оружие, броня, взрывы, стрельба (перенос 03b_combat.js).
import 'dart:math' as math;

import 'battle.dart';
import 'core.dart';
import 'data.dart';

const double QPI = math.pi / 4, HPI = math.pi / 2;
const double SUPP_K = 9; // перевод подавления от пуль в шкалу 0–100

String NM(Squad sq) => sq.t.name;

/* ---------- создание отряда ---------- */
WI mkWI(String id, Map<String, int> a) {
  final w = WPN[id]!;
  final am = <String, int>{};
  for (final k in w.a) {
    final v = a[k] ?? 0;
    if (v > 0) am[k] = v;
  }
  return WI(id, w, am, Map<String, int>.from(am), S.t + rand(0, 1.2));
}

Squad mkSquad(int side, String vid, double x, double y) {
  final t = VARS[vid]!;
  final c = S.cnt[side]++;
  final calls = SIDES[side].calls;
  final crew = <CrewM>[];
  for (final md in t.men) {
    final a = rnd() * TAU, r = t.veh ? 0.0 : 3 + rnd() * 11;
    crew.add(CrewM(md.job, md.w.map((id) => mkWI(id, md.a)).toList(), math.cos(a) * r, math.sin(a) * r, md.a));
  }
  // запасные патроны, которые несёт расчёт, добавляем к оружию, которому они подходят
  for (final man in crew) {
    for (final k in man.spare.keys) {
      if (man.ws.any((wi) => wi.w.a.contains(k))) continue;
      WI? to;
      for (final m2 in crew) {
        for (final wi in m2.ws) {
          if (wi.w.a.contains(k)) {
            to = wi;
            break;
          }
        }
        if (to != null) break;
      }
      if (to != null) {
        to.am[k] = (to.am[k] ?? 0) + man.spare[k]!;
        to.init[k] = (to.init[k] ?? 0) + man.spare[k]!;
      }
    }
  }
  final sq = Squad(S.nextId++, side, t.cls, vid, t, '${calls[c % calls.length]}-${1 + c ~/ calls.length}', x, y, side == 1 ? 0 : math.pi, crew,
      t.veh ? 100 : 0, t.morale);
  sq.born = S.t;
  final cell = cellIdx(x, y), mv = t.veh ? T_MV_V : T_MV_I;
  if (mv[ter[cell]] == 0) {
    final n = nearestPassable(cell, mv);
    sq.x = (n % GW + .5) * CELL;
    sq.y = ((n ~/ GW) + .5) * CELL;
  }
  final used = <int>{};
  for (final s2 in S.squads) {
    if (s2.side == side && !s2.dead) used.add(s2.no);
  }
  sq.no = 0;
  for (int i = 1; i <= 16; i++) {
    if (!used.contains(i)) {
      sq.no = i;
      break;
    }
  }
  S.squads.add(sq);
  S.byId[sq.id] = sq;
  return sq;
}

double ammoPct(Squad sq) {
  double s = 0;
  int n = 0;
  for (final man in sq.crew) {
    for (final wi in man.ws) {
      if (wi.w.k == 'mg' && wi.w.coax) continue;
      int c = 0, i = 0;
      for (final k in wi.init.keys) {
        c += wi.am[k] ?? 0;
        i += wi.init[k]!;
      }
      if (i > 0) {
        s += c / i;
        n++;
      }
    }
  }
  return n > 0 ? s / n * 100 : 100;
}

/* ---------- потери ---------- */
void addBody(Squad sq, CrewM man) {
  S.bodyI = (S.bodyI + 1) % 420;
  S.bodies[S.bodyI] = Body(sq.x + man.dx, sq.y + man.dy, sq.side, S.t);
}

void inherit(Squad sq, CrewM man) {
  // оружие расчёта переходит к живому бойцу
  for (final wi in man.ws.toList()) {
    if (!const ['mg', 'hmg', 'rocket', 'atgm'].contains(wi.w.k)) continue;
    int n = 0;
    for (final v in wi.am.values) {
      n += v;
    }
    if (n <= 0) continue;
    CrewM? to;
    for (final m2 in sq.crew) {
      if (m2.ok && !m2.ws.any((x) => x.w.k == wi.w.k)) {
        to = m2;
        break;
      }
    }
    if (to != null) {
      to.ws.add(wi);
      wi.next = S.t + 3;
    }
  }
}

void outMan(Squad sq, CrewM man, int? srcSide) {
  if (!man.ok || sq.dead) return;
  man.ok = false;
  sq.men--;
  sq.morale -= sq.t.veh ? 3 : 7;
  sq.lastHit = S.t;
  S.stats.lost[sq.side]++;
  if (srcSide != null) S.stats.kills[srcSide]++;
  if (!sq.t.veh) {
    addBody(sq, man);
    inherit(sq, man);
  }
  if (!sq.hurtLog && sq.men <= sq.max / 2 && sq.men > 0) {
    sq.hurtLog = true;
    ev('${sq.name} понесло потери', sq.side == S.player ? 'warn' : 'info', sq.x, sq.y, evSide(sq));
  }
  if (sq.t.veh) updateVehHp(sq);
  if (sq.men <= 0) destroySquad(sq, srcSide, sq.t.veh ? 'crew' : '');
}

void casualty(Squad sq, int? srcSide) {
  if (sq.dead || sq.men <= 0) return;
  int k = (rnd() * sq.men).toInt();
  for (final man in sq.crew) {
    if (man.ok) {
      if (k-- == 0) {
        outMan(sq, man, srcSide);
        return;
      }
    }
  }
}

void updateVehHp(Squad sq) {
  final crew = sq.men / sq.max;
  sq.hp = math.max(1, 100 * (.45 * crew + .3 * (sq.mob ? 1 : 0) + .25 * (sq.gunOut ? 0 : 1)));
  if (sq.fireT != 0) sq.hp = math.min(sq.hp, 28);
}

void destroySquad(Squad sq, int? srcSide, String why) {
  if (sq.dead) return;
  sq.dead = true;
  S.sel.remove(sq.id);
  if (sq.cargo != 0) {
    final inf = S.byId[sq.cargo];
    if (inf != null && !inf.dead) {
      inf.carried = 0;
      sq.cargo = 0;
      inf.x = sq.x;
      inf.y = sq.y;
      inf.supp = 70;
      inf.morale -= 14;
      final p = why == 'ammo' ? .85 : (why == 'fire' ? 0.0 : .35);
      for (final man in inf.crew) {
        if (man.ok && rnd() < p) outMan(inf, man, srcSide);
      }
    }
  }
  if (sq.t.veh) {
    S.stats.veh[sq.side]++;
    S.wrecks.add(Wreck(sq.x, sq.y, sq.fa, sq.type, sq.side, S.t, sq.t));
    boom(sq.x, sq.y, 38, 2);
  }
  sq.men = 0;
  final mine = sq.side == S.player;
  final why2 = why == 'ammo' ? ' · детонация боекомплекта' : (why == 'fire' ? ' · пожар' : '');
  if (mine) {
    ev('Потеряно: ${sq.name} (${NM(sq)})$why2', 'bad', sq.x, sq.y);
  } else if (vis4player(sq) || S.autoplay) {
    ev('Уничтожено: ${NM(sq)} ${sideName(sq.side)}$why2', 'good', sq.x, sq.y);
  }
}

/* ---------- броня и пробитие ---------- */
double penAt(Ammo a, double d) => (a.k == 'HEAT' || a.k == 'ATGM') ? a.pen[0] : lerp(a.pen[0], a.pen[1], math.min(1, d / 1000));

({String face, double th}) armourFace(Squad tg, double ax, double ay, Ammo a) {
  final arm = tg.t.arm!;
  final ce = a.k == 'HEAT' || a.k == 'ATGM';
  final ci = ce ? 1 : 0;
  if (a.top) return (face: 't', th: arm.t[ci]);
  final rel = angDiff(tg.fa, math.atan2(ay - tg.y, ax - tg.x)).abs();
  String face;
  double theta;
  if (rel < QPI * 1.1) {
    face = 'f';
    theta = rel;
  } else if (rel > QPI * 2.9) {
    face = 'r';
    theta = math.pi - rel;
  } else {
    face = 's';
    theta = (rel - HPI).abs();
  }
  final base = face == 'f' ? arm.f[ci] : (face == 'r' ? arm.r[ci] : arm.s[ci]);
  return (face: face, th: base / math.pow(math.cos(math.min(theta, 1.1)), ce ? .6 : 1));
}

String? bestAmmo(WI wi, Squad tg, double sx, double sy, double d) {
  String? best;
  double bs = -1e9;
  final w = wi.w;
  for (final k in wi.am.keys) {
    if (wi.am[k]! <= 0) continue;
    final a = AMMO[k]!;
    if (a.k == 'SMK') continue;
    double sc;
    if (tg.t.veh) {
      final af = armourFace(tg, sx, sy, a), pen = penAt(a, d);
      if (a.k == 'SA') {
        if (pen < af.th * .6) continue;
        sc = pen / af.th;
      } else if (a.k == 'HE') {
        if (w.k == 'ugl') continue;
        if (pen < af.th * .5) continue;
        sc = pen / af.th * .8;
      } else {
        sc = 1 + pen / af.th;
      }
    } else {
      if (a.k == 'HEAT' || a.k == 'ATGM') {
        if (w.k == 'rocket' || w.k == 'atgm') continue;
        sc = .2;
      } else if (a.k == 'HE') {
        sc = 3;
      } else if (a.k == 'AP') {
        sc = .6;
      } else {
        sc = 1;
      }
    }
    if (sc > bs) {
      bs = sc;
      best = k;
    }
  }
  return best;
}

void resolveHitVeh(Squad tg, Ammo a, double ax, double ay, int? srcSide, double d, [bool? zoneHint]) {
  if (tg.dead || tg.t.arm == null) return;
  final af = armourFace(tg, ax, ay, a);
  final pen = penAt(a, d) * rand(.93, 1.07);
  final big = a.k != 'SA' && (a.cal >= 57 || a.k == 'HEAT' || a.k == 'ATGM');
  tg.lastShot = S.t;
  tg.lastHit = S.t;
  final turret = zoneHint ?? ((tg.t.cls == 'tank' || tg.t.cls == 'ifv') && rnd() < .42);
  if (pen >= af.th) {
    penetrate(tg, a, turret, pen / af.th, big, srcSide);
    return;
  }
  tg.supp = math.min(100, tg.supp + (big ? 14 : 3));
  if (big && a.k != 'HE' && rnd() < (af.face == 's' ? .1 : .04) && tg.mob) {
    tg.mob = false;
    updateVehHp(tg);
    ev('${NM(tg)} потерял ход', tg.side == S.player ? 'warn' : 'good', tg.x, tg.y, evSide(tg));
  }
}

void penetrate(Squad tg, Ammo a, bool turret, double margin, bool big, int? srcSide) {
  double pk = a.k == 'SA' ? .06 : (big ? (a.k == 'HE' ? .22 : .42) : .13);
  if (margin > 1.6) pk += .15;
  final jobs = turret ? const ['commander', 'gunner', 'loader'] : const ['driver', 'loader'];
  for (final man in tg.crew) {
    if (man.ok && (jobs.contains(man.job) || (big && rnd() < .2)) && rnd() < pk) outMan(tg, man, srcSide);
  }
  if (tg.dead) return;
  if (big) {
    final vis = evSide(tg);
    if (rnd() < tg.t.vuln * (turret ? 1 : .65) * (a.k == 'HE' ? .3 : 1)) {
      destroySquad(tg, srcSide, 'ammo');
      boom(tg.x, tg.y, 60, 2);
      return;
    }
    if (tg.fireT == 0 && rnd() < .28) {
      tg.fireT = S.t + .001;
      tg.smoking = true;
      ev('${NM(tg)} горит', tg.side == S.player ? 'warn' : 'good', tg.x, tg.y, vis);
    }
    if (!turret && tg.mob && rnd() < .35) {
      tg.mob = false;
      ev('${NM(tg)} потерял ход', tg.side == S.player ? 'warn' : 'good', tg.x, tg.y, vis);
    }
    if (turret && !tg.gunOut && rnd() < .3) {
      tg.gunOut = true;
      ev('${NM(tg)}: орудие выведено из строя', tg.side == S.player ? 'warn' : 'good', tg.x, tg.y, vis);
    }
  }
  updateVehHp(tg);
}

/* ---------- взрывы ---------- */
void blastAt(double x, double y, double rad, double kill, int? srcSide, [Squad? onlySq]) {
  final list = S.squads.toList();
  for (final sq in list) {
    if (sq.dead || sq.carried != 0 || (onlySq != null && sq != onlySq)) continue;
    final dd = dist(sq.x, sq.y, x, y);
    if (dd > rad + 24) continue;
    if (sq.t.veh) continue;
    final cov = coverOf(sq) * .55;
    for (final man in sq.crew) {
      if (!man.ok) continue;
      final r = dist(sq.x + man.dx, sq.y + man.dy, x, y);
      if (r >= rad) continue;
      final p = kill * math.pow(1 - r / rad, 1.2) * (1 - cov);
      if (rnd() < p) outMan(sq, man, srcSide);
      if (sq.dead) break;
    }
  }
}

void suppressArea(double x, double y, double R, double amt, [double vehFactor = .3]) {
  for (final sq in S.squads) {
    if (sq.dead || sq.carried != 0) continue;
    final d = dist(sq.x, sq.y, x, y);
    if (d > R) continue;
    sq.supp = math.min(100, sq.supp + amt * (1 - d / R) * (sq.t.veh ? vehFactor : 1));
    sq.morale -= 2.5 * (1 - d / R) * (sq.t.veh ? .3 : 1);
    sq.lastShot = S.t;
    sq.lastHit = math.max(sq.lastHit, S.t - 2);
  }
}

void shellLand(double x, double y, int? srcSide, [String ammoId = 'he82']) {
  final a = AMMO[ammoId]!;
  boom(x, y, 34, 0);
  S.craterQ.add([x, y, rand(6, 10)]);
  blastAt(x, y, a.rad, a.kill, srcSide);
  final top = a.withTop();
  for (final sq in S.squads.toList()) {
    if (!sq.dead && sq.t.veh && dist(sq.x, sq.y, x, y) < 9 + sq.t.len * .3) resolveHitVeh(sq, top, x, y, srcSide, 0, false);
  }
  suppressArea(x, y, a.rad * 2.6, a.supp * 2.2);
}

/* ---------- прицеливание ---------- */
double minArm(Squad e) => math.min(e.t.arm!.s[0], e.t.arm!.r[0]);

void acquire(Squad sq) {
  final t = sq.t;
  if (t.mortar) {
    sq.tg = null;
    return;
  }
  final o = sq.order;
  if (o != null && o.kind == 'attack') {
    final e = S.byId[o.targetId];
    if (e != null && !e.dead && isSpotted(e, sq.side) && dist(sq.x, sq.y, e.x, e.y) <= t.range && los(sq.x, sq.y, e.x, e.y)) {
      sq.tg = e;
      return;
    }
  }
  Squad? best;
  double bs = -1e9;
  for (final e in S.squads) {
    if (e.dead || e.carried != 0 || e.side == sq.side || !isSpotted(e, sq.side)) continue;
    final d = dist(sq.x, sq.y, e.x, e.y);
    if (d > t.range) continue;
    double sc = -d;
    if (e.t.veh) {
      if (t.hasShot && d <= t.shotRange && t.atPen >= minArm(e)) {
        sc += 450;
      } else if (d <= t.sr && t.saPen >= minArm(e) * .6) {
        sc += 0;
      } else {
        continue;
      }
    } else {
      if (t.cls == 'at' && d > t.sr) continue;
      if (d > t.sr) continue;
      if (e.type == 'at' || e.type == 'mg') sc += 90;
      if (e.t.mortar) sc += 40;
    }
    if (sc <= bs) continue;
    if (!los(sq.x, sq.y, e.x, e.y)) continue;
    best = e;
    bs = sc;
  }
  sq.tg = best;
}

/* ---------- стрельба ---------- */
double operatorFactor(Squad sq, CrewM man, WI wi) {
  if (sq.t.veh) {
    if (wi.w.job == 'gunner' || wi.w.coax) {
      if (sq.gunOut && wi.w.job != 'commander') return 0;
    }
    if (man.ok) return 1;
    if (man.job == 'gunner' && sq.crew.any((m2) => m2.ok && m2.job == 'commander')) return .5;
    return 0;
  }
  return man.ok ? 1 : 0;
}

void fireControl(Squad sq, Squad tg, double d, double dt) {
  final eff = effOf(sq), t = sq.t, veh = t.veh, now = S.t;
  if (eff <= 0 || sq.stance == 'cease') return;
  if (sq.stance == 'ambush') {
    if (d > 110 && now - sq.lastHit > 3) return;
    sq.stance = 'free';
    ev('${sq.name}: засада сработала', sq.side == S.player ? 'info' : 'warn', sq.x, sq.y, evSide(sq));
  }
  if (sq.sneak && sq.moving && d > 90) return;
  final noLoader = (veh && t.cls == 'tank' && t.men.length > 3) ? !sq.crew.any((m2) => m2.ok && m2.job == 'loader') : false;
  bool fired = false;
  for (final man in sq.crew) {
    for (final wi in man.ws.toList()) {
      final w = wi.w;
      if (w.k == 'mortar') continue;
      if (d > w.rng || (w.minR > 0 && d < w.minR)) continue;
      if (veh && w.coax && tg.t.veh && !(tg.t.arm!.s[0] < 14)) continue; // пулемёт в спарке по броне не работает
      final op = operatorFactor(sq, man, wi);
      if (op <= 0) continue;
      if (now < wi.next) continue;
      if (sq.moving && const ['rocket', 'atgm', 'sniper', 'ugl'].contains(w.k)) continue;
      if (sq.moving && w.setup > 0) {
        wi.next = now + w.setup;
        continue;
      }
      if (sq.moving && w.k == 'cannon' && t.cls != 'tank') continue;
      final ak = bestAmmo(wi, tg, sq.x, sq.y, d);
      if (ak == null) continue;
      fireWeapon(sq, man, wi, ak, tg, d, eff * op, noLoader);
      fired = true;
    }
  }
  if (fired) sq.lastFire = now;
}

void fireWeapon(Squad sq, CrewM man, WI wi, String ak, Squad tg, double d, double eff, bool noLoader) {
  final w = wi.w, a = AMMO[ak]!, now = S.t, t = sq.t, tv = tg.t.veh;
  final sx = sq.x + man.dx, sy = sq.y + man.dy;
  final rangeF = 1 - math.pow(math.min(1, d / w.rng), 1.4) * .6;
  final diff = (sq.side == S.aiSide || S.autoplay) ? S.diff.acc : 1.0;
  final suppF = 1 - sq.supp / 100 * (t.veh ? .3 : .7);
  final mvF = sq.moving ? (t.moveFire * ((w.k == 'mg' || w.k == 'hmg') ? .5 : 1)) : 1.0;
  final cov = tv ? coverOf(tg) : coverOf(tg) * (1 - ((a.k == 'AP' && w.k == 'sniper') ? .55 : 0));
  final covF = 1 - cov * .65, shotRate = w.rpm / 60;
  final base = w.acc * rangeF * suppF * mvF * diff * (w.k == 'atgm' ? 1 : covF) * ((tg.moving && (w.k == 'rocket' || w.k == 'cannon')) ? .8 : 1);
  if (w.k == 'cannon' || w.k == 'rocket' || w.k == 'atgm' || w.k == 'ugl') {
    // одиночный выстрел с временем полёта
    final interval = (w.rl * ((noLoader && w.loader) ? 1.8 : 1)) / math.max(.4, eff);
    final fl = .25 + d / (a.spd > 0 ? a.spd : 400);
    wi.am[ak] = wi.am[ak]! - 1;
    wi.next = now + interval;
    S.pend.add(Pending('shot', now + fl, ak, from: sq.id, to: tg.id, hit: rnd() < base, ax: sx, ay: sy, x1: tg.x, y1: tg.y, t0: now, d: d));
    sq.ammo = ammoPct(sq);
    HOOK.onSfx?.call('shot', sx, sy, 1.25);
    if (w.k != 'ugl') boom(sx + math.cos(sq.fa) * 10, sy + math.sin(sq.fa) * 10, 6, 1);
    return;
  }
  // очередь или одиночные выстрелы: считаем пачками за ~0,3 с
  int n = a.burst ? 4 : ((w.k == 'mg' || w.k == 'hmg') ? 4 : (w.k == 'sniper' ? 1 : (w.k == 'acan' ? 4 : 1)));
  n = math.min(n, wi.am[ak]!);
  if (n <= 0) return;
  wi.am[ak] = wi.am[ak]! - n;
  wi.next = now + n / (shotRate * math.max(.4, eff));
  wi.burst++;
  if (w.k != 'sniper' && (wi.burst % math.max(2, (w.mag / n).round())) == 0 && w.k != 'acan') wi.next += w.rl * .35;
  int hits = 0;
  for (int i = 0; i < n; i++) {
    if (rnd() < base) hits++;
  }
  final near = (1 - math.min(1, d / w.rng) * .6) * .9 + .1;
  tg.supp = math.min(100, tg.supp + (a.supp > 0 ? a.supp : .4) * n * near * SUPP_K * (tv ? .12 : 1) * (hits > 0 ? 1 : .7) * eff * .5);
  tg.lastShot = now;
  for (int i = 0; i < hits; i++) {
    if (tg.dead) break;
    if (tv) {
      if (a.k == 'SA') {
        if (penAt(a, d) * rand(.9, 1.1) >= armourFace(tg, sx, sy, a).th) resolveHitVeh(tg, a, sx, sy, sq.side, d, false);
      } else {
        resolveHitVeh(tg, a, sx, sy, sq.side, d);
      }
    } else if (a.k == 'HE') {
      blastAt(tg.x + rand(-4, 4), tg.y + rand(-4, 4), a.rad, a.kill, sq.side, tg);
    } else if (rnd() < a.kill) {
      casualty(tg, sq.side);
    }
  }
  sq.fxT -= .25;
  if (sq.fxT <= 0) {
    sq.fxT = rand(.12, .3);
    final sp = d * .04;
    addTracer(sx, sy, tg.x + rand(-sp, sp), tg.y + rand(-sp, sp), sq.side);
    HOOK.onSfx?.call('shot', sx, sy, w.k == 'rifle' ? .55 : 1);
  }
  if (!(now - sq.lastAmmoCalc < 1)) {
    sq.lastAmmoCalc = now;
    sq.ammo = ammoPct(sq);
  }
}

void processPending() {
  for (int i = S.pend.length - 1; i >= 0; i--) {
    final p = S.pend[i];
    if (S.t < p.at) continue;
    S.pend.removeAt(i);
    final from = S.byId[p.from];
    final fs = from?.side;
    if (p.kind == 'shell') {
      shellLand(p.x1, p.y1, fs, p.am);
    } else if (p.kind == 'shot') {
      final a = AMMO[p.am]!, tg = S.byId[p.to];
      if (tg == null || tg.dead) {
        boom(p.x1, p.y1, a.k == 'HE' ? 18 : 12, 1);
        if (a.k == 'HE') blastAt(p.x1, p.y1, a.rad, a.kill, fs);
        continue;
      }
      if (p.hit) {
        boom(tg.x, tg.y, a.k == 'HE' ? 26 : 20, 0);
        if (tg.t.veh) {
          resolveHitVeh(tg, a, p.ax, p.ay, fs, p.d);
          if (a.k == 'HE') suppressArea(tg.x, tg.y, a.rad * 2, a.supp);
        } else {
          blastAt(tg.x, tg.y, a.rad > 0 ? a.rad : 3, a.kill > 0 ? a.kill : .5, fs, tg);
          if (a.k != 'HE' && rnd() < .5) casualty(tg, fs);
          tg.supp = math.min(100, tg.supp + 35);
        }
      } else {
        final ox = tg.x + rand(-34, 34), oy = tg.y + rand(-34, 34);
        boom(ox, oy, a.k == 'HE' ? 22 : 14, 1);
        if (a.k == 'HE') {
          blastAt(ox, oy, a.rad, a.kill, fs);
          suppressArea(ox, oy, a.rad * 2.4, a.supp);
        } else {
          tg.supp = math.min(100, tg.supp + 22);
        }
      }
      tg.lastShot = S.t;
    }
  }
}

/* ---------- миномёт ---------- */
void mortarStep(Squad sq, double dt) {
  final o = sq.order;
  if (o == null || o.kind != 'fire') return;
  WI? wi;
  for (final m2 in sq.crew) {
    if (!m2.ok) continue;
    for (final x in m2.ws) {
      if (x.w.k == 'mortar') {
        wi = x;
        break;
      }
    }
    if (wi != null) break;
  }
  if (wi == null) {
    sq.order = null;
    return;
  }
  final d = dist(sq.x, sq.y, o.x, o.y);
  if (d > wi.w.rng || d < wi.w.minR) {
    sq.order = null;
    ev('${sq.name}: цель вне досягаемости', 'warn', sq.x, sq.y, sq.side);
    return;
  }
  final he = wi.am['he82'] ?? 0;
  if (he < 3) {
    sq.order = null;
    ev('${sq.name}: нет мин', 'warn', sq.x, sq.y, sq.side);
    return;
  }
  sq.fa = math.atan2(o.y - sq.y, o.x - sq.x);
  o.deploy += dt;
  if (o.deploy < 3) return;
  o.next -= dt;
  if (o.next > 0) return;
  o.next = 7;
  final blind = !S.squads.any((e) => !e.dead && e.side != sq.side && isSpotted(e, sq.side) && dist(e.x, e.y, o.x, o.y) < 130);
  final sigma = (22 + d * .03) * (blind ? 2.2 : 1);
  for (int i = 0; i < 3; i++) {
    final a = rnd() * TAU, r = (rnd() + rnd() + rnd() - 1.5).abs() * sigma * 1.6;
    S.pend.add(Pending('shell', S.t + 2.2 + d / 700 + i * .6, 'he82', from: sq.id, x1: o.x + math.cos(a) * r, y1: o.y + math.sin(a) * r));
  }
  wi.am['he82'] = he - 3;
  sq.ammo = ammoPct(sq);
  sq.lastFire = S.t;
  HOOK.onSfx?.call('shot', sq.x, sq.y, 1.5);
  boom(sq.x, sq.y, 8, 1);
  if (--o.salvos <= 0) sq.order = null;
}

/* ---------- пожар на технике ---------- */
void vehicleFire(Squad sq) {
  if (sq.fireT == 0 || sq.dead) return;
  final age = S.t - sq.fireT;
  if (age > 9 + (sq.id % 5)) {
    // экипаж покидает горящую машину
    destroySquad(sq, null, 'fire');
    boom(sq.x, sq.y, 44, 2);
  }
}

/* ---------- сводка вооружения для карточки отряда ---------- */
class LoadoutEntry {
  final String n, k;
  int c = 0, r = 0;
  final Map<String, int> ammo = {};
  LoadoutEntry(this.n, this.k);
}

List<LoadoutEntry> loadoutOf(Squad sq) {
  final map = <String, LoadoutEntry>{};
  for (final man in sq.crew) {
    if (!man.ok && !sq.t.veh) continue;
    for (final wi in man.ws) {
      int r = 0;
      for (final v in wi.am.values) {
        r += v;
      }
      final e = map.putIfAbsent(wi.w.n, () => LoadoutEntry(wi.w.n, wi.w.k));
      e.c++;
      e.r += r;
      wi.am.forEach((k, v) => e.ammo[k] = (e.ammo[k] ?? 0) + v);
    }
  }
  return map.values.toList();
}

/* ---------- посадка и высадка ---------- */
void boardVeh(Squad inf, Squad v) {
  if (v.cargo != 0 || inf.carried != 0) return;
  v.cargo = inf.id;
  inf.carried = v.id;
  inf.order = null;
  inf.path = null;
  inf.tg = null;
  S.sel.remove(inf.id);
  ev('${inf.name} села на ${NM(v)}', 'info', v.x, v.y, inf.side);
}

bool dismountVeh(Squad v) {
  final inf = S.byId[v.cargo];
  if (inf == null || inf.dead) {
    v.cargo = 0;
    return false;
  }
  inf.carried = 0;
  v.cargo = 0;
  final a = v.fa + math.pi;
  inf.x = v.x + math.cos(a) * 22;
  inf.y = v.y + math.sin(a) * 22;
  inf.fa = v.fa;
  inf.order = null;
  inf.path = null;
  inf.supp = math.max(inf.supp, 12);
  if (T_MV_I[ter[cellIdx(inf.x, inf.y)]] == 0) {
    inf.x = v.x;
    inf.y = v.y;
  }
  ev('${inf.name} высадилась из ${NM(v)}', 'info', v.x, v.y, inf.side);
  return true;
}

void setStance(List<Squad> sqs, String st) {
  for (final q in sqs) {
    if (q.dead || q.t.mortar) continue;
    q.stance = st;
    if (st == 'ambush') {
      q.order = Order('hold');
      q.path = null;
      q.fort = math.max(q.fort, .3);
    }
  }
}

/* ---------- артиллерийская поддержка ---------- */
String? useArty(int side, double x, double y) {
  if (!canUse(side, 'arty')) return 'Артиллерия ещё не готова';
  if (side == S.player && S.fog[cellIdx(x, y)] == 0) return 'Нет данных о районе: сначала разведайте его';
  final obs = S.squads.any((e) => !e.dead && e.side != side && e.carried == 0 && isSpotted(e, side) && dist(e.x, e.y, x, y) < 160);
  final a = S.ab[side]['arty']!;
  a.ch--;
  a.cd = AB_CD['arty']!;
  final sg = obs ? 34.0 : 70.0;
  for (int i = 0; i < 6; i++) {
    final ang = rnd() * TAU, r = (rnd() + rnd() + rnd() - 1.5).abs() * sg * 1.5;
    S.pend.add(Pending('shell', S.t + 9 + i * .55, 'he152', x1: x + math.cos(ang) * r, y1: y + math.sin(ang) * r));
  }
  ev('Артиллерия: огонь на поражение, подлётное время 9 с', 'info', x, y, side);
  HOOK.onSfx?.call('shot', BASE[side][0], BASE[side][1], 1);
  return null;
}
