// Демонстрационные данные для веб-версии редактора (снимки экрана в CI).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:rubezh/game/core.dart';
import 'package:rubezh/game/map.dart';
import 'package:rubezh/game/mapdef.dart';
import 'package:rubezh/gfx/render.dart';

import 'state.dart';

Future<void> seedDemo() async {
  if (ED.maps.isNotEmpty) return;
  genMap();
  final im = await renderTerrainImage();
  final bd = await im.toByteData(format: ui.ImageByteFormat.png);
  if (bd == null) return;
  const rel = 'mod/maps/demo.png';
  await ED.ws.write(rel, bd.buffer.asUint8List());
  final b = builtinMap();
  final m = MapDef(
    id: 'demo',
    name: 'Демо: переправа',
    brief: 'Пример карты из картинки',
    image: rel,
    terrain: Uint8List.fromList(ter),
    height: Float32List.fromList(hgt),
    objs: [...MAP.objs],
    owners: [...b.owners],
    bases: b.bases,
    zones: [...b.zones],
    asm: b.asm,
    choke: b.choke,
  );
  await ED.saveMap(m);
}
