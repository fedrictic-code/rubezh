// Экраны: меню, подбор сил, итог боя, настройки.
import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/model.dart';
import '../game/battle.dart';
import '../game/core.dart';
import '../game/data.dart';
import 'kit.dart';
import 'theme.dart';
import 'widgets.dart';

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(color: const Color(0xEB0E1317), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: child,
          ),
        ),
      );
}


/* ---------- меню ---------- */
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: APP,
      builder: (context, _) => SafeArea(
        child: Column(children: [
          const Spacer(flex: 3),
          Text.rich(
            TextSpan(children: [const TextSpan(text: 'РУ'), TextSpan(text: 'Б', style: TextStyle(color: C.amber)), const TextSpan(text: 'ЕЖ')]),
            style: disp(54, ls: .08).copyWith(shadows: const [Shadow(blurRadius: 24, color: Colors.black)]),
          ),
          Text('ПЕРЕПРАВА У СЕЛА ДУБКИ', style: disp(12, color: C.txt.withValues(alpha: .75), ls: .2).copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black)])),
          const Spacer(flex: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xE60E1317), borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: _SideBtn(0)),
                    const SizedBox(width: 10),
                    Expanded(child: _SideBtn(1)),
                  ]),
                  const SizedBox(height: 10),
                  Seg<String>(
                    items: [for (final e in DIFFS.entries) (e.key, e.value.name)],
                    value: APP.diff,
                    onChanged: (v) {
                      APP.diff = v;
                      APP.changed();
                    },
                  ),
                  const SizedBox(height: 14),
                  BigBtn('В бой', () {
                    if (APP.force[APP.side].isEmpty) APP.force[APP.side] = APP.presetCounts(APP.side);
                    APP.go(Screen.force);
                  }, icon: Icons.play_arrow_rounded, h: 58),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GhostBtn(APP.tutorial ? 'Обучение: вкл' : 'Обучение: выкл', () {
                        APP.tutorial = !APP.tutorial;
                        APP.changed();
                      }, icon: Icons.school_outlined, on: APP.tutorial),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GhostBtn('Настройки', () {
                        APP.settingsOpen = true;
                        APP.changed();
                      }, icon: Icons.settings_outlined),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SideBtn extends StatelessWidget {
  final int s;
  const _SideBtn(this.s);
  @override
  Widget build(BuildContext context) {
    final on = APP.side == s;
    final c = C.side(s);
    return Press(
      sound: true,
      scale: .96,
      onTap: () {
        APP.side = s;
        APP.changed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 84,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: .2) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? c : C.line, width: on ? 2 : 1),
        ),
        child: Row(children: [
          UnitIcon(s == 0 ? 'at' : 'tank', s, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(SIDES[s].name.toUpperCase(), maxLines: 1, style: disp(15)),
              const SizedBox(height: 3),
              Text(s == 0 ? 'Оборона' : 'Наступление', style: body(12.5, color: on ? C.txt : C.mut, w: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/* ---------- подбор сил ---------- */
class ForceScreen extends StatelessWidget {
  const ForceScreen({super.key});

  List<Variant> _list() => variantsFor(APP.side).where((v) => SHOP_TABS[APP.shopTab].$2.contains(v.cls)).toList();

  void _change(int d) {
    final id = APP.shopSel;
    if (id == null) return;
    final c = APP.force[APP.side];
    if (d > 0) {
      if (VARS[id]!.cost > APP.budgetOf(APP.side) - APP.forceCost(c) || APP.forceN(c) >= MAX_UNITS) return;
      c[id] = (c[id] ?? 0) + 1;
    } else {
      if ((c[id] ?? 0) == 0) return;
      c[id] = c[id]! - 1;
      if (c[id] == 0) c.remove(id);
    }
    APP.changed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: APP,
      builder: (context, _) {
        final side = APP.side, c = APP.force[side], budget = APP.budgetOf(side), used = APP.forceCost(c), n = APP.forceN(c), left = budget - used;
        final list = _list();
        if (list.isNotEmpty && !list.any((v) => v.id == APP.shopSel)) APP.shopSel = list[0].id;
        final sel = list.isEmpty ? null : VARS[APP.shopSel];
        final ids = c.keys.toList()..sort((a, b) => TYPE_ORDER.indexOf(VARS[a]!.cls) - TYPE_ORDER.indexOf(VARS[b]!.cls));
        final slots = <String>[for (final id in ids) for (int i = 0; i < c[id]!; i++) id];
        final total = ((slots.length / 4).ceil() * 4).clamp(8, 32);
        return Container(
          color: C.ink,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    child: Row(children: [
                      RoundBtn(icon: Icons.arrow_back, size: 42, onTap: () => APP.go(Screen.menu)),
                      Expanded(
                        child: Column(children: [
                          Text(SIDES[side].name.toUpperCase(), style: disp(17)),
                          Text('${side == 1 ? 'Наступление' : 'Оборона'} · отрядов $n из $MAX_UNITS', style: body(11, color: C.mut)),
                        ]),
                      ),
                      const SizedBox(width: 42),
                    ]),
                  ),
                  SizedBox(
                    height: 38,
                    child: Row(children: [
                      for (int i = 0; i < SHOP_TABS.length; i++)
                        Expanded(
                          child: Press(
                            sound: true,
                            scale: .97,
                            onTap: () {
                              APP.shopTab = i;
                              APP.shopSel = null;
                              APP.changed();
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == APP.shopTab ? C.amber : C.line, width: 2))),
                              child: Text(SHOP_TABS[i].$1, style: body(14, color: i == APP.shopTab ? C.amber : C.mut, w: FontWeight.w700)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final v = list[i];
                        final on = v.id == APP.shopSel, poor = v.cost > left;
                        final k = c[v.id] ?? 0;
                        return Press(
                          sound: true,
                          scale: .95,
                          onTap: () {
                            APP.shopSel = v.id;
                            APP.changed();
                          },
                          child: Opacity(
                            opacity: poor ? .5 : 1,
                            child: Container(
                              width: 112,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: on ? C.amber.withValues(alpha: .1) : const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? C.amber : C.line, width: on ? 1.6 : 1)),
                              child: Stack(children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  Text(v.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(12, w: FontWeight.w700)),
                                  Expanded(child: Center(child: UnitIcon(v.cls, side, size: 46))),
                                  Text('◆ ${v.cost.toInt()}', textAlign: TextAlign.center, style: mono(12, color: C.amber)),
                                ]),
                                if (k > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(color: C.amber, shape: BoxShape.circle),
                                      child: Text('$k', style: mono(11, color: const Color(0xFF1A1405))),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: sel == null
                        ? const SizedBox(height: 60)
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(sel.name + ((c[sel.id] ?? 0) > 0 ? ' × ${c[sel.id]}' : ''), style: body(15, w: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('${sel.desc} · ${sel.hint} · стоимость ${sel.cost.toInt()}', style: body(12, color: C.mut)),
                          ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(children: [
                      Expanded(child: _ShopBtn(Icons.add, 'Купить', sel != null && sel.cost <= left && n < MAX_UNITS, () => _change(1))),
                      const SizedBox(width: 8),
                      Expanded(child: _ShopBtn(Icons.remove, 'Продать', sel != null && (c[sel.id] ?? 0) > 0, () => _change(-1))),
                    ]),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 4,
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.05,
                      children: [
                        for (int i = 0; i < total; i++)
                          i < slots.length
                              ? GestureDetector(
                                  onTap: () {
                                    final cls = VARS[slots[i]]!.cls;
                                    APP.shopTab = SHOP_TABS.indexWhere((t) => t.$2.contains(cls)).clamp(0, 3);
                                    APP.shopSel = slots[i];
                                    APP.changed();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
                                    child: Column(children: [
                                      Expanded(child: UnitIcon(VARS[slots[i]]!.cls, side, size: 30)),
                                      Text(VARS[slots[i]]!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(9, color: C.mut)),
                                    ]),
                                  ),
                                )
                              : Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x14FFFFFF)))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('ОЧКИ', style: disp(11, color: C.mut)),
                        Text('◆ ${left.toInt()} из ${budget.toInt()}', style: mono(14, color: C.amber)),
                      ]),
                      const SizedBox(height: 5),
                      BarLine(used / budget, C.amber, h: 6),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: GhostBtn('Рекомендуемый состав', () {
                          APP.force[side] = APP.presetCounts(side);
                          APP.changed();
                        })),
                        const SizedBox(width: 8),
                        Expanded(
                            child: GhostBtn('Очистить', () {
                          APP.force[side] = {};
                          APP.changed();
                        })),
                      ]),
                      const SizedBox(height: 10),
                      BigBtn('К бою', n > 0 ? CTL.startBattle : null, icon: Icons.check_rounded, h: 56),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShopBtn extends StatelessWidget {
  final IconData ic;
  final String t;
  final bool en;
  final VoidCallback onTap;
  const _ShopBtn(this.ic, this.t, this.en, this.onTap);
  @override
  Widget build(BuildContext context) => GhostBtn(t, en ? onTap : null, icon: ic);
}

/* ---------- итог боя ---------- */
class EndScreen extends StatelessWidget {
  const EndScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final o = APP.endInfo;
    if (o == null || !hasBattle) return const SizedBox.shrink();
    final win = o.winner == S.player;
    final m = S.player, e = 1 - m, st = S.stats;
    Widget row(String a, int x, int y) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(a, style: body(14, color: C.mut))),
            SizedBox(width: 60, child: Text('$x', textAlign: TextAlign.right, style: mono(16, color: C.side(S.player)))),
            SizedBox(width: 90, child: Text('$y', textAlign: TextAlign.right, style: mono(16, color: C.side(1 - S.player)))),
          ]),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Container(
        color: Color.fromRGBO(0, 0, 0, .7 * v.clamp(0.0, 1.0)),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .85 + .15 * v, child: child)),
      ),
      child: _Card(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(win ? Icons.military_tech : Icons.flag_outlined, size: 54, color: win ? C.amber : C.bad),
          Text(win ? 'ПОБЕДА' : 'ПОРАЖЕНИЕ', textAlign: TextAlign.center, style: disp(32, color: win ? C.ok : C.bad, ls: .12)),
          const SizedBox(height: 6),
          Text('${o.why} · ${fmtTime(S.t)} боя', textAlign: TextAlign.center, style: body(13, color: C.mut)),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: SizedBox()),
            SizedBox(width: 60, child: Text('Вы', textAlign: TextAlign.right, style: body(11, color: C.mut))),
            SizedBox(width: 90, child: Text('Противник', textAlign: TextAlign.right, style: body(11, color: C.mut))),
          ]),
          row('Потеряно бойцов', st.lost[m], st.lost[e]),
          row('Потеряно техники', st.veh[m], st.veh[e]),
          row('Рубежей под контролем', S.objs.where((x) => x.owner == m).length, S.objs.where((x) => x.owner == e).length),
          const SizedBox(height: 16),
          BigBtn('Ещё раз', CTL.startBattle),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GhostBtn('В меню', CTL.toMenu)),
            const SizedBox(width: 8),
            Expanded(
                child: GhostBtn('Осмотреть поле', () {
              APP.endShown = false;
              APP.changed();
            })),
          ]),
        ]),
      ),
    );
  }
}

/* ---------- настройки ---------- */
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  Widget _row(String t, Widget w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(t, style: body(15, w: FontWeight.w600))), const SizedBox(width: 10), w]),
      );

  @override
  Widget build(BuildContext context) {
    final inGame = hasBattle && APP.screen == Screen.game;
    void close() {
      APP.settingsOpen = false;
      APP.changed();
    }

    return Container(
      color: const Color(0xB3000000),
      child: _Card(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('НАСТРОЙКИ', style: disp(20))),
            RoundBtn(icon: Icons.close, size: 40, onTap: close),
          ]),
          const SizedBox(height: 10),
          _row('Звук', Toggle(APP.sound, () {
            APP.sound = !APP.sound;
            APP.changed();
          })),
          _row('Вибрация', Toggle(APP.haptics, () {
            APP.haptics = !APP.haptics;
            APP.changed();
          })),
          _row('Обучение в следующем бою', Toggle(APP.tutorial, () {
            APP.tutorial = !APP.tutorial;
            APP.changed();
          })),
          _row('Экономия батареи (30 кадров/с, проще графика)', Toggle(APP.lite, () {
            APP.lite = !APP.lite;
            APP.changed();
          })),
          _row('Счётчик кадров', Toggle(APP.showPerf, () {
            APP.showPerf = !APP.showPerf;
            APP.changed();
          })),
          if (inGame) ...[
            const SizedBox(height: 8),
            GhostBtn('Проверка нагрузки: +120 отрядов', () {
              close();
              CTL.stress(120);
            }, icon: Icons.speed),
            const SizedBox(height: 8),
            GhostBtn('Выйти в меню', () {
              close();
              CTL.toMenu();
            }, icon: Icons.logout),
          ],
          const SizedBox(height: 14),
          BigBtn('Готово', close),
        ]),
      ),
    );
  }
}
