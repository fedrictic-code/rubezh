// Отрисовка поля боя и мини-карты (перенос 05_render.js).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show CustomPainter, Listenable;

import '../game/battle.dart';
import '../game/core.dart';
import '../game/data.dart';
import '../game/fxcfg.dart';
import 'ctx2d.dart';
import 'sprites.dart';
import 'terrain.dart';

class Cam {
  double x = 1200, y = 750, z = .5;
}

class Ping {
  final double x, y;
  final String kind;
  final int t;
  Ping(this.x, this.y, this.kind, this.t);
}

class UiState {
  String? mode; // прицел способности: drone/smoke/fire/fpv/arty
  Pt? ptr;
  List<double>? box; // x0,y0,x1,y1 в экранных координатах
  int hoverId = 0;
  final List<Ping> pings = [];
  bool perf = false;
  bool lite = false; // экономный режим графики
  bool menu = true; // на экране меню рисуется только фон
}

final UiState UI = UiState();
final Cam cam = Cam();

class View {
  static double w = 800, h = 600, dpr = 1;
}

double wsx(double x) => (x - cam.x) * cam.z + View.w / 2;
double wsy(double y) => (y - cam.y) * cam.z + View.h / 2;
Pt s2w(double sx, double sy) => Pt((sx - View.w / 2) / cam.z + cam.x, (sy - View.h / 2) / cam.z + cam.y);

void clampCam() {
  final minZ = math.min(View.w / W, View.h / H);
  cam.z = clamp(cam.z, minZ, 2.2);
  final hw = View.w / 2 / cam.z, hh = View.h / 2 / cam.z;
  cam.x = hw * 2 >= W ? W / 2 : clamp(cam.x, hw, W - hw);
  cam.y = hh * 2 >= H ? H / 2 : clamp(cam.y, hh, H - hh);
}

/// Картинки, которые строятся один раз или по событию.
/// Местность «Переправы», нарисованная кодом.
Future<ui.Image> renderTerrainImage() => renderTerrain();

class Assets {
  static ui.Image? terrain;
  static ui.Image? fog;
  static bool fogBusy = false;
  static final List<List<double>> craters = [];
  /// Картинки эффектов из мода (путь → изображение).
  static final Map<String, ui.Image> fxImg = {};
  static const int fogK = 2; // во сколько раз сглаженный туман подробнее сетки (дальше сглаживает видеокарта)
  static Uint8List? _fogPrev;

  static Future<void> loadTerrain() async {
    terrain = await renderTerrain();
  }

  /// Туман войны: 0 — не видно, 1 — разведано, 2 — видно сейчас. Плавные края.
  static void fogPaint() {
    if (fogBusy) return;
    final f = S.fog;
    // туман не изменился — картинку не пересчитываем
    final prev = _fogPrev;
    if (fog != null && prev != null && prev.length == f.length) {
      bool same = true;
      for (int i = 0; i < f.length; i++) {
        if (prev[i] != f[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        S.fogDirty = false;
        return;
      }
    }
    _fogPrev = Uint8List.fromList(f);
    fogBusy = true;
    final w = GW * fogK, h = GH * fogK;
    final px = Uint8List(w * h * 4);
    double val(int x, int y) {
      x = x < 0 ? 0 : (x >= GW ? GW - 1 : x);
      y = y < 0 ? 0 : (y >= GH ? GH - 1 : y);
      final v = f[y * GW + x];
      return v == 2 ? 0 : (v == 1 ? 92 : 190);
    }

    for (int y = 0; y < h; y++) {
      final gy = (y + .5) / fogK - .5;
      final y0 = gy.floor();
      double ty = gy - y0;
      ty = ty * ty * (3 - 2 * ty);
      for (int x = 0; x < w; x++) {
        final gx = (x + .5) / fogK - .5;
        final x0 = gx.floor();
        double tx = gx - x0;
        tx = tx * tx * (3 - 2 * tx);
        final a = val(x0, y0) * (1 - tx) + val(x0 + 1, y0) * tx;
        final b = val(x0, y0 + 1) * (1 - tx) + val(x0 + 1, y0 + 1) * tx;
        final al = (a * (1 - ty) + b * ty).round();
        final p = (y * w + x) * 4;
        // premultiplied (6,10,14)
        px[p] = 6 * al ~/ 255;
        px[p + 1] = 10 * al ~/ 255;
        px[p + 2] = 14 * al ~/ 255;
        px[p + 3] = al;
      }
    }
    S.fogDirty = false;
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, (im) {
      final old = fog;
      fog = im;
      old?.dispose();
      fogBusy = false;
    });
  }
}

bool fogVisible(int c) => S.fog[c] == 2;

/* ---------- юниты ---------- */

void drawMen(Ctx2D g, Squad sq) {
  final s = sq.side;
  final rad = math.max(3.7, 3.0 / cam.z);
  final ca = math.cos(sq.fa), sa = math.sin(sq.fa);
  for (int i = 0; i < sq.crew.length; i++) {
    final cm = sq.crew[i];
    if (!cm.ok) continue;
    final bob = sq.moving ? math.sin(S.t * 9 + i * 1.7) * .7 : 0.0;
    final px = sq.x + cm.dx + bob * sa, py = sq.y + cm.dy - bob * ca;
    if (!UI.lite) {
      g.fillStyle = 'rgba(0,0,0,.28)';
      g.beginPath();
      g.ellipse(px + 1.6, py + 2, rad, rad * .8);
      g.doFill();
    }
    cm.kind ??= soldierKind(CrewKind(cm.job, cm.ws.map((w) => w.id).toList()));
    final sp = SpriteCache.soldier(s, cm.kind!);
    if (sp == null) continue;
    final u = rad * .95;
    g.save();
    g.translate(px, py);
    g.rotate(sq.fa);
    g.imageAt(sp.img, -sp.X * u, -sp.X * u, sp.X * 2 * u, sp.X * 2 * u);
    g.restore();
  }
  if (sq.type == 'mortar') {
    g.strokeStyle = '#2a2f33';
    g.lineWidth = 2;
    g.line(sq.x - 4, sq.y + 3, sq.x + math.cos(sq.fa) * 9, sq.y + math.sin(sq.fa) * 9 - 3);
    g.fillStyle = '#3a4045';
    g.fillCircle(sq.x - 4, sq.y + 3, 3.4);
  }
  if (sq.fort > .6 && !sq.moving) {
    g.strokeStyle = 'rgba(70,56,36,.55)';
    g.lineWidth = 2;
    g.beginPath();
    g.arc(sq.x, sq.y, 17, math.pi * .1 + sq.fa, math.pi * .9 + sq.fa);
    g.doStroke();
  }
}

final ui.ColorFilter _deadF = ui.ColorFilter.mode(rgba(16, 12, 10, .8), ui.BlendMode.srcATop);
final ui.ColorFilter _deadT = ui.ColorFilter.mode(rgba(16, 12, 10, .82), ui.BlendMode.srcATop);
const ui.ColorFilter _shadowF = ui.ColorFilter.mode(ui.Color(0xFF000000), ui.BlendMode.srcIn);

void drawVeh(Ctx2D g, double x, double y, double fa, double ta, Variant t, int side, bool wreck) {
  final sp = SpriteCache.vehSprite(t, side);
  if (sp == null) {
    g.save();
    g.translate(x, y);
    g.rotate(fa);
    g.fillStyle = wreck ? '#2b2724' : '#566048';
    g.fillRect(-t.len / 2, -t.wid / 2, t.len, t.wid);
    g.restore();
    return;
  }
  final tur = wreck ? fa + .5 : ta;
  if (!UI.lite) {
    g.save();
    g.translate(x + 2.6, y + 3.6);
    g.rotate(fa);
    g.scale(1.3);
    g.imageAt(sp.hull, -sp.hw / 2, -sp.hh / 2, sp.hw, sp.hh, filter: _shadowF, opacity: .32);
    g.restore();
  }
  g.save();
  g.translate(x, y);
  g.rotate(fa);
  g.scale(1.3);
  g.imageAt(sp.hull, -sp.hw / 2, -sp.hh / 2, sp.hw, sp.hh, filter: wreck ? _deadF : null);
  g.translate(sp.tx, sp.ty);
  g.rotate(tur - fa);
  if (!UI.lite) {
    g.save();
    g.translate(2.2, 2.8);
    g.imageAt(sp.tur.img, -sp.tur.w / 2, -sp.tur.h / 2, sp.tur.w, sp.tur.h, filter: _shadowF, opacity: .28);
    g.restore();
  }
  g.imageAt(sp.tur.img, -sp.tur.w / 2, -sp.tur.h / 2, sp.tur.w, sp.tur.h, filter: wreck ? _deadT : null);
  g.restore();
}

/* ---------- значки типов ---------- */
void drawGlyph(Ctx2D g, String type, double cx, double cy, double s, ui.Color col) {
  g.save();
  g.translate(cx, cy);
  g.stroke = col;
  g.fill = col;
  g.lineWidth = math.max(1.2, s * .13);
  g.cap = ui.StrokeCap.round;
  g.join = ui.StrokeJoin.round;
  final h = s / 2;
  if (type == 'rifle' || type == 'mg' || type == 'at') {
    g.strokeRect(-h, -h * .62, s, s * .62 * 2);
    g.beginPath();
    g.moveTo(-h, -h * .62);
    g.lineTo(h, h * .62);
    g.moveTo(h, -h * .62);
    g.lineTo(-h, h * .62);
    g.doStroke();
    if (type == 'mg') g.line(0, -h * .62, 0, -h * 1.05);
    if (type == 'at') {
      g.beginPath();
      g.moveTo(-h * .5, h * 1.0);
      g.lineTo(0, h * .62);
      g.lineTo(h * .5, h * 1.0);
      g.doStroke();
    }
  } else if (type == 'sniper') {
    g.beginPath();
    g.arc(0, 0, h * .72, 0, TAU);
    g.moveTo(-h * 1.05, 0);
    g.lineTo(h * 1.05, 0);
    g.moveTo(0, -h * 1.05);
    g.lineTo(0, h * 1.05);
    g.doStroke();
  } else if (type == 'mortar') {
    g.beginPath();
    g.arc(0, h * .35, h * .5, 0, TAU);
    g.doStroke();
    g.line(0, h * .1, h * .5, -h * .95);
  } else if (type == 'ifv') {
    g.strokeRect(-h, -h * .55, s, s * .55 * 2);
    g.beginPath();
    g.ellipse(0, 0, h * .42, h * .3);
    g.doFill();
    g.line(h * .4, 0, h * 1.05, 0);
  } else if (type == 'tank') {
    g.beginPath();
    g.ellipse(0, 0, h * .95, h * .6);
    g.doStroke();
    g.beginPath();
    g.arc(-h * .1, 0, h * .3, 0, TAU);
    g.doFill();
    g.line(h * .1, 0, h * 1.15, 0);
  }
  g.restore();
}

/* ---------- плашки отрядов ---------- */
void drawPlates(Ctx2D g, Squad sq, bool enemy, bool sel) {
  final sx = wsx(sq.x), sy = wsy(sq.y);
  if (sx < -40 || sy < -40 || sx > View.w + 40 || sy > View.h + 40) return;
  final c = SIDES[sq.side];
  final px = sx - 15, py = sy - math.min(30, 14 + 10 * cam.z) - (sq.t.veh ? 4 : 0);
  final gold = css('#e3b341');
  if (sel) {
    g.stroke = gold;
    g.lineWidth = 2;
    g.beginPath();
    g.arc(sx, sy, 17 + (sq.t.veh ? 4 : 0), 0, TAU);
    g.doStroke();
    g.fill = rgba(227, 179, 65, .10);
    g.doFill();
  }
  g.fill = ui.Color(c.dark);
  g.alpha = .94;
  rrp(g, px, py, 30, 15, 4);
  g.doFill();
  g.alpha = 1;
  g.stroke = sel ? gold : ui.Color(c.color);
  g.lineWidth = sel ? 2 : 1.4;
  g.doStroke();
  drawGlyph(g, sq.type, px + 8.5, py + 7.5, 9, css('#f1f3f4'));
  if (!enemy && sq.no > 0) {
    g.fill = sel ? gold : css('#0c1013');
    g.stroke = sel ? gold : ui.Color(c.color);
    g.lineWidth = 1.4;
    g.beginPath();
    g.arc(px - 2, py + 2, 7, 0, TAU);
    g.doFill();
    g.doStroke();
    g.text('${sq.no}', px - 2, py + 2.5, size: 9, bold: true, align: 'center', color: sel ? css('#17130a') : css('#eef1f3'));
  }
  if (!enemy) {
    g.text(sq.t.veh ? '${math.max(1, (sq.hp / sq.hpMax * 100).ceil())}' : '${sq.men}', px + 28, py + 8, size: 10, bold: true, align: 'right', color: css('#eef1f3'));
  }
  if (sq.cargo != 0) {
    final inf = S.byId[sq.cargo];
    g.text('+${inf?.men ?? ''}', px + 2, py - 4, size: 9, bold: true, color: gold);
  }
  if (!enemy && (sq.stance == 'ambush' || sq.stance == 'cease' || sq.sneak)) {
    g.text(sq.stance == 'ambush' ? 'ЗАСАДА' : (sq.stance == 'cease' ? 'ТИХО' : 'СКРЫТНО'), px + 30, py - 4, size: 9, bold: true, align: 'right', color: gold);
  }
  if (!enemy) {
    final m = clamp(sq.morale / 100, 0, 1);
    g.fillStyle = 'rgba(0,0,0,.55)';
    g.fillRect(px, py + 17, 30, 3);
    g.fillStyle = m > .6 ? '#7ec27a' : (m > .35 ? '#e8b04a' : '#e0584a');
    g.fillRect(px, py + 17, 30 * m, 3);
    if (sq.supp > 4) {
      g.fillStyle = 'rgba(0,0,0,.55)';
      g.fillRect(px, py + 21, 30, 2.5);
      g.fillStyle = '#ee8a3a';
      g.fillRect(px, py + 21, 30 * sq.supp / 100, 2.5);
    }
  }
  if (sq.rout) {
    g.text('ОТХОД', sx, py - 5, size: 9, bold: true, align: 'center', color: css('#e0584a'));
  } else if (!enemy && sq.supp >= 75) {
    g.text('ПРИЖАТЫ', sx, py - 5, size: 9, bold: true, align: 'center', color: css('#ee8a3a'));
  }
  if ((sel || cam.z > .85) && !enemy) {
    g.text(sq.name, sx, sy + 17, size: 10, align: 'center', baseline: 'top', color: rgba(240, 244, 246, .92), outline: rgba(0, 0, 0, .7), outlineW: 3);
  }
}

/* ---------- кадр ---------- */
class WorldPainter extends CustomPainter {
  WorldPainter(Listenable repaint) : super(repaint: repaint);

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    View.w = size.width;
    View.h = size.height;
    final g = Ctx2D(canvas);
    g.fillStyle = '#0b0f12';
    g.fillRect(0, 0, size.width, size.height);
    if (UI.menu || !hasBattle) {
      final tr0 = Assets.terrain;
      if (tr0 != null) {
        clampCam();
        final k0 = tr0.width / W;
        canvas.save();
        canvas.translate(View.w / 2 - cam.x * cam.z, View.h / 2 - cam.y * cam.z);
        canvas.scale(cam.z);
        final ax0 = clamp(cam.x - View.w / 2 / cam.z, 0, W), ax1 = clamp(cam.x + View.w / 2 / cam.z, 0, W);
        final ay0 = clamp(cam.y - View.h / 2 / cam.z, 0, H), ay1 = clamp(cam.y + View.h / 2 / cam.z, 0, H);
        g.image(tr0, ui.Rect.fromLTRB(ax0 * k0, ay0 * k0, ax1 * k0, ay1 * k0), ui.Rect.fromLTRB(ax0, ay0, ax1, ay1));
        canvas.restore();
        g.fillStyle = 'rgba(8,12,15,.55)';
        g.fillRect(0, 0, size.width, size.height);
      }
      return;
    }
    clampCam();
    canvas.save();
    canvas.clipRect(ui.Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(View.w / 2 - cam.x * cam.z, View.h / 2 - cam.y * cam.z);
    canvas.scale(cam.z);
    final x0 = clamp(cam.x - View.w / 2 / cam.z, 0, W), x1 = clamp(cam.x + View.w / 2 / cam.z, 0, W);
    final y0 = clamp(cam.y - View.h / 2 / cam.z, 0, H), y1 = clamp(cam.y + View.h / 2 / cam.z, 0, H);
    final tr = Assets.terrain;
    if (tr != null) {
      final k = tr.width / W;
      g.image(tr, ui.Rect.fromLTRB(x0 * k, y0 * k, x1 * k, y1 * k), ui.Rect.fromLTRB(x0, y0, x1, y1));
    }
    // воронки от попаданий
    while (S.craterQ.isNotEmpty) {
      Assets.craters.add(S.craterQ.removeLast());
      if (Assets.craters.length > 500) Assets.craters.removeAt(0);
    }
    for (final c in Assets.craters) {
      if (c[0] < x0 - 20 || c[0] > x1 + 20 || c[1] < y0 - 20 || c[1] > y1 + 20) continue;
      if (!UI.lite) {
        g.fillStyle = 'rgba(55,42,28,.55)';
        g.beginPath();
        g.ellipse(c[0], c[1], c[2] + 3, c[2] * .8 + 3);
        g.doFill();
      }
      g.fillStyle = '#36291a';
      g.beginPath();
      g.ellipse(c[0], c[1], c[2], c[2] * .78);
      g.doFill();
    }
    if (S.fogDirty || Assets.fog == null) Assets.fogPaint();
    final fg = Assets.fog;
    if (fg != null) g.imageAt(fg, 0, 0, W, H);
    final vx0 = x0 - 60, vx1 = x1 + 60, vy0 = y0 - 60, vy1 = y1 + 60;
    bool inV(Squad e) => e.x > vx0 && e.x < vx1 && e.y > vy0 && e.y < vy1;
    // рубежи
    for (final o in S.objs) {
      final col = o.owner == 0 ? ui.Color(SIDES[0].color) : (o.owner == 1 ? ui.Color(SIDES[1].color) : css('#d8dde0'));
      g.fill = o.owner >= 0 ? col.withValues(alpha: .094) : rgba(216, 221, 224, .06);
      g.beginPath();
      g.arc(o.x, o.y, o.r, 0, TAU);
      g.doFill();
      g.dash = [10, 8];
      g.dashKey = 'obj${o.id}';
      g.stroke = col;
      g.alpha = .75;
      g.lineWidth = 2 / cam.z * .9 + .6;
      g.beginPath();
      g.arc(o.x, o.y, o.r, 0, TAU);
      g.doStroke();
      g.dash = null;
      g.dashKey = null;
      g.alpha = 1;
      if (o.ctrl.abs() > .02) {
        final sd = o.ctrl > 0 ? 1 : 0;
        g.stroke = ui.Color(SIDES[sd].color);
        g.lineWidth = 4 / cam.z * .8 + 1.5;
        g.cap = ui.StrokeCap.round;
        g.beginPath();
        g.arc(o.x, o.y, o.r - 6, -math.pi / 2, -math.pi / 2 + TAU * o.ctrl.abs());
        g.doStroke();
        g.cap = ui.StrokeCap.butt;
      }
    }
    // отметки приказов
    final nowp = DateTime.now().millisecondsSinceEpoch;
    for (int i = UI.pings.length - 1; i >= 0; i--) {
      final q = UI.pings[i], a = (nowp - q.t) / 900;
      if (a > 1) {
        UI.pings.removeAt(i);
        continue;
      }
      final hot = q.kind == 'atk' || q.kind == 'fight' || q.kind == 'fire';
      g.stroke = hot ? rgba(238, 138, 58, 1 - a) : rgba(227, 179, 65, 1 - a);
      g.lineWidth = 2.2 / cam.z * .9;
      g.beginPath();
      g.arc(q.x, q.y, (7 + a * 24) / math.max(.55, cam.z * .9), 0, TAU);
      g.doStroke();
    }
    // тела и обломки
    for (final b in S.bodies) {
      if (b == null || b.x < vx0 || b.x > vx1 || b.y < vy0 || b.y > vy1) continue;
      if (S.fog[cellIdx(b.x, b.y)] == 0) continue;
      g.fill = b.side == 0 ? rgba(40, 70, 110, .75) : rgba(110, 45, 40, .75);
      g.beginPath();
      g.ellipse(b.x, b.y, 2.6, 1.5, b.x);
      g.doFill();
    }
    for (final w in S.wrecks) {
      if (w.x < vx0 || w.x > vx1 || w.y < vy0 || w.y > vy1) continue;
      if (S.fog[cellIdx(w.x, w.y)] == 0) continue;
      drawVeh(g, w.x, w.y, w.fa, w.fa, w.vt, w.side, true);
      if (S.t - w.t < 240) {
        g.fill = rgba(60, 55, 52, .35 - (S.t - w.t) / 800);
        final ph = S.t * .6;
        for (int i = 0; i < 3; i++) {
          final q = (ph + i / 3) % 1;
          g.fillCircle(w.x + math.sin(q * 5 + i) * 4, w.y - q * 26, 5 + q * 8);
        }
      }
    }
    // маршруты выделенных
    g.lineWidth = 1.6 / cam.z;
    g.dash = [6 / cam.z, 6 / cam.z];
    for (final id in S.sel) {
      final sq = S.byId[id];
      if (sq == null || sq.dead || sq.order == null) continue;
      final o = sq.order!;
      if (o.kind == 'attack') {
        final e = S.byId[o.targetId];
        if (e != null && !e.dead) {
          g.stroke = rgba(224, 88, 74, .85);
          g.line(sq.x, sq.y, e.x, e.y);
        }
        continue;
      }
      if (o.kind == 'fire') {
        g.stroke = rgba(238, 138, 58, .9);
        g.line(sq.x, sq.y, o.x, o.y);
        g.beginPath();
        g.arc(o.x, o.y, 40, 0, TAU);
        g.doStroke();
        continue;
      }
      final path = sq.path;
      if (path == null || sq.pi >= path.length) continue;
      g.stroke = o.kind == 'fight' ? rgba(238, 138, 58, .9) : (o.kind == 'retreat' ? rgba(160, 170, 178, .8) : rgba(227, 179, 65, .85));
      g.beginPath();
      g.moveTo(sq.x, sq.y);
      for (int i = sq.pi; i < path.length; i++) {
        g.lineTo(path[i].x, path[i].y);
      }
      g.doStroke();
      final e = path.last;
      g.save();
      g.dash = null;
      g.translate(e.x, e.y);
      g.rotate(math.pi / 4);
      final r = 5 / cam.z * .9 + 2;
      g.strokeRect(-r, -r, 2 * r, 2 * r);
      g.restore();
    }
    g.dash = null;
    // зона расстановки
    final vis = <Squad>[];
    if (S.deploying) {
      final z = ZONE[S.player];
      g.fillStyle = 'rgba(227,179,65,.08)';
      g.fillRect(z.x0, z.y0, z.x1 - z.x0, z.y1 - z.y0);
      g.strokeStyle = 'rgba(227,179,65,.7)';
      g.lineWidth = 2 / cam.z;
      g.dash = [10 / cam.z, 8 / cam.z];
      g.dashKey = 'zone${S.player}';
      g.strokeRect(z.x0, z.y0, z.x1 - z.x0, z.y1 - z.y0);
      g.dash = null;
      g.dashKey = null;
    }
    for (final sq in S.squads) {
      if (sq.dead || sq.carried != 0 || !inV(sq)) continue;
      final mine = sq.side == S.player, seen = mine || isSpotted(sq, S.player);
      if (!seen) continue;
      vis.add(sq);
      if (sq.t.veh) {
        drawVeh(g, sq.x, sq.y, sq.fa, sq.ta == 0 ? sq.fa : sq.ta, sq.t, sq.side, false);
      } else {
        drawMen(g, sq);
      }
    }
    // дым горящей техники
    for (final sq in vis) {
      if (sq.t.veh && sq.smoking) {
        g.fill = rgba(40, 38, 36, .35);
        final ph = S.t * .8 + sq.id;
        for (int i = 0; i < 3; i++) {
          final q = (ph + i / 3) % 1;
          g.fillCircle(sq.x + math.sin(q * 6 + i) * 3, sq.y - q * 24, 4 + q * 7);
        }
      }
    }
    // трассеры
    g.cap = ui.StrokeCap.round;
    for (final t in S.tr) {
      if (!t.on) continue;
      final age = S.t - t.t0;
      if (age > t.life) {
        t.on = false;
        continue;
      }
      if (!(fogVisible(cellIdx(t.x1, t.y1)) || fogVisible(cellIdx(t.x0, t.y0)))) continue;
      final f = age / t.life, a = math.max(0.0, f - FX.tracerLen * .73), b = math.min(1.0, f + FX.tracerLen * .27);
      g.stroke = ui.Color(t.side == 0 ? FX.tracerUa : FX.tracerRu);
      g.lineWidth = math.max(.9, FX.tracerWidth / cam.z * .8);
      g.line(lerp(t.x0, t.x1, a), lerp(t.y0, t.y1, a), lerp(t.x0, t.x1, b), lerp(t.y0, t.y1, b));
    }
    for (final p in S.pend) {
      if (p.kind == 'shot' && S.t < p.at) {
        final f = (S.t - p.t0) / (p.at - p.t0), x = lerp(p.ax, p.x1, f), y = lerp(p.ay, p.y1, f);
        if (!(fogVisible(cellIdx(x, y)) || fogVisible(cellIdx(p.ax, p.ay)))) continue;
        final tr = FX.missileTrail;
        if (FX.missileSmokeOn && !UI.lite) {
          g.stroke = ui.Color(FX.missileSmoke);
          g.lineWidth = FX.missileWidth * 2.2;
          g.line(lerp(p.ax, p.x1, math.max(0.0, f - tr * 3)), lerp(p.ay, p.y1, math.max(0.0, f - tr * 3)), lerp(p.ax, p.x1, math.max(0.0, f - tr)), lerp(p.ay, p.y1, math.max(0.0, f - tr)));
        }
        g.stroke = ui.Color(FX.missile);
        g.lineWidth = FX.missileWidth;
        g.line(lerp(p.ax, p.x1, math.max(0.0, f - tr)), lerp(p.ay, p.y1, math.max(0.0, f - tr)), x, y);
      }
    }
    g.cap = ui.StrokeCap.butt;
    // взрывы
    for (final e in S.ex) {
      if (!e.on) continue;
      final age = S.t - e.t0;
      if (age > e.life) {
        e.on = false;
        continue;
      }
      if (!fogVisible(cellIdx(e.x, e.y))) continue;
      final p = age / e.life;
      if (e.kind == 1) {
        final fc = ui.Color(FX.flash);
        g.fill = fc.withValues(alpha: fc.a * (1 - p));
        g.fillCircle(e.x, e.y, e.r * FX.flashSize * (.6 + p));
        continue;
      }
      final bf = e.kind == 2 ? FX.big : FX.boom;
      final r = e.r * bf.size;
      final spr = bf.sprite == null ? null : Assets.fxImg[bf.sprite!];
      if (spr != null) {
        final s = r * 2.4 * (.7 + p * .6);
        g.alpha = 1 - p * p;
        g.imageAt(spr, e.x - s / 2, e.y - s / 2, s, s);
        g.alpha = 1;
        continue;
      }
      final sc = ui.Color(bf.smoke), fc = ui.Color(bf.fire);
      g.fill = sc.withValues(alpha: (1 - p) * .5 * sc.a);
      g.fillCircle(e.x, e.y - p * 8, r * (.7 + p * 1.1));
      if (p < .5) {
        g.fill = fc.withValues(alpha: (1 - p * 2) * .9 * fc.a);
        g.fillCircle(e.x, e.y, r * (.4 + p * 1.1));
      }
      if (bf.sparks > 0 && p < .6 && !UI.lite) {
        g.stroke = fc.withValues(alpha: (1 - p / .6) * fc.a);
        g.lineWidth = 1.2;
        for (int i = 0; i < bf.sparks; i++) {
          final a = (i * 2.399 + e.x * .01) % TAU, d0 = r * (.3 + p * 1.6), d1 = d0 + r * .35;
          g.line(e.x + math.cos(a) * d0, e.y + math.sin(a) * d0, e.x + math.cos(a) * d1, e.y + math.sin(a) * d1);
        }
      }
    }
    // дым
    for (final s in S.smokes) {
      if (s.x < vx0 - 80 || s.x > vx1 + 80 || s.y < vy0 - 80 || s.y > vy1 + 80) continue;
      for (int i = 0; i < (UI.lite ? 5 : 9); i++) {
        final a = i * 2.4 + S.t * .12 * (i % 2 == 1 ? 1 : -1), r = s.r * (.2 + (i % 4) * .17);
        g.fill = rgba(224, 228, 230, .34 - (i % 3) * .05);
        g.fillCircle(s.x + math.cos(a) * r, s.y + math.sin(a) * r, s.r * (.34 + (i % 3) * .06));
      }
    }
    // дроны
    for (final d in S.drones) {
      if (d.side != S.player && !fogVisible(cellIdx(d.x, d.y))) continue;
      final c = ui.Color(SIDES[d.side].color);
      if (d.side == S.player) {
        g.dash = [8, 8];
        g.stroke = c;
        g.alpha = .5;
        g.lineWidth = 1.4 / cam.z * .8;
        g.beginPath();
        g.arc(d.x, d.y, d.vision, 0, TAU);
        g.doStroke();
        g.dash = null;
        g.alpha = 1;
      }
      g.save();
      g.translate(d.x, d.y);
      g.rotate(S.t * 6);
      g.strokeStyle = '#111111';
      g.lineWidth = 2;
      g.beginPath();
      g.moveTo(-7, -7);
      g.lineTo(7, 7);
      g.moveTo(7, -7);
      g.lineTo(-7, 7);
      g.doStroke();
      g.fill = c;
      g.fillCircle(0, 0, 3);
      g.restore();
    }
    for (final f in S.fpv) {
      if (f.side != S.player && !fogVisible(cellIdx(f.x, f.y))) continue;
      final tg = S.byId[f.tid];
      if (tg != null) {
        g.stroke = ui.Color(SIDES[f.side].color);
        g.alpha = .55;
        g.lineWidth = 1;
        g.line(f.x, f.y, tg.x, tg.y);
        g.alpha = 1;
      }
      g.fillStyle = '#ffffff';
      g.fillCircle(f.x, f.y, 2.6);
      g.fill = ui.Color(SIDES[f.side].color);
      g.fillCircle(f.x, f.y, 1.6);
    }
    // прицел способности
    if (UI.ptr != null && UI.mode != null) {
      final m = UI.mode!, p = UI.ptr!;
      g.dash = [8, 6];
      g.lineWidth = 2 / cam.z * .9;
      g.strokeStyle = '#e3b341';
      if (m == 'drone') {
        g.beginPath();
        g.arc(p.x, p.y, 430, 0, TAU);
        g.doStroke();
      } else if (m == 'smoke') {
        g.beginPath();
        g.arc(p.x, p.y, 58, 0, TAU);
        g.doStroke();
      } else if (m == 'fire') {
        g.strokeStyle = '#ee8a3a';
        g.beginPath();
        g.arc(p.x, p.y, 40, 0, TAU);
        g.doStroke();
        for (final id in S.sel) {
          final sq = S.byId[id];
          if (sq != null && sq.t.mortar) {
            g.alpha = .35;
            g.beginPath();
            g.arc(sq.x, sq.y, sq.t.range, 0, TAU);
            g.doStroke();
            g.beginPath();
            g.arc(sq.x, sq.y, sq.t.minRange, 0, TAU);
            g.doStroke();
            g.alpha = 1;
          }
        }
      } else if (m == 'arty') {
        g.beginPath();
        g.arc(p.x, p.y, 70, 0, TAU);
        g.doStroke();
      }
      g.dash = null;
    }
    canvas.restore();

    // экранные элементы
    for (final o in S.objs) {
      final sx = wsx(o.x), sy = wsy(o.y - o.r);
      if (sx < -80 || sx > View.w + 80 || sy < -40 || sy > View.h + 40) continue;
      g.text(o.name.toUpperCase(), sx, sy - 2, size: 11, bold: true, align: 'center', baseline: 'bottom', color: o.owner >= 0 ? css('#ffffff') : css('#cfd5d9'), outline: rgba(0, 0, 0, .75), outlineW: 3.5);
    }
    // призраки
    for (final e in S.squads) {
      if (e.dead || e.side == S.player || isSpotted(e, S.player)) continue;
      final lk = e.lk[S.player];
      if (lk == null || S.t - e.seenAt[S.player] > 10) continue;
      final sx = wsx(lk.x), sy = wsy(lk.y);
      if (sx < -30 || sy < -30 || sx > View.w + 30 || sy > View.h + 30) continue;
      g.alpha = .55 * (1 - (S.t - e.seenAt[S.player]) / 10);
      g.dash = [3, 3];
      g.stroke = ui.Color(SIDES[e.side].color);
      g.lineWidth = 1.4;
      rrp(g, sx - 15, sy - 24, 30, 15, 4);
      g.doStroke();
      g.dash = null;
      drawGlyph(g, e.type, sx, sy - 16.5, 9, ui.Color(SIDES[e.side].color));
      g.alpha = 1;
    }
    for (final sq in vis) {
      drawPlates(g, sq, sq.side != S.player, S.sel.contains(sq.id));
    }
    if (UI.hoverId != 0) {
      final e = S.byId[UI.hoverId];
      if (e != null && !e.dead) {
        g.strokeStyle = '#e0584a';
        g.lineWidth = 1.6;
        g.beginPath();
        g.arc(wsx(e.x), wsy(e.y), 20, 0, TAU);
        g.doStroke();
      }
    }
    final b = UI.box;
    if (b != null) {
      g.fillStyle = 'rgba(227,179,65,.12)';
      g.strokeStyle = '#e3b341';
      g.lineWidth = 1.2;
      final l = math.min(b[0], b[2]), t = math.min(b[1], b[3]), w = (b[2] - b[0]).abs(), h = (b[3] - b[1]).abs();
      g.fillRect(l, t, w, h);
      g.strokeRect(l, t, w, h);
    }
  }
}

/* ---------- мини-карта ---------- */
class MiniPainter extends CustomPainter {
  MiniPainter(Listenable repaint) : super(repaint: repaint);

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final g = Ctx2D(canvas);
    final w = size.width, h = size.height;
    g.fillStyle = '#0b0f12';
    g.fillRect(0, 0, w, h);
    final tr = Assets.terrain;
    if (tr != null) g.imageAt(tr, 0, 0, w, h);
    if (!hasBattle) return;
    final fg = Assets.fog;
    if (fg != null) g.imageAt(fg, 0, 0, w, h);
    final sx = w / W, sy = h / H;
    for (final o in S.objs) {
      g.stroke = o.owner == 0 ? ui.Color(SIDES[0].color) : (o.owner == 1 ? ui.Color(SIDES[1].color) : css('#dddddd'));
      g.lineWidth = 1.5;
      g.beginPath();
      g.arc(o.x * sx, o.y * sy, math.max(4, o.r * sx), 0, TAU);
      g.doStroke();
    }
    for (final sq in S.squads) {
      if (sq.dead || sq.carried != 0) continue;
      final mine = sq.side == S.player;
      if (!mine && !isSpotted(sq, S.player)) continue;
      g.fill = ui.Color(SIDES[sq.side].color);
      final r = sq.t.veh ? 3.0 : 2.3;
      g.fillRect(sq.x * sx - r, sq.y * sy - r, r * 2, r * 2);
      if (S.sel.contains(sq.id)) {
        g.strokeStyle = '#e3b341';
        g.lineWidth = 1;
        g.strokeRect(sq.x * sx - r - 1, sq.y * sy - r - 1, r * 2 + 2, r * 2 + 2);
      }
    }
    for (final d in S.drones) {
      if (d.side == S.player) {
        g.fillStyle = '#ffffff';
        g.fillRect(d.x * sx - 1.5, d.y * sy - 1.5, 3, 3);
      }
    }
    final hw = View.w / 2 / cam.z, hh = View.h / 2 / cam.z;
    g.strokeStyle = 'rgba(255,255,255,.85)';
    g.lineWidth = 1.2;
    g.strokeRect((cam.x - hw) * sx, (cam.y - hh) * sy, hw * 2 * sx, hh * 2 * sy);
  }
}
