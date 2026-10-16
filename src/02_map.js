/* =====================  КАРТА «ПЕРЕПРАВА»  ===================== */
const MAP = { forests: [], buildings: [], roads: [], trenches: [], fields: [], river: [], bridge: null, craters: [], objs: [] };
const RIVER_W = 70;

function smoothPoly(p, seg = 10) {
  if (p.length < 3) return p.slice(); const out = [p[0]];
  for (let i = 1; i < p.length - 1; i++) {
    const m0 = i === 1 ? p[0] : [(p[i - 1][0] + p[i][0]) / 2, (p[i - 1][1] + p[i][1]) / 2];
    const m1 = i === p.length - 2 ? p[p.length - 1] : [(p[i][0] + p[i + 1][0]) / 2, (p[i][1] + p[i + 1][1]) / 2];
    for (let s = 1; s <= seg; s++) { const t = s / seg, u = 1 - t; out.push([u * u * m0[0] + 2 * u * t * p[i][0] + t * t * m1[0], u * u * m0[1] + 2 * u * t * p[i][1] + t * t * m1[1]]); }
  }
  return out;
}
function distToPoly(x, y, P) {
  let best = 1e9;
  for (let i = 0; i < P.length - 1; i++) {
    const ax = P[i][0], ay = P[i][1], bx = P[i + 1][0], by = P[i + 1][1], dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy;
    let t = l2 ? ((x - ax) * dx + (y - ay) * dy) / l2 : 0; t = clamp(t, 0, 1);
    const d = Math.hypot(x - ax - dx * t, y - ay - dy * t); if (d < best) best = d;
  }
  return best;
}
function forCircle(cx, cy, r, fn) {
  const x0 = Math.max(0, ((cx - r) / CELL) | 0), x1 = Math.min(GW - 1, ((cx + r) / CELL) | 0), y0 = Math.max(0, ((cy - r) / CELL) | 0), y1 = Math.min(GH - 1, ((cy + r) / CELL) | 0);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (dist((x + .5) * CELL, (y + .5) * CELL, cx, cy) <= r) fn(y * GW + x, x, y);
}
function stampLine(P, width, fn) { for (let i = 0; i < P.length - 1; i++) { const d = dist(P[i][0], P[i][1], P[i + 1][0], P[i + 1][1]), n = Math.max(1, Math.ceil(d / 8)); for (let k = 0; k <= n; k++) forCircle(lerp(P[i][0], P[i + 1][0], k / n), lerp(P[i][1], P[i + 1][1], k / n), width / 2, fn); } }

function genMap() {
  const r = mulberry32(20241016);
  ter.fill(0);
  // высоты
  const hills = [[1930, 520, 190, 1], [1780, 1130, 160, .85], [600, 340, 210, .5], [720, 1190, 180, .45], [1320, 200, 120, .3], [2250, 1250, 200, .4]];
  for (let iy = 0; iy < GH; iy++) for (let ix = 0; ix < GW; ix++) {
    const x = (ix + .5) * CELL, y = (iy + .5) * CELL; let h = .06 * Math.sin(x * .004 + 1) * Math.cos(y * .005);
    for (const [hx, hy, s, a] of hills) { const dx = x - hx, dy = y - hy; h += a * Math.exp(-(dx * dx + dy * dy) / (2 * s * s)); }
    hgt[iy * GW + ix] = clamp(h, 0, 1);
  }
  // река
  MAP.river = smoothPoly([[1060, -60], [1120, 200], [1040, 430], [1100, 640], [1180, 800], [1090, 1010], [1020, 1230], [1080, 1560]], 12);
  for (let iy = 0; iy < GH; iy++) for (let ix = 0; ix < GW; ix++) {
    const x = (ix + .5) * CELL, y = (iy + .5) * CELL;
    if (distToPoly(x, y, MAP.river) < RIVER_W / 2) ter[iy * GW + ix] = (Math.abs(y - 350) < 45 || Math.abs(y - 1130) < 45) ? T.FORD : T.WATER;
  }
  // мост
  MAP.bridge = { x: 1150, y: 740, w: 150, h: 34 };
  forCircle(1150, 740, 80, (c, cx, cy) => { const x = (cx + .5) * CELL, y = (cy + .5) * CELL; if (Math.abs(x - 1150) < 80 && Math.abs(y - 740) < 17) ter[c] = T.BRIDGE; });
  // дороги
  MAP.roads = [smoothPoly([[-20, 760], [380, 748], [760, 738], [1085, 741]], 8), smoothPoly([[1215, 742], [1480, 738], [1830, 734], [2420, 716]], 8)];
  for (const road of MAP.roads) stampLine(road, 40, c => { if (ter[c] === T.OPEN || ter[c] === T.FOREST) ter[c] = T.ROAD; });
  // село
  const bl = MAP.buildings;
  const addB = (x, y, w, h) => { bl.push({ x, y, w, h, tone: r() }); const x0 = x - 6, x1 = x + w + 6, y0 = y - 6, y1 = y + h + 6; for (let iy = Math.max(0, (y0 / CELL) | 0); iy <= Math.min(GH - 1, (y1 / CELL) | 0); iy++) for (let ix = Math.max(0, (x0 / CELL) | 0); ix <= Math.min(GW - 1, (x1 / CELL) | 0); ix++) { const cx = (ix + .5) * CELL, cy = (iy + .5) * CELL; const c = iy * GW + ix; if (cx > x0 && cx < x1 && cy > y0 && cy < y1 && ter[c] !== T.WATER && ter[c] !== T.ROAD) ter[c] = T.BUILD; } };
  for (let x = 1560; x < 1850; x += 58) {
    if (r() > .15) addB(x + r() * 10, 664 + r() * 8, 38 + r() * 26, 30 + r() * 14);
    if (r() > .15) addB(x + r() * 10, 772 + r() * 8, 38 + r() * 26, 30 + r() * 14);
    if (r() > .5) addB(x + r() * 14, 598 + r() * 14, 36 + r() * 24, 28 + r() * 12);
    if (r() > .5) addB(x + r() * 14, 850 + r() * 14, 36 + r() * 24, 28 + r() * 12);
  }
  addB(1380, 820, 44, 34); addB(1280, 640, 40, 30); addB(2060, 830, 46, 32); addB(2110, 640, 40, 30);
  // лес
  const patches = [[420, 260, 150], [520, 560, 110], [330, 980, 170], [660, 1080, 130], [860, 380, 100], [900, 1260, 140], [1330, 330, 110], [1290, 1000, 100], [1330, 1250, 120], [1520, 470, 90], [1690, 300, 120], [2060, 430, 120], [1810, 600, 70], [1700, 1190, 140], [1860, 1030, 100], [2200, 760, 90], [2250, 300, 160], [2100, 1300, 130], [560, 800, 60], [760, 520, 60]];
  MAP.forests = patches;
  for (const [cx, cy, rad] of patches) forCircle(cx, cy, rad * 1.5, (c, ix, iy) => { const x = (ix + .5) * CELL, y = (iy + .5) * CELL; const thr = rad * (.65 + .55 * vnoise(x * .014, y * .014)); if (dist(x, y, cx, cy) < thr && ter[c] === T.OPEN) ter[c] = T.FOREST; });
  // окопы
  MAP.trenches = [
    [[1500, 610], [1512, 690], [1500, 760], [1512, 830], [1500, 905]], [[1580, 598], [1680, 588], [1780, 598]], [[1580, 884], [1680, 894], [1780, 884]],
    [[1830, 560], [1890, 592], [1960, 572], [2020, 520]], [[1880, 462], [1930, 440], [1990, 450]], [[1700, 1090], [1760, 1070], [1840, 1090]], [[1262, 690], [1268, 740], [1262, 800]]
  ];
  for (const t of MAP.trenches) stampLine(smoothPoly(t, 6), 14, c => { if (ter[c] !== T.WATER && ter[c] !== T.BUILD && ter[c] !== T.ROAD) ter[c] = T.TRENCH; });
  // воронки и завалы
  for (let i = 0; i < 26; i++) { const x = rand(1350, 2050), y = rand(520, 960); MAP.craters.push([x, y, rand(7, 15)]); }
  for (let i = 0; i < 12; i++) { const x = rand(1400, 1900), y = rand(560, 920); forCircle(x, y, 12, c => { if (ter[c] === T.OPEN) ter[c] = T.RUBBLE; }); }
  // поля (только вид)
  MAP.fields = [[80, 80, 300, 200], [120, 380, 250, 200], [60, 1130, 320, 260], [420, 1230, 200, 200], [1420, 90, 240, 220], [2100, 900, 260, 280], [2000, 1210, 300, 220], [1500, 1180, 160, 200], [700, 640, 150, 70]];
  MAP.objs = [
    { id: 0, name: 'Мост', x: 1150, y: 740, r: 85, key: false },
    { id: 1, name: 'Село Дубки', x: 1700, y: 742, r: 110, key: true },
    { id: 2, name: 'Высота 112', x: 1930, y: 520, r: 95, key: true }
  ];
}

/* =====================  ГРАФИКА: реестр ART  ===================== */
/* Любой ключ можно заменить своим PNG (см. «Графика» в настройках).
   map — карта целиком 2400×1500; soldier_ua/ru — боец, смотрит вправо; veh_ifv_ua … — техника, смотрит вправо;
   icon_rifle … icon_tank — значки отрядов (квадрат). */
const ART = {};
const ART_KEYS = [
  ['map', 'Карта целиком', '2400×1500', 'Подложка поля боя. Сетка проходимости остаётся прежней.'],
  ['soldier_ua', 'Боец ВСУ', '64×64', 'Вид сверху, смотрит вправо'], ['soldier_ru', 'Боец ВС РФ', '64×64', 'Вид сверху, смотрит вправо'],
  ['veh_ifv_ua', 'БМП ВСУ', '240×110', 'Корпус вместе с башней, смотрит вправо'], ['veh_ifv_ru', 'БМП ВС РФ', '240×110', 'Корпус вместе с башней, смотрит вправо'],
  ['veh_tank_ua', 'Танк ВСУ', '300×140', 'Корпус вместе с башней, смотрит вправо'], ['veh_tank_ru', 'Танк ВС РФ', '300×140', 'Корпус вместе с башней, смотрит вправо'],
  ...TYPE_ORDER.map(t => ['icon_' + t, 'Значок: ' + NAMES[t][0][0], '128×128', 'Для карточек и плашек'])
];
const art = k => ART[k] || null;
function loadArt(key, url) { return new Promise(res => { const im = new Image(); im.onload = () => { ART[key] = { img: im, w: im.naturalWidth, h: im.naturalHeight, url }; res(true); }; im.onerror = () => res(false); im.src = url; }); }

/* ---------- значки отрядов (векторные, по умолчанию) ---------- */
function drawGlyph(g, type, cx, cy, s, col) {
  g.save(); g.translate(cx, cy); g.strokeStyle = col; g.fillStyle = col; g.lineWidth = Math.max(1.2, s * .13); g.lineCap = 'round'; g.lineJoin = 'round';
  const h = s / 2;
  if (type === 'rifle' || type === 'mg' || type === 'at') { g.strokeRect(-h, -h * .62, s, s * .62 * 2); g.beginPath(); g.moveTo(-h, -h * .62); g.lineTo(h, h * .62); g.moveTo(h, -h * .62); g.lineTo(-h, h * .62); g.stroke(); if (type === 'mg') { g.beginPath(); g.moveTo(0, -h * .62); g.lineTo(0, -h * 1.05); g.stroke(); } if (type === 'at') { g.beginPath(); g.moveTo(-h * .5, h * 1.0); g.lineTo(0, h * .62); g.lineTo(h * .5, h * 1.0); g.stroke(); } }
  else if (type === 'sniper') { g.beginPath(); g.arc(0, 0, h * .72, 0, TAU); g.moveTo(-h * 1.05, 0); g.lineTo(h * 1.05, 0); g.moveTo(0, -h * 1.05); g.lineTo(0, h * 1.05); g.stroke(); }
  else if (type === 'mortar') { g.beginPath(); g.arc(0, h * .35, h * .5, 0, TAU); g.stroke(); g.beginPath(); g.moveTo(0, h * .1); g.lineTo(h * .5, -h * .95); g.stroke(); }
  else if (type === 'ifv') { g.strokeRect(-h, -h * .55, s, s * .55 * 2); g.beginPath(); g.ellipse(0, 0, h * .42, h * .3, 0, 0, TAU); g.fill(); g.moveTo(h * .4, 0); g.lineTo(h * 1.05, 0); g.stroke(); }
  else if (type === 'tank') { g.beginPath(); g.ellipse(0, 0, h * .95, h * .6, 0, 0, TAU); g.stroke(); g.beginPath(); g.arc(-h * .1, 0, h * .3, 0, TAU); g.fill(); g.moveTo(h * .1, 0); g.lineTo(h * 1.15, 0); g.stroke(); }
  g.restore();
}
const iconCache = {};
function iconURL(type, side) {
  const k = type + side + (ART['icon_' + type] ? 'a' : ''); if (iconCache[k]) return iconCache[k];
  const c = document.createElement('canvas'); c.width = c.height = 96; const g = c.getContext('2d');
  const a = art('icon_' + type);
  if (a) g.drawImage(a.img, 0, 0, 96, 96); else { g.fillStyle = SIDES[side].dark; g.beginPath(); g.roundRect(4, 4, 88, 88, 16); g.fill(); g.strokeStyle = SIDES[side].color; g.lineWidth = 4; g.stroke(); drawGlyph(g, type, 48, 48, 50, '#f3f5f6'); }
  return iconCache[k] = c.toDataURL();
}

/* =====================  ОТРИСОВКА МЕСТНОСТИ  ===================== */
const TS = 1.25;
function renderTerrain() {
  const c = document.createElement('canvas'); c.width = Math.round(W * TS); c.height = Math.round(H * TS); const g = c.getContext('2d'); g.scale(TS, TS);
  const r = mulberry32(77);
  const ell = (x, y, rx, ry, col) => { g.fillStyle = col; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill(); };
  const poly = (P, w, col, cap = 'round') => { g.strokeStyle = col; g.lineWidth = w; g.lineCap = cap; g.lineJoin = 'round'; g.beginPath(); P.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.stroke(); };
  if (art('map')) { g.drawImage(art('map').img, 0, 0, W, H); return c; }
  g.fillStyle = '#5f7c47'; g.fillRect(0, 0, W, H);
  for (let i = 0; i < 2600; i++) { const x = r() * W, y = r() * H; ell(x, y, 30 + r() * 90, 20 + r() * 60, r() < .5 ? 'rgba(125,152,84,.07)' : 'rgba(62,92,52,.08)'); }
  // поля
  MAP.fields.forEach(([x, y, w, h], i) => { const tones = ['#8a9150', '#a09a58', '#76874a', '#9a8e55']; g.fillStyle = tones[i % 4]; g.fillRect(x, y, w, h); g.strokeStyle = 'rgba(40,40,20,.18)'; g.lineWidth = 1.2; for (let k = 5; k < (i % 2 ? w : h); k += 9) { g.beginPath(); if (i % 2) { g.moveTo(x + k, y); g.lineTo(x + k, y + h); } else { g.moveTo(x, y + k); g.lineTo(x + w, y + k); } g.stroke(); } g.strokeStyle = 'rgba(30,45,20,.35)'; g.lineWidth = 3; g.strokeRect(x, y, w, h); });
  // рельеф
  const hc = document.createElement('canvas'); hc.width = GW; hc.height = GH; const hg = hc.getContext('2d'), id = hg.createImageData(GW, GH);
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const i = y * GW + x, l = hgt[y * GW + Math.max(0, x - 1)], rr = hgt[y * GW + Math.min(GW - 1, x + 1)], u = hgt[Math.max(0, y - 1) * GW + x], d = hgt[Math.min(GH - 1, y + 1) * GW + x];
    const s = ((l - rr) + (u - d)) * 5 + hgt[i] * .12 - .04, p = i * 4; if (s > 0) { id.data[p] = 255; id.data[p + 1] = 250; id.data[p + 2] = 215; id.data[p + 3] = clamp(s * 255, 0, 120); } else { id.data[p] = 10; id.data[p + 1] = 20; id.data[p + 2] = 10; id.data[p + 3] = clamp(-s * 255, 0, 120); }
  }
  hg.putImageData(id, 0, 0); g.imageSmoothingEnabled = true; g.drawImage(hc, 0, 0, W, H);
  // река
  poly(MAP.river, RIVER_W + 18, 'rgba(120,112,80,.65)'); poly(MAP.river, RIVER_W + 4, '#6a8f8a'); poly(MAP.river, RIVER_W - 6, '#4c7c8e'); poly(MAP.river, RIVER_W * .55, '#41717f');
  g.strokeStyle = 'rgba(200,230,235,.22)'; g.lineWidth = 1.4; for (let k = -2; k <= 2; k++) { g.beginPath(); MAP.river.forEach((p, i) => { const o = k * 11 + Math.sin(i * .5 + k) * 2; i ? g.lineTo(p[0] + o, p[1]) : g.moveTo(p[0] + o, p[1]); }); g.stroke(); }
  for (const fy of [350, 1130]) { for (let i = 0; i < 46; i++) { const y = fy + rand(-40, 40); let best = MAP.river[0]; for (const p of MAP.river) if (Math.abs(p[1] - y) < Math.abs(best[1] - y)) best = p; ell(best[0] + rand(-30, 30), y, rand(2, 5), rand(1.5, 3), 'rgba(170,165,140,.7)'); } }
  // дороги
  for (const road of MAP.roads) { poly(road, 46, 'rgba(70,60,40,.28)'); poly(road, 40, '#a59670'); poly(road, 28, '#b6a77f'); g.setLineDash([14, 22]); poly(road, 2, 'rgba(120,105,70,.55)', 'butt'); g.setLineDash([]); }
  // мост
  { const b = MAP.bridge; g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(b.x - b.w / 2 + 4, b.y - b.h / 2 + 5, b.w, b.h); g.fillStyle = '#7a6040'; g.fillRect(b.x - b.w / 2, b.y - b.h / 2, b.w, b.h); g.strokeStyle = 'rgba(40,28,14,.55)'; g.lineWidth = 1; for (let x = b.x - b.w / 2 + 5; x < b.x + b.w / 2; x += 6) { g.beginPath(); g.moveTo(x, b.y - b.h / 2); g.lineTo(x, b.y + b.h / 2); g.stroke(); } g.fillStyle = '#4f3b24'; g.fillRect(b.x - b.w / 2, b.y - b.h / 2 - 2, b.w, 3); g.fillRect(b.x - b.w / 2, b.y + b.h / 2 - 1, b.w, 3); }
  // воронки
  for (const [x, y, rad] of MAP.craters) { ell(x, y, rad + 3, rad * .8 + 3, 'rgba(60,45,30,.35)'); ell(x, y, rad, rad * .78, '#40321f'); ell(x - 1, y - 1, rad * .6, rad * .45, '#2d2316'); }
  // окопы
  for (const t of MAP.trenches) { const P = smoothPoly(t, 6); poly(P, 20, 'rgba(112,96,64,.9)'); poly(P, 11, '#3b2f21'); poly(P, 6, '#2a2017'); }
  // деревья
  const trees = []; for (let i = 0; i < GW * GH; i++) if (ter[i] === T.FOREST) { const cx = (i % GW) * CELL, cy = ((i / GW) | 0) * CELL; const n = 4; for (let k = 0; k < n; k++) trees.push([cx + r() * CELL, cy + r() * CELL, 8 + r() * 6, r()]); }
  trees.sort((a, b) => a[1] - b[1]);
  for (const [x, y, rad] of trees) ell(x + 4, y + 5, rad, rad * .85, 'rgba(8,16,8,.3)');
  const crowns = ['#2e4c2b', '#36592f', '#3f6536', '#2a4527'];
  for (const [x, y, rad, k] of trees) { ell(x, y, rad, rad, crowns[(k * 4) | 0]); ell(x - rad * .25, y - rad * .3, rad * .6, rad * .55, 'rgba(150,190,100,.22)'); }
  // здания
  const roofs = ['#8b6a55', '#7c8086', '#9a5f4a', '#6f737a', '#a48a6b', '#855a4c'];
  for (const b of MAP.buildings) {
    g.fillStyle = 'rgba(0,0,0,.32)'; g.fillRect(b.x + 6, b.y + 7, b.w, b.h); g.fillStyle = '#cfc8b6'; g.fillRect(b.x, b.y, b.w, b.h);
    const col = roofs[(b.tone * roofs.length) | 0]; g.fillStyle = col; g.fillRect(b.x + 2, b.y + 2, b.w - 4, b.h - 4);
    g.fillStyle = 'rgba(255,255,255,.14)'; g.fillRect(b.x + 2, b.y + 2, b.w - 4, (b.h - 4) / 2); g.fillStyle = 'rgba(0,0,0,.2)'; g.fillRect(b.x + 2, b.y + 2 + (b.h - 4) / 2, b.w - 4, (b.h - 4) / 2);
    g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 1; g.beginPath(); g.moveTo(b.x + 2, b.y + b.h / 2); g.lineTo(b.x + b.w - 2, b.y + b.h / 2); g.stroke();
  }
  // зерно
  for (let i = 0; i < 14000; i++) { g.fillStyle = r() < .5 ? 'rgba(255,255,230,.05)' : 'rgba(0,0,0,.06)'; g.fillRect(r() * W, r() * H, 1.4, 1.4); }
  return c;
}
let terrainCanvas = null, miniBase = null;
function buildTerrain() {
  terrainCanvas = renderTerrain();
  miniBase = document.createElement('canvas'); miniBase.width = 240; miniBase.height = 150; const g = miniBase.getContext('2d'); g.drawImage(terrainCanvas, 0, 0, 240, 150);
}
