// ИИ противника (перенос 04_ai.js).
import 'dart:math' as math;

import 'battle.dart';
import 'combat.dart';
import 'core.dart';
import 'data.dart';

const List<Map<String, double>> AI_MIX = [
  {'rifle': .30, 'mg': .10, 'at': .12, 'sniper': .06, 'mortar': .07, 'ifv': .20, 'tank': .15}, // наступающие
  {'rifle': .30, 'mg': .15, 'at': .20, 'sniper': .08, 'mortar': .10, 'ifv': .12, 'tank': .05} // обороняющиеся
];

void aiTick() {
  final sides = S.autoplay ? [0, 1] : [S.aiSide];
  for (final s in sides) {
    aiThink(s);
  }
}

void aiThink(int s) {
  final atk = s == S.atk;
  final mine = S.squads.where((q) => !q.dead && q.side == s && !q.rout && q.carried == 0).toList();
  aiBuy(s);
  aiAbilities(s, atk, mine);
  // цель наступающих: первая цель, не находящаяся под их контролем
  ObjState? goal;
  if (atk) {
    for (final o in S.objs) {
      if (o.owner != s) {
        goal = o;
        break;
      }
    }
    goal ??= S.objs[1];
  }
  final inf = mine.where((q) => !q.t.veh && q.role == 'assault' && q.wave != 'gather').toList();
  final xs = inf.map((q) => q.x).toList()..sort();
  final double? infX = xs.isNotEmpty ? xs[(xs.length * .7).floor()] : null;
  // волны подкрепления: сбор у рубежа развёртывания, затем общий бросок
  const asmX = 880.0, asmY = 740.0;
  final gath = mine.where((q) => q.wave == 'gather').toList();
  if (atk) {
    for (final q in mine) {
      if (q.wave == null && q.role == 'assault' && S.t - q.born > 1 && q.mountTo == 0) {
        if (S.t > 20 && dist(q.x, q.y, asmX, asmY) > 260) {
          q.wave = 'gather';
          issue([q], 'move', asmX + rand(-60, 60), asmY + rand(-80, 80));
        } else {
          q.wave = 'go';
        }
      }
    }
    final there = gath.where((q) => dist(q.x, q.y, asmX, asmY) < 200).toList();
    final old = gath.any((q) => S.t - q.born > 70);
    if (there.length >= 4 || (old && there.length >= 2)) {
      for (final q in gath) {
        q.wave = 'go';
        q.order = null;
      }
    }
  }
  if (atk && S.t < 8 && !S.mountDone) {
    // наступающие едут на броне: пехота садится в БМП/БТР
    S.mountDone = true;
    final carriers = mine.where((q) => q.t.cap > 0 && q.cargo == 0).toList();
    final troops = mine.where((q) => !q.t.veh && q.type == 'rifle' && q.role == 'assault').toList();
    for (final v in carriers) {
      Squad? best;
      double bd = 1e9;
      for (final tp in troops) {
        if (tp.mountTo != 0 || tp.men > v.t.cap) continue;
        final d = dist(tp.x, tp.y, v.x, v.y);
        if (d < bd) {
          bd = d;
          best = tp;
        }
      }
      if (best != null) {
        best.mountTo = v.id;
        issue([best], 'mount', v.x, v.y, v.id);
      }
    }
  }
  if (goal != null) {
    for (final v in S.squads.toList()) {
      if (!v.dead && v.side == s && v.cargo != 0) {
        if (dist(v.x, v.y, goal.x, goal.y) < goal.r + 260 || v.supp > 40 || v.hp < 55) dismountVeh(v);
      }
    }
  }
  for (final q in mine) {
    if (q.cargo != 0 && goal != null) {
      final o = q.order;
      if (o == null || o.kind != 'fight' || S.t - q.orderT > 25) {
        final dx = goal.x - q.x, dy = goal.y - q.y, d = math.sqrt(dx * dx + dy * dy), k = math.max(0, d - 200) / (d == 0 ? 1 : d);
        issue([q], 'fight', q.x + dx * k, q.y + dy * k);
      }
      continue;
    }
    if (q.t.mortar) {
      if (atk && q.post == null && S.t > 15) {
        q.post = Pt(760, 700 + rand(-40, 40));
        issue([q], 'move', q.post!.x, q.post!.y);
      }
      aiMortar(q, s);
      continue;
    }
    if (q.wave == 'gather') continue;
    final o = q.order;
    if (atk) {
      if (S.t < 6) continue;
      if (q.type == 'sniper') {
        if (q.post == null) {
          q.post = Pt(960 + rand(-30, 30), 610 + rand(-30, 30));
          issue([q], 'move', q.post!.x, q.post!.y);
        } else if (o == null) {
          issue([q], 'hold', 0, 0);
        }
        continue;
      }
      if (q.role == 'escort') {
        if (infX != null && q.x > infX + 90 && goal != null) {
          if (o == null || o.kind != 'hold') issue([q], 'hold', 0, 0);
          continue;
        }
        if (o != null && o.kind == 'fight' && S.t - q.orderT < 25) continue;
        if (goal != null) {
          final dx = goal.x - q.x, dy = goal.y - q.y, d = math.sqrt(dx * dx + dy * dy), k = math.max(0, d - 230) / (d == 0 ? 1 : d);
          issue([q], 'fight', q.x + dx * k, q.y + dy * k);
        }
        continue;
      }
      if (o == null || (o.kind == 'fight' && S.t - q.orderT > 25) || (o.kind == 'hold' && q.role == 'assault')) {
        if (goal != null) {
          final a = rnd() * TAU, r = rnd() * goal.r * .6;
          issue([q], 'fight', goal.x + math.cos(a) * r, goal.y + math.sin(a) * r);
        }
      }
    } else {
      if (q.role == 'counter') {
        if (o != null && o.kind == 'fight' && S.t - q.orderT < 20) continue;
        if (o != null && o.kind == 'hold' && S.t - q.orderT < 40) continue;
        // самый напряжённый рубеж: где больше противника, иначе ключевой с наименьшим числом своих
        ObjState? best;
        double bs = -1e9;
        for (final ob in S.objs) {
          final sc = ob.w[S.atk] * 3 - ob.w[s] + (ob.owner != s ? 2 : 0) + (ob.key ? 1 : 0);
          if (sc > bs) {
            bs = sc;
            best = ob;
          }
        }
        if (best != null) {
          final a = rnd() * TAU, r = rnd() * best.r * .7;
          final x = best.x + math.cos(a) * r, y = best.y + math.sin(a) * r;
          if (best.owner != s || best.contested) {
            issue([q], 'fight', x, y);
          } else {
            issue([q], 'move', x, y);
            q.post = Pt(x, y);
          }
        }
      } else if (q.post != null) {
        if (o == null) {
          if (dist(q.x, q.y, q.post!.x, q.post!.y) > 30) {
            issue([q], 'move', q.post!.x, q.post!.y);
          } else {
            issue([q], 'hold', 0, 0);
          }
        }
      }
    }
  }
}

void aiBuy(int s) {
  if (S.queue.where((q) => q.side == s).length >= 3) return;
  final mix = AI_MIX[s == S.atk ? 0 : 1];
  final all = variantsFor(s);
  final vs = all.where((v) => v.cost <= S.pts[s]).toList();
  if (vs.isEmpty) return;
  if (S.pts[s] < 140 && rnd() < .5) return;
  double wt(Variant v) => mix[v.cls]! / all.where((x) => x.cls == v.cls).length;
  double tot = 0;
  for (final v in vs) {
    tot += wt(v);
  }
  double r = rnd() * tot;
  Variant pick = vs[0];
  for (final v in vs) {
    r -= wt(v);
    if (r <= 0) {
      pick = v;
      break;
    }
  }
  buyUnit(s, pick.id);
}

void aiMortar(Squad q, int s) {
  if (q.order != null && q.order!.kind == 'fire') return;
  if (q.ammo < 8 || S.t - q.orderT < 10) return;
  Squad? best;
  double bs = 0;
  for (final e in S.squads) {
    if (e.dead || e.side == s || !isSpotted(e, s)) continue;
    final d = dist(q.x, q.y, e.x, e.y);
    if (d > q.t.range * .95 || d < q.t.minRange * 1.1) continue;
    if (S.squads.any((f) => !f.dead && f.side == s && dist(f.x, f.y, e.x, e.y) < 95)) continue;
    double sc = 1;
    for (final o in S.squads) {
      if (!o.dead && o.side == e.side && o != e && dist(o.x, o.y, e.x, e.y) < 80) sc += .6;
    }
    if (!e.t.veh) sc += 1;
    if (!e.moving) sc += .5;
    if (sc > bs) {
      bs = sc;
      best = e;
    }
  }
  if (best != null) issue([q], 'fire', best.x, best.y);
}

void aiAbilities(int s, bool atk, List<Squad> mine) {
  if (canUse(s, 'drone') && S.t > 20 && rnd() < .3) {
    double tx, ty;
    final foes = S.squads.where((e) => !e.dead && e.side != s && e.lk[s] != null && S.t - e.seenAt[s] < 40).toList();
    if (foes.isNotEmpty && rnd() < .5) {
      final f = foes[(rnd() * foes.length).toInt()];
      tx = f.lk[s]!.x;
      ty = f.lk[s]!.y;
    } else {
      ObjState o;
      if (atk) {
        o = S.objs.firstWhere((x) => x.owner != s, orElse: () => S.objs[1]);
      } else {
        o = S.objs[0];
      }
      tx = o.x + rand(-120, 120);
      ty = o.y + rand(-120, 120);
    }
    useDrone(s, tx, ty);
  }
  if (canUse(s, 'fpv') && rnd() < .45) {
    Squad? best;
    double bs = -1;
    for (final e in S.squads) {
      if (e.dead || e.side == s || !isSpotted(e, s)) continue;
      final sc = (e.t.veh ? 3 : 0) + (e.t.hasShot ? 1.5 : 0) + (e.type == 'mg' ? 1 : 0) + rnd();
      if (sc > bs) {
        bs = sc;
        best = e;
      }
    }
    if (best != null) useFpv(s, best.id);
  }
  if (canUse(s, 'arty') && S.t > 40 && rnd() < .2) {
    Squad? best;
    double bs = 0;
    for (final e in S.squads) {
      if (e.dead || e.carried != 0 || e.side == s || !isSpotted(e, s)) continue;
      if (S.squads.any((f) => !f.dead && f.side == s && dist(f.x, f.y, e.x, e.y) < 120)) continue;
      double sc = 1;
      for (final o in S.squads) {
        if (!o.dead && o.side == e.side && o != e && dist(o.x, o.y, e.x, e.y) < 90) sc += 1;
      }
      if (!e.t.veh) sc += .5;
      if (sc > bs) {
        bs = sc;
        best = e;
      }
    }
    if (best != null && bs >= 2.5) useArty(s, best.x, best.y);
  }
  if (atk && canUse(s, 'smoke') && rnd() < .12) {
    final near = mine.any((q) => !q.t.veh && dist(q.x, q.y, 1150, 740) < 220);
    if (near && S.squads.any((e) => !e.dead && e.side != s && isSpotted(e, s))) useSmoke(s, 1230, 740);
  }
}
