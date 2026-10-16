import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubezh/game/battle.dart';
import 'package:rubezh/game/core.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh/game/fxcfg.dart';
import 'package:rubezh/game/map.dart';
import 'package:rubezh/game/mapdef.dart';
import 'package:rubezh/mod/codec.dart';
import 'package:rubezh/mod/mod.dart';

void main() {
  test('юниты: JSON туда и обратно без потерь', () {
    for (final v in VARIANTS) {
      final j = unitToJson(v);
      final v2 = unitFromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
      expect(unitToJson(v2), j, reason: v.id);
      expect(v2.range, v.range, reason: v.id);
      expect(v2.atPen, v.atPen, reason: v.id);
    }
    for (final w in WPN.values) {
      expect(wpnToJson(wpnFromJson(wpnToJson(w))), wpnToJson(w));
    }
    for (final a in AMMO.values) {
      expect(ammoToJson(ammoFromJson(ammoToJson(a))), ammoToJson(a));
    }
  });

  test('мод: новый танк, новое оружие, звуки, эффекты', () {
    final base = VARIANTS.length;
    final t72 = unitToJson(VARS['tank_t72b3']!);
    final mod = {
      'ammo': [
        {'id': 'apfsds_new', 'k': 'AP', 'n': 'Новый БОПС', 'pen': [650, 600], 'supp': 12, 'spd': 1700, 'cal': 125}
      ],
      'weapons': [
        {'id': 'gun_new', 'n': 'Новая пушка', 'k': 'cannon', 'rpm': 8, 'mag': 1, 'rl': 6, 'rng': 1100, 'acc': .8, 'a': ['apfsds_new'], 'job': 'gunner', 'auto': true}
      ],
      'units': [
        {
          ...t72,
          'id': 'tank_new',
          'name': 'Т-72Б3М',
          'look': 'tank_t72b3',
          'men': [
            {'job': 'driver', 'w': [], 'a': {}},
            {'job': 'gunner', 'w': ['gun_new'], 'a': {'apfsds_new': 20}},
            {'job': 'commander', 'w': [], 'a': {}},
          ],
        },
        {'id': 'broken', 'cls': 'rifle', 'men': [{'job': 'rifle', 'w': ['no_such_gun'], 'a': {}}]},
      ],
      'removed': ['sniper_ru'],
      'sounds': {'shot_cannon': ['mod/sfx/gun.wav']},
      'fx': {'tracerWidth': 2.0, 'big': {'sparks': 12}},
    };
    applyModJson(jsonDecode(jsonEncode(mod)) as Map<String, dynamic>);
    expect(VARS.containsKey('tank_new'), true);
    expect(VARS['tank_new']!.atPen, 650);
    expect(VARS.containsKey('broken'), false);
    expect(VARS.containsKey('sniper_ru'), false);
    expect(VARIANTS.length, base); // +1 новый, −1 удалённый, сломанный не добавлен
    expect(SOUNDS['shot_cannon'], ['mod/sfx/gun.wav']);
    expect(FX.tracerWidth, 2.0);
    expect(FX.big.sparks, 12);
    expect(PRESET[1].contains('sniper_ru'), false);
    // повторное применение пустого мода возвращает всё как было
    applyModJson({});
    expect(VARS.containsKey('tank_new'), false);
    expect(VARS.containsKey('sniper_ru'), true);
    expect(FX.tracerWidth, 1.3);
  });

  test('карта из мода: разметка, рубежи, бой ИИ', () {
    final t = Uint8List(GW * GH);
    // река поперёк с бродом посередине, лес слева
    for (int y = 0; y < GH; y++) {
      for (int x = 0; x < GW; x++) {
        if (x >= 58 && x <= 61) t[y * GW + x] = (y > 34 && y < 40) ? Ter.BRIDGE : Ter.WATER;
        if (x > 20 && x < 30 && y > 10 && y < 30) t[y * GW + x] = Ter.FOREST;
      }
    }
    final j = {
      'id': 'test',
      'name': 'Проверка',
      'terrain': base64Encode(t),
      'objs': [
        {'name': 'Мост', 'x': 1200, 'y': 740, 'r': 80, 'key': false, 'owner': -1},
        {'name': 'Хутор', 'x': 1800, 'y': 500, 'r': 110, 'key': true, 'owner': 0},
      ],
      'bases': [[2350, 740], [50, 740]],
      'zones': [[1400, 60, 2360, 1440], [50, 60, 560, 1440]],
    };
    final m = MapDef.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
    expect(m.builtin, false);
    final back = MapDef.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect(back.objs.length, 2);
    applyMap(m);
    expect(MAP.objs.length, 2);
    expect(ter[cellIdx(1200, 500)], Ter.WATER);
    expect(DEF_SLOTS['inf']!.length, greaterThan(3));
    rng = math.Random(3);
    final b = newBattle(0, 'normal');
    b.autoplay = true;
    int ticks = 0;
    while (b.over == null && ticks < 6000) {
      step();
      ticks++;
    }
    print('карта из мода: ${b.over?.why ?? "без итога"} · ${b.t.toStringAsFixed(0)} с · потери ${b.stats.lost}');
    expect(b.squads.length, greaterThan(10));
    // возврат к встроенной карте
    applyMap(builtinMap());
    expect(MAP.objs.length, 3);
    expect(BASE[1][0], 50);
  });
}
