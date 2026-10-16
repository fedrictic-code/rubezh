// Интерфейс боя в портретной раскладке: верхняя панель, приказы, мини-карта, сетка отрядов, карточка отряда.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/loop.dart';
import '../app/model.dart';
import '../game/battle.dart';
import '../game/combat.dart';
import '../game/core.dart';
import '../game/data.dart';
import '../gfx/render.dart';
import 'theme.dart';
import 'widgets.dart';

class Hud extends StatelessWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([LOOP.hud, CTL, APP]),
      builder: (context, _) {
        if (!hasBattle) return const SizedBox.shrink();
        final dep = S.deploying;
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Stack(children: [
            Positioned(left: 0, right: 0, top: 0, child: _TopBar(dep: dep)),
            if (dep) ...[
              Positioned(
                left: 0,
                right: 0,
                top: 92,
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 340,
                      child: Text('Расставьте отряды на светлой части карты.\nКогда будете готовы, нажмите «Начать».',
                          textAlign: TextAlign.center,
                          style: body(14, color: Colors.white, w: FontWeight.w700, h: 1.35).copyWith(shadows: const [Shadow(blurRadius: 4, color: Colors.black), Shadow(blurRadius: 8, color: Colors.black)])),
                    ),
                  ),
                ),
              ),
              Positioned(right: 2, top: 44, child: _BeginBtn()),
            ],
            Positioned(left: 0, right: 0, bottom: 0, child: _Bottom(dep: dep)),
            if (CTL.deckOpen) const Positioned(left: -8, right: -8, bottom: -6, child: _DeckSheet()),
            if (APP.showPerf)
              Positioned(
                left: 0,
                top: 40,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.black54,
                    child: Text('FPS ${LOOP.perf.fps.toStringAsFixed(0)} · шаг ${LOOP.perf.sim.toStringAsFixed(2)} мс · отрядов ${S.squads.length}', style: mono(10, color: C.ok)),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _BeginBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: CTL.beginBattle,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.amber.withValues(alpha: .7)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A3138), Color(0xFF15191D)]),
            boxShadow: const [BoxShadow(blurRadius: 14, offset: Offset(0, 4), color: Colors.black54)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.keyboard_double_arrow_right, color: C.amber, size: 22),
            Text('НАЧАТЬ', style: disp(11, color: C.amber, ls: .14)),
          ]),
        ),
      );
}

/* ---------- верхняя панель ---------- */
class _TopBar extends StatelessWidget {
  final bool dep;
  const _TopBar({required this.dep});

  Widget _sp(int n) => GestureDetector(
        onTap: () => CTL.setSpeed(n),
        child: Container(
          width: 30,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: S.speed == n ? C.amber.withValues(alpha: .16) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text('$n×', style: mono(12, color: S.speed == n ? C.amber : C.mut)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final left = LIMIT - S.t;
    final inc = S.inc[S.player];
    final keys = S.objs.where((o) => o.key);
    final holdAll = keys.every((x) => x.owner == S.atk);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Glass(
        r: 10,
        pad: const EdgeInsets.all(2),
        child: Row(children: [
          IconBtn(CTL.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, CTL.togglePause),
          _sp(1),
          _sp(2),
          _sp(4),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: dep
            ? const SizedBox.shrink()
            : Row(children: [
                for (final o in S.objs)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _ObjCard(o: o, hold: o.key && S.holdT > 0 && holdAll),
                    ),
                  ),
                if (S.holdT > 0) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _HoldCard())),
              ]),
      ),
      const SizedBox(width: 8),
      Glass(
        r: 10,
        pad: const EdgeInsets.fromLTRB(10, 2, 2, 2),
        child: Row(children: [
          Text(fmtTime(left), style: mono(15)),
          const SizedBox(width: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: '◆ ${S.pts[S.player].floor()}', style: mono(13, color: C.amber)),
            TextSpan(text: ' +${inc.toStringAsFixed(1)}/с', style: mono(10, color: C.mut, w: FontWeight.w500)),
          ])),
          IconBtn(Icons.settings_outlined, () {
            APP.settingsOpen = true;
            APP.changed();
          }),
        ]),
      ),
    ]);
  }
}

class _ObjCard extends StatelessWidget {
  final ObjState o;
  final bool hold;
  const _ObjCard({required this.o, required this.hold});
  @override
  Widget build(BuildContext context) {
    final own = o.owner >= 0 ? SIDES[o.owner].short : 'нейтрально';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 5),
      decoration: glass(r: 9, border: hold ? C.amber.withValues(alpha: .7) : null),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(o.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(10))),
          Text(o.contested ? 'бой' : own, style: body(9, color: C.mut)),
        ]),
        const SizedBox(height: 3),
        Container(
          height: 4,
          decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(2)),
          child: Stack(children: [
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: ((1 - o.ctrl) / 2).clamp(0.0, 1.0), child: Container(color: C.ua))),
            Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: ((1 + o.ctrl) / 2).clamp(0.0, 1.0), child: Container(color: C.ru))),
          ]),
        ),
      ]),
    );
  }
}

class _HoldCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 5),
        decoration: glass(r: 9, border: C.amber.withValues(alpha: .7)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('УДЕРЖАНИЕ', maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(10))),
            Text(S.atk == S.player ? 'цель' : 'угроза', style: body(9, color: C.mut)),
          ]),
          const SizedBox(height: 3),
          BarLine(S.holdT / HOLD_NEED, C.amber, h: 4),
        ]),
      );
}

/* ---------- нижняя часть ---------- */
class _Bottom extends StatelessWidget {
  final bool dep;
  const _Bottom({required this.dep});

  @override
  Widget build(BuildContext context) {
    final sel = CTL.selSquads();
    final now = nowMs();
    final showHint = CTL.toastMsg.isNotEmpty && now < CTL.toastUntil;
    final logs = CTL.log.where((l) => now - l.born < 7200).toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showHint)
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.amber.withValues(alpha: .5))),
            child: Text(CTL.toastMsg, textAlign: TextAlign.center, style: body(12)),
          ),
        ),
      if (logs.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FractionallySizedBox(
              widthFactor: .78,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in logs)
                  GestureDetector(
                    onTap: () {
                      cam.x = l.x;
                      cam.y = l.y;
                      clampCam();
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: now - l.born > 6500 ? 0 : 1,
                      child: Text(l.text, style: body(12, color: _logColor(l.kind), h: 1.3).copyWith(shadows: const [Shadow(blurRadius: 2, color: Colors.black), Shadow(blurRadius: 3, color: Colors.black)])),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      if (!dep && sel.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: _Orders(sel: sel)),
      SizedBox(height: 148, child: _Dock(sel: sel)),
    ]);
  }

  Color _logColor(String k) => switch (k) {
        'good' => const Color(0xFF9EE09A),
        'bad' => const Color(0xFFFF8A6A),
        'warn' => const Color(0xFFF3B04E),
        _ => const Color(0xFFCFD8E0),
      };
}

class _Orders extends StatelessWidget {
  final List<Squad> sel;
  const _Orders({required this.sel});

  Widget _c(String id, IconData ic, String t) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: PillBtn(on: UI.mode == id, onTap: () => CTL.commandBtn(id), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 15), const SizedBox(width: 5), Text(t)])),
      );

  @override
  Widget build(BuildContext context) {
    final anyMortar = sel.any((q) => q.t.mortar);
    final allVeh = sel.every((q) => q.t.veh);
    return SizedBox(
      height: 30,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        _c('move', Icons.arrow_right_alt, 'Движение'),
        _c('fight', Icons.gps_fixed, 'Атака'),
        _c('hold', Icons.shield_outlined, 'Окопаться'),
        _c('retreat', Icons.keyboard_backspace, 'Отход'),
        if (anyMortar) _c('fire', Icons.rocket_launch_outlined, 'Огонь'),
        if (!allVeh) _c('sneak', Icons.visibility_off_outlined, 'Скрытно'),
        if (!allVeh) _c('mount', Icons.directions_bus_outlined, 'Посадка'),
        if (sel.any((q) => q.cargo != 0)) _c('dismount', Icons.logout, 'Высадка'),
      ]),
    );
  }
}

/* ---------- док: мини-карта, отряды, карточка ---------- */
class _Dock extends StatelessWidget {
  final List<Squad> sel;
  const _Dock({required this.sel});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 27, child: _MiniCol()),
      const SizedBox(width: 5),
      Expanded(flex: 29, child: _SqCol()),
      const SizedBox(width: 5),
      Expanded(flex: 44, child: _InfoCol(sel: sel)),
    ]);
  }
}

class _MiniCol extends StatelessWidget {
  void _go(Offset p, Size s) {
    cam.x = p.dx / s.width * W;
    cam.y = p.dy / s.height * H;
    clampCam();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: glass(r: 10, color: C.panel),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 8 / 5,
          child: LayoutBuilder(builder: (context, c) {
            final sz = Size(c.maxWidth, c.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _go(d.localPosition, sz),
              onPanUpdate: (d) => _go(d.localPosition, sz),
              child: ClipRRect(borderRadius: BorderRadius.circular(5), child: CustomPaint(painter: MiniPainter(LOOP.frame), size: sz)),
            );
          }),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: CTL.toggleDeck,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (CTL.deckOpen ? C.amber : C.ok).withValues(alpha: CTL.deckOpen ? .14 : .08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: (CTL.deckOpen ? C.amber : C.ok).withValues(alpha: .5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: CTL.deckOpen ? C.amber : C.ok),
                const SizedBox(width: 4),
                Text('Резерв', style: body(12, color: CTL.deckOpen ? C.amber : C.ok)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SqCol extends StatelessWidget {
  static const _ab = [('drone', Icons.flight, 'БПЛА'), ('fpv', Icons.near_me, 'FPV'), ('smoke', Icons.cloud_outlined, 'Дым'), ('arty', Icons.adjust, 'Арт')];

  @override
  Widget build(BuildContext context) {
    final mine = <int, Squad>{};
    for (final q in S.squads) {
      if (q.side == S.player && !q.dead && q.no > 0) mine[q.no] = q;
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: glass(r: 10),
      child: Column(children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [for (int i = 1; i <= 16; i++) _SqCell(i, mine[i])],
          ),
        ),
        const SizedBox(height: 3),
        Row(children: [
          for (final a in _ab)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: _AbBtn(a.$1, a.$2),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _SqCell extends StatelessWidget {
  final int no;
  final Squad? q;
  const _SqCell(this.no, this.q);
  @override
  Widget build(BuildContext context) {
    final q = this.q;
    if (q == null) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0x14FFFFFF))),
        child: Opacity(opacity: .28, child: Text('$no', style: mono(12, w: FontWeight.w700))),
      );
    }
    final on = S.sel.contains(q.id);
    Color border = const Color(0x24FFFFFF);
    Color txt = C.txt;
    if (q.rout) {
      border = C.bad;
      txt = C.bad;
    } else if (q.supp >= 75) {
      border = C.warn;
    }
    if (on) border = C.amber;
    final mc = q.morale > 60 ? C.ok : (q.morale > 35 ? C.amber : C.bad);
    return GestureDetector(
      onTap: () => CTL.sqTap(no),
      child: Opacity(
        opacity: q.carried != 0 ? .5 : 1,
        child: Container(
          decoration: BoxDecoration(color: on ? C.amber.withValues(alpha: .2) : const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(5), border: Border.all(color: border)),
          child: Stack(alignment: Alignment.center, children: [
            Text('$no', style: mono(12, color: on ? Colors.white : txt, w: FontWeight.w700)),
            Positioned(right: 2, top: 0, child: Text(q.t.veh ? '▬' : (q.t.mortar ? '◔' : ''), style: mono(7, color: C.mut))),
            Positioned(left: 2, right: 2, bottom: 1, child: Container(height: 2, decoration: BoxDecoration(color: mc, borderRadius: BorderRadius.circular(1)))),
          ]),
        ),
      ),
    );
  }
}

class _AbBtn extends StatelessWidget {
  final String k;
  final IconData ic;
  const _AbBtn(this.k, this.ic);
  @override
  Widget build(BuildContext context) {
    final a = S.ab[S.player][k]!;
    final on = UI.mode == k;
    return GestureDetector(
      onTap: () => CTL.abilityBtn(k),
      child: Opacity(
        opacity: a.ch <= 0 ? .45 : 1,
        child: Container(
          height: 30,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(color: on ? C.amber.withValues(alpha: .12) : const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: on ? C.amber : C.line)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(top: 3, child: Icon(ic, size: 15, color: on ? C.amber : C.txt)),
            Positioned(left: 0, right: 0, bottom: 1, child: Text('×${a.ch}', textAlign: TextAlign.center, style: mono(9, color: C.amber))),
            if (a.cd > 0) Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 30 * (a.cd / AB_CD[k]!).clamp(0.0, 1.0), color: const Color(0x8C000000))),
          ]),
        ),
      ),
    );
  }
}

Color _mcol(double v) => v > 60 ? C.ok : (v > 35 ? C.amber : C.bad);

class _InfoCol extends StatelessWidget {
  final List<Squad> sel;
  const _InfoCol({required this.sel});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (sel.isEmpty) {
      child = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Выберите отряд на карте или по номеру слева.', textAlign: TextAlign.center, style: body(11, color: C.mut)),
        const SizedBox(height: 6),
        GestureDetector(onTap: CTL.selectAll, child: Text('Выбрать все', style: body(11, color: C.amber, w: FontWeight.w700))),
      ]);
    } else if (sel.length == 1) {
      child = _OneInfo(q: sel[0]);
    } else {
      child = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const SizedBox(width: 18),
          Expanded(child: Text('Выбрано: ${sel.length}', textAlign: TextAlign.center, style: disp(13))),
          _x(),
        ]),
        Text(CTL.multi ? 'Режим добавления включён' : 'Приказ получат все', style: body(10, color: C.mut)),
        const SizedBox(height: 3),
        Expanded(
          child: ClipRect(
            child: Wrap(spacing: 3, runSpacing: 3, children: [
              for (final q in sel)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(4), border: Border.all(color: C.line)),
                  child: Text('${q.no} ${q.name} · ${q.t.veh ? '${(q.hp / q.hpMax * 100).ceil()}%' : q.men}', style: mono(9, w: FontWeight.w500)),
                ),
            ]),
          ),
        ),
      ]);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      clipBehavior: Clip.hardEdge,
      decoration: glass(r: 10),
      child: child,
    );
  }
}

Widget _x() => GestureDetector(
      onTap: () => CTL.selectOnly(null),
      child: Container(width: 18, height: 18, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(5)), child: const Icon(Icons.close, size: 12)),
    );

class _OneInfo extends StatelessWidget {
  final Squad q;
  const _OneInfo({required this.q});

  String _status() {
    if (q.stance == 'ambush') return 'Засада · огонь по сигналу';
    if (q.stance == 'cease') return 'Огонь запрещён';
    if (q.cargo != 0) return 'Везёт десант · ${S.byId[q.cargo]?.men ?? 0} чел.';
    if (q.sneak) return 'Скрытное движение';
    if (q.rout) return 'Отступает';
    if (q.supp >= 75) return 'Прижаты огнём';
    final o = q.order;
    if (q.tg != null && !q.tg!.dead) return 'Ведёт огонь · ${NM(q.tg!).toLowerCase()}';
    if (o != null) {
      switch (o.kind) {
        case 'move':
          return 'Движется';
        case 'fight':
          return 'Атака · идёт в бой';
        case 'attack':
          return 'Сближается с целью';
        case 'hold':
          return q.fort > .9 ? 'Окопался · защита повышена' : 'Окапывается';
        case 'retreat':
          return 'Отход';
        case 'fire':
          return 'Миномётный огонь';
      }
    }
    return q.fort > .9 ? 'Окопался' : 'Ожидает приказа';
  }

  Color _statusColor() {
    if (q.stance == 'ambush' || q.stance == 'cease') return C.amber;
    if (q.rout) return C.bad;
    if (q.supp >= 75) return C.warn;
    return C.txt;
  }

  Widget _bar(String n, double v, Color c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(n, maxLines: 1, style: body(8, color: C.mut, h: 1.1)),
            const SizedBox(height: 2),
            BarLine(v / 100, c),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final L = loadoutOf(q);
    final main = L.isNotEmpty ? L[0] : null;
    final rounds = main == null ? 0 : main.ammo.values.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const SizedBox(width: 18),
        Expanded(child: Text(q.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: disp(13))),
        _x(),
      ]),
      const SizedBox(height: 3),
      Row(children: [
        Expanded(
          flex: 3,
          child: _MiniBtn(q.stance == 'cease' ? 'Не стрелять' : 'Огонь по готовн.', q.stance == 'cease', () => CTL.commandBtn('cease')),
        ),
        const SizedBox(width: 3),
        Expanded(flex: 2, child: _MiniBtn('Засада', q.stance == 'ambush', () => CTL.commandBtn('ambush'))),
      ]),
      const SizedBox(height: 3),
      Row(children: [
        UnitIcon(q.type, q.side, size: 30),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            q.t.veh
                ? Row(children: [
                    Expanded(child: BarLine(q.hp / q.hpMax, _mcol(q.hp / q.hpMax * 100), h: 5)),
                    const SizedBox(width: 4),
                    Text('${q.hp.ceil()}%', style: mono(10)),
                  ])
                : Wrap(spacing: 2, runSpacing: 2, children: [
                    for (int i = 0; i < q.max; i++)
                      Container(width: 7, height: 10, decoration: BoxDecoration(color: i < q.men ? C.txt : const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(2))),
                  ]),
            const SizedBox(height: 2),
            Text(_status(), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, color: _statusColor())),
          ]),
        ),
      ]),
      const SizedBox(height: 3),
      GestureDetector(
        onTap: () {
          CTL.infoOpen = !CTL.infoOpen;
          CTL.changed();
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(main != null ? main.n + (main.c > 1 ? ' ×${main.c}' : '') : q.t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, color: C.mut))),
          Text(main != null && rounds > 0 ? '▮ ×$rounds' : '', style: mono(10, color: C.amber)),
        ]),
      ),
      const Spacer(),
      if (CTL.infoOpen)
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Wrap(spacing: 3, runSpacing: 3, children: [
              for (final e in L)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(4), border: Border.all(color: C.line)),
                  child: Text(
                      e.n + (e.c > 1 ? ' ×${e.c}' : '') + ((e.k == 'rifle' || e.k == 'mg' || e.k == 'hmg') ? '' : ' ${e.ammo.entries.map((a) => '${AMMO[a.key]!.n} ${a.value}').join(', ')}'),
                      style: mono(9, w: FontWeight.w500)),
                ),
            ]),
          ),
        )
      else
        Row(children: [
          _bar('Стойк.', q.morale, _mcol(q.morale)),
          _bar('Подавл.', q.supp, C.warn),
          _bar('Боезап.', q.ammo, C.mut),
        ]),
    ]);
  }
}

class _MiniBtn extends StatelessWidget {
  final String t;
  final bool on;
  final VoidCallback onTap;
  const _MiniBtn(this.t, this.on, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? C.amber.withValues(alpha: .14) : const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(5), border: Border.all(color: on ? C.amber : C.line)),
          child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, color: on ? C.amber : C.txt)),
        ),
      );
}

/* ---------- подкрепление ---------- */
class _DeckSheet extends StatelessWidget {
  const _DeckSheet();
  @override
  Widget build(BuildContext context) {
    final pts = S.pts[S.player].floor();
    final q = S.queue.where((x) => x.side == S.player).toList();
    final list = <Variant>[];
    for (final c in TYPE_ORDER) {
      for (final t in variantsFor(S.player)) {
        if (t.cls == c) list.add(t);
      }
    }
    final maxH = MediaQuery.of(context).size.height * .62;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: C.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: C.line)),
        boxShadow: [BoxShadow(blurRadius: 30, offset: Offset(0, -10), color: Colors.black54)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('ПОДКРЕПЛЕНИЕ', style: disp(13, ls: .1)),
          const SizedBox(width: 10),
          Text('◆ $pts', style: mono(13, color: C.amber)),
          const Spacer(),
          GestureDetector(
            onTap: CTL.toggleDeck,
            child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, size: 18)),
          ),
        ]),
        const SizedBox(height: 6),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in list)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 24 - 6) / 2,
                  child: _UnitCard(t: t, enabled: pts >= t.cost),
                ),
            ]),
          ),
        ),
        if (q.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Text('В пути:', style: body(11, color: C.mut)),
            for (final x in q) Text('${VARS[x.type]!.name} · ${math.max(0, (x.at - S.t).ceil())} с', style: body(11, color: C.amber)),
          ]),
        ],
      ]),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Variant t;
  final bool enabled;
  const _UnitCard({required this.t, required this.enabled});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              if (buyUnit(S.player, t.id)) CTL.changed();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(9), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UnitIcon(t.cls, S.player, size: 26),
              const SizedBox(width: 6),
              Expanded(child: Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, w: FontWeight.w700))),
              Text('◆ ${t.cost.toInt()}', style: mono(11, color: C.amber)),
            ]),
            const SizedBox(height: 3),
            Text('${t.desc} · ${t.hint} · прибытие ${t.delay.toInt()} с', maxLines: 3, overflow: TextOverflow.ellipsis, style: body(10, color: C.mut)),
          ]),
        ),
      ),
    );
  }
}
