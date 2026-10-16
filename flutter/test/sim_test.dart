import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubezh/game/battle.dart';
import 'package:rubezh/game/core.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh/game/map.dart';

void main() {
  test('данные: 22 состава, у каждого есть оружие', () {
    expect(VARIANTS.length, 22);
    for (final v in VARIANTS) {
      expect(v.men, isNotEmpty);
      for (final m in v.men) {
        for (final w in m.w) {
          expect(WPN.containsKey(w), true, reason: '${v.id}: $w');
        }
      }
    }
    expect(VARS['tank_t72b3']!.atPen, greaterThan(400));
    expect(VARS['mortar_82']!.mortar, true);
  });

  test('карта: река, мост, дорога проходимы', () {
    genMap();
    final c = <int, int>{};
    for (final t in ter) {
      c[t] = (c[t] ?? 0) + 1;
    }
    print('местность: $c');
    expect(c[Ter.WATER]!, greaterThan(100));
    expect(c[Ter.BRIDGE]!, greaterThan(3));
    expect(c[Ter.BUILD]!, greaterThan(20));
    final p = findPath(100, 740, 2300, 740, true);
    expect(p, isNotNull);
    final p2 = findPath(100, 400, 2000, 900, false);
    expect(p2, isNotNull);
  });

  test('бой ИИ против ИИ', () {
    genMap();
    final res = <String>[];
    int w0 = 0, w1 = 0;
    for (int seed = 1; seed <= 8; seed++) {
      rng = math.Random(seed);
      final b = newBattle(0, 'normal');
      b.autoplay = true;
      final sw = Stopwatch()..start();
      int ticks = 0;
      while (b.over == null && ticks < 15000) {
        step();
        ticks++;
      }
      sw.stop();
      final o = b.over;
      if (o != null) {
        if (o.winner == 0) {
          w0++;
        } else {
          w1++;
        }
      }
      res.add('seed $seed: ${o == null ? "без итога" : "победа ${SIDES[o.winner].short} (${o.why})"} · ${b.t.toStringAsFixed(0)} с · '
          'потери ${b.stats.lost} · техника ${b.stats.veh} · отрядов ${b.squads.where((s) => !s.dead).length} · '
          '${sw.elapsedMilliseconds} мс (${(sw.elapsedMicroseconds / ticks).toStringAsFixed(0)} мкс/шаг)');
    }
    print(res.join('\n'));
    print('ИТОГО: ВСУ $w0, ВС РФ $w1');
    expect(w0 + w1, greaterThan(0));
  });
}
