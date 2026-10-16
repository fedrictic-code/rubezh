// Ядро: константы, математика, сетка проходимости, видимость, поиск пути.
// Перенос с JS-версии (01_core.js). Координаты в метрах: 1 единица = 1 м.
import 'dart:math' as math;
import 'dart:typed_data';

import 'battle.dart' show S, hasBattle;

const double W = 2400, H = 1500, CELL = 20, TICK = 0.05;
const int GW = 120, GH = 75;
const double TAU = math.pi * 2;

double clamp(num v, num a, num b) => (v < a ? a : (v > b ? b : v)).toDouble();
double lerp(double a, double b, double t) => a + (b - a) * t;
double dist(double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  return math.sqrt(dx * dx + dy * dy);
}

/// Генератор случайных чисел игры. В тестах можно подменить на детерминированный.
math.Random rng = math.Random();
double rand(double a, double b) => a + rng.nextDouble() * (b - a);
double rnd() => rng.nextDouble();

/// Детерминированный генератор для карты (mulberry32).
double Function() mulberry32(int seed) {
  int a = seed & 0xFFFFFFFF;
  return () {
    a = (a + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = a;
    t = _imul(t ^ (t >>> 15), 1 | t);
    t = (t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF ^ t;
    t &= 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  };
}

int _imul(int a, int b) {
  // 32-битное умножение как Math.imul (результат — беззнаковое 32 бита).
  final ah = (a >>> 16) & 0xFFFF, al = a & 0xFFFF, bh = (b >>> 16) & 0xFFFF, bl = b & 0xFFFF;
  return ((al * bl) + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

double hash2(int x, int y) {
  int h = _imul(x & 0xFFFFFFFF, 374761393) ^ _imul(y & 0xFFFFFFFF, 668265263);
  h = _imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) & 0xFFFFFFFF) / 4294967296.0;
}

double vnoise(double x, double y) {
  final xi = x.floor(), yi = y.floor();
  final xf = x - xi, yf = y - yi;
  double s(double t) => t * t * (3 - 2 * t);
  final a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
  return lerp(lerp(a, b, s(xf)), lerp(c, d, s(xf)), s(yf));
}

String fmtTime(double sec) {
  final s = math.max(0, sec.ceil());
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

double angDiff(double a, double b) {
  double d = b - a;
  while (d > math.pi) d -= TAU;
  while (d < -math.pi) d += TAU;
  return d;
}

class Pt {
  double x, y;
  Pt(this.x, this.y);
}

/// Типы местности.
class Ter {
  static const int OPEN = 0, FOREST = 1, BUILD = 2, WATER = 3, ROAD = 4, TRENCH = 5, RUBBLE = 6, BRIDGE = 7, FORD = 8;
}

const List<double> T_COVER = [0, .45, .8, 0, 0, .75, .3, 0, 0];
const List<double> T_OPAC = [0, .5, 1, 0, 0, 0, .05, 0, 0];
const List<double> T_MV_I = [1, .6, .7, 0, 1.1, .8, .85, 1.1, .5];
const List<double> T_MV_V = [1, .3, 0, 0, 1.35, .2, .6, 1, .45];

final Uint8List ter = Uint8List(GW * GH);
final Float32List hgt = Float32List(GW * GH);

int cellIdx(double x, double y) {
  final ix = x < 0 ? 0 : (x >= W ? GW - 1 : (x / CELL).toInt());
  final iy = y < 0 ? 0 : (y >= H ? GH - 1 : (y / CELL).toInt());
  return iy * GW + ix;
}

/// Непрозрачность на линии (лес, здания).
double losOpacity(double x0, double y0, double x1, double y1) {
  final d = dist(x0, y0, x1, y1);
  if (d < 1) return 0;
  final n = math.max(1, (d / (CELL * .5)).ceil());
  final sx = (x1 - x0) / n, sy = (y1 - y0) / n;
  final c0 = cellIdx(x0, y0), c1 = cellIdx(x1, y1);
  double sum = 0;
  int last = -1;
  for (int i = 1; i < n; i++) {
    final c = cellIdx(x0 + sx * i, y0 + sy * i);
    if (c == last) continue;
    last = c;
    if (c == c0 || c == c1) continue;
    final o = T_OPAC[ter[c]];
    if (o > 0) {
      sum += o;
      if (sum >= 1) return 1;
    }
  }
  return sum;
}

bool segCircle(double x0, double y0, double x1, double y1, double cx, double cy, double r) {
  final dx = x1 - x0, dy = y1 - y0, l2 = dx * dx + dy * dy;
  double t = l2 > 0 ? ((cx - x0) * dx + (cy - y0) * dy) / l2 : 0;
  t = clamp(t, 0, 1);
  final px = x0 + dx * t - cx, py = y0 + dy * t - cy;
  return px * px + py * py < r * r;
}

bool los(double x0, double y0, double x1, double y1) {
  if (losOpacity(x0, y0, x1, y1) >= 1) return false;
  if (hasBattle) {
    final sm = S.smokes;
    for (int i = 0; i < sm.length; i++) {
      final s = sm[i];
      if (segCircle(x0, y0, x1, y1, s.x, s.y, s.r)) return false;
    }
  }
  return true;
}

/* ---------- поиск пути (A* по сетке) ---------- */
final Float32List _pfG = Float32List(GW * GH);
final Int32List _pfFrom = Int32List(GW * GH);
final Uint32List _pfStamp = Uint32List(GW * GH);
final Uint32List _pfClosed = Uint32List(GW * GH);
int _pfId = 0;
final List<int> _heapI = [];
final List<double> _heapF = [];
const List<int> _DX = [1, -1, 0, 0, 1, 1, -1, -1], _DY = [0, 0, 1, -1, 1, -1, 1, -1];

void _hpush(int i, double f) {
  int n = _heapI.length;
  _heapI.add(i);
  _heapF.add(f);
  while (n > 0) {
    final p = (n - 1) >> 1;
    if (_heapF[p] <= f) break;
    _heapI[n] = _heapI[p];
    _heapF[n] = _heapF[p];
    n = p;
  }
  _heapI[n] = i;
  _heapF[n] = f;
}

int _hpop() {
  final top = _heapI[0];
  final li = _heapI.removeLast(), lf = _heapF.removeLast();
  final n = _heapI.length;
  if (n > 0) {
    int k = 0;
    for (;;) {
      int c = 2 * k + 1;
      if (c >= n) break;
      if (c + 1 < n && _heapF[c + 1] < _heapF[c]) c++;
      if (_heapF[c] >= lf) break;
      _heapI[k] = _heapI[c];
      _heapF[k] = _heapF[c];
      k = c;
    }
    _heapI[k] = li;
    _heapF[k] = lf;
  }
  return top;
}

int nearestPassable(int c, List<double> mv) {
  if (mv[ter[c]] > 0) return c;
  final cx = c % GW, cy = c ~/ GW;
  for (int r = 1; r < 14; r++) {
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (math.max(dx.abs(), dy.abs()) != r) continue;
        final x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= GW || y >= GH) continue;
        final i = y * GW + x;
        if (mv[ter[i]] > 0) return i;
      }
    }
  }
  return c;
}

bool lineClear(double ax, double ay, double bx, double by, List<double> mv, double thr) {
  final d = dist(ax, ay, bx, by), n = math.max(1, (d / 8).ceil());
  for (int i = 0; i <= n; i++) {
    final m = mv[ter[cellIdx(ax + (bx - ax) * i / n, ay + (by - ay) * i / n)]];
    if (m < thr) return false;
  }
  return true;
}

List<Pt>? findPath(double sx, double sy, double tx, double ty, bool veh) {
  final mv = veh ? T_MV_V : T_MV_I;
  final s = nearestPassable(cellIdx(sx, sy), mv), t = nearestPassable(cellIdx(tx, ty), mv);
  final tcx = (t % GW + .5) * CELL, tcy = (t ~/ GW + .5) * CELL;
  final direct = mv[ter[cellIdx(tx, ty)]] > 0;
  final ex = direct ? tx : tcx, ey = direct ? ty : tcy;
  if (s == t) return [Pt(ex, ey)];
  final id = ++_pfId;
  _heapI.clear();
  _heapF.clear();
  _pfG[s] = 0;
  _pfStamp[s] = id;
  _pfFrom[s] = -1;
  _hpush(s, 0);
  final gx = t % GW, gy = t ~/ GW;
  bool found = false;
  while (_heapI.isNotEmpty) {
    final c = _hpop();
    if (_pfClosed[c] == id) continue;
    _pfClosed[c] = id;
    if (c == t) {
      found = true;
      break;
    }
    final cx = c % GW, cy = c ~/ GW;
    for (int k = 0; k < 8; k++) {
      final nx = cx + _DX[k], ny = cy + _DY[k];
      if (nx < 0 || ny < 0 || nx >= GW || ny >= GH) continue;
      final n = ny * GW + nx, m = mv[ter[n]];
      if (m == 0 || _pfClosed[n] == id) continue;
      if (k > 3 && (mv[ter[cy * GW + nx]] == 0 || mv[ter[ny * GW + cx]] == 0)) continue;
      final ng = _pfG[c] + (k > 3 ? 1.414 : 1) / m;
      if (_pfStamp[n] != id || ng < _pfG[n]) {
        _pfStamp[n] = id;
        _pfG[n] = ng;
        _pfFrom[n] = c;
        final ax = (nx - gx).abs(), ay = (ny - gy).abs();
        _hpush(n, ng + (math.max(ax, ay) + .414 * math.min(ax, ay)) * .72);
      }
    }
  }
  if (!found) return null;
  final cells = <int>[];
  for (int c = t; c != -1; c = _pfFrom[c]) {
    cells.add(c);
  }
  final P = cells.reversed.map((c) => Pt((c % GW + .5) * CELL, (c ~/ GW + .5) * CELL)).toList();
  P[0] = Pt(sx, sy);
  P[P.length - 1] = Pt(ex, ey);
  final thr = veh ? .4 : .55;
  final out = <Pt>[];
  int i = 0;
  while (i < P.length - 1) {
    int j = P.length - 1;
    while (j > i + 1 && !lineClear(P[i].x, P[i].y, P[j].x, P[j].y, mv, thr)) {
      j--;
    }
    out.add(P[j]);
    i = j;
  }
  return out;
}
