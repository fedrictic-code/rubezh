/* =====================  СПРАЙТЫ (рисуются кодом, кешируются)  =====================
   Корпус и башня — отдельные картинки: башня вращается независимо.
   Любой спрайт можно заменить через реестр ART (veh_<id>, veh_<id>_hull, soldier_<side>). */
const SPS = 7;                       // пикселей спрайта на единицу мира
const SPC = { veh: {}, sol: {} };
const rrp = (g, x, y, w, h, r) => { g.beginPath(); g.roundRect(x, y, w, h, r); };
function spCanvas(wu, hu, px = SPS) { const c = document.createElement('canvas'); c.width = Math.ceil(wu * px); c.height = Math.ceil(hu * px); const g = c.getContext('2d'); g.scale(px, px); g.translate(wu / 2, hu / 2); return [c, g]; }
function spCopy(c, mode, fill) { const o = document.createElement('canvas'); o.width = c.width; o.height = c.height; const g = o.getContext('2d'); g.drawImage(c, 0, 0); g.globalCompositeOperation = mode; g.fillStyle = fill; g.fillRect(0, 0, o.width, o.height); return o; }
function spPal(v, side) {
  const P = side === 0 ? { base: '#57623f', lt: '#6e7a52', dk: '#3a432b', tan: '#8d8458', mk: '#2c3321' } : { base: '#505e3b', lt: '#687652', dk: '#34402a', tan: '#74633f', mk: '#2a3220' };
  if (v.id === 'tank_abrams') Object.assign(P, { base: '#9a8c62', lt: '#b0a376', dk: '#6c6143', tan: '#7d7048' });
  if (v.id === 'tank_leo2') Object.assign(P, { base: '#4b5940', lt: '#627252', dk: '#2f3a29', tan: '#6b6a45' });
  if (v.id === 'bradley') Object.assign(P, { base: '#58634a', lt: '#707c5c', dk: '#38412d' });
  return P;
}
function spCamo(g, P, seed, ext) {
  const r = mulberry32(seed); g.save(); g.clip();
  for (let i = 0; i < 26; i++) { g.fillStyle = r() < .55 ? P.dk : P.tan; g.globalAlpha = .55; g.beginPath(); g.ellipse((r() - .5) * ext, (r() - .5) * ext * .5, 1.2 + r() * 3, .8 + r() * 1.6, r() * 3, 0, TAU); g.fill(); }
  g.globalAlpha = 1; g.restore();
}
function spPoly(g, pts) { g.beginPath(); pts.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.closePath(); }
function spEra(g, x0, x1, y0, y1, step, sz) { g.fillStyle = 'rgba(22,26,18,.62)'; g.strokeStyle = 'rgba(0,0,0,.5)'; g.lineWidth = .06; for (let x = x0; x < x1; x += step) for (let y = y0; y <= y1; y += step) { g.fillRect(x, y, sz, sz); g.strokeRect(x, y, sz, sz); } }
function spBarrel(g, x0, len, wd, col, opt = {}) {
  g.fillStyle = col; g.fillRect(x0, -wd / 2, len - x0, wd);
  if (opt.sleeve) { g.fillStyle = opt.sleeveCol || col; g.fillRect(x0 + (len - x0) * .22, -wd * .85, (len - x0) * .5, wd * 1.7); }
  if (opt.ext) { g.fillStyle = col; g.fillRect(x0 + (len - x0) * .62, -wd * .85, (len - x0) * .1, wd * 1.7); }
  g.fillStyle = '#15171a'; g.fillRect(len - .7, -wd * .75, .7, wd * 1.5);
  g.fillStyle = 'rgba(255,255,255,.18)'; g.fillRect(x0, -wd / 2, len - x0, wd * .25);
}

/* ---------- корпус ---------- */
function spHull(v, side) {
  const L = v.len, Wd = v.wid, id = v.id, wh = !!v.wheeled, tank = v.cls === 'tank', P = spPal(v, side), [c, g] = spCanvas(L + 3, Wd + 3), hw = Wd / 2 - (wh ? .3 : Wd * .11);
  const trk = Wd * (tank ? .21 : .23);
  if (wh) {
    for (const a of [-.36, -.13, .13, .36]) for (const s of [-1, 1]) {
      const y = s < 0 ? -Wd / 2 - .1 : Wd / 2 - 1.5 + .1; g.fillStyle = '#121416'; rrp(g, L * a - 1.2, y, 2.4, 1.6, .6); g.fill();
      g.fillStyle = '#25292c'; rrp(g, L * a - .8, y + .25, 1.6, 1.1, .4); g.fill();
    }
  } else for (const s of [-1, 1]) {
    const y0 = s < 0 ? -Wd / 2 : Wd / 2 - trk; g.fillStyle = '#1b1e21'; rrp(g, -L / 2, y0, L, trk, trk * .45); g.fill();
    g.strokeStyle = '#363b40'; g.lineWidth = .11; for (let x = -L / 2 + .7; x < L / 2 - .5; x += .75) { g.beginPath(); g.moveTo(x, y0 + .12); g.lineTo(x, y0 + trk - .12); g.stroke(); }
    g.fillStyle = '#2b3034'; for (let i = 0; i < 6; i++) { g.beginPath(); g.arc(-L / 2 + L * (.12 + .152 * i), y0 + trk / 2, trk * .3, 0, TAU); g.fill(); }
  }
  // корпус
  const nose = wh ? [[-L / 2 + .3, -hw], [L * .12, -hw], [L / 2 - .2, -hw * .68], [L / 2 - .2, hw * .68], [L * .12, hw], [-L / 2 + .3, hw]] : [[-L / 2 + .5, -hw], [L * .27, -hw], [L / 2 - .3, -hw * .6], [L / 2 - .3, hw * .6], [L * .27, hw], [-L / 2 + .5, hw]];
  spPoly(g, nose); g.fillStyle = P.base; g.fill(); spCamo(g, P, id.length * 977 + side * 31, L);
  spPoly(g, nose); g.strokeStyle = P.mk; g.lineWidth = .16; g.stroke();
  // глацис, моторное отделение
  const gl = g.createLinearGradient(L * .27, 0, L / 2, 0); gl.addColorStop(0, 'rgba(255,255,255,0)'); gl.addColorStop(1, 'rgba(255,255,255,.16)'); spPoly(g, nose); g.fillStyle = gl; g.fill();
  g.strokeStyle = 'rgba(0,0,0,.3)'; g.lineWidth = .1; for (let x = -L / 2 + 1; x < -L * .1; x += .55) { g.beginPath(); g.moveTo(x, -hw * .7); g.lineTo(x, hw * .7); g.stroke(); }
  g.fillStyle = 'rgba(0,0,0,.14)'; g.fillRect(-L / 2 + .9, -hw * .72, L * .36, hw * 1.44); g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = .1; g.strokeRect(-L / 2 + .9, -hw * .72, L * .36, hw * 1.44);
  // динамическая защита и обвес
  if (['tank_t64bv', 'tank_t72b3', 'tank_t80bvm', 'tank_t90m'].includes(id)) spEra(g, L * .3, L / 2 - .9, -hw * .78, hw * .55, .85, .62);
  if (id === 'tank_t72b3' || id === 'tank_t64bv' || id === 'tank_t90m') { g.fillStyle = '#3d4a33'; for (const dy of [hw * .38, hw * .72]) { rrp(g, -L / 2 + .7, dy - .45, 2.4, .9, .4); g.fill(); g.strokeStyle = '#1d2418'; g.lineWidth = .08; g.stroke(); } }
  if (tank) {
    if (id === 'tank_leo2' || id === 'tank_abrams' || id === 'tank_t90m') for (const s of [-1, 1]) { g.fillStyle = P.dk; g.globalAlpha = .9; g.fillRect(-L * .38, s < 0 ? -Wd / 2 + .15 : Wd / 2 - trk * .95, L * .62, trk * .8); g.globalAlpha = 1; g.strokeStyle = 'rgba(0,0,0,.45)'; g.lineWidth = .09; for (let x = -L * .38; x < L * .24; x += 2.4) { g.beginPath(); g.moveTo(x, s < 0 ? -Wd / 2 + .15 : Wd / 2 - trk * .95); g.lineTo(x, s < 0 ? -Wd / 2 + .15 + trk * .8 : Wd / 2 - trk * .15); g.stroke(); } }
    else for (const s of [-1, 1]) { g.fillStyle = '#262b27'; g.fillRect(L * .12, s < 0 ? -Wd / 2 + .12 : Wd / 2 - trk * .9, L * .36, trk * .78); }
    g.fillStyle = P.dk; g.beginPath(); g.arc(L * .31, id === 'tank_leo2' ? -hw * .45 : 0, Wd * .095, 0, TAU); g.fill(); g.strokeStyle = 'rgba(255,255,255,.25)'; g.lineWidth = .08; g.stroke();
  } else {
    g.fillStyle = P.dk; for (const dx of [-L * .28, -L * .1]) { rrp(g, dx - .8, -hw * .5, 1.6, 1.2, .2); g.fill(); rrp(g, dx - .8, hw * .5 - 1.2, 1.6, 1.2, .2); g.fill(); }
    if (id === 'bradley') { g.strokeStyle = 'rgba(0,0,0,.4)'; g.lineWidth = .1; for (const s of [-1, 1]) for (let x = -L * .35; x < L * .25; x += 2.2) g.strokeRect(x, s < 0 ? -hw : hw - 1.4, 2, 1.4); }
  }
  // фары
  g.fillStyle = '#d9d4a4'; for (const s of [-1, 1]) { g.beginPath(); g.arc(L / 2 - .7, s * hw * .52, .26, 0, TAU); g.fill(); }
  // опознавательный знак стороны на корме
  g.fillStyle = SIDES[side].color; g.globalAlpha = .9; g.fillRect(-L / 2 + .7, -.45, .75, .9); g.globalAlpha = 1;
  return c;
}

/* ---------- башня (центр картинки = ось вращения) ---------- */
function spTurret(v, side) {
  const L = v.len, Wd = v.wid, id = v.id, P = spPal(v, side), tank = v.cls === 'tank';
  const gunL = tank ? L * .78 : id === 'bmp3' ? L * .5 : L * .55, ext = gunL + 1.2, [c, g] = spCanvas(ext * 2, Wd + 2);
  const G = '#2a2d30';
  if (id === 'tank_leo2' || id === 'tank_abrams') {
    const tl = L * .36, tw = Wd * .7, A = id === 'tank_abrams';
    const pts = (A ? [[-.7, -.36], [-.2, -.43], [.28, -.5], [.55, -.22], [.55, .22], [.28, .5], [-.2, .43], [-.7, .36]] : [[-.55, -.42], [0, -.5], [.34, -.46], [.5, -.2], [.5, .2], [.34, .46], [0, .5], [-.55, .42]]).map(p => [p[0] * tl, p[1] * tw]);
    spBarrel(g, tl * .45, gunL, .5, G, { sleeve: A, ext: !A, sleeveCol: '#3a3e41' });
    spPoly(g, pts); g.fillStyle = P.base; g.fill(); spCamo(g, P, 5 + id.length, tl); spPoly(g, pts); g.strokeStyle = P.mk; g.lineWidth = .16; g.stroke();
    g.fillStyle = 'rgba(255,255,255,.12)'; g.fillRect(tl * .1, -tw * .45, tl * .3, tw * .9);
    g.fillStyle = P.dk; rrp(g, tl * .38, -tw * .13, tl * .22, tw * .26, .3); g.fill();
    g.fillStyle = P.dk; g.beginPath(); g.arc(-tl * .1, tw * .22, Wd * .09, 0, TAU); g.fill(); g.strokeStyle = 'rgba(255,255,255,.3)'; g.lineWidth = .08; g.stroke();
    g.fillStyle = P.dk; rrp(g, -tl * .28, -tw * .3, 1.5, 1.3, .2); g.fill(); g.fillStyle = '#151719'; g.fillRect(tl * .05, tw * .3, .9, .45);
    if (A) { g.strokeStyle = '#2a2d30'; g.lineWidth = .18; g.beginPath(); g.moveTo(-tl * .15, -tw * .1); g.lineTo(tl * .05, -tw * .1); g.stroke(); }
  } else if (tank) {
    const tl = L * .36, tw = Wd * .66;
    spBarrel(g, tl * .4, gunL, .5, G, { ext: true });
    g.beginPath(); g.ellipse(0, 0, tl * .55, tw / 2, 0, 0, TAU); g.fillStyle = P.base; g.fill(); spCamo(g, P, 11 + id.length, tl); g.beginPath(); g.ellipse(0, 0, tl * .55, tw / 2, 0, 0, TAU); g.strokeStyle = P.mk; g.lineWidth = .16; g.stroke();
    g.fillStyle = 'rgba(255,255,255,.12)'; g.beginPath(); g.ellipse(tl * .12, 0, tl * .3, tw * .32, 0, 0, TAU); g.fill();
    g.fillStyle = P.dk; rrp(g, tl * .38, -tw * .14, tl * .2, tw * .28, .3); g.fill();
    if (id !== 'tank_t64bv') { for (const s of [-1, 1]) { g.save(); g.translate(tl * .3, s * tw * .27); g.rotate(s * .55); if (id === 'tank_t90m') { g.fillStyle = 'rgba(24,28,20,.7)'; g.fillRect(-tl * .2, -tw * .1, tl * .4, tw * .2); g.strokeStyle = 'rgba(0,0,0,.55)'; g.lineWidth = .08; g.strokeRect(-tl * .2, -tw * .1, tl * .4, tw * .2); for (let k = -.12; k < .2; k += .12) { g.beginPath(); g.moveTo(tl * k, -tw * .1); g.lineTo(tl * k, tw * .1); g.stroke(); } } else spEra(g, -tl * .18, tl * .2, -tw * .1, tw * .1, .8, .55); g.restore(); } } else for (const s of [-1, 1]) { g.save(); g.translate(tl * .3, s * tw * .27); g.rotate(s * .55); spEra(g, -tl * .18, tl * .2, -tw * .08, tw * .08, .8, .55); g.restore(); }
    g.fillStyle = P.dk; g.beginPath(); g.arc(-tl * .1, tw * .22, Wd * .085, 0, TAU); g.fill(); g.strokeStyle = 'rgba(255,255,255,.3)'; g.lineWidth = .08; g.stroke();
    g.fillStyle = '#1b1d1f'; g.fillRect(tl * .12, -tw * .27, .8, .55);
    if (id === 'tank_t72b3' || id === 'tank_t80bvm') { g.fillStyle = P.dk; rrp(g, -tl * .5, -tw * .12, 1.1, tw * .24, .3); g.fill(); }
  } else {
    const wide = id === 'bmp3', tl = L * (wide ? .32 : .27), tw = Wd * (wide ? .64 : .52);
    if (id === 'bradley') {
      spBarrel(g, tl * .3, gunL, .42, G, { sleeve: true, sleeveCol: '#33373a' });
      const pts = [[-.5, -.5], [.4, -.5], [.55, -.3], [.55, .3], [.4, .5], [-.5, .5]].map(p => [p[0] * tl * 1.2, p[1] * tw]);
      spPoly(g, pts); g.fillStyle = P.base; g.fill(); spCamo(g, P, 91, tl); spPoly(g, pts); g.strokeStyle = P.mk; g.lineWidth = .15; g.stroke();
      g.fillStyle = P.dk; rrp(g, -tl * .2, -tw * .95, tl * .55, tw * .42, .2); g.fill(); g.strokeStyle = '#1d2418'; g.lineWidth = .08; g.stroke(); g.fillStyle = '#16181a'; g.beginPath(); g.arc(tl * .15, -tw * .74, .35, 0, TAU); g.fill();
      g.fillStyle = P.dk; g.beginPath(); g.arc(-tl * .1, tw * .22, Wd * .08, 0, TAU); g.fill();
    } else {
      if (wide) { spBarrel(g, tl * .3, gunL * .86, 1.0, G, { ext: false }); g.save(); g.translate(0, -tw * .36); spBarrel(g, tl * .3, gunL * 1.05, .34, G); g.restore(); }
      else spBarrel(g, tl * .3, gunL, id === 'btr82' ? .34 : .36, G);
      g.beginPath(); g.ellipse(0, 0, tl * .6, tw / 2, 0, 0, TAU); g.fillStyle = P.base; g.fill(); spCamo(g, P, 55 + id.length, tl); g.beginPath(); g.ellipse(0, 0, tl * .6, tw / 2, 0, 0, TAU); g.strokeStyle = P.mk; g.lineWidth = .15; g.stroke();
      g.fillStyle = 'rgba(255,255,255,.13)'; g.beginPath(); g.ellipse(tl * .12, 0, tl * .3, tw * .3, 0, 0, TAU); g.fill();
      g.fillStyle = P.dk; g.beginPath(); g.arc(-tl * .1, tw * .18, Wd * .08, 0, TAU); g.fill(); g.strokeStyle = 'rgba(255,255,255,.28)'; g.lineWidth = .08; g.stroke();
      if (id === 'bmp2') { g.fillStyle = '#2a2d30'; g.fillRect(-tl * .35, tw * .06, tl * .75, .5); g.fillRect(tl * .38, tw * .02, .9, .9); }
    }
  }
  return { c, w: ext * 2, h: Wd + 2 };
}
function vehSprite(t, side) {
  const key = t.id + side; let s = SPC.veh[key]; if (s) return s;
  const hull = spHull(t, side), tu = spTurret(t, side), hw = (t.len + 3), hh = (t.wid + 3);
  const tx = { tank_leo2: -.02, tank_abrams: -.03, bmp3: -.02, btr82: .12, bradley: -.02, bmp2: .08 }[t.id] ?? .05, ty = { bradley: .1, bmp2: -.06 }[t.id] ?? 0;
  s = SPC.veh[key] = { hull, hullDead: spCopy(hull, 'source-atop', 'rgba(16,12,10,.8)'), hullSh: spCopy(hull, 'source-in', '#000'), tur: tu, turDead: spCopy(tu.c, 'source-atop', 'rgba(16,12,10,.82)'), turSh: spCopy(tu.c, 'source-in', '#000'), hw, hh, tx: t.len * tx, ty: t.wid * ty };
  return s;
}

/* ---------- боец ---------- */
function soldierKind(cm) {
  if (cm.job === 'sniper') return 'sniper';
  const ids = cm.ws.map(w => w.id); if (ids.some(i => ['rpg7', 'nlaw', 'javelin', 'kornet', 'm3'].includes(i))) return 'at';
  if (ids.some(i => ['pkm', 'nsv', 'm2', 'rpk74'].includes(i))) return 'mg'; if (ids.includes('gp25')) return 'gren';
  return cm.job === 'leader' ? 'lead' : 'rifle';
}
function soldierSprite(side, kind) {
  const key = side + kind; let c = SPC.sol[key]; if (c) return c;
  const P = 28, X = 2.9; c = document.createElement('canvas'); c.width = c.height = Math.ceil(X * 2 * P); const g = c.getContext('2d'); g.scale(P, P); g.translate(X, X);
  const U = side === 0 ? { u: '#5e6b44', u2: '#78865c', u3: '#3f4a2e', h: '#4d5a3a', pk: '#49543a' } : { u: '#566341', u2: '#6f7d55', u3: '#38432b', h: '#5b6744', pk: '#454f35' };
  const dark = '#1d2217', skin = '#c9a47e', gun = '#1f2226';
  g.lineJoin = g.lineCap = 'round';
  // рюкзак
  g.fillStyle = U.pk; rrp(g, -1.05, -.55, .85, 1.1, .28); g.fill(); g.strokeStyle = dark; g.lineWidth = .08; g.stroke();
  if (kind === 'at') { g.fillStyle = '#3a3f2f'; for (const s of [-1, 1]) { rrp(g, -1.4, s * .28 - .17, 1.3, .34, .17); g.fill(); } g.fillStyle = '#2b2f24'; for (const s of [-1, 1]) { g.beginPath(); g.arc(-1.4, s * .28, .2, 0, TAU); g.fill(); } }
  if (kind === 'lead') { g.strokeStyle = '#222'; g.lineWidth = .06; g.beginPath(); g.moveTo(-.9, .3); g.lineTo(-1.9, 1.4); g.stroke(); }
  if (kind === 'mg') { g.fillStyle = '#2d3326'; rrp(g, -.2, -1.15, .8, .5, .1); g.fill(); }
  // корпус
  g.fillStyle = U.u; g.beginPath(); g.ellipse(-.1, 0, .55, 1.0, 0, 0, TAU); g.fill(); g.strokeStyle = dark; g.lineWidth = .1; g.stroke();
  g.fillStyle = U.u2; g.globalAlpha = .7; g.beginPath(); g.ellipse(-.15, -.3, .24, .32, .4, 0, TAU); g.fill(); g.fillStyle = U.u3; g.beginPath(); g.ellipse(-.1, .38, .22, .3, -.3, 0, TAU); g.fill(); g.globalAlpha = 1;
  // руки и оружие
  const wep = () => {
    g.fillStyle = gun;
    if (kind === 'rifle' || kind === 'lead') { rrp(g, .15, -.11, 2.2, .22, .08); g.fill(); g.fillRect(.7, .1, .24, .5); }
    else if (kind === 'gren') { rrp(g, .15, -.11, 2.1, .22, .08); g.fill(); rrp(g, .7, .1, 1.1, .24, .1); g.fill(); }
    else if (kind === 'mg') { rrp(g, .1, -.13, 2.7, .26, .08); g.fill(); g.strokeStyle = gun; g.lineWidth = .07; g.beginPath(); g.moveTo(2.2, .1); g.lineTo(2.55, .55); g.moveTo(2.2, -.1); g.lineTo(2.55, -.55); g.stroke(); }
    else if (kind === 'sniper') { rrp(g, .0, -.09, 2.9, .18, .06); g.fill(); g.fillRect(.7, -.24, .8, .15); g.strokeStyle = gun; g.lineWidth = .06; g.beginPath(); g.moveTo(2.3, .08); g.lineTo(2.6, .5); g.moveTo(2.3, -.08); g.lineTo(2.6, -.5); g.stroke(); }
    else if (kind === 'at') { g.fillStyle = '#4d5841'; rrp(g, -.85, .12, 2.9, .44, .22); g.fill(); g.strokeStyle = dark; g.lineWidth = .07; g.stroke(); g.fillStyle = '#2c3126'; g.beginPath(); g.ellipse(2.15, .34, .4, .24, 0, 0, TAU); g.fill(); g.fillStyle = gun; rrp(g, .3, -.1, 1.2, .18, .06); g.fill(); }
  };
  g.strokeStyle = U.u; g.lineWidth = .42; g.beginPath(); g.moveTo(.0, -.82); g.lineTo(.95, kind === 'at' ? -.12 : -.22); g.moveTo(.0, .82); g.lineTo(.7, kind === 'at' ? .4 : .26); g.stroke();
  wep();
  g.fillStyle = skin; for (const [x, y] of [[.95, kind === 'at' ? -.12 : -.22], [.7, kind === 'at' ? .4 : .26]]) { g.beginPath(); g.arc(x, y, .17, 0, TAU); g.fill(); }
  // каска и нашивка стороны
  g.fillStyle = U.h; g.beginPath(); g.arc(.1, 0, .48, 0, TAU); g.fill(); g.strokeStyle = dark; g.lineWidth = .09; g.stroke();
  g.fillStyle = 'rgba(255,255,255,.2)'; g.beginPath(); g.arc(.02, -.12, .26, 0, TAU); g.fill();
  g.fillStyle = SIDES[side].color; g.beginPath(); g.arc(.12, 0, .17, 0, TAU); g.fill();
  return SPC.sol[key] = { c, X };
}
