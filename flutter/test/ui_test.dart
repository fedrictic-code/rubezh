import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubezh/app/controller.dart';
import 'package:rubezh/app/model.dart';
import 'package:rubezh/game/battle.dart';
import 'package:rubezh/gfx/render.dart';
import 'package:rubezh/ui/hud.dart';
import 'package:rubezh/ui/screens.dart';

Future<void> tapText(WidgetTester t, String s) async {
  await t.tap(find.text(s).first, warnIfMissed: true);
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('настройки: переключатели', (t) async {
    t.view.physicalSize = const Size(412 * 3, 880 * 3);
    t.view.devicePixelRatio = 3;
    APP.sound = true;
    APP.haptics = true;
    APP.settingsOpen = true;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AnimatedBuilder(animation: APP, builder: (_, __) => const SettingsSheet()))));
    await tapText(t, 'Звук');
    expect(APP.sound, false);
    await tapText(t, 'Звук');
    expect(APP.sound, true);
    await tapText(t, 'Вибрация');
    expect(APP.haptics, false);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('бой: нижние кнопки', (t) async {
    t.view.physicalSize = const Size(412 * 3, 880 * 3);
    t.view.devicePixelRatio = 3;
    View.w = 412;
    View.h = 880;
    APP.tutorial = false;
    APP.force[0] = APP.presetCounts(0);
    UI.menu = false;
    CTL.startBattle();
    CTL.beginBattle();
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Hud())));
    await t.pump(const Duration(milliseconds: 100));

    await t.tap(find.byIcon(Icons.pause_rounded));
    await t.pump(const Duration(milliseconds: 50));
    expect(CTL.paused, true, reason: 'пауза');
    await t.tap(find.text('1×'));
    await t.pump(const Duration(milliseconds: 50));
    expect(S.speed, 2, reason: 'скорость');

    await tapText(t, 'Все');
    expect(S.sel.isNotEmpty, true, reason: 'выбрать все');
    await tapText(t, 'Атака');
    expect(UI.mode, 'fight', reason: 'атака');
    await tapText(t, 'Атака');
    expect(UI.mode, null, reason: 'атака повторно');
    await tapText(t, 'Окоп');
    expect(S.sel.map((id) => S.byId[id]!).every((q) => q.order?.kind == 'hold' || q.t.veh || q.carried != 0), true, reason: 'окоп');
    await tapText(t, 'Ещё');
    expect(CTL.moreOpen, true, reason: 'ещё');
    await tapText(t, 'Назад');
    expect(CTL.moreOpen, false);

    await tapText(t, 'БПЛА');
    expect(UI.mode, 'drone', reason: 'БПЛА');
    await tapText(t, 'Резерв');
    expect(CTL.deckOpen, true, reason: 'резерв');
    await t.pump(const Duration(seconds: 1));

    // чип отряда: обычное касание выбирает только его
    CTL.toggleDeck();
    await t.pump(const Duration(milliseconds: 100));
    final q = S.squads.firstWhere((x) => x.side == S.player && x.no == 2);
    await t.tap(find.text('2').last);
    await t.pump(const Duration(milliseconds: 50));
    expect(S.sel.length, 1, reason: 'один отряд');
    expect(S.sel.contains(q.id), true);
    await t.pump(const Duration(seconds: 2));
  });
}
