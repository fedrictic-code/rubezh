// Поле боя: рисование и ввод (касания, мышь, колесо).
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide View;

import '../app/controller.dart';
import '../app/loop.dart';
import '../game/battle.dart';
import '../game/core.dart';
import '../gfx/render.dart';

class Battlefield extends StatefulWidget {
  const Battlefield({super.key});
  @override
  State<Battlefield> createState() => _BfState();
}

class _BfState extends State<Battlefield> {
  final Map<int, Ptr> P = {};
  String? gMode; // null, pan, pinch, box
  double d0 = 1, z0 = 1, gcx = 0, gcy = 0, cam0x = 0, cam0y = 0;

  bool get _shift => HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

  void _down(PointerDownEvent e) {
    LOOP.poke();
    if (UI.menu) return;
    CTL.gestShift = _shift;
    final mouse = e.kind == PointerDeviceKind.mouse;
    int btn = 0;
    if (mouse) {
      if ((e.buttons & kSecondaryMouseButton) != 0) {
        btn = 2;
      } else if ((e.buttons & kMiddleMouseButton) != 0) {
        btn = 1;
      }
    }
    P[e.pointer] = Ptr(e.localPosition.dx, e.localPosition.dy, mouse ? 'mouse' : 'touch', btn);
    if (P.length == 2) {
      final l = P.values.toList();
      d0 = math.max(1, math.sqrt(math.pow(l[0].x - l[1].x, 2) + math.pow(l[0].y - l[1].y, 2)).toDouble());
      z0 = cam.z;
      gcx = (l[0].x + l[1].x) / 2;
      gcy = (l[0].y + l[1].y) / 2;
      gMode = 'pinch';
      for (final q in l) {
        q.moved = true;
      }
      UI.box = null;
    } else if (P.length == 1) {
      gMode = null;
      cam0x = cam.x;
      cam0y = cam.y;
    }
  }

  void _move(PointerMoveEvent e) {
    LOOP.poke();
    final p = P[e.pointer];
    final w = s2w(e.localPosition.dx, e.localPosition.dy);
    UI.ptr = Pt(w.x, w.y);
    if (p == null) return;
    p.x = e.localPosition.dx;
    p.y = e.localPosition.dy;
    if (gMode == 'pinch' && P.length >= 2) {
      final l = P.values.toList();
      final d = math.max(1.0, math.sqrt(math.pow(l[0].x - l[1].x, 2) + math.pow(l[0].y - l[1].y, 2)).toDouble());
      final cx = (l[0].x + l[1].x) / 2, cy = (l[0].y + l[1].y) / 2;
      final bf = s2w(gcx, gcy);
      cam.z = z0 * d / d0;
      clampCam();
      final af = s2w(cx, cy);
      cam.x += bf.x - af.x;
      cam.y += bf.y - af.y;
      gcx = cx;
      gcy = cy;
      clampCam();
      return;
    }
    if (P.length != 1) return;
    final dx = p.x - p.sx, dy = p.y - p.sy;
    if (!p.moved && math.sqrt(dx * dx + dy * dy) > 8) {
      p.moved = true;
      gMode = p.kind == 'mouse' ? ((p.btn == 0 && UI.mode == null) ? 'box' : 'pan') : 'pan';
      if (gMode == 'box') UI.box = [p.sx, p.sy, p.x, p.y];
    }
    if (gMode == 'pan') {
      cam.x = cam0x - dx / cam.z;
      cam.y = cam0y - dy / cam.z;
      clampCam();
    } else if (gMode == 'box' && UI.box != null) {
      UI.box![2] = p.x;
      UI.box![3] = p.y;
    }
  }

  void _hover(PointerHoverEvent e) {
    if (UI.mode != null) LOOP.poke();
    final w = s2w(e.localPosition.dx, e.localPosition.dy);
    UI.ptr = Pt(w.x, w.y);
    if (hasBattle && !UI.menu && e.kind == PointerDeviceKind.mouse) {
      final h = CTL.pick(e.localPosition.dx, e.localPosition.dy, false);
      UI.hoverId = (h != null && h.enemy && CTL.selSquads().isNotEmpty) ? h.sq.id : 0;
    }
  }

  void _up(PointerEvent e) {
    LOOP.poke();
    final p = P.remove(e.pointer);
    if (p == null) return;
    if (gMode == 'pinch') {
      if (P.length < 2) {
        for (final q in P.values) {
          q.moved = true;
          q.sx = q.x;
          q.sy = q.y;
        }
        if (P.isNotEmpty) {
          gMode = null;
          cam0x = cam.x;
          cam0y = cam.y;
        } else {
          gMode = null;
        }
      }
      return;
    }
    if (!p.moved && e is PointerUpEvent) {
      CTL.tap(p);
    } else if (gMode == 'box' && UI.box != null) {
      CTL.finishBox(UI.box!);
    }
    UI.box = null;
    gMode = null;
  }

  void _signal(PointerSignalEvent e) {
    LOOP.poke();
    if (e is PointerScrollEvent && !UI.menu) {
      final bf = s2w(e.localPosition.dx, e.localPosition.dy);
      cam.z *= math.exp(-e.scrollDelta.dy * .0012);
      clampCam();
      final af = s2w(e.localPosition.dx, e.localPosition.dy);
      cam.x += bf.x - af.x;
      cam.y += bf.y - af.y;
      clampCam();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      View.w = c.maxWidth;
      View.h = c.maxHeight;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        onPointerHover: _hover,
        onPointerSignal: _signal,
        child: RepaintBoundary(child: CustomPaint(painter: WorldPainter(LOOP.frame), size: Size.infinite)),
      );
    });
  }
}
