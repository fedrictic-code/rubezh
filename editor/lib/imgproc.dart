// Обработка картинок: подгонка карты, распознавание местности, фон и обрезка у спрайтов.
// Функции верхнего уровня, чтобы их можно было запускать в отдельном потоке через compute().
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rubezh/game/core.dart';

class MapImageJob {
  final Uint8List bytes;
  final bool crop; // true — обрезать по краям до 16:10, false — растянуть
  MapImageJob(this.bytes, this.crop);
}

class MapImageResult {
  final Uint8List jpg; // подогнанная картинка
  final Uint8List terrain; // GW×GH типов клеток
  final String? error;
  MapImageResult(this.jpg, this.terrain, [this.error]);
}

/// Подгоняет картинку к пропорции поля (2400×1500), уменьшает до 3000 px и размечает местность по цветам.
MapImageResult prepareMapImage(MapImageJob job) {
  final src = img.decodeImage(job.bytes);
  if (src == null) return MapImageResult(Uint8List(0), Uint8List(0), 'Картинка не читается');
  img.Image im = src;
  const aspect = W / H;
  if (job.crop) {
    final a = im.width / im.height;
    if (a > aspect) {
      final w = (im.height * aspect).round();
      im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: 0, width: w, height: im.height);
    } else if (a < aspect) {
      final h = (im.width / aspect).round();
      im = img.copyCrop(im, x: 0, y: (im.height - h) ~/ 2, width: im.width, height: h);
    }
  }
  final tw = math.min(3000, math.max(1200, im.width)), th = (tw / aspect).round();
  im = img.copyResize(im, width: tw, height: th, interpolation: img.Interpolation.average);
  final ter = classify(im);
  return MapImageResult(Uint8List.fromList(img.encodeJpg(im, quality: 88)), ter);
}

/// Повторное распознавание по уже сохранённой картинке карты.
Uint8List classifyBytes(Uint8List jpg) {
  final im = img.decodeImage(jpg);
  if (im == null) return Uint8List(GW * GH);
  return classify(im);
}

/// Разметка по цветам: вода — синее, лес — тёмно-зелёное, застройка — пёстрое серо-красное, дорога — ровное серое.
Uint8List classify(img.Image im) {
  final out = Uint8List(GW * GH);
  final cw = im.width / GW, ch = im.height / GH;
  for (int gy = 0; gy < GH; gy++) {
    for (int gx = 0; gx < GW; gx++) {
      final x0 = (gx * cw).floor(), x1 = math.max(x0 + 1, ((gx + 1) * cw).floor());
      final y0 = (gy * ch).floor(), y1 = math.max(y0 + 1, ((gy + 1) * ch).floor());
      double r = 0, g = 0, b = 0, l2 = 0;
      int n = 0;
      final st = math.max(1, ((x1 - x0) / 6).floor());
      for (int y = y0; y < y1 && y < im.height; y += st) {
        for (int x = x0; x < x1 && x < im.width; x += st) {
          final p = im.getPixel(x, y);
          final pr = p.r / 255, pg = p.g / 255, pb = p.b / 255;
          r += pr;
          g += pg;
          b += pb;
          final l = .3 * pr + .59 * pg + .11 * pb;
          l2 += l * l;
          n++;
        }
      }
      if (n == 0) continue;
      r /= n;
      g /= n;
      b /= n;
      final lum = .3 * r + .59 * g + .11 * b;
      final std = math.sqrt(math.max(0, l2 / n - lum * lum));
      final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
      final v = mx, s = mx == 0 ? 0.0 : (mx - mn) / mx;
      double h = 0;
      if (mx != mn) {
        if (mx == r) {
          h = 60 * (((g - b) / (mx - mn)) % 6);
        } else if (mx == g) {
          h = 60 * ((b - r) / (mx - mn) + 2);
        } else {
          h = 60 * ((r - g) / (mx - mn) + 4);
        }
      }
      if (h < 0) h += 360;
      int t = Ter.OPEN;
      if (b > r * 1.12 && b >= g * .98 && s > .15 && v < .9) {
        t = Ter.WATER;
      } else if (g >= r && g >= b && v < .42 && s > .12) {
        t = Ter.FOREST;
      } else if (std > .11 && (s < .25 || ((h < 30 || h > 330) && s > .3))) {
        t = Ter.BUILD;
      } else if (s < .12 && v > .3 && v < .8 && std < .06) {
        t = Ter.ROAD;
      }
      out[gy * GW + gx] = t;
    }
  }
  // одиночные клетки воды и застройки обычно ошибка — сглаживаем
  final res = Uint8List.fromList(out);
  for (int gy = 1; gy < GH - 1; gy++) {
    for (int gx = 1; gx < GW - 1; gx++) {
      final c = gy * GW + gx, t = out[c];
      if (t == Ter.OPEN) continue;
      int same = 0;
      for (final d in const [-1, 1, -GW, GW]) {
        if (out[c + d] == t) same++;
      }
      if (same == 0) res[c] = Ter.OPEN;
    }
  }
  return res;
}

class SpriteJob {
  final Uint8List bytes;
  final int rotate; // градусы, кратно 90
  final bool flip, removeBg, trim;
  final int tolerance; // 0..255
  SpriteJob(this.bytes, {this.rotate = 0, this.flip = false, this.removeBg = false, this.trim = true, this.tolerance = 40});
}

/// Подготовка спрайта: поворот, отражение, удаление однотонного фона от краёв, обрезка пустых полей. Возвращает PNG.
Uint8List? processSprite(SpriteJob j) {
  var im = img.decodeImage(j.bytes);
  if (im == null) return null;
  im = im.convert(numChannels: 4);
  if (j.rotate % 360 != 0) im = img.copyRotate(im, angle: j.rotate);
  if (j.flip) im = img.flipHorizontal(im);
  if (j.removeBg) im = _removeBg(im, j.tolerance);
  if (j.trim) im = _trim(im);
  if (im.width > 512 || im.height > 512) {
    final k = 512 / math.max(im.width, im.height);
    im = img.copyResize(im, width: (im.width * k).round(), height: (im.height * k).round(), interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodePng(im));
}

img.Image _removeBg(img.Image im, int tol) {
  final w = im.width, h = im.height;
  final seen = Uint8List(w * h);
  final stack = <int>[];
  final c0 = im.getPixel(0, 0);
  final br = c0.r.toInt(), bg = c0.g.toInt(), bb = c0.b.toInt();
  bool near(int x, int y) {
    final p = im.getPixel(x, y);
    return (p.r - br).abs() + (p.g - bg).abs() + (p.b - bb).abs() <= tol * 3 || p.a < 10;
  }

  for (final s in [0, w - 1, (h - 1) * w, h * w - 1]) {
    stack.add(s);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    if (seen[i] == 1) continue;
    seen[i] = 1;
    final x = i % w, y = i ~/ w;
    if (!near(x, y)) continue;
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    if (x > 0) stack.add(i - 1);
    if (x < w - 1) stack.add(i + 1);
    if (y > 0) stack.add(i - w);
    if (y < h - 1) stack.add(i + w);
  }
  return im;
}

img.Image _trim(img.Image im) {
  int x0 = im.width, y0 = im.height, x1 = -1, y1 = -1;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a > 12) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < x0 || y1 < y0) return im;
  return img.copyCrop(im, x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1);
}
