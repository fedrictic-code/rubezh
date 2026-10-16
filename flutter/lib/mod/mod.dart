// Мод: свои карты, юниты, оружие, звуки, эффекты и графика. Файлы лежат в assets/mod/.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../game/battle.dart';
import '../game/data.dart';
import '../game/fxcfg.dart';
import '../game/mapdef.dart';
import 'codec.dart';

/// Откуда читать файлы мода: в игре — ресурсы приложения, в редакторе — папка на диске.
abstract class ModSource {
  /// path — путь внутри assets/, например «mod/mod.json».
  Future<String?> text(String path);
  Future<Uint8List?> bytes(String path);
}

const String MOD_JSON = 'mod/mod.json';

class ModInfo {
  final List<MapDef> maps = [];
  final List<String> warnings = [];
  Map<String, dynamic> raw = {};
}

final ModInfo MOD = ModInfo();

/// Юниты до применения мода — нужны для «look» (чей нарисованный вид взять) и для сброса.
final Map<String, Variant> BASE_VARS = {for (final v in VARIANTS) v.id: v};
final Map<String, Ammo> BASE_AMMO = Map.of(AMMO);
final Map<String, Wpn> BASE_WPN = Map.of(WPN);
final Map<String, Arm> BASE_ARM = Map.of(ARM);

Future<ui.Image?> decodeImage(Uint8List? b) async {
  if (b == null || b.isEmpty) return null;
  try {
    final codec = await ui.instantiateImageCodec(b);
    final f = await codec.getNextFrame();
    return f.image;
  } catch (_) {
    return null;
  }
}

/// Читает mod.json и применяет его к данным игры. Возвращает сведения о картах и предупреждения.
Future<ModInfo> loadMod(ModSource src) async {
  MOD.maps.clear();
  MOD.warnings.clear();
  final txt = await src.text(MOD_JSON);
  Map<String, dynamic> j = {};
  if (txt != null && txt.trim().isNotEmpty) {
    try {
      j = jsonDecode(txt) as Map<String, dynamic>;
    } catch (e) {
      MOD.warnings.add('mod.json не читается: $e');
    }
  }
  MOD.raw = j;
  applyModJson(j);
  for (final p in (j['maps'] as List? ?? const [])) {
    final mt = await src.text(p as String);
    if (mt == null) {
      MOD.warnings.add('Нет файла карты $p');
      continue;
    }
    try {
      MOD.maps.add(MapDef.fromJson(jsonDecode(mt) as Map<String, dynamic>));
    } catch (e) {
      MOD.warnings.add('Карта $p не читается: $e');
    }
  }
  return MOD;
}

/// Применяет данные мода (без файлов): боеприпасы, оружие, броня, юниты, составы, звуки, эффекты.
void applyModJson(Map<String, dynamic> j) {
  // снимок исходных данных берётся до первых изменений
  if (BASE_VARS.isEmpty || BASE_AMMO.isEmpty || BASE_WPN.isEmpty || BASE_ARM.isEmpty) return;
  // сброс к исходным данным, чтобы повторное применение не копило изменения
  AMMO
    ..clear()
    ..addAll(BASE_AMMO);
  WPN
    ..clear()
    ..addAll(BASE_WPN);
  ARM
    ..clear()
    ..addAll(BASE_ARM);
  for (final a in (j['ammo'] as List? ?? const [])) {
    try {
      final x = ammoFromJson(a as Map<String, dynamic>);
      AMMO[x.id] = x;
    } catch (e) {
      MOD.warnings.add('Боеприпас: $e');
    }
  }
  for (final a in (j['armor'] as List? ?? const [])) {
    try {
      ARM[(a as Map<String, dynamic>)['id'] as String] = armFromJson(a);
    } catch (e) {
      MOD.warnings.add('Броня: $e');
    }
  }
  for (final w in (j['weapons'] as List? ?? const [])) {
    try {
      final x = wpnFromJson(w as Map<String, dynamic>);
      final miss = x.a.where((k) => !AMMO.containsKey(k)).toList();
      if (miss.isNotEmpty) {
        MOD.warnings.add('Оружие ${x.id}: нет боеприпасов ${miss.join(', ')}');
        continue;
      }
      WPN[x.id] = x;
    } catch (e) {
      MOD.warnings.add('Оружие: $e');
    }
  }
  // юниты пересобираются, чтобы учесть изменённое оружие
  final list = <Variant>[for (final v in BASE_VARS.values) unitFromJson(unitToJson(v))];
  final removed = <String>{for (final r in (j['removed'] as List? ?? const [])) r as String};
  for (final u in (j['units'] as List? ?? const [])) {
    try {
      final v = unitFromJson(u as Map<String, dynamic>);
      final err = checkUnit(v);
      if (err.isNotEmpty) {
        MOD.warnings.add('${v.name}: ${err.join('; ')}');
        continue;
      }
      final i = list.indexWhere((x) => x.id == v.id);
      if (i >= 0) {
        list[i] = v;
      } else {
        list.add(v);
      }
    } catch (e) {
      MOD.warnings.add('Юнит: $e');
    }
  }
  list.removeWhere((v) => removed.contains(v.id));
  VARIANTS
    ..clear()
    ..addAll(list);
  rebuildVars();
  final pr = j['presets'] as List?;
  if (pr != null && pr.length == 2) {
    for (int s = 0; s < 2; s++) {
      final ids = [for (final x in pr[s] as List) x as String].where(VARS.containsKey).toList();
      if (ids.isNotEmpty) PRESET[s] = ids;
    }
  }
  for (int s = 0; s < 2; s++) {
    PRESET[s] = PRESET[s].where(VARS.containsKey).toList();
  }
  final b = j['budget'] as List?;
  if (b != null && b.length == 2) {
    BUDGET[0] = (b[0] as num).toDouble();
    BUDGET[1] = (b[1] as num).toDouble();
  }
  final snd = defaultSounds();
  SOUNDS
    ..clear()
    ..addAll(snd);
  final js = j['sounds'] as Map<String, dynamic>?;
  if (js != null) {
    js.forEach((k, v) {
      final l = [for (final p in v as List) p as String];
      if (l.isNotEmpty) SOUNDS[k] = l;
    });
  }
  final fresh = FxCfg();
  FX.load(fresh.toJson());
  FX.load(j['fx'] as Map<String, dynamic>?);
}

/// Список картинок, которые нужны моду (графика юнитов и эффектов).
List<String> modImagePaths() {
  final out = <String>{};
  for (final v in VARIANTS) {
    final a = v.art;
    if (a == null) continue;
    if (a.hull != null) out.add(a.hull!);
    if (a.turret != null) out.add(a.turret!);
  }
  if (FX.boom.sprite != null) out.add(FX.boom.sprite!);
  if (FX.big.sprite != null) out.add(FX.big.sprite!);
  final sol = MOD.raw['soldiers'] as Map<String, dynamic>?;
  sol?.forEach((_, m) => (m as Map<String, dynamic>).forEach((_, p) => out.add(p as String)));
  return out.toList();
}
