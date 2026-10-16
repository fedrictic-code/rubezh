// Единый набор элементов управления: нажатие с откликом, круглая кнопка, большие кнопки.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/fx.dart';
import 'theme.dart';

/// Обёртка: при касании элемент чуть проседает, лёгкая вибрация.
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final bool sound;
  final double scale;
  const Press({super.key, required this.child, this.onTap, this.onLongPress, this.sound = false, this.scale = .92});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: en ? (_) => _set(true) : null,
      onTapUp: en ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.sound) {
                Fx.tap();
              } else {
                Fx.haptic(0);
              }
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              Fx.haptic(1);
              widget.onLongPress!();
            },
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Круглая кнопка: значок или текст, подпись снизу, счётчик, кольцо перезарядки, вспышка при готовности.
class RoundBtn extends StatefulWidget {
  final IconData? icon;
  final String? text, label, badge;
  final VoidCallback? onTap;
  final bool on, enabled, solid, ready;
  final double size, cd; // cd: доля оставшейся перезарядки 0..1
  final Color? accent;
  const RoundBtn({super.key, this.icon, this.text, this.label, this.badge, this.onTap, this.on = false, this.enabled = true, this.solid = false, this.ready = false, this.size = 48, this.cd = 0, this.accent});
  @override
  State<RoundBtn> createState() => _RoundBtnState();
}

class _RoundBtnState extends State<RoundBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didUpdateWidget(covariant RoundBtn old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _p.forward(from: 0);
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget, s = w.size;
    final ac = w.accent ?? C.amber;
    final fill = w.solid ? ac : (w.on ? ac.withValues(alpha: .2) : C.panel);
    final fg = w.solid ? const Color(0xFF1A1405) : (w.on ? ac : C.txt);
    final border = w.solid ? ac : (w.on ? ac : const Color(0x33FFFFFF));
    Widget face = Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: w.on ? 1.8 : 1.2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: w.icon != null ? Icon(w.icon, size: s * .46, color: fg) : Text(w.text ?? '', style: mono(s * .3, color: fg, w: FontWeight.w800)),
    );
    face = Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      AnimatedBuilder(
        animation: _p,
        builder: (_, __) {
          final t = _p.value;
          if (t <= 0 || t >= 1) return SizedBox(width: s, height: s);
          final k = (t * 2) % 1; // две волны
          return Container(
            width: s * (1 + .55 * k),
            height: s * (1 + .55 * k),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ac.withValues(alpha: (1 - k) * .9), width: 2.5)),
          );
        },
      ),
      face,
      if (w.cd > 0) IgnorePointer(child: CustomPaint(size: Size(s, s), painter: _CdPainter(w.cd))),
      if (w.badge != null)
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: w.solid ? C.ink : ac, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.ink, width: 1.5)),
            child: Text(w.badge!, style: mono(10, color: w.solid ? ac : const Color(0xFF1A1405), w: FontWeight.w800)),
          ),
        ),
    ]);
    Widget out = face;
    if (w.label != null) {
      out = Column(mainAxisSize: MainAxisSize.min, children: [
        face,
        const SizedBox(height: 3),
        Text(w.label!, maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: body(10.5, color: w.on ? ac : C.txt, w: FontWeight.w600).copyWith(shadows: const [Shadow(blurRadius: 3, color: Colors.black)])),
      ]);
    }
    return Opacity(opacity: w.enabled ? 1 : .42, child: Press(onTap: w.enabled ? w.onTap : null, child: out));
  }
}

class _CdPainter extends CustomPainter {
  final double cd;
  _CdPainter(this.cd);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(0, 0, s.width, s.height);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * cd, true, Paint()..color = const Color(0x99000000));
    c.drawArc(r.deflate(1.5), -math.pi / 2 + math.pi * 2 * cd, math.pi * 2 * (1 - cd), false,
        Paint()
          ..color = C.amber.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant _CdPainter o) => o.cd != cd;
}

class BigBtn extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  final IconData? icon;
  final double h;
  const BigBtn(this.t, this.onTap, {super.key, this.icon, this.h = 54});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Press(
          sound: true,
          scale: .96,
          onTap: onTap,
          child: Container(
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.amber,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: C.amber.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, color: const Color(0xFF1A1405), size: 22), const SizedBox(width: 8)],
              Text(t.toUpperCase(), style: disp(18, color: const Color(0xFF1A1405), ls: .08)),
            ]),
          ),
        ),
      );
}

class GhostBtn extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool on;
  const GhostBtn(this.t, this.onTap, {super.key, this.icon, this.on = false});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Press(
          sound: true,
          scale: .96,
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? C.amber.withValues(alpha: .14) : const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? C.amber : C.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: on ? C.amber : C.txt), const SizedBox(width: 6)],
              Flexible(child: Text(t, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, color: on ? C.amber : C.txt, w: FontWeight.w600))),
            ]),
          ),
        ),
      );
}

/// Сегментированный переключатель.
class Seg<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Seg({super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: Press(
                sound: true,
                scale: .96,
                onTap: () => onChanged(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: it.$1 == value ? C.amber : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                  child: Text(it.$2, style: body(13.5, color: it.$1 == value ? const Color(0xFF1A1405) : C.txt, w: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      );
}

/// Переключатель вкл/выкл.
class Toggle extends StatelessWidget {
  final bool v;
  final VoidCallback onTap;
  const Toggle(this.v, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Press(
        sound: true,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment: v ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: v ? C.amber : const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(15)),
          child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      );
}
