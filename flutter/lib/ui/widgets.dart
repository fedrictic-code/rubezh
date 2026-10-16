// Общие виджеты: значок типа отряда, кнопки.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../gfx/ctx2d.dart';
import '../gfx/render.dart' show drawGlyph;
import 'theme.dart';

class UnitIcon extends StatelessWidget {
  final String type;
  final int side;
  final double size;
  const UnitIcon(this.type, this.side, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _IconPainter(type, side)));
}

class _IconPainter extends CustomPainter {
  final String type;
  final int side;
  _IconPainter(this.type, this.side);
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final g = Ctx2D(canvas);
    final s = size.width;
    g.fill = ui.Color(SIDES[side].dark);
    g.beginPath();
    g.roundRect(s * .04, s * .04, s * .92, s * .92, s * .17);
    g.doFill();
    g.stroke = ui.Color(SIDES[side].color);
    g.lineWidth = s * .042;
    g.doStroke();
    drawGlyph(g, type, s / 2, s / 2, s * .52, css('#f3f5f6'));
  }

  @override
  bool shouldRepaint(covariant _IconPainter o) => o.type != type || o.side != side;
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  final double r;
  const Glass({super.key, required this.child, this.pad = EdgeInsets.zero, this.r = 12});
  @override
  Widget build(BuildContext context) => Container(padding: pad, decoration: glass(r: r), child: child);
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool on;
  final double size;
  const IconBtn(this.icon, this.onTap, {super.key, this.on = false, this.size = 32});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: 18, color: on ? C.amber : C.txt)),
      );
}
