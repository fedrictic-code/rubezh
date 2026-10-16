// Загрузка мода из ресурсов приложения и подготовка карты к бою.
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../game/fxcfg.dart';
import '../game/mapdef.dart';
import '../gfx/render.dart';
import '../gfx/sprites.dart';
import '../mod/mod.dart';

class AssetModSource implements ModSource {
  @override
  Future<String?> text(String path) async {
    try {
      return await rootBundle.loadString('assets/$path');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> bytes(String path) async {
    try {
      final d = await rootBundle.load('assets/$path');
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
}

final AssetModSource ASSETS = AssetModSource();
ui.Image? _builtinTerrain;
String _terrainFor = '';

/// Все карты: встроенная и карты мода.
List<MapDef> allMaps() => [builtinMap(), ...MOD.maps];

/// Загружает мод, графику юнитов и эффектов. Вызывается при запуске.
Future<void> bootMod() async {
  await loadMod(ASSETS);
  Future<ui.Image?> img(String p) async => decodeImage(await ASSETS.bytes(p));
  for (final p in [FX.boom.sprite, FX.big.sprite]) {
    if (p == null) continue;
    final im = await img(p);
    if (im != null) Assets.fxImg[p] = im;
  }
  await SpriteCache.warm(img: img, soldiers: MOD.raw['soldiers'] as Map<String, dynamic>?, looks: BASE_VARS);
}

/// Делает карту текущей: местность (картинка или нарисованная кодом) и разметка для симуляции.
Future<void> prepareMap(MapDef m) async {
  applyMap(m);
  if (_terrainFor == m.id && Assets.terrain != null) return;
  if (m.image == null) {
    _builtinTerrain ??= await renderTerrainImage();
    Assets.terrain = _builtinTerrain;
  } else {
    final im = await decodeImage(await ASSETS.bytes(m.image!));
    Assets.terrain = im ?? (_builtinTerrain ??= await renderTerrainImage());
  }
  _terrainFor = m.id;
}
