// Раздел «Оружие»: оружие, боеприпасы, броня.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh/mod/codec.dart';
import 'package:rubezh/mod/mod.dart';

import '../files.dart';
import '../state.dart';
import '../widgets.dart';

const List<(String, String)> WPN_KINDS = [
  ('rifle', 'Автомат / винтовка'),
  ('mg', 'Пулемёт'),
  ('hmg', 'Крупнокалиберный пулемёт'),
  ('sniper', 'Снайперская винтовка'),
  ('ugl', 'Подствольный гранатомёт'),
  ('rocket', 'Гранатомёт (ракета)'),
  ('atgm', 'ПТУР'),
  ('mortar', 'Миномёт'),
  ('cannon', 'Пушка'),
  ('acan', 'Автоматическая пушка'),
];
const List<(String, String)> AMMO_KINDS = [
  ('SA', 'Пули'),
  ('HE', 'Осколочно-фугасный'),
  ('AP', 'Бронебойный'),
  ('HEAT', 'Кумулятивный'),
  ('ATGM', 'Ракета ПТУР'),
  ('SMK', 'Дымовой'),
];

class WeaponsPage extends StatefulWidget {
  const WeaponsPage({super.key});
  @override
  State<WeaponsPage> createState() => _WeaponsPageState();
}

class _WeaponsPageState extends State<WeaponsPage> {
  int tab = 0;
  String? sel;
  Map<String, dynamic>? cur;
  bool dirty = false, isNew = false;
  int ver = 0;

  String get key => const ['weapons', 'ammo', 'armor'][tab];
  bool isBase(String id) => switch (tab) { 0 => BASE_WPN.containsKey(id), 1 => BASE_AMMO.containsKey(id), _ => BASE_ARM.containsKey(id) };
  bool exists(String id) => switch (tab) { 0 => WPN.containsKey(id), 1 => AMMO.containsKey(id), _ => ARM.containsKey(id) };

  Map<String, dynamic> jsonOf(String id) {
    final m = ED.modItem(key, id);
    if (m != null) return jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    final j = switch (tab) { 0 => wpnToJson(WPN[id]!), 1 => ammoToJson(AMMO[id]!), _ => armToJson(id, ARM[id]!) };
    return jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
  }

  List<(String, String)> items() => switch (tab) {
        0 => [for (final w in WPN.values) (w.id, '${w.n} · ${w.k}')],
        1 => [for (final a in AMMO.values) (a.id, '${a.n} · ${a.k}')],
        _ => [for (final a in ARM.keys) (a, a)],
      };

  void open(String id) => setState(() {
        sel = id;
        cur = jsonOf(id);
        dirty = false;
        isNew = false;
        ver++;
      });

  void set(String k, dynamic v) => setState(() {
        cur![k] = v;
        dirty = true;
      });

  Future<void> save() async {
    final c = cur!;
    if (isNew && exists(c['id'] as String)) {
      ED.say('id «${c['id']}» уже занят');
      return;
    }
    ED.putItem(key, c);
    await ED.saveMod();
    setState(() {
      dirty = false;
      isNew = false;
      sel = c['id'] as String;
    });
    ED.say('Сохранено');
  }

  Future<void> create() async {
    final name = await ask(context, 'Новый элемент', 'Название');
    if (name == null) return;
    var id = slug(name);
    while (exists(id)) {
      id = '${id}_2';
    }
    final base = cur != null ? jsonDecode(jsonEncode(cur)) as Map<String, dynamic> : jsonOf(items().first.$1);
    base['id'] = id;
    if (tab < 2) base['n'] = name;
    setState(() {
      sel = id;
      cur = base;
      isNew = true;
      dirty = true;
      ver++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ED,
      builder: (context, _) => DefaultTabController(
        length: 3,
        child: Column(children: [
          Container(
            color: kPanel,
            child: TabBar(
              onTap: (i) => setState(() {
                tab = i;
                sel = null;
                cur = null;
              }),
              tabs: const [Tab(text: 'Оружие'), Tab(text: 'Боеприпасы'), Tab(text: 'Броня')],
            ),
          ),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 300,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: Text(cur == null ? 'Новый' : 'Новый (копия выбранного)')),
                  ),
                  Expanded(
                    child: ListView(children: [
                      for (final it in items())
                        ListTile(
                          dense: true,
                          selected: sel == it.$1,
                          title: Text(it.$2),
                          subtitle: Text('${it.$1}${ED.modItem(key, it.$1) != null ? (isBase(it.$1) ? ' · изменён' : ' · новый') : ''}'),
                          onTap: () async {
                            if (dirty && !await confirm(context, 'Несохранённые изменения', 'Перейти без сохранения?', ok: 'Перейти')) return;
                            open(it.$1);
                          },
                        ),
                    ]),
                  ),
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: cur == null ? const Center(child: Text('Выберите слева', style: TextStyle(color: kMut))) : _form()),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _form() {
    final c = cur!;
    final id = c['id'] as String;
    final k = '$tab$id$ver';
    final used = tab == 0
        ? VARIANTS.where((v) => v.men.any((m) => m.w.contains(id))).map((v) => v.name).toList()
        : tab == 1
            ? WPN.values.where((w) => w.a.contains(id)).map((w) => w.n).toList()
            : VARIANTS.where((v) => v.armId == id).map((v) => v.name).toList();
    return Column(children: [
      Container(
        color: const Color(0xFF12171B),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Expanded(child: Text(tab < 2 ? '${c['n']}' : id, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (!isNew && ED.modItem(key, id) != null)
            TextButton(
              onPressed: () async {
                final msg = isBase(id) ? 'Вернуть исходные значения?' : 'Удалить этот элемент? Юниты, которые его используют, перестанут загружаться.';
                if (!await confirm(context, isBase(id) ? 'Сбросить' : 'Удалить', msg)) return;
                ED.dropItem(key, id);
                await ED.saveMod();
                if (isBase(id)) {
                  open(id);
                } else {
                  setState(() {
                    cur = null;
                    sel = null;
                  });
                }
              },
              child: Text(isBase(id) ? 'Сбросить к исходному' : 'Удалить'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: dirty || isNew ? save : null, icon: const Icon(Icons.save_outlined), label: const Text('Сохранить')),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (tab == 0) ..._weapon(c, k),
          if (tab == 1) ..._ammo(c, k),
          if (tab == 2) ..._armor(c, k),
          if (used.isNotEmpty) Text('Используется: ${used.join(', ')}', style: const TextStyle(color: kMut)),
        ]),
      ),
    ]);
  }

  List<Widget> _weapon(Map<String, dynamic> c, String k) => [
        Section('Оружие', [
          Fields([
            TextF('id', c['id'] as String, (v) => set('id', slug(v)), key: ValueKey('i$k'), enabled: isNew),
            TextF('Название', '${c['n']}', (v) => set('n', v), key: ValueKey('n$k')),
            DropF<String>('Тип', c['k'] as String, WPN_KINDS, (v) => set('k', v)),
          ]),
          Fields([
            NumF('Выстрелов в минуту', c['rpm'] as num, (v) => set('rpm', v), key: ValueKey('r$k')),
            NumF('Магазин', c['mag'] as num, (v) => set('mag', v), key: ValueKey('m$k')),
            NumF('Перезарядка', c['rl'] as num, (v) => set('rl', v), key: ValueKey('rl$k'), suffix: 'с'),
          ]),
          Fields([
            NumF('Дальность', c['rng'] as num, (v) => set('rng', v), key: ValueKey('g$k'), suffix: 'м'),
            NumF('Точность 0…1', c['acc'] as num, (v) => set('acc', v), key: ValueKey('a$k')),
            NumF('Мин. дальность', (c['minR'] ?? 0) as num, (v) => set('minR', v), key: ValueKey('mi$k'), suffix: 'м'),
          ]),
          Fields([
            NumF('Развёртывание', (c['setup'] ?? 0) as num, (v) => set('setup', v), key: ValueKey('su$k'), suffix: 'с'),
            DropF<String>('Кто стреляет (в технике)', (c['job'] ?? '') as String, const [('', 'Любой'), ('gunner', 'Наводчик'), ('commander', 'Командир')], (v) => set('job', v.isEmpty ? null : v)),
            const SizedBox(),
          ]),
          Wrap(spacing: 16, children: [
            SwitchF('Спаренный (стреляет вместе с пушкой)', (c['coax'] ?? false) as bool, (v) => set('coax', v)),
            SwitchF('Автомат заряжания', (c['auto'] ?? false) as bool, (v) => set('auto', v)),
            SwitchF('Нужен заряжающий', (c['loader'] ?? false) as bool, (v) => set('loader', v)),
            SwitchF('Одноразовый', (c['disp'] ?? false) as bool, (v) => set('disp', v)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Боеприпасы:', style: TextStyle(color: kMut)),
            for (final a in (c['a'] as List).cast<String>())
              InputChip(label: Text(AMMO[a]?.n ?? '$a?'), onDeleted: () => set('a', (c['a'] as List).where((x) => x != a).toList())),
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline),
              itemBuilder: (_) => [for (final a in AMMO.values) PopupMenuItem(value: a.id, child: Text('${a.n} · ${a.k}'))],
              onSelected: (a) => set('a', [...(c['a'] as List), a]),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Звук выстрела задаётся по типу оружия в разделе «Звуки».', style: TextStyle(color: kMut, fontSize: 12)),
        ]),
      ];

  List<Widget> _ammo(Map<String, dynamic> c, String k) {
    final pen = [for (final x in (c['pen'] as List? ?? const [0, 0])) (x as num).toDouble()];
    return [
      Section('Боеприпас', [
        Fields([
          TextF('id', c['id'] as String, (v) => set('id', slug(v)), key: ValueKey('i$k'), enabled: isNew),
          TextF('Название', '${c['n']}', (v) => set('n', v), key: ValueKey('n$k')),
          DropF<String>('Тип', c['k'] as String, AMMO_KINDS, (v) => set('k', v)),
        ]),
        Fields([
          NumF('Пробитие вблизи, мм', pen[0], (v) => set('pen', [v, pen[1]]), key: ValueKey('p0$k')),
          NumF('Пробитие на 1 км, мм', pen[1], (v) => set('pen', [pen[0], v]), key: ValueKey('p1$k')),
          NumF('Калибр, мм', (c['cal'] ?? 0) as num, (v) => set('cal', v), key: ValueKey('cl$k')),
        ]),
        Fields([
          NumF('Подавление', (c['supp'] ?? 0) as num, (v) => set('supp', v), key: ValueKey('su$k')),
          NumF('Убойность 0…1', (c['kill'] ?? 0) as num, (v) => set('kill', v), key: ValueKey('ki$k')),
          NumF('Радиус разрыва', (c['rad'] ?? 0) as num, (v) => set('rad', v), key: ValueKey('ra$k'), suffix: 'м'),
        ]),
        Fields([
          NumF('Скорость полёта', (c['spd'] ?? 0) as num, (v) => set('spd', v), key: ValueKey('sp$k'), suffix: 'м/с'),
          SwitchF('Удар сверху (по крыше)', (c['top'] ?? false) as bool, (v) => set('top', v)),
          SwitchF('Очередью', (c['burst'] ?? false) as bool, (v) => set('burst', v)),
        ]),
      ]),
    ];
  }

  List<Widget> _armor(Map<String, dynamic> c, String k) {
    List<double> pair(String f) => [for (final x in (c[f] as List? ?? const [10, 10])) (x as num).toDouble()];
    Widget row(String f, String name) {
      final p = pair(f);
      return Fields([
        Text(name, style: const TextStyle(height: 2.6)),
        NumF('Корпус, мм', p[0], (v) => set(f, [v, p[1]]), key: ValueKey('$f 0$k')),
        NumF('Башня, мм', p[1], (v) => set(f, [p[0], v]), key: ValueKey('$f 1$k')),
      ]);
    }

    return [
      Section('Броня (эквивалент, мм)', [
        Fields([TextF('id', c['id'] as String, (v) => set('id', slug(v)), key: ValueKey('i$k'), enabled: isNew), const SizedBox(), const SizedBox()]),
        row('f', 'Лоб'),
        row('s', 'Борт'),
        row('r', 'Корма'),
        row('t', 'Крыша'),
      ]),
    ];
  }
}
