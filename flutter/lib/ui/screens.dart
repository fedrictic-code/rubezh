// Экраны: меню, подбор сил, итог боя, настройки.
import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/model.dart';
import '../game/battle.dart';
import '../game/core.dart';
import '../game/data.dart';
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

Widget _h2(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(t.toUpperCase(), style: disp(11, color: C.mut, ls: .14)));

class BigBtn extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  const BigBtn(this.t, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(12)),
            child: Text(t.toUpperCase(), style: disp(16, color: const Color(0xFF1A1405), ls: .12)),
          ),
        ),
      );
}

class GhostBtn extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  const GhostBtn(this.t, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
          child: Text(t, textAlign: TextAlign.center, style: body(13)),
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
      builder: (context, _) => _Card(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text.rich(
            TextSpan(children: [const TextSpan(text: 'РУ'), TextSpan(text: 'Б', style: TextStyle(color: C.amber)), const TextSpan(text: 'ЕЖ')]),
            style: disp(40, ls: .1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('Тактика в реальном времени · Flutter 0.2', textAlign: TextAlign.center, style: body(12, color: C.mut)),
          const SizedBox(height: 14),
          Text.rich(
            const TextSpan(children: [
              TextSpan(text: 'Переправа у села Дубки. ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: 'Река делит поле боя. Наступающие должны взять и удержать 40 секунд село Дубки и высоту 112. Обороняющимся нужно продержаться 12 минут. Очки подкрепления приносят захваченные рубежи.'),
            ]),
            style: body(13, h: 1.45),
          ),
          _h2('Сторона'),
          Row(children: [
            Expanded(child: _SideBtn(0)),
            const SizedBox(width: 8),
            Expanded(child: _SideBtn(1)),
          ]),
          _h2('Сложность'),
          Row(children: [
            for (final e in DIFFS.entries)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: PillBtn(
                    h: 38,
                    r: 10,
                    on: APP.diff == e.key,
                    onTap: () {
                      APP.diff = e.key;
                      APP.changed();
                    },
                    child: Text(e.value.name),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          BigBtn('В бой', () {
            if (APP.force[APP.side].isEmpty) APP.force[APP.side] = APP.presetCounts(APP.side);
            APP.go(Screen.force);
          }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GhostBtn('Как играть', () => _how(context))),
            const SizedBox(width: 8),
            Expanded(
                child: GhostBtn('Настройки', () {
              APP.settingsOpen = true;
              APP.changed();
            })),
          ]),
        ]),
      ),
    );
  }

  void _how(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.sheet,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle(
            style: body(13, h: 1.5),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Управление', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 10),
              Text('Касание. Коснитесь отряда, затем земли: отряд пойдёт туда. Коснитесь видимого врага: сосредоточить огонь. Пальцем тяните карту, двумя пальцами масштабируйте.'),
              SizedBox(height: 8),
              Text('Мышь. Левая кнопка: выбор и рамка. Правая: приказ. Колесо: масштаб.'),
              SizedBox(height: 8),
              Text('Бой. Огонь подавляет: прижатая пехота не двигается и стреляет хуже, а потом теряет стойкость и отступает. Лес и здания дают укрытие, но закрывают обзор. Окопавшийся отряд получает защиту.'),
              SizedBox(height: 8),
              Text('Поддержка. Миномёт без наблюдателя бьёт неточно. БПЛА открывает карту, FPV бьёт по видимой цели, дым закрывает обзор.'),
            ]),
          ),
        ),
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
    return GestureDetector(
      onTap: () {
        APP.side = s;
        APP.changed();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: on ? c.withValues(alpha: .16) : const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? c : C.line, width: on ? 1.6 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(SIDES[s].name, style: body(15, w: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(s == 0 ? 'Оборона · окопы, высота, ПТРК' : 'Наступление · броня, миномёт', style: body(11, color: C.mut)),
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
                      PillBtn(h: 38, r: 10, onTap: () => APP.go(Screen.menu), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.close, size: 16), SizedBox(width: 4), Text('Отмена')])),
                      Expanded(
                        child: Column(children: [
                          Text(SIDES[side].name.toUpperCase(), style: disp(15)),
                          Text('${side == 1 ? 'Наступление' : 'Оборона'} · отрядов $n из $MAX_UNITS', style: body(11, color: C.mut)),
                        ]),
                      ),
                      PillBtn(h: 38, r: 10, enabled: n > 0, border: C.amber, onTap: CTL.startBattle, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, size: 16, color: C.amber), SizedBox(width: 4), Text('К бою')])),
                    ]),
                  ),
                  SizedBox(
                    height: 38,
                    child: Row(children: [
                      for (int i = 0; i < SHOP_TABS.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              APP.shopTab = i;
                              APP.shopSel = null;
                              APP.changed();
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == APP.shopTab ? C.amber : C.line, width: 2))),
                              child: Text(SHOP_TABS[i].$1, style: body(13, color: i == APP.shopTab ? C.amber : C.mut, w: FontWeight.w700)),
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
                        return GestureDetector(
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
                                  Text(v.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(11, w: FontWeight.w700)),
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
  Widget build(BuildContext context) => PillBtn(h: 44, r: 10, enabled: en, onTap: onTap, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(ic, size: 18), const SizedBox(width: 6), Text(t, style: body(14, w: FontWeight.w700))]));
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
            Expanded(child: Text(a, style: body(13, color: C.mut))),
            SizedBox(width: 70, child: Text('$x', textAlign: TextAlign.right, style: mono(14))),
            SizedBox(width: 90, child: Text('$y', textAlign: TextAlign.right, style: mono(14))),
          ]),
        );
    return Container(
      color: const Color(0xB3000000),
      child: _Card(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(win ? 'ПОБЕДА' : 'ПОРАЖЕНИЕ', textAlign: TextAlign.center, style: disp(32, color: win ? C.ok : C.bad, ls: .12)),
          const SizedBox(height: 6),
          Text('${o.why} · ${fmtTime(S.t)} боя', textAlign: TextAlign.center, style: body(13, color: C.mut)),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: SizedBox()),
            SizedBox(width: 70, child: Text('Вы', textAlign: TextAlign.right, style: body(11, color: C.mut))),
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

  Widget _sw(bool v, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: v ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: v ? C.amber : const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(13)),
          child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB3000000),
      child: _Card(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('НАСТРОЙКИ', style: disp(16)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('Звук', style: body(14))),
            _sw(APP.sound, () {
              APP.sound = !APP.sound;
              APP.changed();
            }),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Счётчик кадров и нагрузки', style: body(14))),
            _sw(APP.showPerf, () {
              APP.showPerf = !APP.showPerf;
              APP.changed();
            }),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Проверка нагрузки: +120 отрядов, ИИ ведёт обе стороны', style: body(14))),
            const SizedBox(width: 10),
            SizedBox(
                width: 100,
                child: GhostBtn('Запустить', hasBattle && APP.screen == Screen.game
                    ? () {
                        APP.settingsOpen = false;
                        APP.changed();
                        CTL.stress(120);
                      }
                    : null)),
          ]),
          const SizedBox(height: 12),
          Text('Графика нарисована кодом. Загрузка собственных картинок появится в следующей версии.', style: body(12, color: C.mut, h: 1.45)),
          const SizedBox(height: 18),
          BigBtn('Готово', () {
            APP.settingsOpen = false;
            APP.changed();
          }),
        ]),
      ),
    );
  }
}
