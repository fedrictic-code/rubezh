// Перевод данных игры в JSON и обратно (для модов и редактора).
import '../game/data.dart';

double _d(dynamic v, [double def = 0]) => v == null ? def : (v as num).toDouble();
List<double> _dl(dynamic v, List<double> def) => v == null ? def : [for (final x in v as List) (x as num).toDouble()];

Map<String, dynamic> ammoToJson(Ammo a) => {
      'id': a.id,
      'k': a.k,
      'n': a.n,
      'pen': a.pen,
      'supp': a.supp,
      'kill': a.kill,
      'rad': a.rad,
      'spd': a.spd,
      'cal': a.cal,
      'top': a.top,
      'burst': a.burst,
    };

Ammo ammoFromJson(Map<String, dynamic> j) => Ammo(
      j['id'] as String,
      (j['k'] ?? 'SA') as String,
      (j['n'] ?? j['id']) as String,
      pen: _dl(j['pen'], const [0, 0]),
      supp: _d(j['supp']),
      kill: _d(j['kill']),
      rad: _d(j['rad']),
      spd: _d(j['spd']),
      cal: _d(j['cal']),
      top: (j['top'] ?? false) as bool,
      burst: (j['burst'] ?? false) as bool,
    );

Map<String, dynamic> wpnToJson(Wpn w) => {
      'id': w.id,
      'n': w.n,
      'k': w.k,
      'rpm': w.rpm,
      'mag': w.mag,
      'rl': w.rl,
      'rng': w.rng,
      'acc': w.acc,
      'a': w.a,
      'minR': w.minR,
      'setup': w.setup,
      if (w.job != null) 'job': w.job,
      'coax': w.coax,
      'auto': w.auto,
      'loader': w.loader,
      'disp': w.disp,
    };

Wpn wpnFromJson(Map<String, dynamic> j) => Wpn(
      j['id'] as String,
      (j['n'] ?? j['id']) as String,
      (j['k'] ?? 'rifle') as String,
      _d(j['rpm'], 60),
      _d(j['mag'], 30),
      _d(j['rl'], 3),
      _d(j['rng'], 300),
      _d(j['acc'], .3),
      [for (final a in (j['a'] as List? ?? const [])) a as String],
      minR: _d(j['minR']),
      setup: _d(j['setup']),
      job: j['job'] as String?,
      coax: (j['coax'] ?? false) as bool,
      auto: (j['auto'] ?? false) as bool,
      loader: (j['loader'] ?? false) as bool,
      disp: (j['disp'] ?? false) as bool,
    );

Map<String, dynamic> armToJson(String id, Arm a) => {'id': id, 'f': a.f, 's': a.s, 'r': a.r, 't': a.t};

Arm armFromJson(Map<String, dynamic> j) => Arm(_dl(j['f'], const [10, 10]), _dl(j['s'], const [10, 10]), _dl(j['r'], const [8, 8]), _dl(j['t'], const [6, 6]));

Map<String, dynamic> artToJson(UnitArt a) => {
      if (a.hull != null) 'hull': a.hull,
      if (a.turret != null) 'turret': a.turret,
      'scale': a.scale,
      'tx': a.tx,
      'ty': a.ty,
    };

UnitArt? artFromJson(dynamic j) {
  if (j == null) return null;
  final m = j as Map<String, dynamic>;
  return UnitArt(hull: m['hull'] as String?, turret: m['turret'] as String?, scale: _d(m['scale'], 1), tx: _d(m['tx']), ty: _d(m['ty']));
}

Map<String, dynamic> unitToJson(Variant v) => {
      'id': v.id,
      'cls': v.cls,
      'side': v.side,
      'name': v.name,
      'desc': v.desc,
      'hint': v.hint,
      'cost': v.cost,
      'delay': v.delay,
      'speed': v.speed,
      'vision': v.vision,
      'morale': v.morale,
      'men': [
        for (final m in v.men) {'job': m.job, 'w': m.w, 'a': m.a}
      ],
      'veh': v.veh,
      'wheeled': v.wheeled,
      'cap': v.cap,
      'len': v.len,
      'wid': v.wid,
      'vuln': v.vuln,
      'stealth': v.stealth,
      if (v.armId != null) 'arm': v.armId,
      if (v.look != null) 'look': v.look,
      if (v.art != null) 'art': artToJson(v.art!),
    };

Variant unitFromJson(Map<String, dynamic> j) {
  final armId = j['arm'] as String?;
  return Variant(
    j['id'] as String,
    (j['cls'] ?? 'rifle') as String,
    ((j['side'] ?? -1) as num).toInt(),
    (j['name'] ?? j['id']) as String,
    (j['desc'] ?? '') as String,
    _d(j['cost'], 100),
    _d(j['delay'], 10),
    _d(j['speed'], 12),
    _d(j['vision'], 360),
    _d(j['morale'], 70),
    (j['hint'] ?? '') as String,
    [
      for (final m in (j['men'] as List? ?? const []))
        Man((m['job'] ?? 'rifle') as String, [for (final w in (m['w'] as List? ?? const [])) w as String],
            {for (final e in ((m['a'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()})
    ],
    veh: (j['veh'] ?? false) as bool,
    wheeled: (j['wheeled'] ?? false) as bool,
    cap: ((j['cap'] ?? 0) as num).toInt(),
    len: _d(j['len']),
    wid: _d(j['wid']),
    vuln: _d(j['vuln']),
    stealth: _d(j['stealth']),
    arm: armId != null ? ARM[armId] : null,
    armId: armId,
    look: j['look'] as String?,
    art: artFromJson(j['art']),
  );
}

/// Проверка юнита: всё ли оружие и боеприпасы существуют. Пустой список — ошибок нет.
List<String> checkUnit(Variant v) {
  final out = <String>[];
  if (v.men.isEmpty) out.add('В отряде нет бойцов');
  for (final m in v.men) {
    for (final w in m.w) {
      if (!WPN.containsKey(w)) out.add('Нет оружия «$w»');
    }
    for (final a in m.a.keys) {
      if (!AMMO.containsKey(a)) out.add('Нет боеприпаса «$a»');
    }
  }
  if (v.veh && v.armId != null && !ARM.containsKey(v.armId)) out.add('Нет брони «${v.armId}»');
  return out;
}
