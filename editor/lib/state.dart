// Состояние редактора: рабочая папка, mod.json, карты, настройки GitHub.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh/game/mapdef.dart';
import 'package:rubezh/mod/codec.dart';
import 'package:rubezh/mod/mod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'files.dart';

class Ed extends ChangeNotifier {
  late Workspace ws;
  Map<String, dynamic> mod = {'version': 1};
  final List<MapDef> maps = [];
  final List<String> mapPaths = [];
  final Map<String, ui.Image> _img = {};
  String owner = 'fedrictic-code', repo = 'rubezh', branch = 'main', token = '';
  String proxy = ''; // host:port, пусто — напрямую
  String toast = '';
  bool ready = false;
  int rev = 0; // счётчик изменений для перерисовки

  SharedPreferences? _prefs;

  Future<void> init({String? root}) async {
    try {
      final pr = await SharedPreferences.getInstance();
      _prefs = pr;
      owner = pr.getString('gh_owner') ?? owner;
      repo = pr.getString('gh_repo') ?? repo;
      branch = pr.getString('gh_branch') ?? branch;
      token = pr.getString('gh_token') ?? '';
      proxy = pr.getString('gh_proxy') ?? '';
    } catch (_) {}
    if (kIsWeb) {
      ws = Workspace('/', memory: true);
    } else {
      String dir;
      if (root != null) {
        dir = root;
      } else {
        String base;
        try {
          base = (await getApplicationDocumentsDirectory()).path;
        } catch (_) {
          base = Directory.systemTemp.path;
        }
        dir = p.join(base, 'RubezhEditor', 'assets');
      }
      ws = Workspace(dir);
    }
    await ws.ensure();
    await reload();
    ready = true;
    notifyListeners();
  }

  void saveGh() {
    final pr = _prefs;
    if (pr == null) return;
    pr.setString('gh_owner', owner);
    pr.setString('gh_repo', repo);
    pr.setString('gh_branch', branch);
    pr.setString('gh_token', token);
    pr.setString('gh_proxy', proxy);
  }

  void say(String s) {
    toast = s;
    notifyListeners();
  }

  /// Перечитать всё с диска и применить мод к данным игры.
  Future<void> reload() async {
    final t = await ws.text(MOD_JSON);
    try {
      mod = (t == null || t.trim().isEmpty) ? {'version': 1} : jsonDecode(t) as Map<String, dynamic>;
    } catch (e) {
      mod = {'version': 1};
      toast = 'mod.json повреждён и был открыт пустым: $e';
    }
    await loadMod(ws);
    maps
      ..clear()
      ..addAll(MOD.maps);
    mapPaths
      ..clear()
      ..addAll([for (final x in (mod['maps'] as List? ?? const [])) x as String]);
    _img.clear();
    rev++;
    notifyListeners();
  }

  /// Записать mod.json и применить.
  Future<void> saveMod() async {
    mod['version'] = 1;
    await ws.writeJson(MOD_JSON, mod);
    MOD.warnings.clear();
    applyModJson(mod);
    rev++;
    notifyListeners();
  }

  Future<ui.Image?> image(String rel) async {
    final c = _img[rel];
    if (c != null) return c;
    final im = await decodeImage(await ws.bytes(rel));
    if (im != null) _img[rel] = im;
    return im;
  }

  void forgetImage(String rel) => _img.remove(rel);

  /* ---------- списки мода ---------- */
  List<Map<String, dynamic>> list(String key) => [for (final x in (mod[key] as List? ?? const [])) x as Map<String, dynamic>];

  Map<String, dynamic>? modItem(String key, String id) {
    for (final x in list(key)) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  void putItem(String key, Map<String, dynamic> item) {
    final l = list(key);
    final i = l.indexWhere((x) => x['id'] == item['id']);
    if (i >= 0) {
      l[i] = item;
    } else {
      l.add(item);
    }
    mod[key] = l;
  }

  void dropItem(String key, String id) {
    mod[key] = list(key).where((x) => x['id'] != id).toList();
  }

  Set<String> get removed => {for (final x in (mod['removed'] as List? ?? const [])) x as String};
  set removed(Set<String> s) => mod['removed'] = s.toList()..sort();

  /// Юнит изменён модом (или добавлен им).
  bool unitChanged(String id) => modItem('units', id) != null;
  bool unitIsBase(String id) => BASE_VARS.containsKey(id);

  Future<void> saveUnit(Map<String, dynamic> u) async {
    putItem('units', u);
    final r = removed..remove(u['id']);
    removed = r;
    await saveMod();
  }

  Future<void> resetUnit(String id) async {
    dropItem('units', id);
    await saveMod();
  }

  Future<void> deleteUnit(String id) async {
    dropItem('units', id);
    if (unitIsBase(id)) removed = removed..add(id);
    await saveMod();
  }

  Future<void> restoreUnit(String id) async {
    removed = removed..remove(id);
    await saveMod();
  }

  /// JSON юнита для редактирования (из мода или из исходных данных).
  Map<String, dynamic> unitJson(String id) {
    final m = modItem('units', id);
    if (m != null) return jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    final v = VARS[id] ?? BASE_VARS[id];
    return v == null ? {} : jsonDecode(jsonEncode(unitToJson(v))) as Map<String, dynamic>;
  }

  /* ---------- карты ---------- */
  Future<void> saveMap(MapDef m) async {
    final rel = 'mod/maps/${m.id}.json';
    await ws.writeJson(rel, m.toJson());
    if (!mapPaths.contains(rel)) {
      mapPaths.add(rel);
      mod['maps'] = mapPaths.toList();
      await saveMod();
    }
    final i = maps.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      maps[i] = m;
    } else {
      maps.add(m);
    }
    rev++;
    notifyListeners();
  }

  Future<void> deleteMap(MapDef m) async {
    final rel = 'mod/maps/${m.id}.json';
    await ws.delete(rel);
    if (m.image != null) await ws.delete(m.image!);
    mapPaths.remove(rel);
    mod['maps'] = mapPaths.toList();
    maps.removeWhere((x) => x.id == m.id);
    await saveMod();
  }
}

final Ed ED = Ed();
