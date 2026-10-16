'use strict';
/* =====================================================================
   РУБЕЖ — тактика в реальном времени. Прототип v0.1
   Архитектура (под производительность):
   - симуляция с фиксированным шагом 20 Гц, отделена от отрисовки;
   - статичная местность рисуется один раз в оффскрин-холст;
   - туман войны считается лучами на сетке 20 м и обновляется 3 раза в секунду;
   - все данные юнитов в простых объектах, без аллокаций в горячих циклах;
   - вся графика идёт через реестр ART: любой спрайт заменяется своим PNG.
   ===================================================================== */
const W = 2400, H = 1500, CELL = 20, GW = 120, GH = 75, TICK = 0.05;
const TAU = Math.PI * 2;
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function hash2(x, y) { let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }
function vnoise(x, y) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi; const s = t => t * t * (3 - 2 * t); const a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1); return lerp(lerp(a, b, s(xf)), lerp(c, d, s(xf)), s(yf)); }
const fmtTime = s => { s = Math.max(0, Math.ceil(s)); return String((s / 60) | 0).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0'); };

/* ---------- стороны и типы ---------- */
const SIDES = [
  { id: 'ua', name: 'Украина', short: 'ВСУ', color: '#3d8fe0', dark: '#1d4a7a', accent: '#f2cb4b', calls: ['Бриз', 'Ворон', 'Тайга', 'Сокол', 'Гром', 'Лис', 'Клён', 'Барс', 'Дуб', 'Яр', 'Мох', 'Шершень'] },
  { id: 'ru', name: 'Россия', short: 'ВС РФ', color: '#d4483f', dark: '#7a2521', accent: '#f0a08a', calls: ['Север', 'Урал', 'Волк', 'Орёл', 'Шторм', 'Рысь', 'Кедр', 'Берёза', 'Тигр', 'Дон', 'Буран', 'Гранит'] }
];
const NAMES = {
  rifle: [['Стрелковое отделение', 'Пехота'], ['Мотострелковое отделение', 'Мотострелки']],
  mg: [['Пулемётный расчёт', 'ПКМ'], ['Пулемётный расчёт', 'ПКМ']],
  at: [['Расчёт ПТРК', 'Javelin / NLAW'], ['Расчёт ПТУР', 'Корнет']],
  sniper: [['Снайперская пара', 'Дальний огонь'], ['Снайперская пара', 'Дальний огонь']],
  mortar: [['Миномётный расчёт', 'Миномёт 82 мм'], ['Миномётный расчёт', 'Миномёт 82 мм']],
  ifv: [['БМП', 'M2 Bradley'], ['БМП', 'БМП-2']],
  tank: [['Танк', 'Leopard 2'], ['Танк', 'Т-90М']]
};
const DIFFS = { easy: { name: 'Лёгкая', inc: .7, acc: .85 }, normal: { name: 'Нормальная', inc: 1, acc: 1 }, hard: { name: 'Тяжёлая', inc: 1.35, acc: 1.12 } };

/* ---------- местность ---------- */
const T = { OPEN: 0, FOREST: 1, BUILD: 2, WATER: 3, ROAD: 4, TRENCH: 5, RUBBLE: 6, BRIDGE: 7, FORD: 8 };
const T_COVER = [0, .45, .8, 0, 0, .75, .3, 0, 0];
const T_OPAC = [0, .5, 1, 0, 0, 0, .05, 0, 0];
const T_MV_I = [1, .6, .7, 0, 1.1, .8, .85, 1.1, .5];
const T_MV_V = [1, .3, 0, 0, 1.35, .2, .6, 1, .45];
const T_NAME = ['Открытая местность', 'Лес', 'Здание', 'Река', 'Дорога', 'Окоп', 'Развалины', 'Мост', 'Брод'];
const ter = new Uint8Array(GW * GH), hgt = new Float32Array(GW * GH);
function cellIdx(x, y) { const ix = x < 0 ? 0 : x >= W ? GW - 1 : (x / CELL) | 0, iy = y < 0 ? 0 : y >= H ? GH - 1 : (y / CELL) | 0; return iy * GW + ix; }

/* ---------- видимость (линия огня) ---------- */
let S = null; // состояние боя
function losOpacity(x0, y0, x1, y1) {
  const d = dist(x0, y0, x1, y1); if (d < 1) return 0;
  const n = Math.max(1, Math.ceil(d / (CELL * .5))), sx = (x1 - x0) / n, sy = (y1 - y0) / n;
  const c0 = cellIdx(x0, y0), c1 = cellIdx(x1, y1); let sum = 0, last = -1;
  for (let i = 1; i < n; i++) {
    const c = cellIdx(x0 + sx * i, y0 + sy * i);
    if (c === last) continue; last = c;
    if (c === c0 || c === c1) continue;
    const o = T_OPAC[ter[c]]; if (o) { sum += o; if (sum >= 1) return 1; }
  }
  return sum;
}
function segCircle(x0, y0, x1, y1, cx, cy, r) {
  const dx = x1 - x0, dy = y1 - y0, l2 = dx * dx + dy * dy; let t = l2 ? ((cx - x0) * dx + (cy - y0) * dy) / l2 : 0; t = clamp(t, 0, 1);
  const px = x0 + dx * t - cx, py = y0 + dy * t - cy; return px * px + py * py < r * r;
}
function los(x0, y0, x1, y1) {
  if (losOpacity(x0, y0, x1, y1) >= 1) return false;
  if (S) for (let i = 0; i < S.smokes.length; i++) { const s = S.smokes[i]; if (segCircle(x0, y0, x1, y1, s.x, s.y, s.r)) return false; }
  return true;
}

/* ---------- поиск пути (A* по сетке) ---------- */
const PF = { g: new Float32Array(GW * GH), from: new Int32Array(GW * GH), stamp: new Uint32Array(GW * GH), closed: new Uint32Array(GW * GH), id: 0 };
const heapI = [], heapF = [];
const DX = [1, -1, 0, 0, 1, 1, -1, -1], DY = [0, 0, 1, -1, 1, -1, 1, -1];
function hpush(i, f) { let n = heapI.length; heapI.push(i); heapF.push(f); while (n > 0) { const p = (n - 1) >> 1; if (heapF[p] <= f) break; heapI[n] = heapI[p]; heapF[n] = heapF[p]; n = p; } heapI[n] = i; heapF[n] = f; }
function hpop() { const top = heapI[0], li = heapI.pop(), lf = heapF.pop(), n = heapI.length; if (n > 0) { let k = 0; for (; ;) { let c = 2 * k + 1; if (c >= n) break; if (c + 1 < n && heapF[c + 1] < heapF[c]) c++; if (heapF[c] >= lf) break; heapI[k] = heapI[c]; heapF[k] = heapF[c]; k = c; } heapI[k] = li; heapF[k] = lf; } return top; }
function nearestPassable(c, mv) {
  if (mv[ter[c]] > 0) return c; const cx = c % GW, cy = (c / GW) | 0;
  for (let r = 1; r < 14; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue; const x = cx + dx, y = cy + dy; if (x < 0 || y < 0 || x >= GW || y >= GH) continue;
    const i = y * GW + x; if (mv[ter[i]] > 0) return i;
  }
  return c;
}
function lineClear(ax, ay, bx, by, mv, thr) {
  const d = dist(ax, ay, bx, by), n = Math.max(1, Math.ceil(d / 8));
  for (let i = 0; i <= n; i++) { const m = mv[ter[cellIdx(ax + (bx - ax) * i / n, ay + (by - ay) * i / n)]]; if (m < thr) return false; }
  return true;
}
function findPath(sx, sy, tx, ty, veh) {
  const mv = veh ? T_MV_V : T_MV_I;
  const s = nearestPassable(cellIdx(sx, sy), mv), t = nearestPassable(cellIdx(tx, ty), mv);
  const tcx = (t % GW + .5) * CELL, tcy = ((t / GW | 0) + .5) * CELL;
  const ex = mv[ter[cellIdx(tx, ty)]] > 0 ? tx : tcx, ey = mv[ter[cellIdx(tx, ty)]] > 0 ? ty : tcy;
  if (s === t) return [{ x: ex, y: ey }];
  const id = ++PF.id; heapI.length = 0; heapF.length = 0;
  PF.g[s] = 0; PF.stamp[s] = id; PF.from[s] = -1; hpush(s, 0);
  const gx = t % GW, gy = (t / GW) | 0; let found = false;
  while (heapI.length) {
    const c = hpop(); if (PF.closed[c] === id) continue; PF.closed[c] = id;
    if (c === t) { found = true; break; }
    const cx = c % GW, cy = (c / GW) | 0;
    for (let k = 0; k < 8; k++) {
      const nx = cx + DX[k], ny = cy + DY[k]; if (nx < 0 || ny < 0 || nx >= GW || ny >= GH) continue;
      const n = ny * GW + nx, m = mv[ter[n]]; if (m === 0 || PF.closed[n] === id) continue;
      if (k > 3 && (mv[ter[cy * GW + nx]] === 0 || mv[ter[ny * GW + cx]] === 0)) continue;
      const ng = PF.g[c] + (k > 3 ? 1.414 : 1) / m;
      if (PF.stamp[n] !== id || ng < PF.g[n]) {
        PF.stamp[n] = id; PF.g[n] = ng; PF.from[n] = c;
        const ax = Math.abs(nx - gx), ay = Math.abs(ny - gy); hpush(n, ng + (Math.max(ax, ay) + .414 * Math.min(ax, ay)) * .72);
      }
    }
  }
  if (!found) return null;
  const cells = []; for (let c = t; c !== -1; c = PF.from[c]) cells.push(c); cells.reverse();
  const P = cells.map(c => ({ x: (c % GW + .5) * CELL, y: ((c / GW | 0) + .5) * CELL })); P[0] = { x: sx, y: sy }; P[P.length - 1] = { x: ex, y: ey };
  const thr = veh ? .4 : .55, out = []; let i = 0;
  while (i < P.length - 1) { let j = P.length - 1; while (j > i + 1 && !lineClear(P[i].x, P[i].y, P[j].x, P[j].y, mv, thr)) j--; out.push(P[j]); i = j; }
  return out;
}
