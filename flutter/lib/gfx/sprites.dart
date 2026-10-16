// Процедурные спрайты техники и бойцов (перенос 05b_sprites.js).
// Корпус и башня — отдельные картинки: башня вращается независимо.
import 'dart:async';
import 'dart:ui' as ui;

import '../game/core.dart';
import '../game/data.dart';
import 'ctx2d.dart';

const double SPS = 7; // пикселей спрайта на единицу мира

class Pal {
  ui.Color base, lt, dk, tan, mk;
  Pal(String b, String l, String d, String t, String m)
      : base = css(b),
        lt = css(l),
        dk = css(d),
        tan = css(t),
        mk = css(m);
}

Pal spPal(Variant v, int side) {
  final p = side == 0
      ? Pal('#57623f', '#6e7a52', '#3a432b', '#8d8458', '#2c3321')
      : Pal('#505e3b', '#687652', '#34402a', '#74633f', '#2a3220');
  void set(String b, String l, String d, String t) {
    p.base = css(b);
    p.lt = css(l);
    p.dk = css(d);
    p.tan = css(t);
  }

  if (v.id == 'tank_abrams') set('#9a8c62', '#b0a376', '#6c6143', '#7d7048');
  if (v.id == 'tank_leo2') set('#4b5940', '#627252', '#2f3a29', '#6b6a45');
  if (v.id == 'bradley') {
    p.base = css('#58634a');
    p.lt = css('#707c5c');
    p.dk = css('#38412d');
  }
  return p;
}

class _Rec {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  late final Ctx2D g;
  final int w, h;
  _Rec(double wu, double hu, double px)
      : w = (wu * px).ceil(),
        h = (hu * px).ceil() {
    g = Ctx2D(ui.Canvas(rec));
    g.scale(px);
    g.translate(wu / 2, hu / 2);
  }
  Future<ui.Image> done() async {
    final p = rec.endRecording();
    final im = await p.toImage(w, h);
    p.dispose();
    return im;
  }
}

void rrp(Ctx2D g, double x, double y, double w, double h, double r) {
  g.beginPath();
  g.roundRect(x, y, w, h, r);
}

void spPoly(Ctx2D g, List<List<double>> pts) {
  g.beginPath();
  for (int i = 0; i < pts.length; i++) {
    if (i == 0) {
      g.moveTo(pts[i][0], pts[i][1]);
    } else {
      g.lineTo(pts[i][0], pts[i][1]);
    }
  }
  g.closePath();
}

void spCamo(Ctx2D g, Pal P, int seed, double ext) {
  final r = mulberry32(seed);
  g.save();
  g.clip();
  g.alpha = .55;
  for (int i = 0; i < 26; i++) {
    g.fill = r() < .55 ? P.dk : P.tan;
    g.beginPath();
    g.ellipse((r() - .5) * ext, (r() - .5) * ext * .5, 1.2 + r() * 3, .8 + r() * 1.6, r() * 3);
    g.doFill();
  }
  g.alpha = 1;
  g.restore();
}

void spEra(Ctx2D g, double x0, double x1, double y0, double y1, double step, double sz) {
  g.fillStyle = 'rgba(22,26,18,.62)';
  g.strokeStyle = 'rgba(0,0,0,.5)';
  g.lineWidth = .06;
  for (double x = x0; x < x1; x += step) {
    for (double y = y0; y <= y1; y += step) {
      g.fillRect(x, y, sz, sz);
      g.strokeRect(x, y, sz, sz);
    }
  }
}

void spBarrel(Ctx2D g, double x0, double len, double wd, ui.Color col, {bool sleeve = false, bool ext = false, ui.Color? sleeveCol}) {
  g.fillStyle = col;
  g.fillRect(x0, -wd / 2, len - x0, wd);
  if (sleeve) {
    g.fillStyle = sleeveCol ?? col;
    g.fillRect(x0 + (len - x0) * .22, -wd * .85, (len - x0) * .5, wd * 1.7);
  }
  if (ext) {
    g.fillStyle = col;
    g.fillRect(x0 + (len - x0) * .62, -wd * .85, (len - x0) * .1, wd * 1.7);
  }
  g.fillStyle = '#15171a';
  g.fillRect(len - .7, -wd * .75, .7, wd * 1.5);
  g.fillStyle = 'rgba(255,255,255,.18)';
  g.fillRect(x0, -wd / 2, len - x0, wd * .25);
}

/* ---------- корпус ---------- */
Future<ui.Image> spHull(Variant v, int side) async {
  final L = v.len, Wd = v.wid, id = v.id, wh = v.wheeled, tank = v.cls == 'tank', P = spPal(v, side);
  final rc = _Rec(L + 3, Wd + 3, SPS), g = rc.g;
  final hw = Wd / 2 - (wh ? .3 : Wd * .11);
  final trk = Wd * (tank ? .21 : .23);
  if (wh) {
    for (final a in [-.36, -.13, .13, .36]) {
      for (final s in [-1, 1]) {
        final y = s < 0 ? -Wd / 2 - .1 : Wd / 2 - 1.5 + .1;
        g.fillStyle = '#121416';
        rrp(g, L * a - 1.2, y, 2.4, 1.6, .6);
        g.doFill();
        g.fillStyle = '#25292c';
        rrp(g, L * a - .8, y + .25, 1.6, 1.1, .4);
        g.doFill();
      }
    }
  } else {
    for (final s in [-1, 1]) {
      final y0 = s < 0 ? -Wd / 2 : Wd / 2 - trk;
      g.fillStyle = '#1b1e21';
      rrp(g, -L / 2, y0, L, trk, trk * .45);
      g.doFill();
      g.strokeStyle = '#363b40';
      g.lineWidth = .11;
      for (double x = -L / 2 + .7; x < L / 2 - .5; x += .75) {
        g.line(x, y0 + .12, x, y0 + trk - .12);
      }
      g.fillStyle = '#2b3034';
      for (int i = 0; i < 6; i++) {
        g.beginPath();
        g.arc(-L / 2 + L * (.12 + .152 * i), y0 + trk / 2, trk * .3, 0, TAU);
        g.doFill();
      }
    }
  }
  // корпус
  final List<List<double>> nose = wh
      ? [[-L / 2 + .3, -hw], [L * .12, -hw], [L / 2 - .2, -hw * .68], [L / 2 - .2, hw * .68], [L * .12, hw], [-L / 2 + .3, hw]]
      : [[-L / 2 + .5, -hw], [L * .27, -hw], [L / 2 - .3, -hw * .6], [L / 2 - .3, hw * .6], [L * .27, hw], [-L / 2 + .5, hw]];
  spPoly(g, nose);
  g.fill = P.base;
  g.doFill();
  spCamo(g, P, id.length * 977 + side * 31, L);
  spPoly(g, nose);
  g.stroke = P.mk;
  g.lineWidth = .16;
  g.doStroke();
  // глацис, моторное отделение
  g.linearGradient(L * .27, 0, L / 2, 0, [rgba(255, 255, 255, 0), rgba(255, 255, 255, .16)], [0, 1]);
  spPoly(g, nose);
  g.doFill();
  g.fillShader = null;
  g.strokeStyle = 'rgba(0,0,0,.3)';
  g.lineWidth = .1;
  for (double x = -L / 2 + 1; x < -L * .1; x += .55) {
    g.line(x, -hw * .7, x, hw * .7);
  }
  g.fillStyle = 'rgba(0,0,0,.14)';
  g.fillRect(-L / 2 + .9, -hw * .72, L * .36, hw * 1.44);
  g.strokeStyle = 'rgba(0,0,0,.35)';
  g.lineWidth = .1;
  g.strokeRect(-L / 2 + .9, -hw * .72, L * .36, hw * 1.44);
  // динамическая защита и обвес
  if (const ['tank_t64bv', 'tank_t72b3', 'tank_t80bvm', 'tank_t90m'].contains(id)) spEra(g, L * .3, L / 2 - .9, -hw * .78, hw * .55, .85, .62);
  if (id == 'tank_t72b3' || id == 'tank_t64bv' || id == 'tank_t90m') {
    g.fillStyle = '#3d4a33';
    for (final dy in [hw * .38, hw * .72]) {
      rrp(g, -L / 2 + .7, dy - .45, 2.4, .9, .4);
      g.doFill();
      g.strokeStyle = '#1d2418';
      g.lineWidth = .08;
      g.doStroke();
    }
  }
  if (tank) {
    if (id == 'tank_leo2' || id == 'tank_abrams' || id == 'tank_t90m') {
      for (final s in [-1, 1]) {
        g.fill = P.dk;
        g.alpha = .9;
        g.fillRect(-L * .38, s < 0 ? -Wd / 2 + .15 : Wd / 2 - trk * .95, L * .62, trk * .8);
        g.alpha = 1;
        g.strokeStyle = 'rgba(0,0,0,.45)';
        g.lineWidth = .09;
        for (double x = -L * .38; x < L * .24; x += 2.4) {
          g.line(x, s < 0 ? -Wd / 2 + .15 : Wd / 2 - trk * .95, x, s < 0 ? -Wd / 2 + .15 + trk * .8 : Wd / 2 - trk * .15);
        }
      }
    } else {
      for (final s in [-1, 1]) {
        g.fillStyle = '#262b27';
        g.fillRect(L * .12, s < 0 ? -Wd / 2 + .12 : Wd / 2 - trk * .9, L * .36, trk * .78);
      }
    }
    g.fill = P.dk;
    g.beginPath();
    g.arc(L * .31, id == 'tank_leo2' ? -hw * .45 : 0, Wd * .095, 0, TAU);
    g.doFill();
    g.strokeStyle = 'rgba(255,255,255,.25)';
    g.lineWidth = .08;
    g.doStroke();
  } else {
    g.fill = P.dk;
    for (final dx in [-L * .28, -L * .1]) {
      rrp(g, dx - .8, -hw * .5, 1.6, 1.2, .2);
      g.doFill();
      rrp(g, dx - .8, hw * .5 - 1.2, 1.6, 1.2, .2);
      g.doFill();
    }
    if (id == 'bradley') {
      g.strokeStyle = 'rgba(0,0,0,.4)';
      g.lineWidth = .1;
      for (final s in [-1, 1]) {
        for (double x = -L * .35; x < L * .25; x += 2.2) {
          g.strokeRect(x, s < 0 ? -hw : hw - 1.4, 2, 1.4);
        }
      }
    }
  }
  // фары
  g.fillStyle = '#d9d4a4';
  for (final s in [-1, 1]) {
    g.beginPath();
    g.arc(L / 2 - .7, s * hw * .52, .26, 0, TAU);
    g.doFill();
  }
  // опознавательный знак стороны на корме
  g.fill = ui.Color(SIDES[side].color);
  g.alpha = .9;
  g.fillRect(-L / 2 + .7, -.45, .75, .9);
  g.alpha = 1;
  return rc.done();
}

class TurretSprite {
  final ui.Image img;
  final double w, h;
  TurretSprite(this.img, this.w, this.h);
}

/* ---------- башня (центр картинки = ось вращения) ---------- */
Future<TurretSprite> spTurret(Variant v, int side) async {
  final L = v.len, Wd = v.wid, id = v.id, P = spPal(v, side), tank = v.cls == 'tank';
  final gunL = tank ? L * .78 : (id == 'bmp3' ? L * .5 : L * .55), ext = gunL + 1.2;
  final rc = _Rec(ext * 2, Wd + 2, SPS), g = rc.g;
  final G = css('#2a2d30');
  if (id == 'tank_leo2' || id == 'tank_abrams') {
    final tl = L * .36, tw = Wd * .7, A = id == 'tank_abrams';
    final raw = A
        ? [[-.7, -.36], [-.2, -.43], [.28, -.5], [.55, -.22], [.55, .22], [.28, .5], [-.2, .43], [-.7, .36]]
        : [[-.55, -.42], [0, -.5], [.34, -.46], [.5, -.2], [.5, .2], [.34, .46], [0, .5], [-.55, .42]];
    final pts = raw.map((p) => [p[0] * tl, p[1] * tw]).toList();
    spBarrel(g, tl * .45, gunL, .5, G, sleeve: A, ext: !A, sleeveCol: css('#3a3e41'));
    spPoly(g, pts);
    g.fill = P.base;
    g.doFill();
    spCamo(g, P, 5 + id.length, tl);
    spPoly(g, pts);
    g.stroke = P.mk;
    g.lineWidth = .16;
    g.doStroke();
    g.fillStyle = 'rgba(255,255,255,.12)';
    g.fillRect(tl * .1, -tw * .45, tl * .3, tw * .9);
    g.fill = P.dk;
    rrp(g, tl * .38, -tw * .13, tl * .22, tw * .26, .3);
    g.doFill();
    g.fill = P.dk;
    g.beginPath();
    g.arc(-tl * .1, tw * .22, Wd * .09, 0, TAU);
    g.doFill();
    g.strokeStyle = 'rgba(255,255,255,.3)';
    g.lineWidth = .08;
    g.doStroke();
    g.fill = P.dk;
    rrp(g, -tl * .28, -tw * .3, 1.5, 1.3, .2);
    g.doFill();
    g.fillStyle = '#151719';
    g.fillRect(tl * .05, tw * .3, .9, .45);
    if (A) {
      g.strokeStyle = '#2a2d30';
      g.lineWidth = .18;
      g.line(-tl * .15, -tw * .1, tl * .05, -tw * .1);
    }
  } else if (tank) {
    final tl = L * .36, tw = Wd * .66;
    spBarrel(g, tl * .4, gunL, .5, G, ext: true);
    g.beginPath();
    g.ellipse(0, 0, tl * .55, tw / 2);
    g.fill = P.base;
    g.doFill();
    spCamo(g, P, 11 + id.length, tl);
    g.beginPath();
    g.ellipse(0, 0, tl * .55, tw / 2);
    g.stroke = P.mk;
    g.lineWidth = .16;
    g.doStroke();
    g.fillStyle = 'rgba(255,255,255,.12)';
    g.beginPath();
    g.ellipse(tl * .12, 0, tl * .3, tw * .32);
    g.doFill();
    g.fill = P.dk;
    rrp(g, tl * .38, -tw * .14, tl * .2, tw * .28, .3);
    g.doFill();
    for (final s in [-1, 1]) {
      g.save();
      g.translate(tl * .3, s * tw * .27);
      g.rotate(s * .55);
      if (id == 'tank_t90m') {
        g.fillStyle = 'rgba(24,28,20,.7)';
        g.fillRect(-tl * .2, -tw * .1, tl * .4, tw * .2);
        g.strokeStyle = 'rgba(0,0,0,.55)';
        g.lineWidth = .08;
        g.strokeRect(-tl * .2, -tw * .1, tl * .4, tw * .2);
        for (double k = -.12; k < .2; k += .12) {
          g.line(tl * k, -tw * .1, tl * k, tw * .1);
        }
      } else {
        spEra(g, -tl * .18, tl * .2, id == 'tank_t64bv' ? -tw * .08 : -tw * .1, id == 'tank_t64bv' ? tw * .08 : tw * .1, .8, .55);
      }
      g.restore();
    }
    g.fill = P.dk;
    g.beginPath();
    g.arc(-tl * .1, tw * .22, Wd * .085, 0, TAU);
    g.doFill();
    g.strokeStyle = 'rgba(255,255,255,.3)';
    g.lineWidth = .08;
    g.doStroke();
    g.fillStyle = '#1b1d1f';
    g.fillRect(tl * .12, -tw * .27, .8, .55);
    if (id == 'tank_t72b3' || id == 'tank_t80bvm') {
      g.fill = P.dk;
      rrp(g, -tl * .5, -tw * .12, 1.1, tw * .24, .3);
      g.doFill();
    }
  } else {
    final wide = id == 'bmp3', tl = L * (wide ? .32 : .27), tw = Wd * (wide ? .64 : .52);
    if (id == 'bradley') {
      spBarrel(g, tl * .3, gunL, .42, G, sleeve: true, sleeveCol: css('#33373a'));
      final pts = [[-.5, -.5], [.4, -.5], [.55, -.3], [.55, .3], [.4, .5], [-.5, .5]].map((p) => [p[0] * tl * 1.2, p[1] * tw]).toList();
      spPoly(g, pts);
      g.fill = P.base;
      g.doFill();
      spCamo(g, P, 91, tl);
      spPoly(g, pts);
      g.stroke = P.mk;
      g.lineWidth = .15;
      g.doStroke();
      g.fill = P.dk;
      rrp(g, -tl * .2, -tw * .95, tl * .55, tw * .42, .2);
      g.doFill();
      g.strokeStyle = '#1d2418';
      g.lineWidth = .08;
      g.doStroke();
      g.fillStyle = '#16181a';
      g.beginPath();
      g.arc(tl * .15, -tw * .74, .35, 0, TAU);
      g.doFill();
      g.fill = P.dk;
      g.beginPath();
      g.arc(-tl * .1, tw * .22, Wd * .08, 0, TAU);
      g.doFill();
    } else {
      if (wide) {
        spBarrel(g, tl * .3, gunL * .86, 1.0, G);
        g.save();
        g.translate(0, -tw * .36);
        spBarrel(g, tl * .3, gunL * 1.05, .34, G);
        g.restore();
      } else {
        spBarrel(g, tl * .3, gunL, id == 'btr82' ? .34 : .36, G);
      }
      g.beginPath();
      g.ellipse(0, 0, tl * .6, tw / 2);
      g.fill = P.base;
      g.doFill();
      spCamo(g, P, 55 + id.length, tl);
      g.beginPath();
      g.ellipse(0, 0, tl * .6, tw / 2);
      g.stroke = P.mk;
      g.lineWidth = .15;
      g.doStroke();
      g.fillStyle = 'rgba(255,255,255,.13)';
      g.beginPath();
      g.ellipse(tl * .12, 0, tl * .3, tw * .3);
      g.doFill();
      g.fill = P.dk;
      g.beginPath();
      g.arc(-tl * .1, tw * .18, Wd * .08, 0, TAU);
      g.doFill();
      g.strokeStyle = 'rgba(255,255,255,.28)';
      g.lineWidth = .08;
      g.doStroke();
      if (id == 'bmp2') {
        g.fillStyle = '#2a2d30';
        g.fillRect(-tl * .35, tw * .06, tl * .75, .5);
        g.fillRect(tl * .38, tw * .02, .9, .9);
      }
    }
  }
  final im = await rc.done();
  return TurretSprite(im, ext * 2, Wd + 2);
}

class VehSprite {
  final ui.Image hull;
  final TurretSprite tur;
  final double hw, hh, tx, ty;
  VehSprite(this.hull, this.tur, this.hw, this.hh, this.tx, this.ty);
}

/* ---------- боец ---------- */
String soldierKind(CrewKind cm) {
  if (cm.job == 'sniper') return 'sniper';
  final ids = cm.weaponIds;
  if (ids.any((i) => const ['rpg7', 'nlaw', 'javelin', 'kornet', 'm3'].contains(i))) return 'at';
  if (ids.any((i) => const ['pkm', 'nsv', 'm2', 'rpk74'].contains(i))) return 'mg';
  if (ids.contains('gp25')) return 'gren';
  return cm.job == 'leader' ? 'lead' : 'rifle';
}

/// Минимум данных о бойце, нужных для выбора спрайта.
class CrewKind {
  final String job;
  final List<String> weaponIds;
  CrewKind(this.job, this.weaponIds);
}

class SolSprite {
  final ui.Image img;
  final double X;
  SolSprite(this.img, this.X);
}

Future<SolSprite> soldierSprite(int side, String kind) async {
  const double P = 28, X = 2.9;
  final size = (X * 2 * P).ceil();
  final rec = ui.PictureRecorder();
  final g = Ctx2D(ui.Canvas(rec));
  g.scale(P);
  g.translate(X, X);
  final U = side == 0
      ? {'u': '#5e6b44', 'u2': '#78865c', 'u3': '#3f4a2e', 'h': '#4d5a3a', 'pk': '#49543a'}
      : {'u': '#566341', 'u2': '#6f7d55', 'u3': '#38432b', 'h': '#5b6744', 'pk': '#454f35'};
  const dark = '#1d2217', skin = '#c9a47e', gun = '#1f2226';
  g.cap = ui.StrokeCap.round;
  g.join = ui.StrokeJoin.round;
  // рюкзак
  g.fillStyle = U['pk']!;
  rrp(g, -1.05, -.55, .85, 1.1, .28);
  g.doFill();
  g.strokeStyle = dark;
  g.lineWidth = .08;
  g.doStroke();
  if (kind == 'at') {
    g.fillStyle = '#3a3f2f';
    for (final s in [-1, 1]) {
      rrp(g, -1.4, s * .28 - .17, 1.3, .34, .17);
      g.doFill();
    }
    g.fillStyle = '#2b2f24';
    for (final s in [-1, 1]) {
      g.beginPath();
      g.arc(-1.4, s * .28, .2, 0, TAU);
      g.doFill();
    }
  }
  if (kind == 'lead') {
    g.strokeStyle = '#222222';
    g.lineWidth = .06;
    g.line(-.9, .3, -1.9, 1.4);
  }
  if (kind == 'mg') {
    g.fillStyle = '#2d3326';
    rrp(g, -.2, -1.15, .8, .5, .1);
    g.doFill();
  }
  // корпус
  g.fillStyle = U['u']!;
  g.beginPath();
  g.ellipse(-.1, 0, .55, 1.0);
  g.doFill();
  g.strokeStyle = dark;
  g.lineWidth = .1;
  g.doStroke();
  g.alpha = .7;
  g.fillStyle = U['u2']!;
  g.beginPath();
  g.ellipse(-.15, -.3, .24, .32, .4);
  g.doFill();
  g.fillStyle = U['u3']!;
  g.beginPath();
  g.ellipse(-.1, .38, .22, .3, -.3);
  g.doFill();
  g.alpha = 1;
  // руки
  g.strokeStyle = U['u']!;
  g.lineWidth = .42;
  g.beginPath();
  g.moveTo(.0, -.82);
  g.lineTo(.95, kind == 'at' ? -.12 : -.22);
  g.moveTo(.0, .82);
  g.lineTo(.7, kind == 'at' ? .4 : .26);
  g.doStroke();
  // оружие
  g.fillStyle = gun;
  if (kind == 'rifle' || kind == 'lead') {
    rrp(g, .15, -.11, 2.2, .22, .08);
    g.doFill();
    g.fillRect(.7, .1, .24, .5);
  } else if (kind == 'gren') {
    rrp(g, .15, -.11, 2.1, .22, .08);
    g.doFill();
    rrp(g, .7, .1, 1.1, .24, .1);
    g.doFill();
  } else if (kind == 'mg') {
    rrp(g, .1, -.13, 2.7, .26, .08);
    g.doFill();
    g.strokeStyle = gun;
    g.lineWidth = .07;
    g.beginPath();
    g.moveTo(2.2, .1);
    g.lineTo(2.55, .55);
    g.moveTo(2.2, -.1);
    g.lineTo(2.55, -.55);
    g.doStroke();
  } else if (kind == 'sniper') {
    rrp(g, .0, -.09, 2.9, .18, .06);
    g.doFill();
    g.fillRect(.7, -.24, .8, .15);
    g.strokeStyle = gun;
    g.lineWidth = .06;
    g.beginPath();
    g.moveTo(2.3, .08);
    g.lineTo(2.6, .5);
    g.moveTo(2.3, -.08);
    g.lineTo(2.6, -.5);
    g.doStroke();
  } else if (kind == 'at') {
    g.fillStyle = '#4d5841';
    rrp(g, -.85, .12, 2.9, .44, .22);
    g.doFill();
    g.strokeStyle = dark;
    g.lineWidth = .07;
    g.doStroke();
    g.fillStyle = '#2c3126';
    g.beginPath();
    g.ellipse(2.15, .34, .4, .24);
    g.doFill();
    g.fillStyle = gun;
    rrp(g, .3, -.1, 1.2, .18, .06);
    g.doFill();
  }
  g.fillStyle = skin;
  for (final p in [[.95, kind == 'at' ? -.12 : -.22], [.7, kind == 'at' ? .4 : .26]]) {
    g.beginPath();
    g.arc(p[0], p[1], .17, 0, TAU);
    g.doFill();
  }
  // каска и нашивка стороны
  g.fillStyle = U['h']!;
  g.beginPath();
  g.arc(.1, 0, .48, 0, TAU);
  g.doFill();
  g.strokeStyle = dark;
  g.lineWidth = .09;
  g.doStroke();
  g.fillStyle = 'rgba(255,255,255,.2)';
  g.beginPath();
  g.arc(.02, -.12, .26, 0, TAU);
  g.doFill();
  g.fill = ui.Color(SIDES[side].color);
  g.beginPath();
  g.arc(.12, 0, .17, 0, TAU);
  g.doFill();
  final pic = rec.endRecording();
  final im = await pic.toImage(size, size);
  pic.dispose();
  return SolSprite(im, X);
}

/* ---------- кеш ---------- */
class SpriteCache {
  static final Map<String, VehSprite> veh = {};
  static final Map<String, SolSprite> sol = {};

  static const _tx = {'tank_leo2': -.02, 'tank_abrams': -.03, 'bmp3': -.02, 'btr82': .12, 'bradley': -.02, 'bmp2': .08};
  static const _ty = {'bradley': .1, 'bmp2': -.06};

  /// Рисует все нужные спрайты заранее (асинхронно); потом доступ синхронный.
  /// [img] — загрузка картинки мода по пути (своя графика техники и бойцов), [soldiers] — сторона → вид бойца → путь.
  static Future<void> warm({Future<ui.Image?> Function(String path)? img, Map<String, dynamic>? soldiers, Map<String, Variant>? looks}) async {
    veh.clear();
    for (final v in VARIANTS) {
      if (!v.veh) continue;
      final art = v.art;
      ui.Image? hullImg, turImg;
      if (art != null && img != null) {
        if (art.hull != null) hullImg = await img(art.hull!);
        if (art.turret != null) turImg = await img(art.turret!);
      }
      for (final side in v.sides) {
        final key = '${v.id}$side';
        if (hullImg != null) {
          final hw = (v.len + 3) * art!.scale, hh = hw * hullImg.height / hullImg.width;
          final ti = turImg ?? await _blank();
          final tw = turImg == null ? 1.0 : hw * ti.width / hullImg.width, th = turImg == null ? 1.0 : tw * ti.height / ti.width;
          veh[key] = VehSprite(hullImg, TurretSprite(ti, tw, th), hw, hh, v.len * art.tx, v.wid * art.ty);
          continue;
        }
        // нарисованный кодом вид: свой или взятый у другого юнита («look»)
        final Variant src = (v.look != null && looks != null ? looks[v.look!] : null) ?? v;
        final hull = await spHull(src, side), tu = await spTurret(src, side);
        veh[key] = VehSprite(hull, tu, src.len + 3, src.wid + 3, src.len * (_tx[src.id] ?? .05), src.wid * (_ty[src.id] ?? 0));
      }
    }
    for (final side in [0, 1]) {
      for (final k in const ['rifle', 'lead', 'gren', 'mg', 'at', 'sniper']) {
        final p = (soldiers?['$side'] as Map<String, dynamic>?)?[k] as String?;
        final custom = (p != null && img != null) ? await img(p) : null;
        sol['$side$k'] = custom != null ? SolSprite(custom, 2.9) : await soldierSprite(side, k);
      }
    }
  }

  static ui.Image? _blankImg;
  static Future<ui.Image> _blank() async {
    if (_blankImg != null) return _blankImg!;
    final rec = ui.PictureRecorder();
    ui.Canvas(rec);
    final pic = rec.endRecording();
    _blankImg = await pic.toImage(1, 1);
    return _blankImg!;
  }

  static VehSprite? vehSprite(Variant v, int side) => veh['${v.id}$side'];
  static SolSprite? soldier(int side, String kind) => sol['$side$kind'];
}

