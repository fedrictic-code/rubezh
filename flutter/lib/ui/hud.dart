// Интерфейс боя (портрет). Сверху — только сведения, всё управление — внизу, в зоне большого пальца.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/loop.dart';
import '../app/model.dart';
import '../app/tutorial.dart';
import '../game/battle.dart';
import '../game/combat.dart';
import '../game/core.dart';
import '../game/data.dart';
import '../gfx/render.dart';
import 'coach.dart';
import 'kit.dart';
import 'theme.dart';
import 'widgets.dart';

const _shadow = [Shadow(blurRadius: 3, color: Colors.black), Shadow(blurRadius: 6, color: Colors.black)];

class Hud extends StatelessWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([LOOP.hud, CTL, APP, TUT]),
      builder: (context, _) {
        if (!hasBattle) return const SizedBox.shrink();
        final dep = S.deploying;
        final sel = CTL.selSquads();
        return Stack(children: [
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Stack(children: [
              Positioned(left: 0, right: 0, top: 0, child: _Top(dep: dep)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Toast(),
                  if (!dep && sel.isNotEmpty) ...[_InfoCard(sel: sel), const SizedBox(height: 6), _Orders(sel: sel), const SizedBox(height: 8)],
                  if (dep) ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: KeyedSubtree(key: TUT.keys['begin'], child: BigBtn('В бой', CTL.beginBattle, icon: Icons.keyboard_double_arrow_right))),
                    const SizedBox(height: 10),
                  ] else ...[
                    _ActionRow(),
                    const SizedBox(height: 8),
                  ],
                  KeyedSubtree(key: TUT.keys['strip'], child: _Strip()),
                ]),
              ),
            ]),
          ),
          if (CTL.deckOpen) Positioned(left: 0, right: 0, bottom: 0, child: _DeckSheet()),
          const RepaintBoundary(child: CoachLayer()),
          if (APP.showPerf)
            Positioned(
              left: 8,
              bottom: 4,
              child: IgnorePointer(
                child: Text('FPS ${LOOP.perf.fps.toStringAsFixed(0)} · шаг ${LOOP.perf.sim.toStringAsFixed(2)} мс · отрядов ${S.squads.length}', style: mono(10, color: C.ok).copyWith(shadows: _shadow)),
              ),
            ),
        ]);
      },
    );
  }
}

/* ---------- верх: время, очки, рубежи, мини-карта, журнал ---------- */
class _Top extends StatelessWidget {
  final bool dep;
  const _Top({required this.dep});

  @override
  Widget build(BuildContext context) {
    final left = LIMIT - S.t;
    final inc = S.inc[S.player];
    final keys = S.objs.where((o) => o.key);
    final holdAll = keys.every((x) => x.owner == S.atk);
    final now = nowMs();
    final logs = CTL.log.where((l) => now - l.born < 7200).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: glass(r: 20),
          child: Row(children: [
            Icon(Icons.schedule, size: 15, color: left < 60 ? C.bad : C.mut),
            const SizedBox(width: 5),
            Text(fmtTime(left), style: mono(16, color: left < 60 ? C.bad : C.txt)),
            Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 10), color: C.line),
            Text('◆ ${S.pts[S.player].floor()}', style: mono(16, color: C.amber)),
            Text('  +${inc.toStringAsFixed(1)}', style: mono(11, color: C.mut, w: FontWeight.w500)),
          ]),
        ),
        const Spacer(),
        RoundBtn(
          icon: Icons.settings_outlined,
          size: 40,
          onTap: () {
            APP.settingsOpen = true;
            APP.changed();
          },
        ),
      ]),
      if (!dep) ...[
        const SizedBox(height: 6),
        Row(children: [
          for (final o in S.objs) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.5), child: _ObjCard(o: o, hold: o.key && S.holdT > 0 && holdAll))),
        ]),
        if (S.holdT > 0) Padding(padding: const EdgeInsets.fromLTRB(2.5, 5, 2.5, 0), child: _HoldBar()),
      ],
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in logs)
              Press(
                onTap: () {
                  cam.x = l.x;
                  cam.y = l.y;
                  clampCam();
                },
                scale: .98,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: now - l.born > 6500 ? 0 : 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(l.text, maxLines: 2, style: body(12.5, color: _logColor(l.kind), w: FontWeight.w600, h: 1.25).copyWith(shadows: _shadow)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        _Mini(),
      ]),
    ]);
  }

  Color _logColor(String k) => switch (k) {
        'good' => const Color(0xFFA6E8A2),
        'bad' => const Color(0xFFFF9478),
        'warn' => const Color(0xFFF5BC5C),
        _ => const Color(0xFFE2E8EE),
      };
}

class _ObjCard extends StatelessWidget {
  final ObjState o;
  final bool hold;
  const _ObjCard({required this.o, required this.hold});
  @override
  Widget build(BuildContext context) {
    final col = o.contested ? C.warn : (o.owner >= 0 ? C.side(o.owner) : C.mut);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        color: o.owner >= 0 ? Color.alphaBlend(C.side(o.owner).withValues(alpha: .16), C.panel) : C.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hold ? C.amber : col.withValues(alpha: .55), width: hold ? 1.6 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Expanded(child: Text(o.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(10.5))),
        ]),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: o.ctrl.abs().clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(color: o.ctrl > 0 ? C.ru : C.ua, borderRadius: BorderRadius.circular(2))),
          ),
        ),
      ]),
    );
  }
}

class _HoldBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: glass(r: 10, border: C.amber),
        child: Row(children: [
          Text(S.atk == S.player ? 'УДЕРЖАНИЕ' : 'ПРОТИВНИК УДЕРЖИВАЕТ', style: disp(10.5, color: C.amber)),
          const SizedBox(width: 10),
          Expanded(child: BarLine(S.holdT / HOLD_NEED, C.amber, h: 5)),
          const SizedBox(width: 8),
          Text('${math.max(0, HOLD_NEED - S.holdT).ceil()} с', style: mono(12, color: C.amber)),
        ]),
      );
}

class _Mini extends StatelessWidget {
  const _Mini();
  void _go(Offset p, Size s) {
    LOOP.poke();
    cam.x = p.dx / s.width * W;
    cam.y = p.dy / s.height * H;
    clampCam();
  }

  @override
  Widget build(BuildContext context) {
    const w = 124.0, h = w * H / W;
    return Container(
      width: w + 6,
      height: h + 6,
      padding: const EdgeInsets.all(3),
      decoration: glass(r: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _go(d.localPosition, const Size(w, h)),
        onPanUpdate: (d) => _go(d.localPosition, const Size(w, h)),
        child: RepaintBoundary(child: ClipRRect(borderRadius: BorderRadius.circular(7), child: CustomPaint(painter: MiniPainter(LOOP.hud), size: const Size(w, h)))),
      ),
    );
  }
}

/* ---------- подсказка ---------- */
class _Toast extends StatelessWidget {
  const _Toast();
  @override
  Widget build(BuildContext context) {
    final show = CTL.toastMsg.isNotEmpty && nowMs() < CTL.toastUntil;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: c)),
      child: !show
          ? const SizedBox.shrink(key: ValueKey(''))
          : Padding(
              key: ValueKey(CTL.toastMsg),
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.amber.withValues(alpha: .6))),
                  child: Text(CTL.toastMsg, textAlign: TextAlign.center, style: body(13.5, w: FontWeight.w600)),
                ),
              ),
            ),
    );
  }
}

/* ---------- ряд действий: пауза, скорость | способности, резерв ---------- */
class _ActionRow extends StatelessWidget {
  const _ActionRow();
  static const _ab = [('drone', Icons.flight, 'БПЛА'), ('fpv', Icons.near_me, 'FPV'), ('smoke', Icons.cloud_outlined, 'Дым'), ('arty', Icons.adjust, 'Арт')];

  @override
  Widget build(BuildContext context) {
    final pts = S.pts[S.player];
    double cheap = 1e9;
    for (final v in variantsFor(S.player)) {
      cheap = math.min(cheap, v.cost);
    }
    final q = S.queue.where((x) => x.side == S.player).length;
    return LayoutBuilder(builder: (context, c) {
    final sz = ((c.maxWidth - 64) / 7).clamp(38.0, 50.0);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RoundBtn(icon: CTL.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: sz, on: CTL.paused, onTap: CTL.togglePause),
      const SizedBox(width: 6),
      RoundBtn(text: '${S.speed.toInt()}×', size: sz, onTap: () => CTL.setSpeed(S.speed >= 4 ? 1 : (S.speed * 2).toInt())),
      const Spacer(),
      for (final a in _ab) ...[
        Builder(builder: (_) {
          final ab = S.ab[S.player][a.$1]!;
          final ready = ab.ch > 0 && ab.cd <= 0;
          final w = RoundBtn(
            icon: a.$2,
            label: a.$3,
            size: sz,
            badge: '${ab.ch}',
            on: UI.mode == a.$1,
            enabled: ab.ch > 0,
            ready: ready,
            cd: ab.cd > 0 ? (ab.cd / AB_CD[a.$1]!).clamp(0.0, 1.0) : 0,
            onTap: () => CTL.abilityBtn(a.$1),
          );
          return a.$1 == 'drone' ? KeyedSubtree(key: TUT.keys['drone'], child: w) : w;
        }),
        const SizedBox(width: 5),
      ],
      const SizedBox(width: 2),
      KeyedSubtree(
        key: TUT.keys['reserve'],
        child: RoundBtn(icon: Icons.add, label: 'Резерв', solid: true, size: sz, ready: pts >= cheap, badge: q > 0 ? '$q' : null, on: CTL.deckOpen, onTap: CTL.toggleDeck),
      ),
    ]);
    });
  }
}

/* ---------- приказы ---------- */
class _Orders extends StatelessWidget {
  final List<Squad> sel;
  const _Orders({required this.sel});

  Widget _b(String id, IconData ic, String t, {bool? on}) => RoundBtn(icon: ic, label: t, on: on ?? UI.mode == id, onTap: () => CTL.commandBtn(id));

  @override
  Widget build(BuildContext context) {
    final anyMortar = sel.any((q) => q.t.mortar);
    final allVeh = sel.every((q) => q.t.veh);
    final List<Widget> items;
    if (!CTL.moreOpen) {
      items = [
        _b('move', Icons.navigation_rounded, 'Идти'),
        _b('fight', Icons.gps_fixed, 'Атака'),
        _b('hold', Icons.shield_outlined, 'Окоп', on: sel.every((q) => q.order?.kind == 'hold')),
        _b('retreat', Icons.undo_rounded, 'Отход'),
        if (anyMortar) _b('fire', Icons.whatshot_outlined, 'Огонь'),
        RoundBtn(
          icon: Icons.more_horiz,
          label: 'Ещё',
          onTap: () {
            CTL.moreOpen = true;
            CTL.changed();
          },
        ),
      ];
    } else {
      items = [
        RoundBtn(
          icon: Icons.chevron_left,
          label: 'Назад',
          onTap: () {
            CTL.moreOpen = false;
            CTL.changed();
          },
        ),
        if (!allVeh) _b('sneak', Icons.visibility_off_outlined, 'Скрытно'),
        if (!allVeh) _b('mount', Icons.directions_bus_outlined, 'Посадка'),
        if (sel.any((q) => q.cargo != 0)) _b('dismount', Icons.logout, 'Высадка'),
        _b('ambush', Icons.timer_outlined, 'Засада', on: sel.every((q) => q.stance == 'ambush')),
        _b('cease', Icons.block, 'Не стрелять', on: sel.every((q) => q.stance == 'cease')),
      ];
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: glass(r: 16),
      child: Row(children: [for (final w in items) Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: w)))]),
    );
  }
}

/* ---------- карточка выбранных отрядов ---------- */
Color _mcol(double v) => v > 60 ? C.ok : (v > 35 ? C.amber : C.bad);

class _InfoCard extends StatelessWidget {
  final List<Squad> sel;
  const _InfoCard({required this.sel});

  @override
  Widget build(BuildContext context) {
    final close = Press(
      onTap: () => CTL.selectOnly(null),
      child: Container(width: 36, height: 36, alignment: Alignment.center, child: const Icon(Icons.close, size: 20, color: C.mut)),
    );
    if (sel.length > 1) {
      final shown = sel.take(9).toList();
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: glass(r: 14),
        child: Row(children: [
          Text('${sel.length}', style: disp(22, color: C.amber)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(spacing: 3, runSpacing: 3, children: [
              for (final q in shown) UnitIcon(q.type, q.side, size: 24),
              if (sel.length > shown.length) Text('+${sel.length - shown.length}', style: mono(12, color: C.mut)),
            ]),
          ),
          close,
        ]),
      );
    }
    final q = sel[0];
    final L = loadoutOf(q);
    final main = L.isNotEmpty ? L[0] : null;
    return Press(
      scale: .98,
      onTap: () {
        CTL.infoOpen = !CTL.infoOpen;
        CTL.changed();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: glass(r: 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            UnitIcon(q.type, q.side, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(q.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(14))),
                  const SizedBox(width: 6),
                  Text(q.t.veh ? '${(q.hp / q.hpMax * 100).ceil()}%' : '${q.men}/${q.max}', style: mono(12, color: C.mut)),
                ]),
                const SizedBox(height: 2),
                Text(_status(q), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: _statusColor(q), w: FontWeight.w600)),
              ]),
            ),
            SizedBox(
              width: 74,
              child: Column(children: [
                _bar(Icons.favorite, q.morale, _mcol(q.morale)),
                const SizedBox(height: 4),
                _bar(Icons.bolt, q.supp, C.warn),
                const SizedBox(height: 4),
                _bar(Icons.inventory_2_outlined, q.ammo, C.mut),
              ]),
            ),
            close,
          ]),
          if (CTL.infoOpen) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final e in L)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                      e.n + (e.c > 1 ? ' ×${e.c}' : '') + ((e.k == 'rifle' || e.k == 'mg' || e.k == 'hmg') ? '' : ' · ${e.ammo.entries.map((a) => '${AMMO[a.key]!.n} ${a.value}').join(', ')}'),
                      style: body(11.5, w: FontWeight.w600)),
                ),
            ]),
          ] else if (main != null) ...[
            const SizedBox(height: 4),
            Text('${main.n}${main.c > 1 ? ' ×${main.c}' : ''} · коснитесь, чтобы увидеть всё вооружение', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.mut)),
          ],
        ]),
      ),
    );
  }

  Widget _bar(IconData ic, double v, Color c) => Row(children: [
        Icon(ic, size: 11, color: c),
        const SizedBox(width: 4),
        Expanded(child: BarLine(v / 100, c, h: 4)),
      ]);

  static String _status(Squad q) {
    if (q.stance == 'ambush') return 'Засада · огонь по сигналу';
    if (q.stance == 'cease') return 'Огонь запрещён';
    if (q.cargo != 0) return 'Везёт десант · ${S.byId[q.cargo]?.men ?? 0} чел.';
    if (q.sneak) return 'Скрытное движение';
    if (q.rout) return 'Отступает в панике';
    if (q.supp >= 75) return 'Прижаты огнём';
    final o = q.order;
    if (q.tg != null && !q.tg!.dead) return 'Ведёт огонь · ${NM(q.tg!).toLowerCase()}';
    if (o != null) {
      switch (o.kind) {
        case 'move':
          return 'Движется';
        case 'fight':
          return 'Идёт в бой';
        case 'attack':
          return 'Сближается с целью';
        case 'hold':
          return q.fort > .9 ? 'Окопался · защита выше' : 'Окапывается';
        case 'retreat':
          return 'Отходит';
        case 'fire':
          return 'Миномётный огонь';
      }
    }
    return q.fort > .9 ? 'Окопался' : 'Ждёт приказа';
  }

  static Color _statusColor(Squad q) {
    if (q.stance == 'ambush' || q.stance == 'cease') return C.amber;
    if (q.rout) return C.bad;
    if (q.supp >= 75) return C.warn;
    if (q.tg != null && !q.tg!.dead) return const Color(0xFFFFD68A);
    return C.txt;
  }
}

/* ---------- полоса отрядов ---------- */
class _Strip extends StatelessWidget {
  const _Strip();
  @override
  Widget build(BuildContext context) {
    final mine = S.squads.where((q) => q.side == S.player && !q.dead && q.no > 0).toList()..sort((a, b) => a.no - b.no);
    final all = mine.isNotEmpty && mine.where((q) => q.carried == 0).every((q) => S.sel.contains(q.id));
    return Container(
      height: 70,
      padding: const EdgeInsets.all(5),
      decoration: glass(r: 16),
      child: Row(children: [
        Press(
          onTap: () => all ? CTL.selectOnly(null) : CTL.selectAll(),
          child: Container(
            width: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: all ? C.amber.withValues(alpha: .2) : const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(11), border: Border.all(color: all ? C.amber : C.line)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.select_all, size: 20, color: all ? C.amber : C.txt),
              Text('Все', style: body(10.5, color: all ? C.amber : C.mut, w: FontWeight.w600)),
            ]),
          ),
        ),
        Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6), color: C.line),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (_, i) => _SqChip(mine[i]),
          ),
        ),
      ]),
    );
  }
}

class _SqChip extends StatelessWidget {
  final Squad q;
  const _SqChip(this.q);
  @override
  Widget build(BuildContext context) {
    final on = S.sel.contains(q.id);
    Color border = C.line;
    if (q.rout) {
      border = C.bad;
    } else if (q.supp >= 75) {
      border = C.warn;
    }
    if (on) border = C.amber;
    final hp = q.t.veh ? q.hp / q.hpMax : q.men / q.max;
    return Opacity(
      opacity: q.carried != 0 ? .45 : 1,
      child: Press(
        onTap: () => CTL.sqTap(q.no),
        onLongPress: () {
          if (S.sel.contains(q.id)) {
            S.sel.remove(q.id);
          } else {
            S.sel.add(q.id);
          }
          CTL.onSel();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 52,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
          decoration: BoxDecoration(color: on ? C.amber.withValues(alpha: .2) : const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(11), border: Border.all(color: border, width: on ? 1.8 : 1.2)),
          child: Column(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                UnitIcon(q.type, q.side, size: 32),
                Positioned(left: -1, top: -2, child: Text('${q.no}', style: mono(11, color: on ? C.amber : C.txt, w: FontWeight.w800).copyWith(shadows: _shadow))),
                if (q.rout || q.supp >= 75) Positioned(right: -1, top: -2, child: Icon(q.rout ? Icons.directions_run : Icons.bolt, size: 13, color: q.rout ? C.bad : C.warn)),
              ]),
            ),
            const SizedBox(height: 3),
            BarLine(hp, _mcol(q.morale), h: 4),
          ]),
        ),
      ),
    );
  }
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
    final mq = MediaQuery.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(offset: Offset(0, v * 300), child: child),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * .64),
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + mq.padding.bottom),
        decoration: const BoxDecoration(
          color: C.sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(blurRadius: 30, offset: Offset(0, -10), color: Colors.black54)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Text('ПОДКРЕПЛЕНИЕ', style: disp(16)),
            const SizedBox(width: 12),
            Text('◆ $pts', style: mono(16, color: C.amber)),
            const Spacer(),
            RoundBtn(icon: Icons.close, size: 40, onTap: CTL.toggleDeck),
          ]),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              Text('В пути:', style: body(12, color: C.mut)),
              for (final x in q) Text('${VARS[x.type]!.name} · ${math.max(0, (x.at - S.t).ceil())} с', style: body(12, color: C.amber, w: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 8),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: [for (final t in list) _UnitCard(t: t, enabled: pts >= t.cost)],
            ),
          ),
        ]),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Variant t;
  final bool enabled;
  const _UnitCard({required this.t, required this.enabled});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Press(
        scale: .95,
        onTap: enabled
            ? () {
                if (buyUnit(S.player, t.id)) {
                  CTL.toast('${t.name}: прибудет через ${t.delay.toInt()} с', 1800);
                  CTL.changed();
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Row(children: [
            UnitIcon(t.cls, S.player, size: 38),
            const SizedBox(width: 8),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, w: FontWeight.w700, h: 1.15)),
                const SizedBox(height: 3),
                Text('◆ ${t.cost.toInt()}  ·  ${t.delay.toInt()} с', style: mono(12, color: C.amber)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
