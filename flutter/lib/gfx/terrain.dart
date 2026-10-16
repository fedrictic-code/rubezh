// Отрисовка местности в одну картинку (перенос renderTerrain из 02_map.js).
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../game/core.dart';
import '../game/map.dart';
import 'ctx2d.dart';

const double TS = 1.25;

Future<ui.Image> _pixelsToImage(Uint8List px, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

Future<ui.Image> renderTerrain({double ts = TS}) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final g = Ctx2D(canvas);
  g.scale(ts);
  final r = mulberry32(77);
  void ell(double x, double y, double rx, double ry, ui.Color col) {
    g.fill = col;
    g.fillShader = null;
    g.beginPath();
    g.ellipse(x, y, rx, ry);
    g.doFill();
  }

  void poly(Poly P, double w, ui.Color col, [ui.StrokeCap cap = ui.StrokeCap.round]) {
    g.stroke = col;
    g.lineWidth = w;
    g.cap = cap;
    g.join = ui.StrokeJoin.round;
    g.beginPath();
    for (int i = 0; i < P.length; i++) {
      if (i == 0) {
        g.moveTo(P[i][0], P[i][1]);
      } else {
        g.lineTo(P[i][0], P[i][1]);
      }
    }
    g.doStroke();
  }

  g.fillStyle = '#5f7c47';
  g.fillRect(0, 0, W, H);
  for (int i = 0; i < 2600; i++) {
    final x = r() * W, y = r() * H;
    ell(x, y, 30 + r() * 90, 20 + r() * 60, r() < .5 ? css('rgba(125,152,84,.07)') : css('rgba(62,92,52,.08)'));
  }
  // поля
  const tones = ['#8a9150', '#a09a58', '#76874a', '#9a8e55'];
  for (int i = 0; i < MAP.fields.length; i++) {
    final f = MAP.fields[i];
    final x = f[0], y = f[1], w = f[2], h = f[3];
    g.fillStyle = tones[i % 4];
    g.fillRect(x, y, w, h);
    g.strokeStyle = 'rgba(40,40,20,.18)';
    g.lineWidth = 1.2;
    for (double k = 5; k < (i % 2 == 1 ? w : h); k += 9) {
      g.beginPath();
      if (i % 2 == 1) {
        g.moveTo(x + k, y);
        g.lineTo(x + k, y + h);
      } else {
        g.moveTo(x, y + k);
        g.lineTo(x + w, y + k);
      }
      g.doStroke();
    }
    g.strokeStyle = 'rgba(30,45,20,.35)';
    g.lineWidth = 3;
    g.strokeRect(x, y, w, h);
  }
  // рельеф
  final px = Uint8List(GW * GH * 4);
  for (int y = 0; y < GH; y++) {
    for (int x = 0; x < GW; x++) {
      final i = y * GW + x;
      final l = hgt[y * GW + math.max(0, x - 1)], rr = hgt[y * GW + math.min(GW - 1, x + 1)];
      final u = hgt[math.max(0, y - 1) * GW + x], d = hgt[math.min(GH - 1, y + 1) * GW + x];
      final s = ((l - rr) + (u - d)) * 5 + hgt[i] * .12 - .04, p = i * 4;
      if (s > 0) {
        px[p] = 255;
        px[p + 1] = 250;
        px[p + 2] = 215;
        px[p + 3] = clamp(s * 255, 0, 120).toInt();
      } else {
        px[p] = 10;
        px[p + 1] = 20;
        px[p + 2] = 10;
        px[p + 3] = clamp(-s * 255, 0, 120).toInt();
      }
    }
  }
  // premultiply
  for (int i = 0; i < GW * GH; i++) {
    final a = px[i * 4 + 3];
    px[i * 4] = px[i * 4] * a ~/ 255;
    px[i * 4 + 1] = px[i * 4 + 1] * a ~/ 255;
    px[i * 4 + 2] = px[i * 4 + 2] * a ~/ 255;
  }
  final relief = await _pixelsToImage(px, GW, GH);
  g.imageAt(relief, 0, 0, W, H);
  // река
  poly(MAP.river, RIVER_W + 18, css('rgba(120,112,80,.65)'));
  poly(MAP.river, RIVER_W + 4, css('#6a8f8a'));
  poly(MAP.river, RIVER_W - 6, css('#4c7c8e'));
  poly(MAP.river, RIVER_W * .55, css('#41717f'));
  g.strokeStyle = 'rgba(200,230,235,.22)';
  g.lineWidth = 1.4;
  for (int k = -2; k <= 2; k++) {
    g.beginPath();
    for (int i = 0; i < MAP.river.length; i++) {
      final p = MAP.river[i];
      final o = k * 11 + math.sin(i * .5 + k) * 2;
      if (i > 0) {
        g.lineTo(p[0] + o, p[1]);
      } else {
        g.moveTo(p[0] + o, p[1]);
      }
    }
    g.doStroke();
  }
  for (final fy in [350.0, 1130.0]) {
    for (int i = 0; i < 46; i++) {
      final y = fy + rand(-40, 40);
      var best = MAP.river[0];
      for (final p in MAP.river) {
        if ((p[1] - y).abs() < (best[1] - y).abs()) best = p;
      }
      ell(best[0] + rand(-30, 30), y, rand(2, 5), rand(1.5, 3), css('rgba(170,165,140,.7)'));
    }
  }
  // дороги
  for (final road in MAP.roads) {
    poly(road, 46, css('rgba(70,60,40,.28)'));
    poly(road, 40, css('#a59670'));
    poly(road, 28, css('#b6a77f'));
    g.dash = [14, 22];
    poly(road, 2, css('rgba(120,105,70,.55)'), ui.StrokeCap.butt);
    g.dash = null;
  }
  // мост
  {
    final b = MAP.bridge;
    g.fillStyle = 'rgba(0,0,0,.3)';
    g.fillRect(b.x - b.w / 2 + 4, b.y - b.h / 2 + 5, b.w, b.h);
    g.fillStyle = '#7a6040';
    g.fillRect(b.x - b.w / 2, b.y - b.h / 2, b.w, b.h);
    g.strokeStyle = 'rgba(40,28,14,.55)';
    g.lineWidth = 1;
    for (double x = b.x - b.w / 2 + 5; x < b.x + b.w / 2; x += 6) {
      g.beginPath();
      g.moveTo(x, b.y - b.h / 2);
      g.lineTo(x, b.y + b.h / 2);
      g.doStroke();
    }
    g.fillStyle = '#4f3b24';
    g.fillRect(b.x - b.w / 2, b.y - b.h / 2 - 2, b.w, 3);
    g.fillRect(b.x - b.w / 2, b.y + b.h / 2 - 1, b.w, 3);
  }
  // воронки
  for (final c in MAP.craters) {
    final x = c[0], y = c[1], rad = c[2];
    ell(x, y, rad + 3, rad * .8 + 3, css('rgba(60,45,30,.35)'));
    ell(x, y, rad, rad * .78, css('#40321f'));
    ell(x - 1, y - 1, rad * .6, rad * .45, css('#2d2316'));
  }
  // окопы
  for (final t in MAP.trenches) {
    final P = smoothPoly(t, 6);
    poly(P, 20, css('rgba(112,96,64,.9)'));
    poly(P, 11, css('#3b2f21'));
    poly(P, 6, css('#2a2017'));
  }
  // деревья
  final trees = <List<double>>[];
  for (int i = 0; i < GW * GH; i++) {
    if (ter[i] == Ter.FOREST) {
      final cx = (i % GW) * CELL, cy = (i ~/ GW) * CELL;
      for (int k = 0; k < 4; k++) {
        trees.add([cx + r() * CELL, cy + r() * CELL, 8 + r() * 6, r()]);
      }
    }
  }
  trees.sort((a, b) => a[1].compareTo(b[1]));
  final shade = css('rgba(8,16,8,.3)');
  for (final t in trees) {
    ell(t[0] + 4, t[1] + 5, t[2], t[2] * .85, shade);
  }
  final crowns = [css('#2e4c2b'), css('#36592f'), css('#3f6536'), css('#2a4527')];
  final hi = css('rgba(150,190,100,.22)');
  for (final t in trees) {
    final rad = t[2];
    ell(t[0], t[1], rad, rad, crowns[(t[3] * 4).toInt()]);
    ell(t[0] - rad * .25, t[1] - rad * .3, rad * .6, rad * .55, hi);
  }
  // здания
  const roofs = ['#8b6a55', '#7c8086', '#9a5f4a', '#6f737a', '#a48a6b', '#855a4c'];
  for (final b in MAP.buildings) {
    g.fillStyle = 'rgba(0,0,0,.32)';
    g.fillRect(b.x + 6, b.y + 7, b.w, b.h);
    g.fillStyle = '#cfc8b6';
    g.fillRect(b.x, b.y, b.w, b.h);
    g.fillStyle = roofs[(b.tone * roofs.length).toInt()];
    g.fillRect(b.x + 2, b.y + 2, b.w - 4, b.h - 4);
    g.fillStyle = 'rgba(255,255,255,.14)';
    g.fillRect(b.x + 2, b.y + 2, b.w - 4, (b.h - 4) / 2);
    g.fillStyle = 'rgba(0,0,0,.2)';
    g.fillRect(b.x + 2, b.y + 2 + (b.h - 4) / 2, b.w - 4, (b.h - 4) / 2);
    g.strokeStyle = 'rgba(0,0,0,.35)';
    g.lineWidth = 1;
    g.line(b.x + 2, b.y + b.h / 2, b.x + b.w - 2, b.y + b.h / 2);
  }
  // зерно
  final pl = css('rgba(255,255,230,.05)'), dk = css('rgba(0,0,0,.06)');
  final p1 = ui.Paint()..color = pl;
  final p2 = ui.Paint()..color = dk;
  final pts1 = <ui.Offset>[], pts2 = <ui.Offset>[];
  for (int i = 0; i < 14000; i++) {
    final o = ui.Offset(r() * W, r() * H);
    if (r() < .5) {
      pts1.add(o);
    } else {
      pts2.add(o);
    }
  }
  p1
    ..strokeWidth = 1.4
    ..strokeCap = ui.StrokeCap.square;
  p2
    ..strokeWidth = 1.4
    ..strokeCap = ui.StrokeCap.square;
  canvas.drawPoints(ui.PointMode.points, pts1, p1);
  canvas.drawPoints(ui.PointMode.points, pts2, p2);

  final pic = rec.endRecording();
  final img = await pic.toImage((W * ts).round(), (H * ts).round());
  pic.dispose();
  return img;
}
