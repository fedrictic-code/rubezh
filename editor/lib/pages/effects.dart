// Раздел «Эффекты»: взрывы, трассеры, пуски ракет — с живым предпросмотром.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rubezh/game/fxcfg.dart';

import '../state.dart';
import '../widgets.dart';
import 'sprite_dialog.dart';

class EffectsPage extends StatefulWidget {
  const EffectsPage({super.key});
  @override
  State<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends State<EffectsPage> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  late FxCfg f = _copy(FX);
  bool dirty = false;
  final Map<String, ui.Image> sprites = {};

  FxCfg _copy(FxCfg s) => FxCfg()..load(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

  @override
  void initState() {
    super.initState();
    _loadSprites();
  }

  Future<void> _loadSprites() async {
    for (final s in [f.boom.sprite, f.big.sprite]) {
      if (s == null) continue;
      final im = await ED.image(s);
      if (im != null) sprites[s] = im;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  void ch(VoidCallback fn) => setState(() {
        fn();
        dirty = true;
      });

  Future<void> save() async {
    ED.mod['fx'] = f.toJson();
    await ED.saveMod();
    setState(() => dirty = false);
    ED.say('Эффекты сохранены');
  }

  Future<void> pickSpriteFor(BoomFx b, String name) async {
    final png = await pickSprite(context, 'Картинка взрыва', hint: 'Взрыв на прозрачном фоне, вид сверху. В игре он растёт и тает.');
    if (png == null) return;
    final rel = 'mod/art/fx_$name.png';
    await ED.ws.write(rel, png);
    ED.forgetImage(rel);
    final im = await ED.image(rel);
    ch(() {
      b.sprite = rel;
      if (im != null) sprites[rel] = im;
    });
  }

  Widget _boom(BoomFx b, String title, String name) => Section(title, [
        ColorF('Огонь', b.fire, (v) => ch(() => b.fire = v)),
        ColorF('Дым', b.smoke, (v) => ch(() => b.smoke = v)),
        SliderF('Размер', b.size, .3, 3, (v) => ch(() => b.size = v)),
        SliderF('Длительность', b.dur, .3, 3, (v) => ch(() => b.dur = v)),
        SliderF('Искры', b.sparks.toDouble(), 0, 24, (v) => ch(() => b.sparks = v.round()), divisions: 24),
        Row(children: [
          OutlinedButton.icon(onPressed: () => pickSpriteFor(b, name), icon: const Icon(Icons.image_outlined, size: 18), label: Text(b.sprite == null ? 'Своя картинка взрыва' : 'Заменить картинку')),
          if (b.sprite != null) TextButton(onPressed: () => ch(() => b.sprite = null), child: const Text('Без картинки')),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Section('Трассеры (стрелковое оружие)', [
            ColorF('Цвет ВСУ', f.tracerUa, (v) => ch(() => f.tracerUa = v)),
            ColorF('Цвет ВС РФ', f.tracerRu, (v) => ch(() => f.tracerRu = v)),
            SliderF('Толщина', f.tracerWidth, .5, 4, (v) => ch(() => f.tracerWidth = v)),
            SliderF('Длина следа', f.tracerLen, .1, 1, (v) => ch(() => f.tracerLen = v)),
            SliderF('Время жизни', f.tracerLife, .3, 3, (v) => ch(() => f.tracerLife = v)),
          ]),
          Section('Ракеты, ПТУР, снаряды в полёте', [
            ColorF('Цвет', f.missile, (v) => ch(() => f.missile = v)),
            SliderF('Толщина', f.missileWidth, .5, 5, (v) => ch(() => f.missileWidth = v)),
            SliderF('Длина следа', f.missileTrail, .02, .4, (v) => ch(() => f.missileTrail = v)),
            SwitchF('Дымный след', f.missileSmokeOn, (v) => ch(() => f.missileSmokeOn = v)),
            ColorF('Цвет дыма', f.missileSmoke, (v) => ch(() => f.missileSmoke = v)),
          ]),
          Section('Вспышка выстрела и малые попадания', [
            ColorF('Цвет', f.flash, (v) => ch(() => f.flash = v)),
            SliderF('Размер', f.flashSize, .3, 3, (v) => ch(() => f.flashSize = v)),
          ]),
          _boom(f.boom, 'Взрыв (снаряды, мины, гранаты)', 'boom'),
          _boom(f.big, 'Подрыв техники', 'big'),
          Row(children: [
            FilledButton.icon(onPressed: dirty ? save : null, icon: const Icon(Icons.save_outlined), label: const Text('Сохранить')),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ch(() => f = FxCfg()),
              child: const Text('Всё по умолчанию'),
            ),
          ]),
        ]),
      ),
      const VerticalDivider(width: 1),
      SizedBox(
        width: 460,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('ПРЕДПРОСМОТР', style: TextStyle(color: kMut, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(color: const Color(0xFF3F5133), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: FxPreview(f, ac.value, sprites), size: Size.infinite)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Те же правила рисования, что в игре (render.dart), в уменьшенной сцене.
class FxPreview extends CustomPainter {
  final FxCfg f;
  final double t;
  final Map<String, ui.Image> sprites;
  FxPreview(this.f, this.t, this.sprites);

  void boom(Canvas c, BoomFx b, Offset o, double r0, double p) {
    final r = r0 * b.size;
    final spr = b.sprite == null ? null : sprites[b.sprite];
    if (spr != null) {
      final s = r * 2.4 * (.7 + p * .6);
      c.drawImageRect(spr, Rect.fromLTWH(0, 0, spr.width.toDouble(), spr.height.toDouble()), Rect.fromCenter(center: o, width: s, height: s),
          Paint()..color = Color.fromRGBO(255, 255, 255, 1 - p * p));
      return;
    }
    final sc = Color(b.smoke), fc = Color(b.fire);
    c.drawCircle(o.translate(0, -p * 8), r * (.7 + p * 1.1), Paint()..color = sc.withValues(alpha: (1 - p) * .5 * sc.a));
    if (p < .5) c.drawCircle(o, r * (.4 + p * 1.1), Paint()..color = fc.withValues(alpha: (1 - p * 2) * .9 * fc.a));
    if (b.sparks > 0 && p < .6) {
      final pa = Paint()
        ..color = fc.withValues(alpha: (1 - p / .6) * fc.a)
        ..strokeWidth = 1.2;
      for (int i = 0; i < b.sparks; i++) {
        final a = (i * 2.399 + o.dx * .01) % (math.pi * 2), d0 = r * (.3 + p * 1.6), d1 = d0 + r * .35;
        c.drawLine(o + Offset(math.cos(a) * d0, math.sin(a) * d0), o + Offset(math.cos(a) * d1, math.sin(a) * d1), pa);
      }
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final k = math.min(s.width / 220, s.height / 300);
    c.scale(k);
    // трассеры: очередь слева направо
    for (int i = 0; i < 5; i++) {
      final life = .13 * f.tracerLife, t0 = (i * .09) % 1, age = (t - t0) % 1 * 2.6;
      if (age > life) continue;
      final fr = age / life, a = math.max(0.0, fr - f.tracerLen * .73), b = math.min(1.0, fr + f.tracerLen * .27);
      final x0 = 20.0, y0 = 40.0 + i * 3, x1 = 200.0, y1 = 30.0 + i * 5;
      c.drawLine(Offset(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), Offset(x0 + (x1 - x0) * b, y0 + (y1 - y0) * b),
          Paint()
            ..color = Color(i.isEven ? f.tracerUa : f.tracerRu)
            ..strokeWidth = f.tracerWidth
            ..strokeCap = StrokeCap.round);
    }
    // ракета: пуск снизу слева, взрыв справа
    final mf = (t * 1.6) % 1.0;
    const ax = 20.0, ay = 140.0, bx = 190.0, by = 110.0;
    if (mf < .6) {
      final fr = mf / .6, tr = f.missileTrail;
      Offset at(double q) => Offset(ax + (bx - ax) * q.clamp(0, 1), ay + (by - ay) * q.clamp(0, 1));
      if (f.missileSmokeOn) {
        c.drawLine(at(fr - tr * 3), at(fr - tr), Paint()
          ..color = Color(f.missileSmoke)
          ..strokeWidth = f.missileWidth * 2.2
          ..strokeCap = StrokeCap.round);
      }
      c.drawLine(at(fr - tr), at(fr), Paint()
        ..color = Color(f.missile)
        ..strokeWidth = f.missileWidth
        ..strokeCap = StrokeCap.round);
      if (fr < .15) {
        final fc = Color(f.flash);
        c.drawCircle(const Offset(ax, ay), 6 * f.flashSize * (.6 + fr / .15), Paint()..color = fc.withValues(alpha: fc.a * (1 - fr / .15)));
      }
    } else {
      boom(c, f.boom, const Offset(bx, by), 20, (mf - .6) / .4);
    }
    // взрыв мины и подрыв техники
    final p1 = (t * 1.3 + .3) % 1.0;
    boom(c, f.boom, const Offset(60, 220), 26, p1);
    final p2 = t;
    boom(c, f.big, const Offset(160, 220), 38, p2);
  }

  @override
  bool shouldRepaint(covariant FxPreview o) => true;
}
