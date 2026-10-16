// Карта «Переправа»: генерация местности (перенос 02_map.js).
import 'dart:math' as math;

import 'core.dart';

typedef Poly = List<List<double>>;

class Bld {
  final double x, y, w, h, tone;
  const Bld(this.x, this.y, this.w, this.h, this.tone);
}

class Obj {
  final int id;
  final String name;
  final double x, y, r;
  final bool key;
  const Obj(this.id, this.name, this.x, this.y, this.r, this.key);
}

class Bridge {
  final double x, y, w, h;
  const Bridge(this.x, this.y, this.w, this.h);
}

class GameMap {
  List<List<double>> forests = []; // [cx, cy, r]
  List<Bld> buildings = [];
  List<Poly> roads = [];
  List<Poly> trenches = [];
  List<List<double>> fields = []; // [x, y, w, h]
  Poly river = [];
  Bridge bridge = const Bridge(1150, 740, 150, 34);
  List<List<double>> craters = [];
  List<Obj> objs = [];
}

final GameMap MAP = GameMap();
const double RIVER_W = 70;

Poly smoothPoly(Poly p, [int seg = 10]) {
  if (p.length < 3) return p.map((e) => [...e]).toList();
  final out = <List<double>>[p[0]];
  for (int i = 1; i < p.length - 1; i++) {
    final m0 = i == 1 ? p[0] : [(p[i - 1][0] + p[i][0]) / 2, (p[i - 1][1] + p[i][1]) / 2];
    final m1 = i == p.length - 2 ? p[p.length - 1] : [(p[i][0] + p[i + 1][0]) / 2, (p[i][1] + p[i + 1][1]) / 2];
    for (int s = 1; s <= seg; s++) {
      final t = s / seg, u = 1 - t;
      out.add([
        u * u * m0[0] + 2 * u * t * p[i][0] + t * t * m1[0],
        u * u * m0[1] + 2 * u * t * p[i][1] + t * t * m1[1],
      ]);
    }
  }
  return out;
}

double distToPoly(double x, double y, Poly P) {
  double best = 1e9;
  for (int i = 0; i < P.length - 1; i++) {
    final ax = P[i][0], ay = P[i][1], bx = P[i + 1][0], by = P[i + 1][1];
    final dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy;
    double t = l2 > 0 ? ((x - ax) * dx + (y - ay) * dy) / l2 : 0;
    t = clamp(t, 0, 1);
    final d = math.sqrt(math.pow(x - ax - dx * t, 2) + math.pow(y - ay - dy * t, 2));
    if (d < best) best = d;
  }
  return best;
}

void forCircle(double cx, double cy, double r, void Function(int c, int x, int y) fn) {
  final x0 = math.max(0, ((cx - r) / CELL).toInt()), x1 = math.min(GW - 1, ((cx + r) / CELL).toInt());
  final y0 = math.max(0, ((cy - r) / CELL).toInt()), y1 = math.min(GH - 1, ((cy + r) / CELL).toInt());
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      if (dist((x + .5) * CELL, (y + .5) * CELL, cx, cy) <= r) fn(y * GW + x, x, y);
    }
  }
}

void stampLine(Poly P, double width, void Function(int c, int x, int y) fn) {
  for (int i = 0; i < P.length - 1; i++) {
    final d = dist(P[i][0], P[i][1], P[i + 1][0], P[i + 1][1]);
    final n = math.max(1, (d / 8).ceil());
    for (int k = 0; k <= n; k++) {
      forCircle(lerp(P[i][0], P[i + 1][0], k / n), lerp(P[i][1], P[i + 1][1], k / n), width / 2, fn);
    }
  }
}

Poly _poly(List<List<num>> p) => p.map((e) => [e[0].toDouble(), e[1].toDouble()]).toList();

void genMap() {
  final r = mulberry32(20241016);
  ter.fillRange(0, ter.length, 0);
  MAP.buildings = [];
  MAP.craters = [];
  const hills = [
    [1930, 520, 190, 1], [1780, 1130, 160, .85], [600, 340, 210, .5], [720, 1190, 180, .45], [1320, 200, 120, .3], [2250, 1250, 200, .4]
  ];
  for (int iy = 0; iy < GH; iy++) {
    for (int ix = 0; ix < GW; ix++) {
      final x = (ix + .5) * CELL, y = (iy + .5) * CELL;
      double h = .06 * math.sin(x * .004 + 1) * math.cos(y * .005);
      for (final hl in hills) {
        final dx = x - hl[0], dy = y - hl[1], s = hl[2].toDouble();
        h += hl[3] * math.exp(-(dx * dx + dy * dy) / (2 * s * s));
      }
      hgt[iy * GW + ix] = clamp(h, 0, 1);
    }
  }
  // река
  MAP.river = smoothPoly(_poly([[1060, -60], [1120, 200], [1040, 430], [1100, 640], [1180, 800], [1090, 1010], [1020, 1230], [1080, 1560]]), 12);
  for (int iy = 0; iy < GH; iy++) {
    for (int ix = 0; ix < GW; ix++) {
      final x = (ix + .5) * CELL, y = (iy + .5) * CELL;
      if (distToPoly(x, y, MAP.river) < RIVER_W / 2) {
        ter[iy * GW + ix] = ((y - 350).abs() < 45 || (y - 1130).abs() < 45) ? Ter.FORD : Ter.WATER;
      }
    }
  }
  // мост
  MAP.bridge = const Bridge(1150, 740, 150, 34);
  forCircle(1150, 740, 80, (c, cx, cy) {
    final x = (cx + .5) * CELL, y = (cy + .5) * CELL;
    if ((x - 1150).abs() < 80 && (y - 740).abs() < 17) ter[c] = Ter.BRIDGE;
  });
  // дороги
  MAP.roads = [
    smoothPoly(_poly([[-20, 760], [380, 748], [760, 738], [1085, 741]]), 8),
    smoothPoly(_poly([[1215, 742], [1480, 738], [1830, 734], [2420, 716]]), 8),
  ];
  for (final road in MAP.roads) {
    stampLine(road, 40, (c, _, __) {
      if (ter[c] == Ter.OPEN || ter[c] == Ter.FOREST) ter[c] = Ter.ROAD;
    });
  }
  // село
  final bl = MAP.buildings;
  void addB(double x, double y, double w, double h) {
    bl.add(Bld(x, y, w, h, r()));
    final x0 = x - 6, x1 = x + w + 6, y0 = y - 6, y1 = y + h + 6;
    for (int iy = math.max(0, (y0 / CELL).toInt()); iy <= math.min(GH - 1, (y1 / CELL).toInt()); iy++) {
      for (int ix = math.max(0, (x0 / CELL).toInt()); ix <= math.min(GW - 1, (x1 / CELL).toInt()); ix++) {
        final cx = (ix + .5) * CELL, cy = (iy + .5) * CELL, c = iy * GW + ix;
        if (cx > x0 && cx < x1 && cy > y0 && cy < y1 && ter[c] != Ter.WATER && ter[c] != Ter.ROAD) ter[c] = Ter.BUILD;
      }
    }
  }

  for (double x = 1560; x < 1850; x += 58) {
    if (r() > .15) addB(x + r() * 10, 664 + r() * 8, 38 + r() * 26, 30 + r() * 14);
    if (r() > .15) addB(x + r() * 10, 772 + r() * 8, 38 + r() * 26, 30 + r() * 14);
    if (r() > .5) addB(x + r() * 14, 598 + r() * 14, 36 + r() * 24, 28 + r() * 12);
    if (r() > .5) addB(x + r() * 14, 850 + r() * 14, 36 + r() * 24, 28 + r() * 12);
  }
  addB(1380, 820, 44, 34);
  addB(1280, 640, 40, 30);
  addB(2060, 830, 46, 32);
  addB(2110, 640, 40, 30);
  // лес
  final patches = _poly([
    [420, 260, 150], [520, 560, 110], [330, 980, 170], [660, 1080, 130], [860, 380, 100], [900, 1260, 140], [1330, 330, 110],
    [1290, 1000, 100], [1330, 1250, 120], [1520, 470, 90], [1690, 300, 120], [2060, 430, 120], [1810, 600, 70], [1700, 1190, 140],
    [1860, 1030, 100], [2200, 760, 90], [2250, 300, 160], [2100, 1300, 130], [560, 800, 60], [760, 520, 60]
  ]);
  MAP.forests = patches;
  for (final p in patches) {
    final cx = p[0], cy = p[1], rad = p[2];
    forCircle(cx, cy, rad * 1.5, (c, ix, iy) {
      final x = (ix + .5) * CELL, y = (iy + .5) * CELL;
      final thr = rad * (.65 + .55 * vnoise(x * .014, y * .014));
      if (dist(x, y, cx, cy) < thr && ter[c] == Ter.OPEN) ter[c] = Ter.FOREST;
    });
  }
  // окопы
  MAP.trenches = [
    [[1500, 610], [1512, 690], [1500, 760], [1512, 830], [1500, 905]],
    [[1580, 598], [1680, 588], [1780, 598]],
    [[1580, 884], [1680, 894], [1780, 884]],
    [[1830, 560], [1890, 592], [1960, 572], [2020, 520]],
    [[1880, 462], [1930, 440], [1990, 450]],
    [[1700, 1090], [1760, 1070], [1840, 1090]],
    [[1262, 690], [1268, 740], [1262, 800]],
  ].map((t) => _poly(t)).toList();
  for (final t in MAP.trenches) {
    stampLine(smoothPoly(t, 6), 14, (c, _, __) {
      if (ter[c] != Ter.WATER && ter[c] != Ter.BUILD && ter[c] != Ter.ROAD) ter[c] = Ter.TRENCH;
    });
  }
  // воронки и завалы
  for (int i = 0; i < 26; i++) {
    MAP.craters.add([rand(1350, 2050), rand(520, 960), rand(7, 15)]);
  }
  for (int i = 0; i < 12; i++) {
    final x = rand(1400, 1900), y = rand(560, 920);
    forCircle(x, y, 12, (c, _, __) {
      if (ter[c] == Ter.OPEN) ter[c] = Ter.RUBBLE;
    });
  }
  MAP.fields = _poly([
    [80, 80, 300, 200], [120, 380, 250, 200], [60, 1130, 320, 260], [420, 1230, 200, 200], [1420, 90, 240, 220],
    [2100, 900, 260, 280], [2000, 1210, 300, 220], [1500, 1180, 160, 200], [700, 640, 150, 70]
  ]);
  MAP.objs = const [
    Obj(0, 'Мост', 1150, 740, 85, false),
    Obj(1, 'Село Дубки', 1700, 742, 110, true),
    Obj(2, 'Высота 112', 1930, 520, 95, true),
  ];
}
