// Описание карты: встроенная «Переправа» (рисуется кодом) или карта из мода (картинка + разметка клеток).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'battle.dart';
import 'core.dart';
import 'map.dart';

class MapDef {
  String id, name, brief;
  /// Путь к картинке внутри assets/ (для карты из мода); null — местность рисуется кодом.
  String? image;
  /// Типы клеток GW×GH (Ter.*) и высоты 0..1; null — генерация «Переправы».
  Uint8List? terrain;
  Float32List? height;
  List<Obj> objs;
  List<int> owners;
  List<List<double>> bases;
  List<Zone> zones;
  List<double>? asm, post, choke, smoke;
  Map<String, List<List<double>>>? slots;

  MapDef({
    required this.id,
    required this.name,
    this.brief = '',
    this.image,
    this.terrain,
    this.height,
    required this.objs,
    required this.owners,
    required this.bases,
    required this.zones,
    this.asm,
    this.post,
    this.choke,
    this.smoke,
    this.slots,
  });

  bool get builtin => terrain == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brief': brief,
        if (image != null) 'image': image,
        if (terrain != null) 'terrain': base64Encode(terrain!),
        if (height != null) 'height': base64Encode(Uint8List.fromList([for (final h in height!) (h.clamp(0.0, 1.0) * 255).round()])),
        'objs': [
          for (int i = 0; i < objs.length; i++)
            {'name': objs[i].name, 'x': objs[i].x, 'y': objs[i].y, 'r': objs[i].r, 'key': objs[i].key, 'owner': i < owners.length ? owners[i] : -1}
        ],
        'bases': bases,
        'zones': [for (final z in zones) [z.x0, z.y0, z.x1, z.y1]],
        if (asm != null) 'asm': asm,
        if (post != null) 'post': post,
        if (choke != null) 'choke': choke,
        if (smoke != null) 'smoke': smoke,
      };

  static MapDef fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v as num).toDouble();
    List<double>? pt(dynamic v) => v == null ? null : [d(v[0]), d(v[1])];
    final objs = <Obj>[], owners = <int>[];
    final jo = (j['objs'] as List?) ?? const [];
    for (int i = 0; i < jo.length; i++) {
      final o = jo[i] as Map<String, dynamic>;
      objs.add(Obj(i, (o['name'] ?? 'Рубеж ${i + 1}') as String, d(o['x']), d(o['y']), d(o['r'] ?? 90), (o['key'] ?? false) as bool));
      owners.add(((o['owner'] ?? -1) as num).toInt());
    }
    // без ключевых рубежей победить захватом нельзя — тогда ключевыми считаются все
    if (objs.isNotEmpty && !objs.any((o) => o.key)) {
      for (int i = 0; i < objs.length; i++) {
        final o = objs[i];
        objs[i] = Obj(o.id, o.name, o.x, o.y, o.r, true);
      }
    }
    Uint8List? ter0;
    Float32List? h0;
    if (j['terrain'] != null) {
      ter0 = base64Decode(j['terrain'] as String);
      if (ter0.length != GW * GH) ter0 = null;
    }
    if (j['height'] != null) {
      final hb = base64Decode(j['height'] as String);
      if (hb.length == GW * GH) h0 = Float32List.fromList([for (final b in hb) b / 255]);
    }
    final zs = ((j['zones'] as List?) ?? const []).map((z) => Zone(d(z[0]), d(z[2]), d(z[1]), d(z[3]))).toList();
    final bs = ((j['bases'] as List?) ?? const []).map((b) => [d(b[0]), d(b[1])]).toList();
    return MapDef(
      id: j['id'] as String,
      name: (j['name'] ?? j['id']) as String,
      brief: (j['brief'] ?? '') as String,
      image: j['image'] as String?,
      terrain: ter0 ?? Uint8List(GW * GH),
      height: h0,
      objs: objs,
      owners: owners,
      bases: bs.length == 2 ? bs : [[W - 50, H / 2], [50, H / 2]],
      zones: zs.length == 2 ? zs : [Zone(W * .58, W - 40, 60, H - 60), Zone(40, W * .23, 60, H - 60)],
      asm: pt(j['asm']),
      post: pt(j['post']),
      choke: pt(j['choke']),
      smoke: pt(j['smoke']),
    );
  }
}

/// Встроенная карта «Переправа у села Дубки».
MapDef builtinMap() => MapDef(
      id: 'crossing',
      name: 'Переправа у села Дубки',
      brief: 'Река делит поле. Наступающим нужно взять и удержать село Дубки и высоту 112.',
      objs: const [],
      owners: const [-1, 0, 0],
      bases: [
        [2350, 740],
        [50, 740]
      ],
      zones: const [Zone(1380, 2360, 60, 1440), Zone(50, 560, 60, 1440)],
      asm: [880, 740],
      post: [760, 700],
      choke: [1150, 740],
      smoke: [1230, 740],
    );

final Map<String, List<List<double>>> _builtinSlots = {for (final e in DEF_SLOTS.entries) e.key: [for (final p in e.value) [...p]]};

MapDef CUR_MAP = builtinMap();

/// Загружает карту в симуляцию: клетки, высоты, рубежи, зоны, базы, точки ИИ.
void applyMap(MapDef m) {
  CUR_MAP = m;
  if (m.builtin) {
    genMap();
    DEF_SLOTS = {for (final e in _builtinSlots.entries) e.key: [for (final p in e.value) [...p]]};
  } else {
    ter.setAll(0, m.terrain!);
    if (m.height != null) {
      hgt.setAll(0, m.height!);
    } else {
      hgt.fillRange(0, hgt.length, 0);
    }
    MAP.objs = m.objs;
    MAP.buildings = [];
    MAP.forests = [];
    MAP.roads = [];
    MAP.trenches = [];
    MAP.fields = [];
    MAP.river = [];
    MAP.craters = [];
  }
  BASE = [for (final b in m.bases) [...b]];
  ZONE = [...m.zones];
  OBJ_OWNER = [...m.owners];
  final atk = 1, def = 0;
  final keys = MAP.objs.where((o) => o.key).toList();
  final firstKey = keys.isNotEmpty ? keys.first : (MAP.objs.isNotEmpty ? MAP.objs.first : null);
  final ab = BASE[atk];
  final tgt = firstKey != null ? [firstKey.x, firstKey.y] : BASE[def];
  AI_ASM = m.asm ?? [lerp(ab[0], tgt[0], .4), lerp(ab[1], tgt[1], .4)];
  AI_POST = m.post ?? [lerp(ab[0], tgt[0], .3), lerp(ab[1], tgt[1], .3)];
  final first = MAP.objs.isNotEmpty ? MAP.objs.first : null;
  AI_CHOKE = m.choke ?? (first != null ? [first.x, first.y] : [...AI_ASM]);
  AI_SMOKE = m.smoke ?? [...AI_CHOKE];
  if (!m.builtin) DEF_SLOTS = m.slots ?? autoSlots();
}

/// Позиции обороны для ИИ на карте из мода: у рубежей обороняющихся, по укрытиям, лицом к противнику.
Map<String, List<List<double>>> autoSlots() {
  const def = 0, atk = 1;
  final z = ZONE[def];
  bool inZ(double x, double y) => x >= z.x0 && x <= z.x1 && y >= z.y0 && y <= z.y1;
  final r = mulberry32(4242);
  final dirA = [BASE[atk][0] - BASE[def][0], BASE[atk][1] - BASE[def][1]];
  final la = math.max(1.0, math.sqrt(dirA[0] * dirA[0] + dirA[1] * dirA[1]));
  final fx = dirA[0] / la, fy = dirA[1] / la; // от обороны к наступающим
  var anchors = MAP.objs.where((o) => o.key && inZ(o.x, o.y)).toList();
  if (anchors.isEmpty) anchors = MAP.objs.where((o) => inZ(o.x, o.y)).toList();
  final centers = anchors.isNotEmpty ? [for (final o in anchors) [o.x, o.y, o.r]] : [[(z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2, 160.0]];
  List<List<double>> pick(int n, double rMin, double rMax, double front, double Function(int c) score) {
    final cand = <(double, List<double>)>[];
    for (int i = 0; i < 400; i++) {
      final ctr = centers[i % centers.length];
      final a = r() * math.pi * 2, rr = ctr[2] * (rMin + r() * (rMax - rMin));
      var x = ctr[0] + math.cos(a) * rr, y = ctr[1] + math.sin(a) * rr;
      // смещение к фронту
      x += fx * front * ctr[2];
      y += fy * front * ctr[2];
      if (!inZ(x, y)) continue;
      final c = cellIdx(x, y);
      if (T_MV_I[ter[c]] == 0) continue;
      cand.add((score(c) + r() * .3, [x, y]));
    }
    cand.sort((a, b) => b.$1.compareTo(a.$1));
    final out = <List<double>>[];
    for (final c in cand) {
      if (out.any((p) => dist(p[0], p[1], c.$2[0], c.$2[1]) < 45)) continue;
      out.add(c.$2);
      if (out.length >= n) break;
    }
    if (out.isEmpty) out.add([centers[0][0], centers[0][1]]);
    return out;
  }

  double cover(int c) => T_COVER[ter[c]];
  return {
    'inf': pick(16, .2, 1.1, .25, (c) => cover(c) * 2),
    'mg': pick(5, .3, 1.0, .45, (c) => cover(c) * 1.5 + hgt[c]),
    'at': pick(4, .4, 1.2, .55, (c) => cover(c) + (ter[c] == Ter.ROAD ? 0 : .3)),
    'sniper': pick(4, .8, 2.2, .1, (c) => hgt[c] * 2 + cover(c)),
    'rear': pick(10, 1.2, 2.6, -.9, (c) => cover(c) * .5),
  };
}
