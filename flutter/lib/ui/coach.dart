// Слой обучения: подсветка цели (кнопка или отряд на карте) и короткая подсказка рядом.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/loop.dart';
import '../app/tutorial.dart';
import '../game/battle.dart';
import '../gfx/render.dart';
import 'kit.dart';
import 'theme.dart';

class CoachLayer extends StatelessWidget {
  const CoachLayer({super.key});

  Rect? _target(BuildContext context, String t) {
    if (t.isEmpty) return null;
    if (t == 'squad' || t == 'enemy') {
      final q = t == 'squad' ? TUT.squadTarget() : TUT.enemyTarget();
      if (q == null) return null;
      final x = wsx(q.x), y = wsy(q.y) - 8;
      return Rect.fromCenter(center: Offset(x, y), width: 54, height: 54);
    }
    final ctx = TUT.keys[t]?.currentContext;
    final me = context.findRenderObject();
    if (ctx == null || me is! RenderBox) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final o = box.localToGlobal(Offset.zero, ancestor: me);
    return (o & box.size).inflate(4);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([LOOP.frame, TUT]),
      builder: (context, _) {
        final st = TUT.step;
        if (st == null || !hasBattle || TUT.waiting) return const SizedBox.shrink();
        return LayoutBuilder(builder: (context, c) {
          final r = _target(context, st.target);
          final ph = (DateTime.now().millisecondsSinceEpoch % 1400) / 1400;
          final H = c.maxHeight;
          // подсказка над целью, если цель в нижней половине, иначе под ней; без цели — в верхней трети
          double? top, bottom;
          if (r == null) {
            top = H * .3;
          } else if (r.center.dy > H * .5) {
            bottom = H - r.top + 16;
          } else {
            top = r.bottom + 16;
          }
          return Stack(children: [
            if (r != null) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Ring(r, ph)))),
            Positioned(
              left: 16,
              right: 16,
              top: top,
              bottom: bottom,
              child: Align(
                alignment: top != null ? Alignment.topCenter : Alignment.bottomCenter,
                child: _Bubble(text: st.text, n: TUT.i + 1, total: Tutorial.steps.length),
              ),
            ),
          ]);
        });
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final int n, total;
  const _Bubble({required this.text, required this.n, required this.total});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .9 + .1 * v, child: child)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xF2161B20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.amber, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: Text(text, style: body(15.5, w: FontWeight.w700, h: 1.3))),
          Row(children: [
            Text('Обучение · $n из $total', style: body(11.5, color: C.mut)),
            const Spacer(),
            Press(
              onTap: TUT.skip,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Пропустить', style: body(12.5, color: C.amber, w: FontWeight.w700))),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final Rect r;
  final double ph;
  _Ring(this.r, this.ph);
  @override
  void paint(Canvas c, Size s) {
    final rr = math.min(r.width, r.height) / 2;
    final base = RRect.fromRectAndRadius(r, Radius.circular(math.min(rr, 18)));
    c.drawRRect(base, Paint()
      ..color = C.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    final g = base.inflate(4 + ph * 14);
    c.drawRRect(g, Paint()
      ..color = C.amber.withValues(alpha: (1 - ph) * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _Ring o) => true;
}
