// Оформление: графит и сталь; янтарь — выбор и действие; синий/красный — стороны.
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class C {
  static const ink = Color(0xFF0C1013);
  static const panel = Color(0xE60E1317);
  static const panel2 = Color(0xF21A2127);
  static const sheet = Color(0xFF1A2127);
  static const line = Color(0x1AFFFFFF);
  static const txt = Color(0xFFE9EDF0);
  static const mut = Color(0xFF8E9AA4);
  static const amber = Color(0xFFE3B341);
  static const ua = Color(0xFF3D8FE0);
  static const ru = Color(0xFFD4483F);
  static const ok = Color(0xFF7EC27A);
  static const warn = Color(0xFFEE8A3A);
  static const bad = Color(0xFFE0584A);
  static Color side(int s) => s == 0 ? ua : ru;
}

BoxDecoration glass({double r = 12, Color? color, Color? border}) => BoxDecoration(
      color: color ?? C.panel,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: border ?? C.line),
    );

TextStyle mono(double size, {Color color = C.txt, FontWeight w = FontWeight.w600}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color, fontFeatures: const [FontFeature.tabularFigures()], height: 1.15);

TextStyle body(double size, {Color color = C.txt, FontWeight w = FontWeight.w500, double h = 1.25}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color, height: h);

TextStyle disp(double size, {Color color = C.txt, double ls = .06}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color, letterSpacing: size * ls, height: 1.15);

Widget tap(VoidCallback? onTap, Widget child, {HitTestBehavior? behavior}) =>
    GestureDetector(behavior: behavior ?? HitTestBehavior.opaque, onTap: onTap, child: child);

/// Плоская кнопка с рамкой (пилюля команд, кнопки магазина).
class PillBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool on, enabled;
  final double h, r;
  final EdgeInsets pad;
  final Color? border, fill;
  const PillBtn({super.key, required this.child, this.onTap, this.on = false, this.enabled = true, this.h = 30, this.r = 999, this.pad = const EdgeInsets.symmetric(horizontal: 11), this.border, this.fill});

  @override
  Widget build(BuildContext context) {
    final b = on ? C.amber : (border ?? C.line);
    final f = on ? C.amber.withValues(alpha: .14) : (fill ?? C.panel);
    return Opacity(
      opacity: enabled ? 1 : .38,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: h,
          padding: pad,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: f, borderRadius: BorderRadius.circular(r), border: Border.all(color: b)),
          child: DefaultTextStyle(style: body(12, color: on ? C.amber : C.txt), child: child),
        ),
      ),
    );
  }
}

class BarLine extends StatelessWidget {
  final double v; // 0..1
  final Color color;
  final double h;
  final Color? bg;
  const BarLine(this.v, this.color, {super.key, this.h = 3, this.bg});
  @override
  Widget build(BuildContext context) => Container(
        height: h,
        decoration: BoxDecoration(color: bg ?? const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(h / 2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(h / 2))),
        ),
      );
}
