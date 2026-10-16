// Состояние приложения: экран, выбор стороны, состав сил, настройки.
import 'package:flutter/foundation.dart';

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
  bool sound = true, showPerf = false, settingsOpen = false;
  Over? endInfo;
  bool endShown = false;

  void changed() => notifyListeners();

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
