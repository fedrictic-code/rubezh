// Тонкая обёртка над dart:ui Canvas с привычным 2D-интерфейсом (path, fill, stroke, save…).
// Нужна, чтобы процедурную графику (местность, техника, бойцы) переносить почти построчно.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;

const double TAU = math.pi * 2;

final Map<String, ui.Color> _cssCache = {};

/// '#rrggbb' или 'rgba(r,g,b,a)' → Color (результат кешируется; не для динамических строк).
ui.Color css(String s) {
  final hit = _cssCache[s];
  if (hit != null) return hit;
  ui.Color c;
  if (s.startsWith('#')) {
    var h = s.substring(1);
    if (h.length == 3) h = h.split('').map((e) => e + e).join();
    c = ui.Color(0xFF000000 | int.parse(h, radix: 16));
  } else {
    final m = RegExp(r'rgba?\(([^)]*)\)').firstMatch(s)!;
    final p = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
    c = ui.Color.fromRGBO(p[0].round(), p[1].round(), p[2].round(), p.length > 3 ? p[3] : 1.0);
  }
  return _cssCache[s] = c;
}

ui.Color rgba(int r, int g, int b, double a) => ui.Color.fromRGBO(r, g, b, a < 0 ? 0 : (a > 1 ? 1 : a));

class _St {
  final ui.Color fill, stroke;
  final ui.Shader? shader;
  final double lw, alpha;
  final ui.StrokeCap cap;
  final ui.StrokeJoin join;
  final List<double>? dash;
  _St(this.fill, this.stroke, this.shader, this.lw, this.alpha, this.cap, this.join, this.dash);
}

class Ctx2D {
  ui.Canvas c;
  Ctx2D(this.c);

  ui.Color fill = const ui.Color(0xFF000000), stroke = const ui.Color(0xFF000000);
  ui.Shader? fillShader;
  double lineWidth = 1, alpha = 1;
  ui.StrokeCap cap = ui.StrokeCap.butt;
  ui.StrokeJoin join = ui.StrokeJoin.miter;
  List<double>? dash;
  ui.Path path = ui.Path();
  bool _hasPt = false;
  final List<_St> _stack = [];
  final ui.Paint _p = ui.Paint()..isAntiAlias = true;

  set fillStyle(Object v) {
    fillShader = null;
    fill = v is String ? css(v) : v as ui.Color;
  }

  set strokeStyle(Object v) => stroke = v is String ? css(v) : v as ui.Color;

  /* ---------- состояние ---------- */
  void save() {
    _stack.add(_St(fill, stroke, fillShader, lineWidth, alpha, cap, join, dash));
    c.save();
  }

  void restore() {
    if (_stack.isEmpty) return;
    final s = _stack.removeLast();
    fill = s.fill;
    stroke = s.stroke;
    fillShader = s.shader;
    lineWidth = s.lw;
    alpha = s.alpha;
    cap = s.cap;
    join = s.join;
    dash = s.dash;
    c.restore();
  }

  void translate(double x, double y) => c.translate(x, y);
  void rotate(double a) => c.rotate(a);
  void scale(double x, [double? y]) => c.scale(x, y ?? x);

  /* ---------- контур ---------- */
  void beginPath() {
    path = ui.Path();
    _hasPt = false;
  }

  void moveTo(double x, double y) {
    path.moveTo(x, y);
    _hasPt = true;
  }

  void lineTo(double x, double y) {
    if (!_hasPt) {
      path.moveTo(x, y);
      _hasPt = true;
    } else {
      path.lineTo(x, y);
    }
  }

  void closePath() => path.close();

  void arc(double cx, double cy, double r, double a0, double a1, [bool ccw = false]) {
    if (r <= 0) return;
    double sweep = a1 - a0;
    if (sweep.abs() >= TAU - 1e-9) {
      path.addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      _hasPt = true;
      return;
    }
    if (!ccw) {
      while (sweep < 0) {
        sweep += TAU;
      }
    } else {
      while (sweep > 0) {
        sweep -= TAU;
      }
    }
    path.arcTo(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r), a0, sweep, !_hasPt);
    _hasPt = true;
  }

  /// Полный эллипс (повёрнутый на rot).
  void ellipse(double cx, double cy, double rx, double ry, [double rot = 0]) {
    if (rx <= 0 || ry <= 0) return;
    final o = ui.Path()..addOval(ui.Rect.fromLTRB(-rx, -ry, rx, ry));
    final ca = math.cos(rot), sa = math.sin(rot);
    final m = Float64List.fromList([ca, sa, 0, 0, -sa, ca, 0, 0, 0, 0, 1, 0, cx, cy, 0, 1]);
    path.addPath(o.transform(m), ui.Offset.zero);
    _hasPt = true;
  }

  void rect(double x, double y, double w, double h) {
    path.addRect(ui.Rect.fromLTWH(x, y, w, h));
    _hasPt = true;
  }

  void roundRect(double x, double y, double w, double h, double r) {
    path.addRRect(ui.RRect.fromRectXY(ui.Rect.fromLTWH(x, y, w, h), r, r));
    _hasPt = true;
  }

  void clip() => c.clipPath(path);

  /* ---------- заливка и обводка ---------- */
  void doFill() {
    _p
      ..style = ui.PaintingStyle.fill
      ..shader = fillShader
      ..color = fillShader != null ? ui.Color.fromRGBO(0, 0, 0, alpha) : fill.withValues(alpha: fill.a * alpha);
    c.drawPath(path, _p);
    _p.shader = null;
  }

  void doStroke() {
    _p
      ..style = ui.PaintingStyle.stroke
      ..shader = null
      ..strokeWidth = lineWidth
      ..strokeCap = cap
      ..strokeJoin = join
      ..color = stroke.withValues(alpha: stroke.a * alpha);
    c.drawPath(dash == null ? path : _dashed(path, dash!), _p);
  }

  void fillRect(double x, double y, double w, double h) {
    _p
      ..style = ui.PaintingStyle.fill
      ..shader = fillShader
      ..color = fillShader != null ? ui.Color.fromRGBO(0, 0, 0, alpha) : fill.withValues(alpha: fill.a * alpha);
    c.drawRect(ui.Rect.fromLTWH(x, y, w, h), _p);
    _p.shader = null;
  }

  void strokeRect(double x, double y, double w, double h) {
    _p
      ..style = ui.PaintingStyle.stroke
      ..shader = null
      ..strokeWidth = lineWidth
      ..strokeJoin = join
      ..color = stroke.withValues(alpha: stroke.a * alpha);
    c.drawRect(ui.Rect.fromLTWH(x, y, w, h), _p);
  }

  void fillCircle(double x, double y, double r) {
    _p
      ..style = ui.PaintingStyle.fill
      ..shader = null
      ..color = fill.withValues(alpha: fill.a * alpha);
    c.drawCircle(ui.Offset(x, y), r, _p);
  }

  void line(double x0, double y0, double x1, double y1) {
    beginPath();
    moveTo(x0, y0);
    lineTo(x1, y1);
    doStroke();
  }

  void linearGradient(double x0, double y0, double x1, double y1, List<ui.Color> colors, List<double> stops) {
    fillShader = ui.Gradient.linear(ui.Offset(x0, y0), ui.Offset(x1, y1), colors, stops);
  }

  /* ---------- картинки ---------- */
  final ui.Paint _ip = ui.Paint()
    ..isAntiAlias = true
    ..filterQuality = ui.FilterQuality.medium;

  void image(ui.Image im, ui.Rect src, ui.Rect dst, {ui.ColorFilter? filter, double? opacity}) {
    _ip
      ..colorFilter = filter
      ..color = ui.Color.fromRGBO(255, 255, 255, (opacity ?? 1) * alpha);
    c.drawImageRect(im, src, dst, _ip);
    _ip.colorFilter = null;
  }

  /// Картинка целиком в прямоугольник x,y,w,h.
  void imageAt(ui.Image im, double x, double y, double w, double h, {ui.ColorFilter? filter, double? opacity}) {
    image(im, ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), ui.Rect.fromLTWH(x, y, w, h), filter: filter, opacity: opacity);
  }

  /* ---------- текст ---------- */
  static final Map<String, TextPainter> _tp = {};

  void text(String s, double x, double y,
      {double size = 10, bool bold = false, String align = 'left', String baseline = 'middle', ui.Color color = const ui.Color(0xFFFFFFFF), ui.Color? outline, double outlineW = 3}) {
    final key = '$s|$size|$bold|${color.toARGB32()}|${outline?.toARGB32()}|$outlineW';
    var tp = _tp[key];
    if (tp == null) {
      if (_tp.length > 600) _tp.clear();
      final base = TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, height: 1.0, fontFamily: 'sans-serif');
      final spans = <TextSpan>[];
      tp = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: s, style: base.copyWith(color: color)))..layout();
      if (outline != null) {
        final o = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
                text: s,
                style: base.copyWith(
                    foreground: ui.Paint()
                      ..style = ui.PaintingStyle.stroke
                      ..strokeWidth = outlineW
                      ..strokeJoin = ui.StrokeJoin.round
                      ..color = outline)))
          ..layout();
        _tpOut[key] = o;
      }
      spans.clear();
      _tp[key] = tp;
    }
    final w = tp.width, h = tp.height;
    double dx = x, dy = y;
    if (align == 'center') dx -= w / 2;
    if (align == 'right') dx -= w;
    if (baseline == 'middle') dy -= h / 2;
    if (baseline == 'bottom') dy -= h;
    final o = _tpOut[key];
    if (o != null) o.paint(c, ui.Offset(dx, dy));
    tp.paint(c, ui.Offset(dx, dy));
  }

  static final Map<String, TextPainter> _tpOut = {};
}

ui.Path _dashed(ui.Path src, List<double> d) {
  final out = ui.Path();
  for (final m in src.computeMetrics()) {
    double pos = 0;
    int i = 0;
    bool draw = true;
    while (pos < m.length) {
      final len = d[i % d.length];
      if (draw) out.addPath(m.extractPath(pos, math.min(pos + len, m.length)), ui.Offset.zero);
      pos += len;
      i++;
      draw = !draw;
    }
  }
  return out;
}
