// Состояние приложения: экран, выбор стороны, состав сил, настройки.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/battle.dart';
import '../game/data.dart';

enum Screen { loading, menu, force, game }

class AppModel extends ChangeNotifier {
  Screen screen = Screen.loading;
  int side = 0;
  String diff = 'normal';
  final List<Map<String, int>> force = [{}, {}];
  int shopTab = 0;
  String? shopSel;
  bool sound = true, haptics = true, showPerf = false, settingsOpen = false;
  bool tutorial = true; // обучение в следующем бою
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      sound = p.getBool('sound') ?? true;
      haptics = p.getBool('haptics') ?? true;
      tutorial = !(p.getBool('tutDone') ?? false);
      side = p.getInt('side') ?? 0;
      diff = p.getString('diff') ?? 'normal';
    } catch (_) {}
  }

  void save() {
    final p = _prefs;
    if (p == null) return;
    p.setBool('sound', sound);
    p.setBool('haptics', haptics);
    p.setBool('tutDone', !tutorial);
    p.setInt('side', side);
    p.setString('diff', diff);
  }

  Over? endInfo;
  bool endShown = false;

  void changed() {
    save();
    notifyListeners();
  }

  void go(Screen s) {
    screen = s;
    notifyListeners();
  }

  double forceCost(Map<String, int> c) => c.entries.fold(0.0, (s, e) => s + VARS[e.key]!.cost * e.value);
  int forceN(Map<String, int> c) => c.values.fold(0, (s, v) => s + v);
  Map<String, int> presetCounts(int sd) {
    final c = <String, int>{};
    for (final id in PRESET[sd]) {
      c[id] = (c[id] ?? 0) + 1;
    }
    return c;
  }

  List<String> forceList(int sd) {
    final out = <String>[];
    force[sd].forEach((k, n) {
      for (int i = 0; i < n; i++) {
        out.add(k);
      }
    });
    return out;
  }

  double budgetOf(int sd) => BUDGET[sd == 1 ? 1 : 0];
}

final AppModel APP = AppModel();

const List<(String, List<String>)> SHOP_TABS = [
  ('Техника', ['ifv', 'tank']),
  ('Пехота', ['rifle', 'mg', 'sniper']),
  ('ПТ орудия', ['at']),
  ('Поддержка', ['mortar']),
];
