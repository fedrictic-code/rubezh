// Раздел «Карты»: новая карта из PNG/JPG, разметка местности кистью, рубежи, зоны, базы, точки ИИ.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubezh/game/battle.dart';
import 'package:rubezh/game/core.dart';
import 'package:rubezh/game/map.dart';
import 'package:rubezh/game/mapdef.dart';

import '../files.dart';
import '../imgproc.dart';
import '../state.dart';
import '../widgets.dart';

enum MTool { pan, paint, height, obj, zoneUa, zoneRu, baseUa, baseRu, asm, choke }

const List<(int, String, int)> TER_TYPES = [
  (Ter.OPEN, 'Открытое поле', 0x00000000),
  (Ter.FOREST, 'Лес', 0xFF2E7D32),
  (Ter.BUILD, 'Здания', 0xFF8D6E63),
  (Ter.WATER, 'Вода (непроходимо)', 0xFF1E88E5),
  (Ter.ROAD, 'Дорога', 0xFFBDBDBD),
  (Ter.TRENCH, 'Окопы', 0xFF6D4C41),
  (Ter.RUBBLE, 'Руины', 0xFF9E9E9E),
  (Ter.BRIDGE, 'Мост', 0xFFFFB300),
  (Ter.FORD, 'Брод', 0xFF4FC3F7),
];

int terColor(int t) => TER_TYPES.firstWhere((e) => e.$1 == t, orElse: () => TER_TYPES.first).$3;

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});
  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  MapDef? cur;
  ui.Image? img;
  MTool tool = MTool.pan;
  int paintType = Ter.FOREST;
  double brush = 1.5, alpha = .45;
  bool raise = true, showSlots = false, busy = false, dirty = false;
  int? selObj;
  int rev = 0;
  List<List<double>> slots = [];
  Offset? zoneA;
  bool dragObj = false;
  final TransformationController tc = TransformationController();
  bool fitted = false;

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters;
    if (q.containsKey('demo')) {
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && ED.maps.isNotEmpty && cur == null) {
          open(ED.maps.first);
          if (q['tool'] == 'paint') setState(() => tool = MTool.paint);
        }
      });
    }
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  Future<void> open(MapDef m) async {
    if (dirty && cur != null && !await confirm(context, 'Несохранённые изменения', 'Перейти к другой карте без сохранения?', ok: 'Перейти')) return;
    final im = m.image == null ? null : await ED.image(m.image!);
    setState(() {
      cur = m;
      img = im;
      selObj = null;
      fitted = false;
      dirty = false;
      slots = [];
      showSlots = false;
      rev++;
    });
  }

  Future<void> newMap() async {
    final name = await ask(context, 'Новая карта', 'Название карты', init: 'Новая карта');
    if (name == null || !mounted) return;
    final crop = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Подгонка картинки'),
        content: const Text('Поле боя вытянуто 16:10. Картинку другой формы можно обрезать по краям или растянуть.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Растянуть')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Обрезать края')),
        ],
      ),
    );
    if (crop == null) return;
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Картинки', extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'])
    ]);
    if (f == null) return;
    setState(() => busy = true);
    ED.say('Обработка картинки и распознавание местности…');
    try {
      final bytes = await f.readAsBytes();
      final r = await compute(prepareMapImage, MapImageJob(bytes, crop));
      if (r.error != null) {
        ED.say(r.error!);
        return;
      }
      var id = slug(name);
      while (ED.maps.any((m) => m.id == id) || id == 'crossing') {
        id = '${id}_2';
      }
      final imgRel = 'mod/maps/$id.jpg';
      await ED.ws.write(imgRel, r.jpg);
      ED.forgetImage(imgRel);
      final m = MapDef(
        id: id,
        name: name,
        brief: '',
        image: imgRel,
        terrain: r.terrain,
        height: Float32List(GW * GH),
        objs: [Obj(0, 'Рубеж 1', W * .62, H * .5, 110, true)],
        owners: [0],
        bases: [
          [W - 50, H / 2],
          [50, H / 2]
        ],
        zones: [Zone(W * .58, W - 40, 60, H - 60), Zone(40, W * .23, 60, H - 60)],
      );
      await ED.saveMap(m);
      await open(m);
      ED.say('Карта «$name» создана. Проверьте разметку: лес, вода, здания и дороги распознаны по цветам.');
    } catch (e) {
      ED.say('Не получилось: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final m = cur;
    if (m == null) return;
    await ED.saveMap(m);
    setState(() => dirty = false);
    ED.say('Карта сохранена');
  }

  Future<void> reclassify() async {
    final m = cur;
    if (m == null || m.image == null) return;
    if (!await confirm(context, 'Распознать заново', 'Разметка местности будет заменена распознанной по картинке. Продолжить?')) return;
    setState(() => busy = true);
    final b = await ED.ws.bytes(m.image!);
    if (b != null) {
      final t = await compute(classifyBytes, b);
      m.terrain = t;
      dirty = true;
      rev++;
    }
    setState(() => busy = false);
  }

  void computeSlots() {
    final m = cur;
    if (m == null) return;
    applyMap(m);
    slots = [for (final l in autoSlots().values) ...l];
    setState(() => showSlots = true);
  }

  /* ---------- ввод на холсте ---------- */
  void stamp(Offset p) {
    final m = cur!;
    final r = brush * CELL;
    if (tool == MTool.paint) {
      forCircle(p.dx, p.dy, r, (c, _, __) => m.terrain![c] = paintType);
    } else if (tool == MTool.height) {
      m.height ??= Float32List(GW * GH);
      forCircle(p.dx, p.dy, r, (c, x, y) {
        final d = dist((x + .5) * CELL, (y + .5) * CELL, p.dx, p.dy) / math.max(1, r);
        final k = .08 * (1 - d * .7);
        m.height![c] = (m.height![c] + (raise ? k : -k)).clamp(0.0, 1.0);
      });
    }
    dirty = true;
    setState(() => rev++);
  }

  int? objAt(Offset p) {
    final m = cur!;
    for (int i = m.objs.length - 1; i >= 0; i--) {
      final o = m.objs[i];
      if (dist(o.x, o.y, p.dx, p.dy) <= math.max(30, o.r)) return i;
    }
    return null;
  }

  void setObj(int i, {String? name, double? x, double? y, double? r, bool? key, int? owner}) {
    final m = cur!;
    final o = m.objs[i];
    m.objs[i] = Obj(i, name ?? o.name, x ?? o.x, y ?? o.y, r ?? o.r, key ?? o.key);
    while (m.owners.length < m.objs.length) {
      m.owners.add(-1);
    }
    if (owner != null) m.owners[i] = owner;
    dirty = true;
    setState(() => rev++);
  }

  void down(PointerDownEvent e) {
    if (cur == null || tool == MTool.pan || (e.buttons & kPrimaryButton) == 0) return;
    final p = e.localPosition, m = cur!;
    switch (tool) {
      case MTool.paint:
      case MTool.height:
        stamp(p);
      case MTool.obj:
        final i = objAt(p);
        if (i != null) {
          selObj = i;
          dragObj = true;
        } else {
          m.objs.add(Obj(m.objs.length, 'Рубеж ${m.objs.length + 1}', p.dx, p.dy, 90, true));
          m.owners.add(0);
          selObj = m.objs.length - 1;
          dragObj = true;
          dirty = true;
        }
        setState(() => rev++);
      case MTool.zoneUa:
      case MTool.zoneRu:
        zoneA = p;
      case MTool.baseUa:
      case MTool.baseRu:
        m.bases[tool == MTool.baseUa ? 0 : 1] = [p.dx.clamp(0, W), p.dy.clamp(0, H)];
        dirty = true;
        setState(() => rev++);
      case MTool.asm:
        m.asm = [p.dx, p.dy];
        dirty = true;
        setState(() => rev++);
      case MTool.choke:
        m.choke = [p.dx, p.dy];
        m.smoke = [p.dx, p.dy];
        dirty = true;
        setState(() => rev++);
      case MTool.pan:
        break;
    }
  }

  void move(PointerMoveEvent e) {
    if (cur == null || (e.buttons & kPrimaryButton) == 0) return;
    final p = e.localPosition;
    if (tool == MTool.paint || tool == MTool.height) {
      stamp(p);
    } else if (tool == MTool.obj && dragObj && selObj != null) {
      setObj(selObj!, x: p.dx.clamp(0, W), y: p.dy.clamp(0, H));
    } else if ((tool == MTool.zoneUa || tool == MTool.zoneRu) && zoneA != null) {
      final a = zoneA!;
      final z = Zone(math.min(a.dx, p.dx).clamp(0, W), math.max(a.dx, p.dx).clamp(0, W), math.min(a.dy, p.dy).clamp(0, H), math.max(a.dy, p.dy).clamp(0, H));
      cur!.zones[tool == MTool.zoneUa ? 0 : 1] = z;
      dirty = true;
      setState(() => rev++);
    }
  }

  void up(PointerEvent e) {
    dragObj = false;
    zoneA = null;
  }

  List<String> problems(MapDef m) {
    final out = <String>[];
    if (m.objs.isEmpty) out.add('Нет ни одного рубежа');
    if (m.objs.isNotEmpty && !m.objs.any((o) => o.key)) out.add('Нет ключевых рубежей: ключевыми станут все');
    for (int s = 0; s < 2; s++) {
      final z = m.zones[s], b = m.bases[s];
      if ((z.x1 - z.x0) < 150 || (z.y1 - z.y0) < 150) out.add('Зона ${s == 0 ? 'ВСУ' : 'РФ'} слишком маленькая');
      final c = cellIdx(b[0], b[1]);
      if (m.terrain![c] == Ter.WATER) out.add('База ${s == 0 ? 'ВСУ' : 'РФ'} стоит в воде');
    }
    final a = m.zones[0], b = m.zones[1];
    if (a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1) out.add('Зоны расстановки пересекаются');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ED,
      builder: (context, _) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 250, child: _list()),
        const VerticalDivider(width: 1),
        Expanded(child: cur == null ? _empty() : _canvas()),
        if (cur != null) ...[const VerticalDivider(width: 1), SizedBox(width: 330, child: _inspector())],
      ]),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, size: 64, color: kMut),
          const SizedBox(height: 12),
          const Text('Выберите карту слева или создайте новую из картинки.', style: TextStyle(color: kMut)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: busy ? null : newMap, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Новая карта из PNG/JPG')),
        ]),
      );

  Widget _list() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(onPressed: busy ? null : newMap, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Новая из картинки')),
        ),
        const ListTile(
          dense: true,
          leading: Icon(Icons.lock_outline, size: 18),
          title: Text('Переправа у села Дубки'),
          subtitle: Text('Встроенная, рисуется кодом'),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(children: [
            for (final m in ED.maps)
              ListTile(
                selected: cur?.id == m.id,
                leading: const Icon(Icons.map_outlined),
                title: Text(m.name),
                subtitle: Text('${m.objs.length} руб. · ${m.id}'),
                onTap: () => open(m),
              ),
            if (ED.maps.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Своих карт пока нет.', style: TextStyle(color: kMut))),
          ]),
        ),
        if (busy) const LinearProgressIndicator(),
      ]);

  Widget _toolBtn(MTool t, IconData ic, String tip) => Tooltip(
        message: tip,
        child: IconButton(
          isSelected: tool == t,
          style: IconButton.styleFrom(backgroundColor: tool == t ? kAmber.withValues(alpha: .2) : null),
          icon: Icon(ic, color: tool == t ? kAmber : null),
          onPressed: () => setState(() => tool = t),
        ),
      );

  Widget _canvas() {
    return Column(children: [
      Container(
        color: kPanel,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          _toolBtn(MTool.pan, Icons.pan_tool_outlined, 'Рука: двигать карту (колесо — масштаб)'),
          _toolBtn(MTool.paint, Icons.brush_outlined, 'Кисть местности'),
          _toolBtn(MTool.height, Icons.terrain_outlined, 'Высоты (холмы дают обзор)'),
          _toolBtn(MTool.obj, Icons.flag_outlined, 'Рубежи: клик — добавить или выбрать, тянуть — двигать'),
          _toolBtn(MTool.zoneUa, Icons.crop_square, 'Зона расстановки ВСУ: протяните прямоугольник'),
          _toolBtn(MTool.zoneRu, Icons.crop_din, 'Зона расстановки РФ: протяните прямоугольник'),
          _toolBtn(MTool.baseUa, Icons.home_outlined, 'База ВСУ (откуда приходит подкрепление)'),
          _toolBtn(MTool.baseRu, Icons.home_work_outlined, 'База РФ'),
          _toolBtn(MTool.asm, Icons.groups_outlined, 'Точка сбора наступающих (ИИ)'),
          _toolBtn(MTool.choke, Icons.compare_arrows, 'Узкое место: ИИ ставит здесь дым'),
          const Spacer(),
          Text(_toolHint(), style: const TextStyle(color: kMut, fontSize: 12)),
          const SizedBox(width: 8),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          if (!fitted) {
            final k = math.min(c.maxWidth / W, c.maxHeight / H) * .96;
            tc.value = Matrix4.identity()
              ..translate((c.maxWidth - W * k) / 2, (c.maxHeight - H * k) / 2)
              ..scale(k);
            fitted = true;
          }
          return ClipRect(
            child: ColoredBox(
              color: const Color(0xFF0B0F12),
              child: InteractiveViewer(
                transformationController: tc,
                constrained: false,
                minScale: .1,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(2000),
                panEnabled: tool == MTool.pan,
                child: Listener(
                  onPointerDown: down,
                  onPointerMove: move,
                  onPointerUp: up,
                  onPointerCancel: up,
                  child: CustomPaint(
                    size: const Size(W, H),
                    painter: _MapPainter(cur!, img, rev, alpha, selObj, tool == MTool.height, showSlots ? slots : const []),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ]);
  }

  String _toolHint() => switch (tool) {
        MTool.pan => 'Тяните карту, колесо мыши — масштаб',
        MTool.paint => 'Рисуйте местность левой кнопкой',
        MTool.height => raise ? 'Поднимайте высоты' : 'Опускайте высоты',
        MTool.obj => 'Клик — новый рубеж или выбор, тянуть — двигать',
        MTool.zoneUa || MTool.zoneRu => 'Протяните прямоугольник зоны',
        MTool.baseUa || MTool.baseRu => 'Кликните, где база',
        MTool.asm => 'Кликните, где наступающие собираются перед атакой',
        MTool.choke => 'Кликните на мост или проход',
      };

  Widget _inspector() {
    final m = cur!;
    final pr = problems(m);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Section('Карта', [
        TextF('Название', m.name, (v) {
          m.name = v;
          dirty = true;
        }, key: ValueKey('name${m.id}')),
        const SizedBox(height: 8),
        TextF('Описание задачи (одна строка)', m.brief, (v) {
          m.brief = v;
          dirty = true;
        }, key: ValueKey('brief${m.id}'), lines: 2),
        const SizedBox(height: 4),
        Text('Файл: ${m.id}.json', style: const TextStyle(color: kMut, fontSize: 12)),
      ]),
      if (tool == MTool.paint)
        Section('Кисть местности', [
          for (final t in TER_TYPES)
            RadioListTile<int>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: t.$1,
              groupValue: paintType,
              onChanged: (v) => setState(() => paintType = v!),
              title: Row(children: [
                Container(width: 16, height: 16, decoration: BoxDecoration(color: Color(t.$3 == 0 ? 0x22FFFFFF : t.$3), borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.white24))),
                const SizedBox(width: 8),
                Text(t.$2),
              ]),
            ),
          SliderF('Размер кисти', brush, .5, 8, (v) => setState(() => brush = v)),
        ]),
      if (tool == MTool.height)
        Section('Высоты', [
          SwitchF(raise ? 'Поднимать' : 'Опускать', raise, (v) => setState(() => raise = v)),
          SliderF('Размер кисти', brush, .5, 10, (v) => setState(() => brush = v)),
          const Text('Отряды на высоте видят дальше. Белым показана высота.', style: TextStyle(color: kMut, fontSize: 12)),
        ]),
      Section('Вид', [
        SliderF('Прозрачность разметки', alpha, 0, 1, (v) => setState(() => alpha = v)),
        Row(children: [
          OutlinedButton.icon(onPressed: busy || m.image == null ? null : reclassify, icon: const Icon(Icons.auto_fix_high, size: 18), label: const Text('Распознать заново')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: showSlots ? () => setState(() => showSlots = false) : computeSlots, child: Text(showSlots ? 'Скрыть позиции ИИ' : 'Позиции обороны ИИ')),
        ]),
      ]),
      if (selObj != null && selObj! < m.objs.length) _objSection(m, selObj!),
      if (tool == MTool.obj && selObj == null) const Section('Рубежи', [Text('Кликните на карте, чтобы добавить рубеж, или на существующий, чтобы выбрать.', style: TextStyle(color: kMut))]),
      Section('Проверка', [
        if (pr.isEmpty) const Text('Ошибок нет', style: TextStyle(color: Color(0xFF7EC27A))),
        for (final p in pr) Text('• $p', style: const TextStyle(color: Color(0xFFEE8A3A))),
      ]),
      FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: Text(dirty ? 'Сохранить карту *' : 'Сохранить карту')),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () async {
          if (!await confirm(context, 'Удалить карту', 'Карта «${m.name}» и её картинка будут удалены.', ok: 'Удалить')) return;
          await ED.deleteMap(m);
          setState(() {
            cur = null;
            dirty = false;
          });
        },
        icon: const Icon(Icons.delete_outline, color: Color(0xFFE0584A)),
        label: const Text('Удалить карту', style: TextStyle(color: Color(0xFFE0584A))),
      ),
    ]);
  }

  Widget _objSection(MapDef m, int i) {
    final o = m.objs[i];
    final ow = i < m.owners.length ? m.owners[i] : -1;
    return Section('Рубеж ${i + 1}', [
      TextF('Название', o.name, (v) => setObj(i, name: v), key: ValueKey('on$i${m.id}')),
      const SizedBox(height: 8),
      SliderF('Радиус', o.r, 40, 240, (v) => setObj(i, r: v)),
      SwitchF('Ключевой (нужен для победы)', o.key, (v) => setObj(i, key: v)),
      const SizedBox(height: 6),
      DropF<int>('В начале боя у', ow, const [(-1, 'Ничей'), (0, 'ВСУ'), (1, 'ВС РФ')], (v) => setObj(i, owner: v)),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            m.objs.removeAt(i);
            if (i < m.owners.length) m.owners.removeAt(i);
            for (int k = 0; k < m.objs.length; k++) {
              final x = m.objs[k];
              m.objs[k] = Obj(k, x.name, x.x, x.y, x.r, x.key);
            }
            selObj = null;
            dirty = true;
            setState(() => rev++);
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Удалить рубеж'),
        ),
      ),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  final MapDef m;
  final ui.Image? img;
  final int rev;
  final double alpha;
  final int? sel;
  final bool heights;
  final List<List<double>> slots;
  _MapPainter(this.m, this.img, this.rev, this.alpha, this.sel, this.heights, this.slots);

  void _text(Canvas c, String s, double x, double y, Color col, {double size = 22}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size, fontWeight: FontWeight.w800, shadows: const [Shadow(blurRadius: 4, color: Colors.black), Shadow(blurRadius: 8, color: Colors.black)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    final full = const Rect.fromLTWH(0, 0, W, H);
    if (img != null) {
      c.drawImageRect(img!, Rect.fromLTWH(0, 0, img!.width.toDouble(), img!.height.toDouble()), full, Paint()..filterQuality = FilterQuality.medium);
    } else {
      c.drawRect(full, Paint()..color = const Color(0xFF3A4A2E));
    }
    final t = m.terrain!;
    final p = Paint();
    if (alpha > 0) {
      for (int y = 0; y < GH; y++) {
        int x = 0;
        while (x < GW) {
          final v = t[y * GW + x];
          int e = x + 1;
          while (e < GW && t[y * GW + e] == v) {
            e++;
          }
          if (v != Ter.OPEN) {
            p.color = Color(terColor(v)).withValues(alpha: alpha);
            c.drawRect(Rect.fromLTWH(x * CELL, y * CELL, (e - x) * CELL, CELL), p);
          }
          x = e;
        }
      }
    }
    final h = m.height;
    if (heights && h != null) {
      for (int i = 0; i < h.length; i++) {
        if (h[i] <= .01) continue;
        p.color = Colors.white.withValues(alpha: h[i] * .55);
        c.drawRect(Rect.fromLTWH((i % GW) * CELL, (i ~/ GW) * CELL, CELL, CELL), p);
      }
    }
    // зоны
    for (int s = 0; s < 2; s++) {
      final z = m.zones[s], col = s == 0 ? kUa : kRu;
      final r = Rect.fromLTRB(z.x0, z.y0, z.x1, z.y1);
      c.drawRect(r, Paint()..color = col.withValues(alpha: .1));
      c.drawRect(r, Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);
      _text(c, s == 0 ? 'ЗОНА ВСУ' : 'ЗОНА РФ', r.center.dx, r.top + 24, col, size: 26);
    }
    // базы
    for (int s = 0; s < 2; s++) {
      final b = m.bases[s], col = s == 0 ? kUa : kRu;
      c.drawCircle(Offset(b[0], b[1]), 26, Paint()..color = col);
      c.drawCircle(Offset(b[0], b[1]), 26, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      _text(c, 'Б', b[0], b[1], Colors.white, size: 26);
    }
    // рубежи
    for (int i = 0; i < m.objs.length; i++) {
      final o = m.objs[i];
      final ow = i < m.owners.length ? m.owners[i] : -1;
      final col = ow == 0 ? kUa : (ow == 1 ? kRu : Colors.white);
      c.drawCircle(Offset(o.x, o.y), o.r, Paint()..color = col.withValues(alpha: .14));
      c.drawCircle(Offset(o.x, o.y), o.r, Paint()
        ..color = i == sel ? kAmber : col
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == sel ? 6 : 3.5);
      _text(c, '${o.key ? '★ ' : ''}${o.name}', o.x, o.y - o.r - 18, Colors.white);
    }
    // точки ИИ
    void mark(List<double>? pt, String s, Color col) {
      if (pt == null) return;
      c.drawRect(Rect.fromCenter(center: Offset(pt[0], pt[1]), width: 30, height: 30), Paint()..color = col);
      _text(c, s, pt[0], pt[1], Colors.black, size: 18);
    }

    mark(m.asm, 'С', const Color(0xFFE3B341));
    mark(m.choke, 'У', const Color(0xFF9EE09A));
    for (final s in slots) {
      c.drawCircle(Offset(s[0], s[1]), 8, Paint()..color = const Color(0xFF9EE09A));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter o) => o.rev != rev || o.alpha != alpha || o.sel != sel || o.img != img || o.heights != heights || o.slots != slots;
}
