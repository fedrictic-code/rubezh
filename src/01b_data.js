/* =====================================================================
   ДАННЫЕ: оружие, боеприпасы, составы отрядов, техника.
   Значения ориентировочные, по открытым справочным данным о реальных
   образцах, подогнанные под масштаб карты (1 единица = 1 м, дальности
   стрельбы сжаты). Их можно спокойно менять: баланс настраивается здесь.
   ===================================================================== */

/* ---------- боеприпасы ----------
   k: SA — стрелковые, AP — бронебойный, HE — осколочно-фугасный,
      HEAT — кумулятивный, ATGM — ракета, SMK — дым
   pen: пробитие стали (мм) вплотную и на 1000 м; для HEAT/ATGM — постоянное
   rad: радиус поражения осколками (м); kill: шанс поражения бойца в центре
   supp: подавление за один выстрел; spd: скорость снаряда (м/с)
   top: удар сверху (в крышу) */
const AMMO = {
  sa545: { k: 'SA', n: '5,45×39', pen: [3, 2], supp: .35, kill: .42 },
  sa556: { k: 'SA', n: '5,56×45', pen: [3, 2], supp: .35, kill: .42 },
  sa762: { k: 'SA', n: '7,62×54R', pen: [9, 5], supp: .6, kill: .55 },
  sa127: { k: 'SA', n: '12,7 мм', pen: [24, 13], supp: 1.5, kill: .85 },
  sa338: { k: 'SA', n: '8,6 мм', pen: [8, 5], supp: .8, kill: .9 },
  sa50: { k: 'SA', n: '12,7×99', pen: [24, 15], supp: 1.5, kill: .92 },
  vog25: { k: 'HE', n: 'ВОГ-25', pen: [0, 0], rad: 7, kill: .75, supp: 6, spd: 76, cal: 40 },
  ap30: { k: 'AP', n: '30 мм БПС', pen: [58, 36], supp: 3, kill: .6, cal: 30, burst: true },
  he30: { k: 'HE', n: '30 мм ОФ', pen: [12, 8], rad: 4, kill: .5, supp: 3, cal: 30, burst: true },
  ap25: { k: 'AP', n: '25 мм БПС', pen: [62, 46], supp: 3, kill: .6, cal: 25, burst: true },
  he25: { k: 'HE', n: '25 мм ОФ', pen: [10, 7], rad: 4, kill: .5, supp: 3, cal: 25, burst: true },
  apfsds125: { k: 'AP', n: '125 мм БОПС', pen: [570, 520], supp: 12, spd: 1700, cal: 125 },
  heat125: { k: 'HEAT', n: '125 мм КС', pen: [620, 620], supp: 12, spd: 900, cal: 125 },
  he125: { k: 'HE', n: '125 мм ОФ', pen: [75, 65], rad: 20, kill: .9, supp: 14, spd: 850, cal: 125 },
  apfsds120: { k: 'AP', n: '120 мм БОПС', pen: [730, 700], supp: 12, spd: 1650, cal: 120 },
  heat120: { k: 'HEAT', n: '120 мм КС', pen: [520, 520], supp: 12, spd: 1100, cal: 120 },
  he100: { k: 'HE', n: '100 мм ОФ', pen: [55, 48], rad: 17, kill: .9, supp: 11, spd: 250, cal: 100 },
  he82: { k: 'HE', n: '82 мм ОФ', pen: [28, 0], rad: 38, kill: .8, supp: 28, cal: 82 },
  smk82: { k: 'SMK', n: '82 мм дымовая', cal: 82 },
  pg7: { k: 'HEAT', n: 'ПГ-7ВЛ', pen: [500, 500], supp: 8, spd: 120, cal: 40, kill: .6, rad: 3 },
  nlaw: { k: 'HEAT', n: 'NLAW', pen: [650, 650], supp: 8, spd: 180, top: true, cal: 102 },
  javelin: { k: 'ATGM', n: 'Javelin', pen: [800, 800], supp: 10, spd: 150, top: true, cal: 127 },
  kornet: { k: 'ATGM', n: '9М133 Корнет', pen: [1100, 1100], supp: 10, spd: 280, cal: 152 },
  konkurs: { k: 'ATGM', n: '9М113 Конкурс', pen: [600, 600], supp: 10, spd: 200, cal: 135 },
  tow: { k: 'ATGM', n: 'TOW-2B', pen: [900, 900], supp: 10, spd: 280, top: true, cal: 152 },
  he152: { k: 'HE', n: '152 мм ОФ', pen: [120, 0], rad: 44, kill: .7, supp: 36, cal: 152 },
  fpv: { k: 'HEAT', n: 'FPV', pen: [300, 300], supp: 20, top: true, cal: 100, rad: 6, kill: .8 }
};

/* ---------- оружие ----------
   k: rifle, mg, hmg, sniper, ugl, rocket, atgm, cannon, acan, mortar
   rpm — темп прицельного огня, mag — ёмкость, rl — перезарядка, rng — дальность, acc — меткость вплотную */
const WPN = {
  ak74: { n: 'АК-74', k: 'rifle', rpm: 72, mag: 30, rl: 3, rng: 270, acc: .3, a: ['sa545'] },
  ak12: { n: 'АК-12', k: 'rifle', rpm: 76, mag: 30, rl: 3, rng: 280, acc: .31, a: ['sa545'] },
  m4: { n: 'M4A1', k: 'rifle', rpm: 76, mag: 30, rl: 2.6, rng: 280, acc: .32, a: ['sa556'] },
  rpk74: { n: 'РПК-74', k: 'mg', rpm: 140, mag: 45, rl: 4, rng: 340, acc: .26, a: ['sa545'] },
  pkm: { n: 'ПКМ', k: 'mg', rpm: 260, mag: 100, rl: 6, rng: 460, acc: .24, a: ['sa762'] },
  nsv: { n: 'НСВ 12,7', k: 'hmg', rpm: 220, mag: 50, rl: 6, rng: 640, acc: .22, a: ['sa127'], setup: 3.5 },
  m2: { n: 'M2 Browning', k: 'hmg', rpm: 220, mag: 100, rl: 6, rng: 650, acc: .22, a: ['sa50'], setup: 3.5 },
  m82: { n: 'Barrett M82', k: 'sniper', rpm: 9, mag: 10, rl: 4, rng: 900, acc: .72, a: ['sa50'] },
  t5000: { n: 'Т-5000', k: 'sniper', rpm: 9, mag: 5, rl: 4, rng: 860, acc: .74, a: ['sa338'] },
  gp25: { n: 'ГП-25', k: 'ugl', rpm: 5, mag: 1, rl: 4, rng: 360, acc: .2, a: ['vog25'] },
  rpg7: { n: 'РПГ-7', k: 'rocket', rpm: 5, mag: 1, rl: 5, rng: 300, acc: .6, a: ['pg7'], disp: 1 },
  nlaw: { n: 'NLAW', k: 'rocket', rpm: 5, mag: 1, rl: 5, rng: 620, acc: .8, a: ['nlaw'], disp: 1 },
  javelin: { n: 'Javelin', k: 'atgm', rpm: 4, mag: 1, rl: 11, rng: 1050, acc: .88, a: ['javelin'] },
  kornet: { n: 'Корнет', k: 'atgm', rpm: 4, mag: 1, rl: 14, rng: 1100, acc: .85, a: ['kornet'] },
  mortar82: { n: 'Миномёт 2Б14', k: 'mortar', rpm: 15, mag: 1, rl: 4, rng: 1300, minR: 240, acc: 1, a: ['he82', 'smk82'] },
  /* вооружение техники */
  pkt: { n: 'ПКТ', k: 'mg', rpm: 300, mag: 250, rl: 5, rng: 460, acc: .22, a: ['sa762'], job: 'gunner', coax: true },
  m240: { n: 'M240', k: 'mg', rpm: 300, mag: 250, rl: 5, rng: 460, acc: .22, a: ['sa762'], job: 'gunner', coax: true },
  d81: { n: '125 мм 2А46', k: 'cannon', rpm: 8, mag: 1, rl: 6.5, rng: 1050, acc: .78, a: ['apfsds125', 'heat125', 'he125'], job: 'gunner', auto: true },
  l55: { n: '120 мм Rh-120', k: 'cannon', rpm: 9, mag: 1, rl: 5.5, rng: 1100, acc: .82, a: ['apfsds120', 'heat120'], job: 'gunner', loader: true },
  m256: { n: '120 мм M256', k: 'cannon', rpm: 9, mag: 1, rl: 5.5, rng: 1100, acc: .82, a: ['apfsds120', 'heat120'], job: 'gunner', loader: true },
  a2a42: { n: '30 мм 2А42', k: 'acan', rpm: 260, mag: 80, rl: 4, rng: 760, acc: .3, a: ['ap30', 'he30'], job: 'gunner' },
  a2a72: { n: '30 мм 2А72', k: 'acan', rpm: 240, mag: 80, rl: 4, rng: 760, acc: .3, a: ['ap30', 'he30'], job: 'gunner' },
  a2a70: { n: '100 мм 2А70', k: 'cannon', rpm: 10, mag: 1, rl: 5, rng: 800, acc: .62, a: ['he100'], job: 'gunner' },
  m242: { n: '25 мм M242', k: 'acan', rpm: 250, mag: 80, rl: 4, rng: 780, acc: .32, a: ['ap25', 'he25'], job: 'gunner' },
  konkurs: { n: 'Конкурс', k: 'atgm', rpm: 4, mag: 1, rl: 13, rng: 900, acc: .78, a: ['konkurs'], job: 'gunner' },
  tow: { n: 'TOW-2B', k: 'atgm', rpm: 4, mag: 1, rl: 12, rng: 1000, acc: .84, a: ['tow'], job: 'gunner' },
  nsvt: { n: 'Зенитный пулемёт', k: 'hmg', rpm: 220, mag: 100, rl: 6, rng: 640, acc: .2, a: ['sa127'], job: 'commander', coax: true }
};

/* ---------- сборка составов ----------
   m(job, оружие[], боезапас{}) — один боец / член экипажа. Если у оружия есть
   несколько типов боеприпасов, боезапас записывается по именам боеприпасов. */
const mn = (job, w, a) => ({ job, w, a });

/* Вспомогательные броневые профили: [стальной эквивалент против БОПС, против кумулятива] */
const ARM = {
  t64bv: { f: [440, 760], s: [70, 120], r: [32, 32], t: [22, 22] },
  t72b3: { f: [520, 860], s: [80, 140], r: [35, 35], t: [25, 25] },
  t80bvm: { f: [620, 1020], s: [95, 170], r: [38, 38], t: [28, 28] },
  t90m: { f: [800, 1280], s: [110, 210], r: [40, 40], t: [30, 30] },
  leo2: { f: [650, 920], s: [75, 130], r: [35, 35], t: [30, 30] },
  abrams: { f: [660, 880], s: [90, 140], r: [40, 40], t: [30, 30] },
  bmp2: { f: [38, 38], s: [18, 18], r: [14, 14], t: [10, 10] },
  bmp3: { f: [64, 64], s: [22, 22], r: [16, 16], t: [12, 12] },
  btr82: { f: [10, 10], s: [9, 9], r: [8, 8], t: [6, 6] },
  bradley: { f: [44, 56], s: [26, 30], r: [20, 20], t: [14, 14] }
};

const VARIANTS = [
  /* ---------- пехота ---------- */
  { id: 'ua_rifle', cls: 'rifle', side: 0, name: 'Стрелковое отделение', desc: '6 бойцов: АК, РПК, ГП-25, РПГ-7', cost: 60, delay: 8, speed: 12, vision: 360, morale: 70, hint: 'Универсальная пехота',
    men: [mn('leader', ['ak74'], { sa545: 120 }), mn('rifle', ['ak74'], { sa545: 150 }), mn('rifle', ['ak74'], { sa545: 150 }), mn('gunner', ['rpk74'], { sa545: 270 }), mn('grenadier', ['ak74', 'gp25'], { sa545: 90, vog25: 18 }), mn('at', ['ak74', 'rpg7'], { sa545: 90, pg7: 2 })] },
  { id: 'ru_rifle', cls: 'rifle', side: 1, name: 'Мотострелковое отделение', desc: '6 бойцов: АК-12, РПК, ГП-25, РПГ-7', cost: 60, delay: 8, speed: 12, vision: 360, morale: 70, hint: 'Универсальная пехота',
    men: [mn('leader', ['ak12'], { sa545: 120 }), mn('rifle', ['ak12'], { sa545: 150 }), mn('rifle', ['ak12'], { sa545: 150 }), mn('gunner', ['rpk74'], { sa545: 270 }), mn('grenadier', ['ak12', 'gp25'], { sa545: 90, vog25: 18 }), mn('at', ['ak12', 'rpg7'], { sa545: 90, pg7: 2 })] },
  { id: 'mg_pkm', cls: 'mg', side: -1, name: 'Пулемётный расчёт', desc: '3 бойца: ПКМ', cost: 80, delay: 8, speed: 10, vision: 340, morale: 68, hint: 'Подавляет огнём',
    men: [mn('gunner', ['pkm'], { sa762: 450 }), mn('assist', ['ak74'], { sa545: 120, sa762: 300 }), mn('rifle', ['ak74'], { sa545: 150 })] },
  { id: 'mg_nsv', cls: 'mg', side: 1, name: 'Расчёт НСВ', desc: '3 бойца: НСВ 12,7 мм', cost: 120, delay: 10, speed: 8, vision: 340, morale: 70, hint: 'Бьёт по лёгкой технике',
    men: [mn('gunner', ['nsv'], { sa127: 350 }), mn('assist', ['ak12'], { sa545: 90, sa127: 250 }), mn('rifle', ['ak12'], { sa545: 150 })] },
  { id: 'mg_m2', cls: 'mg', side: 0, name: 'Расчёт M2 Browning', desc: '3 бойца: M2 12,7 мм', cost: 120, delay: 10, speed: 8, vision: 340, morale: 70, hint: 'Бьёт по лёгкой технике',
    men: [mn('gunner', ['m2'], { sa50: 350 }), mn('assist', ['m4'], { sa556: 90, sa50: 250 }), mn('rifle', ['m4'], { sa556: 150 })] },
  { id: 'at_rpg', cls: 'at', side: -1, name: 'Расчёт РПГ', desc: '3 бойца: 2 × РПГ-7', cost: 70, delay: 8, speed: 12, vision: 350, morale: 66, hint: 'Ближний бой с техникой',
    men: [mn('at', ['ak74', 'rpg7'], { sa545: 90, pg7: 3 }), mn('at', ['ak74', 'rpg7'], { sa545: 90, pg7: 3 }), mn('rifle', ['ak74'], { sa545: 150 })] },
  { id: 'at_javelin', cls: 'at', side: 0, name: 'Расчёт Javelin', desc: '3 бойца: Javelin, 3 ракеты', cost: 150, delay: 9, speed: 11, vision: 380, morale: 68, hint: 'Бьёт по крыше',
    men: [mn('at', ['m4', 'javelin'], { sa556: 90, javelin: 1 }), mn('assist', ['m4'], { sa556: 90, javelin: 2 }), mn('rifle', ['m4'], { sa556: 150 })] },
  { id: 'at_nlaw', cls: 'at', side: 0, name: 'Расчёт NLAW', desc: '2 бойца: NLAW × 3', cost: 110, delay: 8, speed: 12, vision: 360, morale: 66, hint: 'Лёгкий ПТРК, удар сверху',
    men: [mn('at', ['m4', 'nlaw'], { sa556: 90, nlaw: 2 }), mn('at', ['m4', 'nlaw'], { sa556: 90, nlaw: 1 })] },
  { id: 'at_kornet', cls: 'at', side: 1, name: 'Расчёт ПТРК «Корнет»', desc: '3 бойца: «Корнет», 3 ракеты', cost: 140, delay: 9, speed: 10, vision: 380, morale: 68, hint: 'Дальний ПТУР',
    men: [mn('at', ['ak12', 'kornet'], { sa545: 90, kornet: 1 }), mn('assist', ['ak12'], { sa545: 90, kornet: 2 }), mn('rifle', ['ak12'], { sa545: 150 })] },
  { id: 'sniper_ua', cls: 'sniper', side: 0, name: 'Снайперская пара', desc: 'Barrett M82 + наблюдатель', cost: 110, delay: 9, speed: 9, vision: 520, morale: 80, stealth: .75, hint: 'Дальний точный огонь',
    men: [mn('sniper', ['m82'], { sa50: 40 }), mn('spotter', ['m4'], { sa556: 120 })] },
  { id: 'sniper_ru', cls: 'sniper', side: 1, name: 'Снайперская пара', desc: 'Т-5000 + наблюдатель', cost: 100, delay: 9, speed: 9, vision: 520, morale: 80, stealth: .75, hint: 'Дальний точный огонь',
    men: [mn('sniper', ['t5000'], { sa338: 40 }), mn('spotter', ['ak12'], { sa545: 120 })] },
  { id: 'mortar_82', cls: 'mortar', side: -1, name: 'Миномётный расчёт', desc: '3 бойца: миномёт 82 мм', cost: 130, delay: 10, speed: 8, vision: 280, morale: 62, hint: 'Огонь по площадям',
    men: [mn('gunner', ['mortar82'], { he82: 42, smk82: 6 }), mn('loader', ['ak74'], { sa545: 120 }), mn('rifle', ['ak74'], { sa545: 120 })] },

  /* ---------- бронетехника ---------- */
  { id: 'bmp2', cls: 'ifv', side: -1, name: 'БМП-2', desc: '30 мм, «Конкурс», экипаж 3, десант 7', veh: true, cap: 7, cost: 190, delay: 12, speed: 26, vision: 430, morale: 85, len: 24, wid: 11, arm: ARM.bmp2, vuln: .2, hint: 'Скорость и скорострельность',
    men: [mn('driver', [], {}), mn('gunner', ['a2a42', 'pkt', 'konkurs'], { ap30: 160, he30: 340, sa762: 2000, konkurs: 4 }), mn('commander', [], {})] },
  { id: 'bmp3', cls: 'ifv', side: 1, name: 'БМП-3', desc: '100 + 30 мм, экипаж 3, десант 7', veh: true, cap: 7, cost: 270, delay: 13, speed: 26, vision: 430, morale: 85, len: 26, wid: 11, arm: ARM.bmp3, vuln: .3, hint: 'Две пушки, фугасное действие',
    men: [mn('driver', [], {}), mn('gunner', ['a2a70', 'a2a72', 'pkt'], { he100: 40, ap30: 100, he30: 400, sa762: 2000 }), mn('commander', [], {})] },
  { id: 'btr82', cls: 'ifv', side: 1, name: 'БТР-82А', desc: '30 мм, колёсный, десант 7', veh: true, cap: 7, wheeled: true, cost: 140, delay: 11, speed: 32, vision: 420, morale: 80, len: 24, wid: 10, arm: ARM.btr82, vuln: .15, hint: 'Быстрый и лёгкий',
    men: [mn('driver', [], {}), mn('gunner', ['a2a72', 'pkt'], { ap30: 100, he30: 300, sa762: 2000 }), mn('commander', [], {})] },
  { id: 'bradley', cls: 'ifv', side: 0, name: 'M2A2 Bradley', desc: '25 мм, TOW, экипаж 3, десант 6', veh: true, cap: 6, cost: 240, delay: 13, speed: 24, vision: 440, morale: 85, len: 25, wid: 12, arm: ARM.bradley, vuln: .2, hint: 'Автопушка и ПТУР',
    men: [mn('driver', [], {}), mn('gunner', ['m242', 'm240', 'tow'], { ap25: 150, he25: 450, sa762: 2200, tow: 3 }), mn('commander', [], {})] },

  /* ---------- танки ---------- */
  { id: 'tank_t64bv', cls: 'tank', side: 0, name: 'Т-64БВ', desc: '125 мм, экипаж 3', veh: true, cost: 250, delay: 14, speed: 22, vision: 440, morale: 86, len: 30, wid: 14, arm: ARM.t64bv, vuln: .42, hint: 'Старый, но грозный',
    men: [mn('driver', [], {}), mn('gunner', ['d81', 'pkt'], { apfsds125: 12, heat125: 6, he125: 10, sa762: 1250 }), mn('commander', ['nsvt'], { sa127: 300 })] },
  { id: 'tank_t72b3', cls: 'tank', side: 1, name: 'Т-72Б3', desc: '125 мм, экипаж 3', veh: true, cost: 290, delay: 14, speed: 22, vision: 440, morale: 88, len: 30, wid: 14, arm: ARM.t72b3, vuln: .42, hint: 'Массовый танк',
    men: [mn('driver', [], {}), mn('gunner', ['d81', 'pkt'], { apfsds125: 12, heat125: 8, he125: 14, sa762: 1250 }), mn('commander', ['nsvt'], { sa127: 300 })] },
  { id: 'tank_t80bvm', cls: 'tank', side: 1, name: 'Т-80БВМ', desc: '125 мм, экипаж 3', veh: true, cost: 330, delay: 14, speed: 25, vision: 450, morale: 88, len: 30, wid: 14, arm: ARM.t80bvm, vuln: .4, hint: 'Быстрый, хорошая броня',
    men: [mn('driver', [], {}), mn('gunner', ['d81', 'pkt'], { apfsds125: 14, heat125: 8, he125: 12, sa762: 1250 }), mn('commander', ['nsvt'], { sa127: 300 })] },
  { id: 'tank_t90m', cls: 'tank', side: 1, name: 'Т-90М', desc: '125 мм, экипаж 3', veh: true, cost: 370, delay: 15, speed: 22, vision: 460, morale: 90, len: 31, wid: 14, arm: ARM.t90m, vuln: .3, hint: 'Лучшая броня РФ',
    men: [mn('driver', [], {}), mn('gunner', ['d81', 'pkt'], { apfsds125: 14, heat125: 8, he125: 14, sa762: 1250 }), mn('commander', ['nsvt'], { sa127: 300 })] },
  { id: 'tank_leo2', cls: 'tank', side: 0, name: 'Leopard 2A6', desc: '120 мм, экипаж 4', veh: true, cost: 380, delay: 15, speed: 22, vision: 470, morale: 90, len: 31, wid: 14, arm: ARM.leo2, vuln: .08, hint: 'Изолированный боекомплект',
    men: [mn('driver', [], {}), mn('gunner', ['l55', 'm240'], { apfsds120: 22, heat120: 20, sa762: 4750 }), mn('commander', ['nsvt'], { sa127: 300 }), mn('loader', [], {})] },
  { id: 'tank_abrams', cls: 'tank', side: 0, name: 'M1A1 Abrams', desc: '120 мм, экипаж 4', veh: true, cost: 400, delay: 15, speed: 23, vision: 470, morale: 90, len: 31, wid: 14, arm: ARM.abrams, vuln: .07, hint: 'Выбивные панели боекомплекта',
    men: [mn('driver', [], {}), mn('gunner', ['m256', 'm240'], { apfsds120: 22, heat120: 18, sa762: 11400 }), mn('commander', ['m2'], { sa50: 900 }), mn('loader', [], {})] }
];

const VARS = {};
for (const v of VARIANTS) VARS[v.id] = v;

/* Классовые значения по умолчанию (для ИИ, иконок и интерфейса) */
const TYPES = {
  rifle: { id: 'rifle', hint: 'Универсальная пехота' }, mg: { id: 'mg' }, at: { id: 'at' }, sniper: { id: 'sniper' }, mortar: { id: 'mortar', mortar: true },
  ifv: { id: 'ifv', veh: true }, tank: { id: 'tank', veh: true }
};
const TYPE_ORDER = ['rifle', 'mg', 'at', 'sniper', 'mortar', 'ifv', 'tank'];

/* Достраиваем производные поля и ссылки на оружие */
(function finishVariants() {
  for (const v of VARIANTS) {
    v.max = v.men.length; v.crewN = v.max;
    if (v.cls === 'mortar') v.mortar = true;
    v.sides = v.side === -1 ? [0, 1] : [v.side];
    let rng = 0, sr = 0, atR = 0, hasShot = false, vsVeh = 0;
    for (const man of v.men) {
      for (const id of man.w) {
        const w = WPN[id]; if (!w) continue; rng = Math.max(rng, w.rng);
        if (w.k === 'rocket' || w.k === 'atgm' || (w.k === 'cannon')) { hasShot = true; atR = Math.max(atR, w.rng); }
        if (['rifle', 'mg', 'hmg', 'sniper', 'acan', 'ugl', 'cannon'].includes(w.k)) sr = Math.max(sr, w.k === 'cannon' ? w.rng : w.rng);
      }
    }
    v.range = Math.max(rng, 1); v.sr = Math.max(sr, 0); v.atR = atR;
    v.shot = hasShot ? { range: atR || v.range, vehOnly: v.cls === 'at' } : null;
    let atPen = 0, saPen = 0;
    for (const man of v.men) for (const id of man.w) { const w = WPN[id]; for (const k of w.a) { const a = AMMO[k]; if (!a.pen) continue; if (a.k === 'HEAT' || a.k === 'ATGM' || (w.k === 'cannon' && a.k === 'AP')) atPen = Math.max(atPen, a.pen[0]); else if (w.k !== 'cannon' && w.k !== 'mortar') saPen = Math.max(saPen, a.pen[0]); } }
    v.atPen = atPen; v.saPen = saPen;
    v.supp = 1; v.ammoUse = .3; v.moveFire = v.veh ? .5 : .3; v.fpInf = 1; v.vsVeh = 1; v.len = v.len || 0; v.wid = v.wid || 0;
    if (v.cls === 'mortar') { v.range = 1300; v.minRange = 240; v.sr = 0; v.fpInf = 0; v.vsVeh = 0; }
    if (v.cls === 'sniper') v.moveFire = 0;
    v.id0 = v.id;
  }
})();
const variantsFor = side => VARIANTS.filter(v => v.sides.includes(side));
