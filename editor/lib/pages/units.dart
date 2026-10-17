// Раздел «Юниты»: характеристики, экипаж и оружие, своя графика техники; графика бойцов пехоты.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh/gfx/sprites.dart';
import 'package:rubezh/mod/codec.dart';
import 'package:rubezh/mod/mod.dart';

import '../files.dart';
import '../state.dart';
import '../widgets.dart';
import 'sprite_dialog.dart';

const List<(String, String)> CLASSES = [
  ('rifle', 'Пехота'),
  ('mg', 'Пулемётчики'),
  ('at', 'Противотанковые'),
  ('sniper', 'Снайперы'),
  ('mortar', 'Миномёты'),
  ('ifv', 'БМП / БТР'),
  ('tank', 'Танки'),
];
const List<(int, String)> SIDE_ITEMS = [(-1, 'Обе стороны'), (0, 'Украина'), (1, 'Россия')];
const List<String> JOBS = ['leader', 'rifle', 'gunner', 'grenadier', 'at', 'assist', 'sniper', 'spotter', 'loader', 'driver', 'commander'];
const Map<String, String> JOB_NAMES = {
  'leader': 'Командир отделения', 'rifle': 'Стрелок', 'gunner': 'Наводчик / пулемётчик', 'grenadier': 'Гранатомётчик (ГП)', 'at': 'Гранатомётчик / ПТ', //
  'assist': 'Помощник', 'sniper': 'Снайпер', 'spotter': 'Наблюдатель', 'loader': 'Заряжающий', 'driver': 'Механик-водитель', 'commander': 'Командир машины',
};

String clsName(String c) => CLASSES.firstWhere((e) => e.$1 == c, orElse: () => (c, c)).$2;

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});
  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  String? selId;
  Map<String, dynamic>? u; // рабочая копия
  bool dirty = false, isNew = false;
  String q = '';
  int tab = 0;
  int ver = 0; // для пересоздания полей при выборе
  bool spin = true;

  @override
  void initState() {
    super.initState();
    final id = Uri.base.queryParameters['unit'];
    if (id != null && VARS.containsKey(id)) select(id);
  }

  void select(String id) {
    setState(() {
      selId = id;
      u = ED.unitJson(id);
      dirty = false;
      isNew = false;
      ver++;
    });
  }

  void set(String k, dynamic v) => setState(() {
        u![k] = v;
        dirty = true;
      });

  Future<void> save() async {
    final x = u!;
    if (isNew && (VARS.containsKey(x['id']) || BASE_VARS.containsKey(x['id']))) {
      ED.say('Юнит с id «${x['id']}» уже есть');
      return;
    }
    x['veh'] = x['cls'] == 'ifv' || x['cls'] == 'tank';
    await ED.saveUnit(x);
    setState(() {
      dirty = false;
      isNew = false;
      selId = x['id'] as String;
    });
    ED.say('«${x['name']}» сохранён');
  }

  Future<void> create({Map<String, dynamic>? from}) async {
    final name = await ask(context, from == null ? 'Новый юнит' : 'Копия юнита', 'Название', init: from == null ? 'Новый отряд' : '${from['name']} (копия)');
    if (name == null) return;
    var id = slug(name);
    while (VARS.containsKey(id) || BASE_VARS.containsKey(id)) {
      id = '${id}_2';
    }
    final base = from != null ? jsonDecode(jsonEncode(from)) as Map<String, dynamic> : ED.unitJson('ua_rifle');
    base['id'] = id;
    base['name'] = name;
    if (from != null && base['look'] == null && (base['veh'] ?? false) == true) base['look'] = from['id'];
    setState(() {
      selId = id;
      u = base;
      dirty = true;
      isNew = true;
      ver++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ED,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Column(children: [
          Container(
            color: kPanel,
            child: TabBar(
              onTap: (i) => setState(() => tab = i),
              tabs: const [Tab(text: 'Отряды и техника'), Tab(text: 'Графика бойцов пехоты')],
            ),
          ),
          Expanded(
            child: tab == 0
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: 300, child: _list()),
                    const VerticalDivider(width: 1),
                    Expanded(child: u == null ? const Center(child: Text('Выберите юнит слева', style: TextStyle(color: kMut))) : _form()),
                  ])
                : SoldierArt(),
          ),
        ]),
      ),
    );
  }

  Widget _list() {
    final rem = ED.removed;
    final all = [...VARIANTS, for (final id in rem) if (BASE_VARS[id] != null) BASE_VARS[id]!];
    final f = all.where((v) => q.isEmpty || v.name.toLowerCase().contains(q.toLowerCase()) || v.id.contains(q.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => create(), icon: const Icon(Icons.add), label: const Text('Новый'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: u == null ? null : () => create(from: u), icon: const Icon(Icons.copy, size: 18), label: const Text('Копия'))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: TextField(decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Поиск'), onChanged: (v) => setState(() => q = v)),
      ),
      Expanded(
        child: ListView(children: [
          for (final c in CLASSES) ...[
            if (f.any((v) => v.cls == c.$1))
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text(c.$2.toUpperCase(), style: const TextStyle(fontSize: 11, color: kMut, fontWeight: FontWeight.w800, letterSpacing: 1))),
            for (final v in f.where((v) => v.cls == c.$1))
              ListTile(
                dense: true,
                selected: selId == v.id,
                enabled: true,
                leading: Container(
                  width: 8,
                  height: 26,
                  decoration: BoxDecoration(color: v.side == 0 ? kUa : (v.side == 1 ? kRu : kAmber), borderRadius: BorderRadius.circular(3)),
                ),
                title: Text(v.name, style: TextStyle(decoration: rem.contains(v.id) ? TextDecoration.lineThrough : null)),
                subtitle: Text('${v.id} · ◆ ${fmtNum(v.cost)}${ED.unitChanged(v.id) ? (ED.unitIsBase(v.id) ? ' · изменён' : ' · новый') : ''}${rem.contains(v.id) ? ' · убран' : ''}'),
                onTap: () async {
                  if (dirty && !await confirm(context, 'Несохранённые изменения', 'Перейти без сохранения?', ok: 'Перейти')) return;
                  select(v.id);
                },
              ),
          ],
        ]),
      ),
    ]);
  }

  List<String> _errors() {
    try {
      return checkUnit(unitFromJson(u!));
    } catch (e) {
      return ['$e'];
    }
  }

  Widget _form() {
    final x = u!;
    final id = x['id'] as String;
    final veh = x['cls'] == 'ifv' || x['cls'] == 'tank';
    final errs = _errors();
    final k = '$id.$ver';
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: const Color(0xFF12171B),
        child: Row(children: [
          Expanded(child: Text('${x['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (!isNew && ED.unitIsBase(id) && ED.unitChanged(id))
            TextButton(
              onPressed: () async {
                if (!await confirm(context, 'Сбросить', 'Вернуть исходные характеристики и графику?')) return;
                await ED.resetUnit(id);
                select(id);
              },
              child: const Text('Сбросить к исходному'),
            ),
          if (!isNew && ED.removed.contains(id))
            TextButton(
              onPressed: () async {
                await ED.restoreUnit(id);
                select(id);
              },
              child: const Text('Вернуть в игру'),
            )
          else if (!isNew)
            TextButton(
              onPressed: () async {
                if (!await confirm(context, 'Убрать из игры', '«${x['name']}» пропадёт из подбора сил и подкреплений.', ok: 'Убрать')) return;
                await ED.deleteUnit(id);
                setState(() {
                  if (!ED.unitIsBase(id)) {
                    u = null;
                    selId = null;
                  }
                });
              },
              child: const Text('Убрать из игры', style: TextStyle(color: Color(0xFFE0584A))),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: (dirty || isNew) && errs.isEmpty ? save : null, icon: const Icon(Icons.save_outlined), label: const Text('Сохранить')),
        ]),
      ),
      if (errs.isNotEmpty)
        Container(
          width: double.infinity,
          color: const Color(0x33E0584A),
          padding: const EdgeInsets.all(8),
          child: Text(errs.join(' · '), style: const TextStyle(color: Color(0xFFFF9478))),
        ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Section('Основное', [
            Fields([
              TextF('id (латиница)', id, (v) => set('id', slug(v)), key: ValueKey('id$k'), enabled: isNew),
              TextF('Название', '${x['name']}', (v) => set('name', v), key: ValueKey('nm$k')),
            ]),
            Fields([
              DropF<int>('Сторона', ((x['side'] ?? -1) as num).toInt(), SIDE_ITEMS, (v) => set('side', v)),
              DropF<String>('Класс', x['cls'] as String, CLASSES, (v) => set('cls', v)),
            ]),
            Fields([
              TextF('Описание (состав, оружие)', '${x['desc'] ?? ''}', (v) => set('desc', v), key: ValueKey('ds$k')),
              TextF('Подсказка (роль)', '${x['hint'] ?? ''}', (v) => set('hint', v), key: ValueKey('hn$k')),
            ]),
          ]),
          Section('Характеристики', [
            Fields([
              NumF('Цена', x['cost'] as num, (v) => set('cost', v), key: ValueKey('c$k'), suffix: '◆'),
              NumF('Прибытие', x['delay'] as num, (v) => set('delay', v), key: ValueKey('d$k'), suffix: 'с'),
              NumF('Скорость', x['speed'] as num, (v) => set('speed', v), key: ValueKey('s$k')),
            ]),
            Fields([
              NumF('Обзор', x['vision'] as num, (v) => set('vision', v), key: ValueKey('v$k'), suffix: 'м'),
              NumF('Стойкость', x['morale'] as num, (v) => set('morale', v), key: ValueKey('m$k')),
              NumF('Скрытность 0…1', (x['stealth'] ?? 0) as num, (v) => set('stealth', v), key: ValueKey('st$k')),
            ]),
          ]),
          if (veh)
            Section('Техника', [
              Fields([
                NumF('Длина', (x['len'] ?? 0) as num, (v) => set('len', v), key: ValueKey('l$k')),
                NumF('Ширина', (x['wid'] ?? 0) as num, (v) => set('wid', v), key: ValueKey('w$k')),
                NumF('Десант, мест', (x['cap'] ?? 0) as num, (v) => set('cap', v.toInt()), key: ValueKey('cp$k'), integer: true),
              ]),
              Fields([
                DropF<String>('Броня', (x['arm'] ?? '') as String, [for (final a in ARM.keys) (a, a)], (v) => set('arm', v)),
                NumF('Уязвимость БК 0…1', (x['vuln'] ?? 0) as num, (v) => set('vuln', v), key: ValueKey('vu$k')),
                SwitchF('Колёсная', (x['wheeled'] ?? false) as bool, (v) => set('wheeled', v)),
              ]),
            ]),
          _crew(x, k),
          if (veh) _art(x, k),
        ]),
      ),
    ]);
  }

  Widget _crew(Map<String, dynamic> x, String k) {
    final men = [for (final m in (x['men'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    void put() => set('men', men);
    return Section('Экипаж и оружие', [
      for (int i = 0; i < men.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              SizedBox(
                width: 240,
                child: DropF<String>('Роль', men[i]['job'] as String, [for (final j in JOBS) (j, JOB_NAMES[j] ?? j)], (v) {
                  men[i]['job'] = v;
                  put();
                }),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Убрать бойца',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () {
                  men.removeAt(i);
                  put();
                },
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Оружие:', style: TextStyle(color: kMut)),
              for (final w in (men[i]['w'] as List).cast<String>())
                InputChip(
                  label: Text(WPN[w]?.n ?? '$w (нет такого)'),
                  onDeleted: () {
                    men[i]['w'] = (men[i]['w'] as List).where((e) => e != w).toList();
                    put();
                  },
                ),
              PopupMenuButton<String>(
                tooltip: 'Добавить оружие',
                icon: const Icon(Icons.add_circle_outline),
                itemBuilder: (_) => [for (final w in WPN.values) PopupMenuItem(value: w.id, child: Text('${w.n} · ${w.k}'))],
                onSelected: (w) {
                  men[i]['w'] = [...(men[i]['w'] as List), w];
                  final a = Map<String, dynamic>.from(men[i]['a'] as Map);
                  for (final am in WPN[w]!.a) {
                    a.putIfAbsent(am, () => _defAmmo(am));
                  }
                  men[i]['a'] = a;
                  put();
                },
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Боезапас:', style: TextStyle(color: kMut)),
              for (final e in (men[i]['a'] as Map).entries)
                SizedBox(
                  width: 170,
                  child: Row(children: [
                    Expanded(
                      child: NumF(AMMO[e.key]?.n ?? '${e.key}?', e.value as num, (v) {
                        (men[i]['a'] as Map)[e.key] = v.toInt();
                        put();
                      }, key: ValueKey('a$k$i${e.key}'), integer: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        (men[i]['a'] as Map).remove(e.key);
                        put();
                      },
                    ),
                  ]),
                ),
              PopupMenuButton<String>(
                tooltip: 'Добавить боеприпас',
                icon: const Icon(Icons.add_circle_outline),
                itemBuilder: (_) => [for (final a in AMMO.values) PopupMenuItem(value: a.id, child: Text('${a.n} · ${a.k}'))],
                onSelected: (a) {
                  (men[i]['a'] as Map)[a] = _defAmmo(a);
                  put();
                },
              ),
            ]),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () {
            men.add({'job': 'rifle', 'w': <String>[], 'a': <String, int>{}});
            put();
          },
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Добавить бойца'),
        ),
      ),
    ]);
  }

  int _defAmmo(String a) {
    final k = AMMO[a]?.k ?? 'SA';
    return switch (k) { 'SA' => 150, 'HE' => 20, 'AP' => 30, 'HEAT' => 3, 'ATGM' => 3, 'SMK' => 6, _ => 10 };
  }

  Widget _art(Map<String, dynamic> x, String k) {
    final id = x['id'] as String;
    final art = Map<String, dynamic>.from((x['art'] as Map?) ?? {});
    void putArt() => set('art', art.isEmpty ? null : art);
    Future<void> pick(String part) async {
      final png = await pickSprite(context, part == 'hull' ? 'Корпус' : 'Башня',
          hint: part == 'hull' ? 'Корпус без башни, нос машины смотрит вправо.' : 'Башня отдельно, ствол смотрит вправо. Точку вращения потом можно указать кликом.');
      if (png == null) return;
      final rel = 'mod/art/${id}_$part.png';
      await ED.ws.write(rel, png);
      ED.forgetImage(rel);
      art[part] = rel;
      art['scale'] ??= 1.0;
      putArt();
    }

    double g(String k, double d) => ((art[k] ?? d) as num).toDouble();
    void setA(String k, double v, [int digits = 3]) {
      art[k] = double.parse(v.toStringAsFixed(digits));
      putArt();
    }

    return Section('Графика', [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          VehPreview(
            key: ValueKey('pv$k${ED.rev}${art['hull']}${art['turret']}'),
            unit: x,
            spin: spin,
            onPlace: art['hull'] == null
                ? null
                : (tx, ty) {
                    art['tx'] = double.parse(tx.toStringAsFixed(3));
                    art['ty'] = double.parse(ty.toStringAsFixed(3));
                    putArt();
                  },
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 320,
            child: Row(children: [
              Switch(value: spin, onChanged: (v) => setState(() => spin = v)),
              const SizedBox(width: 6),
              const Expanded(child: Text('Вращать башню', style: TextStyle(fontSize: 13))),
            ]),
          ),
          if (art['hull'] != null)
            const SizedBox(width: 320, child: Text('Клик по корпусу — поставить туда ось башни.', style: TextStyle(color: kMut, fontSize: 12))),
          if (art['turret'] != null) ...[
            const SizedBox(height: 10),
            PivotPicker(
              key: ValueKey('pp$k${ED.rev}${art['turret']}'),
              path: art['turret'] as String,
              px: g('px', .5),
              py: g('py', .5),
              onPick: (px, py) {
                art['px'] = double.parse(px.toStringAsFixed(3));
                art['py'] = double.parse(py.toStringAsFixed(3));
                putArt();
              },
            ),
            const SizedBox(width: 320, child: Text('Клик по башне — точка, вокруг которой она вращается (центр погона).', style: TextStyle(color: kMut, fontSize: 12))),
          ],
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropF<String>('Вид, нарисованный кодом (если нет своей картинки)', (x['look'] ?? id) as String,
                [for (final v in BASE_VARS.values.where((v) => v.veh)) (v.id, v.name), if (!BASE_VARS.containsKey(id)) (id, '— свой id —')], (v) => set('look', v == id ? null : v)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: () => pick('hull'), icon: const Icon(Icons.image_outlined), label: Text(art['hull'] == null ? 'Загрузить корпус' : 'Заменить корпус')),
              FilledButton.tonalIcon(onPressed: () => pick('turret'), icon: const Icon(Icons.image_outlined), label: Text(art['turret'] == null ? 'Загрузить башню' : 'Заменить башню')),
              if (art['turret'] != null)
                TextButton(
                  onPressed: () {
                    art.remove('turret');
                    putArt();
                  },
                  child: const Text('Без башни'),
                ),
              if (art.isNotEmpty)
                TextButton(
                  onPressed: () {
                    art.clear();
                    putArt();
                  },
                  child: const Text('Убрать свою графику'),
                ),
            ]),
            if (art['hull'] != null) ...[
              const SizedBox(height: 10),
              const Text('КОРПУС', style: TextStyle(color: kMut, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              SliderF('Масштаб корпуса', g('scale', 1), .3, 2.5, (v) => setA('scale', v, 2)),
              const SizedBox(height: 6),
              const Text('БАШНЯ', style: TextStyle(color: kMut, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              if (art['turret'] != null) SliderF('Размер башни', g('tscale', 1), .2, 2.5, (v) => setA('tscale', v, 2)),
              SliderF('Ось на корпусе: вдоль', g('tx', 0), -.6, .6, (v) => setA('tx', v)),
              SliderF('Ось на корпусе: поперёк', g('ty', 0), -.6, .6, (v) => setA('ty', v)),
              if (art['turret'] != null) ...[
                SliderF('Точка вращения: X', g('px', .5), 0, 1, (v) => setA('px', v)),
                SliderF('Точка вращения: Y', g('py', .5), 0, 1, (v) => setA('py', v)),
              ],
            ],
            const SizedBox(height: 6),
            const Text('PNG с прозрачным фоном лучше всего. Фон можно убрать при загрузке.', style: TextStyle(color: kMut, fontSize: 12)),
          ]),
        ),
      ]),
    ]);
  }
}

/// Предпросмотр техники: корпус и башня в масштабе игры; клик по корпусу ставит ось башни.
class VehPreview extends StatefulWidget {
  final Map<String, dynamic> unit;
  final bool spin;
  final void Function(double tx, double ty)? onPlace;
  const VehPreview({super.key, required this.unit, this.spin = true, this.onPlace});
  @override
  State<VehPreview> createState() => _VehPreviewState();
}

class _VehPreviewState extends State<VehPreview> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  ui.Image? hull, tur;
  static const Size sz = Size(320, 240);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final u = widget.unit;
    final art = u['art'] as Map?;
    ui.Image? h, t;
    if (art?['hull'] != null) {
      h = await ED.image(art!['hull'] as String);
      if (art['turret'] != null) t = await ED.image(art['turret'] as String);
    } else {
      try {
        final v = unitFromJson(u);
        final look = (u['look'] != null ? BASE_VARS[u['look']] : null) ?? BASE_VARS[u['id']] ?? v;
        final s = look.sides.first;
        h = await spHull(look, s);
        t = (await spTurret(look, s)).img;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        hull = h;
        tur = t;
      });
    }
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.onPlace == null
            ? null
            : (d) {
                final g = VehGeom(widget.unit, hull, sz);
                final wx = (d.localPosition.dx - sz.width / 2) / g.k, wy = (d.localPosition.dy - sz.height / 2) / g.k;
                widget.onPlace!((wx / g.len).clamp(-.6, .6), (wy / g.wid).clamp(-.6, .6));
              },
        child: MouseRegion(
          cursor: widget.onPlace == null ? MouseCursor.defer : SystemMouseCursors.precise,
          child: Container(
            width: sz.width,
            height: sz.height,
            decoration: BoxDecoration(color: const Color(0xFF3A4A2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
            child: AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: _VehPainter(widget.unit, hull, tur, widget.spin ? ac.value : 0))),
          ),
        ),
      );
}

/// Геометрия предпросмотра: размеры в метрах игры и масштаб на экране.
class VehGeom {
  late final double len, wid, hw, hh, k;
  late final bool custom;
  late final Map? art;
  VehGeom(Map<String, dynamic> u, ui.Image? hull, Size s) {
    len = ((u['len'] ?? 30) as num).toDouble();
    wid = ((u['wid'] ?? 14) as num).toDouble();
    art = u['art'] as Map?;
    custom = art?['hull'] != null;
    final sc = custom ? ((art!['scale'] ?? 1) as num).toDouble() : 1.0;
    hw = (len + 3) * sc;
    hh = custom && hull != null ? hw * hull.height / hull.width : wid + 3;
    k = math.min(s.width * .72 / math.max(hw, len), s.height * .72 / math.max(hh, wid));
  }
}

class _VehPainter extends CustomPainter {
  final Map<String, dynamic> u;
  final ui.Image? hull, tur;
  final double t;
  _VehPainter(this.u, this.hull, this.tur, this.t);

  @override
  void paint(Canvas c, Size s) {
    final g = VehGeom(u, hull, s);
    final k = g.k;
    c.translate(s.width / 2, s.height / 2);
    c.scale(k);
    // габарит машины
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: g.len, height: g.wid), Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / k);
    final h = hull;
    if (h == null) return;
    final p = Paint()..filterQuality = FilterQuality.medium;
    c.drawImageRect(h, Rect.fromLTWH(0, 0, h.width.toDouble(), h.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: g.hw, height: g.hh), p);
    final art = g.art;
    double num0(String key, double d) => ((art?[key] ?? d) as num).toDouble();
    final tx = g.custom ? g.len * num0('tx', 0) : g.len * .05, ty = g.custom ? g.wid * num0('ty', 0) : 0.0;
    final tu = tur;
    c.save();
    c.translate(tx, ty);
    c.rotate(math.sin(t * math.pi * 2) * .9);
    if (tu != null) {
      final tw = g.custom ? g.hw * tu.width / h.width * num0('tscale', 1) : (g.len + 3), th = tw * tu.height / tu.width;
      final px = g.custom ? num0('px', .5) : .5, py = g.custom ? num0('py', .5) : .5;
      c.drawImageRect(tu, Rect.fromLTWH(0, 0, tu.width.toDouble(), tu.height.toDouble()), Rect.fromLTWH(-tw * px, -th * py, tw, th), p);
    }
    // ось вращения
    final cr = Paint()
      ..color = const Color(0xFFE3B341)
      ..strokeWidth = 1.5 / k;
    c.drawLine(Offset(-4 / k, 0), Offset(4 / k, 0), cr);
    c.drawLine(Offset(0, -4 / k), Offset(0, 4 / k), cr);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _VehPainter o) => true;
}

/// Картинка башни отдельно: клик задаёт точку вращения.
class PivotPicker extends StatefulWidget {
  final String path;
  final double px, py;
  final void Function(double px, double py) onPick;
  const PivotPicker({super.key, required this.path, required this.px, required this.py, required this.onPick});
  @override
  State<PivotPicker> createState() => _PivotPickerState();
}

class _PivotPickerState extends State<PivotPicker> {
  ui.Image? img;
  static const Size sz = Size(320, 160);

  @override
  void initState() {
    super.initState();
    ED.image(widget.path).then((i) {
      if (mounted) setState(() => img = i);
    });
  }

  Rect _dst() {
    final i = img!;
    final k = math.min((sz.width - 20) / i.width, (sz.height - 20) / i.height);
    final w = i.width * k, h = i.height * k;
    return Rect.fromLTWH((sz.width - w) / 2, (sz.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: img == null
          ? null
          : (d) {
              final r = _dst();
              widget.onPick(((d.localPosition.dx - r.left) / r.width).clamp(0.0, 1.0), ((d.localPosition.dy - r.top) / r.height).clamp(0.0, 1.0));
            },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: Container(
          width: sz.width,
          height: sz.height,
          decoration: BoxDecoration(color: const Color(0xFF2A3A24), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
          child: img == null ? null : CustomPaint(painter: _PivotPainter(img!, _dst(), widget.px, widget.py)),
        ),
      ),
    );
  }
}

class _PivotPainter extends CustomPainter {
  final ui.Image img;
  final Rect dst;
  final double px, py;
  _PivotPainter(this.img, this.dst, this.px, this.py);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(dst, Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke);
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);
    final o = Offset(dst.left + dst.width * px, dst.top + dst.height * py);
    final p = Paint()
      ..color = const Color(0xFFE3B341)
      ..strokeWidth = 2;
    c.drawLine(o.translate(-10, 0), o.translate(10, 0), p);
    c.drawLine(o.translate(0, -10), o.translate(0, 10), p);
    c.drawCircle(o, 6, p..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _PivotPainter o) => o.px != px || o.py != py || o.img != img || o.dst != dst;
}

/// Графика бойцов: для каждой стороны и вида бойца — своя картинка (вид сверху, смотрит вправо).
class SoldierArt extends StatelessWidget {
  const SoldierArt({super.key});
  static const kinds = [('rifle', 'Стрелок'), ('lead', 'Командир'), ('gren', 'Гранатомётчик (ГП)'), ('mg', 'Пулемётчик'), ('at', 'Гранатомётчик / ПТРК'), ('sniper', 'Снайпер')];

  @override
  Widget build(BuildContext context) {
    final sol = Map<String, dynamic>.from((ED.mod['soldiers'] as Map?) ?? {});
    Future<void> pick(int side, String k) async {
      final png = await pickSprite(context, 'Боец: ${kinds.firstWhere((e) => e.$1 == k).$2}', hint: 'Вид сверху, боец смотрит вправо. Картинка будет уменьшена до размера бойца.');
      if (png == null) return;
      final rel = 'mod/art/soldier_${side}_$k.png';
      await ED.ws.write(rel, png);
      ED.forgetImage(rel);
      final m = Map<String, dynamic>.from((sol['$side'] as Map?) ?? {});
      m[k] = rel;
      sol['$side'] = m;
      ED.mod['soldiers'] = sol;
      await ED.saveMod();
    }

    Future<void> clear(int side, String k) async {
      final m = Map<String, dynamic>.from((sol['$side'] as Map?) ?? {});
      m.remove(k);
      sol['$side'] = m;
      ED.mod['soldiers'] = sol;
      await ED.saveMod();
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final side in const [0, 1])
        Section(side == 0 ? 'Украина' : 'Россия', [
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final kd in kinds)
              Builder(builder: (context) {
                final rel = (sol['$side'] as Map?)?[kd.$1] as String?;
                return Container(
                  width: 180,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                  child: Column(children: [
                    SizedBox(
                      height: 80,
                      child: rel == null
                          ? const Center(child: Text('нарисован кодом', style: TextStyle(color: kMut)))
                          : FutureBuilder(
                              future: ED.ws.bytes(rel),
                              builder: (_, s) => s.data == null ? const SizedBox() : Image.memory(s.data!, fit: BoxFit.contain),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(kd.$2, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(onPressed: () => pick(side, kd.$1), child: Text(rel == null ? 'Загрузить' : 'Заменить')),
                      if (rel != null) IconButton(onPressed: () => clear(side, kd.$1), icon: const Icon(Icons.close, size: 18)),
                    ]),
                  ]),
                );
              }),
          ]),
        ]),
    ]);
  }
}
