// Данные: боеприпасы, оружие, составы отрядов, техника.
// Значения ориентировочные; баланс настраивается здесь.

class Ammo {
  final String id, k, n;
  final List<double> pen;
  final double supp, kill, rad, spd, cal;
  final bool top, burst;
  const Ammo(this.id, this.k, this.n,
      {this.pen = const [0, 0], this.supp = 0, this.kill = 0, this.rad = 0, this.spd = 0, this.cal = 0, this.top = false, this.burst = false});
  bool get hasPen => pen[0] > 0 || pen[1] > 0;
  Ammo withTop() => Ammo(id, k, n, pen: pen, supp: supp, kill: kill, rad: rad, spd: spd, cal: cal, top: true, burst: burst);
}

class Wpn {
  final String id, n, k;
  final double rpm, mag, rl, rng, acc, minR, setup;
  final List<String> a;
  final String? job;
  final bool coax, auto, loader, disp;
  const Wpn(this.id, this.n, this.k, this.rpm, this.mag, this.rl, this.rng, this.acc, this.a,
      {this.minR = 0, this.setup = 0, this.job, this.coax = false, this.auto = false, this.loader = false, this.disp = false});
}

class Arm {
  final List<double> f, s, r, t;
  const Arm(this.f, this.s, this.r, this.t);
}

class Man {
  final String job;
  final List<String> w;
  final Map<String, int> a;
  const Man(this.job, this.w, this.a);
}

class Variant {
  final String id, cls, name, desc, hint;
  final int side; // -1 — обе стороны
  final bool veh, wheeled;
  final int cap;
  final double cost, delay, speed, vision, morale, len, wid, vuln, stealth;
  final Arm? arm;
  final List<Man> men;
  // производные
  late final int max;
  late final bool mortar;
  late final List<int> sides;
  late final double range, sr, atR, atPen, saPen;
  late final bool hasShot, vehOnly;
  late final double shotRange;
  final double supp = 1, ammoUse = .3;
  late final double moveFire, fpInf, vsVeh, minRange;
  Variant(this.id, this.cls, this.side, this.name, this.desc, this.cost, this.delay, this.speed, this.vision, this.morale, this.hint, this.men,
      {this.veh = false, this.wheeled = false, this.cap = 0, this.len = 0, this.wid = 0, this.arm, this.vuln = 0, this.stealth = 0}) {
    max = men.length;
    mortar = cls == 'mortar';
    sides = side == -1 ? [0, 1] : [side];
    double rng = 0, sr0 = 0, atr = 0;
    bool shot = false;
    for (final man in men) {
      for (final id in man.w) {
        final w = WPN[id];
        if (w == null) continue;
        if (w.rng > rng) rng = w.rng;
        if (w.k == 'rocket' || w.k == 'atgm' || w.k == 'cannon') {
          shot = true;
          if (w.rng > atr) atr = w.rng;
        }
        if (const ['rifle', 'mg', 'hmg', 'sniper', 'acan', 'ugl', 'cannon'].contains(w.k) && w.rng > sr0) sr0 = w.rng;
      }
    }
    double atp = 0, sap = 0;
    for (final man in men) {
      for (final id in man.w) {
        final w = WPN[id]!;
        for (final k in w.a) {
          final a = AMMO[k]!;
          if (!a.hasPen) continue;
          if (a.k == 'HEAT' || a.k == 'ATGM' || (w.k == 'cannon' && a.k == 'AP')) {
            if (a.pen[0] > atp) atp = a.pen[0];
          } else if (w.k != 'cannon' && w.k != 'mortar') {
            if (a.pen[0] > sap) sap = a.pen[0];
          }
        }
      }
    }
    range = mortar ? 1300 : (rng < 1 ? 1 : rng);
    sr = mortar ? 0 : sr0;
    atR = atr;
    hasShot = shot;
    shotRange = atr > 0 ? atr : range;
    vehOnly = cls == 'at';
    atPen = atp;
    saPen = sap;
    moveFire = cls == 'sniper' ? 0 : (veh ? .5 : .3);
    fpInf = mortar ? 0 : 1;
    vsVeh = mortar ? 0 : 1;
    minRange = mortar ? 240 : 0;
  }
}


const Map<String, Ammo> AMMO = {
  'sa545': Ammo('sa545', 'SA', '5,45×39', pen: [3.0, 2.0], supp: 0.35, kill: 0.42),
  'sa556': Ammo('sa556', 'SA', '5,56×45', pen: [3.0, 2.0], supp: 0.35, kill: 0.42),
  'sa762': Ammo('sa762', 'SA', '7,62×54R', pen: [9.0, 5.0], supp: 0.6, kill: 0.55),
  'sa127': Ammo('sa127', 'SA', '12,7 мм', pen: [24.0, 13.0], supp: 1.5, kill: 0.85),
  'sa338': Ammo('sa338', 'SA', '8,6 мм', pen: [8.0, 5.0], supp: 0.8, kill: 0.9),
  'sa50': Ammo('sa50', 'SA', '12,7×99', pen: [24.0, 15.0], supp: 1.5, kill: 0.92),
  'vog25': Ammo('vog25', 'HE', 'ВОГ-25', pen: [0.0, 0.0], supp: 6.0, kill: 0.75, rad: 7.0, spd: 76.0, cal: 40.0),
  'ap30': Ammo('ap30', 'AP', '30 мм БПС', pen: [58.0, 36.0], supp: 3.0, kill: 0.6, cal: 30.0, burst: true),
  'he30': Ammo('he30', 'HE', '30 мм ОФ', pen: [12.0, 8.0], supp: 3.0, kill: 0.5, rad: 4.0, cal: 30.0, burst: true),
  'ap25': Ammo('ap25', 'AP', '25 мм БПС', pen: [62.0, 46.0], supp: 3.0, kill: 0.6, cal: 25.0, burst: true),
  'he25': Ammo('he25', 'HE', '25 мм ОФ', pen: [10.0, 7.0], supp: 3.0, kill: 0.5, rad: 4.0, cal: 25.0, burst: true),
  'apfsds125': Ammo('apfsds125', 'AP', '125 мм БОПС', pen: [570.0, 520.0], supp: 12.0, spd: 1700.0, cal: 125.0),
  'heat125': Ammo('heat125', 'HEAT', '125 мм КС', pen: [620.0, 620.0], supp: 12.0, spd: 900.0, cal: 125.0),
  'he125': Ammo('he125', 'HE', '125 мм ОФ', pen: [75.0, 65.0], supp: 14.0, kill: 0.9, rad: 20.0, spd: 850.0, cal: 125.0),
  'apfsds120': Ammo('apfsds120', 'AP', '120 мм БОПС', pen: [730.0, 700.0], supp: 12.0, spd: 1650.0, cal: 120.0),
  'heat120': Ammo('heat120', 'HEAT', '120 мм КС', pen: [520.0, 520.0], supp: 12.0, spd: 1100.0, cal: 120.0),
  'he100': Ammo('he100', 'HE', '100 мм ОФ', pen: [55.0, 48.0], supp: 11.0, kill: 0.9, rad: 17.0, spd: 250.0, cal: 100.0),
  'he82': Ammo('he82', 'HE', '82 мм ОФ', pen: [28.0, 0.0], supp: 28.0, kill: 0.8, rad: 38.0, cal: 82.0),
  'smk82': Ammo('smk82', 'SMK', '82 мм дымовая', cal: 82.0),
  'pg7': Ammo('pg7', 'HEAT', 'ПГ-7ВЛ', pen: [500.0, 500.0], supp: 8.0, kill: 0.6, rad: 3.0, spd: 120.0, cal: 40.0),
  'nlaw': Ammo('nlaw', 'HEAT', 'NLAW', pen: [650.0, 650.0], supp: 8.0, spd: 180.0, cal: 102.0, top: true),
  'javelin': Ammo('javelin', 'ATGM', 'Javelin', pen: [800.0, 800.0], supp: 10.0, spd: 150.0, cal: 127.0, top: true),
  'kornet': Ammo('kornet', 'ATGM', '9М133 Корнет', pen: [1100.0, 1100.0], supp: 10.0, spd: 280.0, cal: 152.0),
  'konkurs': Ammo('konkurs', 'ATGM', '9М113 Конкурс', pen: [600.0, 600.0], supp: 10.0, spd: 200.0, cal: 135.0),
  'tow': Ammo('tow', 'ATGM', 'TOW-2B', pen: [900.0, 900.0], supp: 10.0, spd: 280.0, cal: 152.0, top: true),
  'he152': Ammo('he152', 'HE', '152 мм ОФ', pen: [120.0, 0.0], supp: 36.0, kill: 0.7, rad: 44.0, cal: 152.0),
  'fpv': Ammo('fpv', 'HEAT', 'FPV', pen: [300.0, 300.0], supp: 20.0, kill: 0.8, rad: 6.0, cal: 100.0, top: true),
};

const Map<String, Wpn> WPN = {
  'ak74': Wpn('ak74', 'АК-74', 'rifle', 72.0, 30.0, 3.0, 270.0, 0.3, ['sa545']),
  'ak12': Wpn('ak12', 'АК-12', 'rifle', 76.0, 30.0, 3.0, 280.0, 0.31, ['sa545']),
  'm4': Wpn('m4', 'M4A1', 'rifle', 76.0, 30.0, 2.6, 280.0, 0.32, ['sa556']),
  'rpk74': Wpn('rpk74', 'РПК-74', 'mg', 140.0, 45.0, 4.0, 340.0, 0.26, ['sa545']),
  'pkm': Wpn('pkm', 'ПКМ', 'mg', 260.0, 100.0, 6.0, 460.0, 0.24, ['sa762']),
  'nsv': Wpn('nsv', 'НСВ 12,7', 'hmg', 220.0, 50.0, 6.0, 640.0, 0.22, ['sa127'], setup: 3.5),
  'm2': Wpn('m2', 'M2 Browning', 'hmg', 220.0, 100.0, 6.0, 650.0, 0.22, ['sa50'], setup: 3.5),
  'm82': Wpn('m82', 'Barrett M82', 'sniper', 9.0, 10.0, 4.0, 900.0, 0.72, ['sa50']),
  't5000': Wpn('t5000', 'Т-5000', 'sniper', 9.0, 5.0, 4.0, 860.0, 0.74, ['sa338']),
  'gp25': Wpn('gp25', 'ГП-25', 'ugl', 5.0, 1.0, 4.0, 360.0, 0.2, ['vog25']),
  'rpg7': Wpn('rpg7', 'РПГ-7', 'rocket', 5.0, 1.0, 5.0, 300.0, 0.6, ['pg7'], disp: true),
  'nlaw': Wpn('nlaw', 'NLAW', 'rocket', 5.0, 1.0, 5.0, 620.0, 0.8, ['nlaw'], disp: true),
  'javelin': Wpn('javelin', 'Javelin', 'atgm', 4.0, 1.0, 11.0, 1050.0, 0.88, ['javelin']),
  'kornet': Wpn('kornet', 'Корнет', 'atgm', 4.0, 1.0, 14.0, 1100.0, 0.85, ['kornet']),
  'mortar82': Wpn('mortar82', 'Миномёт 2Б14', 'mortar', 15.0, 1.0, 4.0, 1300.0, 1.0, ['he82', 'smk82'], minR: 240.0),
  'pkt': Wpn('pkt', 'ПКТ', 'mg', 300.0, 250.0, 5.0, 460.0, 0.22, ['sa762'], job: 'gunner', coax: true),
  'm240': Wpn('m240', 'M240', 'mg', 300.0, 250.0, 5.0, 460.0, 0.22, ['sa762'], job: 'gunner', coax: true),
  'd81': Wpn('d81', '125 мм 2А46', 'cannon', 8.0, 1.0, 6.5, 1050.0, 0.78, ['apfsds125', 'heat125', 'he125'], job: 'gunner', auto: true),
  'l55': Wpn('l55', '120 мм Rh-120', 'cannon', 9.0, 1.0, 5.5, 1100.0, 0.82, ['apfsds120', 'heat120'], job: 'gunner', loader: true),
  'm256': Wpn('m256', '120 мм M256', 'cannon', 9.0, 1.0, 5.5, 1100.0, 0.82, ['apfsds120', 'heat120'], job: 'gunner', loader: true),
  'a2a42': Wpn('a2a42', '30 мм 2А42', 'acan', 260.0, 80.0, 4.0, 760.0, 0.3, ['ap30', 'he30'], job: 'gunner'),
  'a2a72': Wpn('a2a72', '30 мм 2А72', 'acan', 240.0, 80.0, 4.0, 760.0, 0.3, ['ap30', 'he30'], job: 'gunner'),
  'a2a70': Wpn('a2a70', '100 мм 2А70', 'cannon', 10.0, 1.0, 5.0, 800.0, 0.62, ['he100'], job: 'gunner'),
  'm242': Wpn('m242', '25 мм M242', 'acan', 250.0, 80.0, 4.0, 780.0, 0.32, ['ap25', 'he25'], job: 'gunner'),
  'konkurs': Wpn('konkurs', 'Конкурс', 'atgm', 4.0, 1.0, 13.0, 900.0, 0.78, ['konkurs'], job: 'gunner'),
  'tow': Wpn('tow', 'TOW-2B', 'atgm', 4.0, 1.0, 12.0, 1000.0, 0.84, ['tow'], job: 'gunner'),
  'nsvt': Wpn('nsvt', 'Зенитный пулемёт', 'hmg', 220.0, 100.0, 6.0, 640.0, 0.2, ['sa127'], job: 'commander', coax: true),
};

const Map<String, Arm> ARM = {
  't64bv': Arm([440.0, 760.0], [70.0, 120.0], [32.0, 32.0], [22.0, 22.0]),
  't72b3': Arm([520.0, 860.0], [80.0, 140.0], [35.0, 35.0], [25.0, 25.0]),
  't80bvm': Arm([620.0, 1020.0], [95.0, 170.0], [38.0, 38.0], [28.0, 28.0]),
  't90m': Arm([800.0, 1280.0], [110.0, 210.0], [40.0, 40.0], [30.0, 30.0]),
  'leo2': Arm([650.0, 920.0], [75.0, 130.0], [35.0, 35.0], [30.0, 30.0]),
  'abrams': Arm([660.0, 880.0], [90.0, 140.0], [40.0, 40.0], [30.0, 30.0]),
  'bmp2': Arm([38.0, 38.0], [18.0, 18.0], [14.0, 14.0], [10.0, 10.0]),
  'bmp3': Arm([64.0, 64.0], [22.0, 22.0], [16.0, 16.0], [12.0, 12.0]),
  'btr82': Arm([10.0, 10.0], [9.0, 9.0], [8.0, 8.0], [6.0, 6.0]),
  'bradley': Arm([44.0, 56.0], [26.0, 30.0], [20.0, 20.0], [14.0, 14.0]),
};

final List<Variant> VARIANTS = [
  Variant('ua_rifle', 'rifle', 0, 'Стрелковое отделение', '6 бойцов: АК, РПК, ГП-25, РПГ-7', 60.0, 8.0, 12.0, 360.0, 70.0, 'Универсальная пехота', [Man('leader', ['ak74'], {'sa545': 120}), Man('rifle', ['ak74'], {'sa545': 150}), Man('rifle', ['ak74'], {'sa545': 150}), Man('gunner', ['rpk74'], {'sa545': 270}), Man('grenadier', ['ak74', 'gp25'], {'sa545': 90, 'vog25': 18}), Man('at', ['ak74', 'rpg7'], {'sa545': 90, 'pg7': 2})]),
  Variant('ru_rifle', 'rifle', 1, 'Мотострелковое отделение', '6 бойцов: АК-12, РПК, ГП-25, РПГ-7', 60.0, 8.0, 12.0, 360.0, 70.0, 'Универсальная пехота', [Man('leader', ['ak12'], {'sa545': 120}), Man('rifle', ['ak12'], {'sa545': 150}), Man('rifle', ['ak12'], {'sa545': 150}), Man('gunner', ['rpk74'], {'sa545': 270}), Man('grenadier', ['ak12', 'gp25'], {'sa545': 90, 'vog25': 18}), Man('at', ['ak12', 'rpg7'], {'sa545': 90, 'pg7': 2})]),
  Variant('mg_pkm', 'mg', -1, 'Пулемётный расчёт', '3 бойца: ПКМ', 80.0, 8.0, 10.0, 340.0, 68.0, 'Подавляет огнём', [Man('gunner', ['pkm'], {'sa762': 450}), Man('assist', ['ak74'], {'sa545': 120, 'sa762': 300}), Man('rifle', ['ak74'], {'sa545': 150})]),
  Variant('mg_nsv', 'mg', 1, 'Расчёт НСВ', '3 бойца: НСВ 12,7 мм', 120.0, 10.0, 8.0, 340.0, 70.0, 'Бьёт по лёгкой технике', [Man('gunner', ['nsv'], {'sa127': 350}), Man('assist', ['ak12'], {'sa545': 90, 'sa127': 250}), Man('rifle', ['ak12'], {'sa545': 150})]),
  Variant('mg_m2', 'mg', 0, 'Расчёт M2 Browning', '3 бойца: M2 12,7 мм', 120.0, 10.0, 8.0, 340.0, 70.0, 'Бьёт по лёгкой технике', [Man('gunner', ['m2'], {'sa50': 350}), Man('assist', ['m4'], {'sa556': 90, 'sa50': 250}), Man('rifle', ['m4'], {'sa556': 150})]),
  Variant('at_rpg', 'at', -1, 'Расчёт РПГ', '3 бойца: 2 × РПГ-7', 70.0, 8.0, 12.0, 350.0, 66.0, 'Ближний бой с техникой', [Man('at', ['ak74', 'rpg7'], {'sa545': 90, 'pg7': 3}), Man('at', ['ak74', 'rpg7'], {'sa545': 90, 'pg7': 3}), Man('rifle', ['ak74'], {'sa545': 150})]),
  Variant('at_javelin', 'at', 0, 'Расчёт Javelin', '3 бойца: Javelin, 3 ракеты', 150.0, 9.0, 11.0, 380.0, 68.0, 'Бьёт по крыше', [Man('at', ['m4', 'javelin'], {'sa556': 90, 'javelin': 1}), Man('assist', ['m4'], {'sa556': 90, 'javelin': 2}), Man('rifle', ['m4'], {'sa556': 150})]),
  Variant('at_nlaw', 'at', 0, 'Расчёт NLAW', '2 бойца: NLAW × 3', 110.0, 8.0, 12.0, 360.0, 66.0, 'Лёгкий ПТРК, удар сверху', [Man('at', ['m4', 'nlaw'], {'sa556': 90, 'nlaw': 2}), Man('at', ['m4', 'nlaw'], {'sa556': 90, 'nlaw': 1})]),
  Variant('at_kornet', 'at', 1, 'Расчёт ПТРК «Корнет»', '3 бойца: «Корнет», 3 ракеты', 140.0, 9.0, 10.0, 380.0, 68.0, 'Дальний ПТУР', [Man('at', ['ak12', 'kornet'], {'sa545': 90, 'kornet': 1}), Man('assist', ['ak12'], {'sa545': 90, 'kornet': 2}), Man('rifle', ['ak12'], {'sa545': 150})]),
  Variant('sniper_ua', 'sniper', 0, 'Снайперская пара', 'Barrett M82 + наблюдатель', 110.0, 9.0, 9.0, 520.0, 80.0, 'Дальний точный огонь', [Man('sniper', ['m82'], {'sa50': 40}), Man('spotter', ['m4'], {'sa556': 120})], stealth: 0.75),
  Variant('sniper_ru', 'sniper', 1, 'Снайперская пара', 'Т-5000 + наблюдатель', 100.0, 9.0, 9.0, 520.0, 80.0, 'Дальний точный огонь', [Man('sniper', ['t5000'], {'sa338': 40}), Man('spotter', ['ak12'], {'sa545': 120})], stealth: 0.75),
  Variant('mortar_82', 'mortar', -1, 'Миномётный расчёт', '3 бойца: миномёт 82 мм', 130.0, 10.0, 8.0, 280.0, 62.0, 'Огонь по площадям', [Man('gunner', ['mortar82'], {'he82': 42, 'smk82': 6}), Man('loader', ['ak74'], {'sa545': 120}), Man('rifle', ['ak74'], {'sa545': 120})]),
  Variant('bmp2', 'ifv', -1, 'БМП-2', '30 мм, «Конкурс», экипаж 3, десант 7', 190.0, 12.0, 26.0, 430.0, 85.0, 'Скорость и скорострельность', [Man('driver', [], {}), Man('gunner', ['a2a42', 'pkt', 'konkurs'], {'ap30': 160, 'he30': 340, 'sa762': 2000, 'konkurs': 4}), Man('commander', [], {})], veh: true, cap: 7, len: 24.0, wid: 11.0, vuln: 0.2, arm: ARM['bmp2']),
  Variant('bmp3', 'ifv', 1, 'БМП-3', '100 + 30 мм, экипаж 3, десант 7', 270.0, 13.0, 26.0, 430.0, 85.0, 'Две пушки, фугасное действие', [Man('driver', [], {}), Man('gunner', ['a2a70', 'a2a72', 'pkt'], {'he100': 40, 'ap30': 100, 'he30': 400, 'sa762': 2000}), Man('commander', [], {})], veh: true, cap: 7, len: 26.0, wid: 11.0, vuln: 0.3, arm: ARM['bmp3']),
  Variant('btr82', 'ifv', 1, 'БТР-82А', '30 мм, колёсный, десант 7', 140.0, 11.0, 32.0, 420.0, 80.0, 'Быстрый и лёгкий', [Man('driver', [], {}), Man('gunner', ['a2a72', 'pkt'], {'ap30': 100, 'he30': 300, 'sa762': 2000}), Man('commander', [], {})], veh: true, wheeled: true, cap: 7, len: 24.0, wid: 10.0, vuln: 0.15, arm: ARM['btr82']),
  Variant('bradley', 'ifv', 0, 'M2A2 Bradley', '25 мм, TOW, экипаж 3, десант 6', 240.0, 13.0, 24.0, 440.0, 85.0, 'Автопушка и ПТУР', [Man('driver', [], {}), Man('gunner', ['m242', 'm240', 'tow'], {'ap25': 150, 'he25': 450, 'sa762': 2200, 'tow': 3}), Man('commander', [], {})], veh: true, cap: 6, len: 25.0, wid: 12.0, vuln: 0.2, arm: ARM['bradley']),
  Variant('tank_t64bv', 'tank', 0, 'Т-64БВ', '125 мм, экипаж 3', 250.0, 14.0, 22.0, 440.0, 86.0, 'Старый, но грозный', [Man('driver', [], {}), Man('gunner', ['d81', 'pkt'], {'apfsds125': 12, 'heat125': 6, 'he125': 10, 'sa762': 1250}), Man('commander', ['nsvt'], {'sa127': 300})], veh: true, len: 30.0, wid: 14.0, vuln: 0.42, arm: ARM['t64bv']),
  Variant('tank_t72b3', 'tank', 1, 'Т-72Б3', '125 мм, экипаж 3', 290.0, 14.0, 22.0, 440.0, 88.0, 'Массовый танк', [Man('driver', [], {}), Man('gunner', ['d81', 'pkt'], {'apfsds125': 12, 'heat125': 8, 'he125': 14, 'sa762': 1250}), Man('commander', ['nsvt'], {'sa127': 300})], veh: true, len: 30.0, wid: 14.0, vuln: 0.42, arm: ARM['t72b3']),
  Variant('tank_t80bvm', 'tank', 1, 'Т-80БВМ', '125 мм, экипаж 3', 330.0, 14.0, 25.0, 450.0, 88.0, 'Быстрый, хорошая броня', [Man('driver', [], {}), Man('gunner', ['d81', 'pkt'], {'apfsds125': 14, 'heat125': 8, 'he125': 12, 'sa762': 1250}), Man('commander', ['nsvt'], {'sa127': 300})], veh: true, len: 30.0, wid: 14.0, vuln: 0.4, arm: ARM['t80bvm']),
  Variant('tank_t90m', 'tank', 1, 'Т-90М', '125 мм, экипаж 3', 370.0, 15.0, 22.0, 460.0, 90.0, 'Лучшая броня РФ', [Man('driver', [], {}), Man('gunner', ['d81', 'pkt'], {'apfsds125': 14, 'heat125': 8, 'he125': 14, 'sa762': 1250}), Man('commander', ['nsvt'], {'sa127': 300})], veh: true, len: 31.0, wid: 14.0, vuln: 0.3, arm: ARM['t90m']),
  Variant('tank_leo2', 'tank', 0, 'Leopard 2A6', '120 мм, экипаж 4', 380.0, 15.0, 22.0, 470.0, 90.0, 'Изолированный боекомплект', [Man('driver', [], {}), Man('gunner', ['l55', 'm240'], {'apfsds120': 22, 'heat120': 20, 'sa762': 4750}), Man('commander', ['nsvt'], {'sa127': 300}), Man('loader', [], {})], veh: true, len: 31.0, wid: 14.0, vuln: 0.08, arm: ARM['leo2']),
  Variant('tank_abrams', 'tank', 0, 'M1A1 Abrams', '120 мм, экипаж 4', 400.0, 15.0, 23.0, 470.0, 90.0, 'Выбивные панели боекомплекта', [Man('driver', [], {}), Man('gunner', ['m256', 'm240'], {'apfsds120': 22, 'heat120': 18, 'sa762': 11400}), Man('commander', ['m2'], {'sa50': 900}), Man('loader', [], {})], veh: true, len: 31.0, wid: 14.0, vuln: 0.07, arm: ARM['abrams']),
];

final Map<String, Variant> VARS = {for (final v in VARIANTS) v.id: v};

const List<String> TYPE_ORDER = ['rifle', 'mg', 'at', 'sniper', 'mortar', 'ifv', 'tank'];
bool isVehCls(String c) => c == 'ifv' || c == 'tank';

List<Variant> variantsFor(int side) => VARIANTS.where((v) => v.sides.contains(side)).toList();

class SideInfo {
  final String id, name, short;
  final int color, dark, accent;
  final List<String> calls;
  const SideInfo(this.id, this.name, this.short, this.color, this.dark, this.accent, this.calls);
}

const List<SideInfo> SIDES = [
  SideInfo('ua', 'Украина', 'ВСУ', 0xFF3D8FE0, 0xFF1D4A7A, 0xFFF2CB4B,
      ['Бриз', 'Ворон', 'Тайга', 'Сокол', 'Гром', 'Лис', 'Клён', 'Барс', 'Дуб', 'Яр', 'Мох', 'Шершень']),
  SideInfo('ru', 'Россия', 'ВС РФ', 0xFFD4483F, 0xFF7A2521, 0xFFF0A08A,
      ['Север', 'Урал', 'Волк', 'Орёл', 'Шторм', 'Рысь', 'Кедр', 'Берёза', 'Тигр', 'Дон', 'Буран', 'Гранит']),
];

const Map<String, List<List<String>>> NAMES = {
  'rifle': [['Стрелковое отделение', 'Пехота'], ['Мотострелковое отделение', 'Мотострелки']],
  'mg': [['Пулемётный расчёт', 'ПКМ'], ['Пулемётный расчёт', 'ПКМ']],
  'at': [['Расчёт ПТРК', 'Javelin / NLAW'], ['Расчёт ПТУР', 'Корнет']],
  'sniper': [['Снайперская пара', 'Дальний огонь'], ['Снайперская пара', 'Дальний огонь']],
  'mortar': [['Миномётный расчёт', 'Миномёт 82 мм'], ['Миномётный расчёт', 'Миномёт 82 мм']],
  'ifv': [['БМП', 'M2 Bradley'], ['БМП', 'БМП-2']],
  'tank': [['Танк', 'Leopard 2'], ['Танк', 'Т-90М']],
};

class Diff {
  final String name;
  final double inc, acc;
  const Diff(this.name, this.inc, this.acc);
}

const Map<String, Diff> DIFFS = {
  'easy': Diff('Лёгкая', .7, .85),
  'normal': Diff('Нормальная', 1, 1),
  'hard': Diff('Тяжёлая', 1.35, 1.12),
};
