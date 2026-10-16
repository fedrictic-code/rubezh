/* =====================  СИМУЛЯЦИЯ  ===================== */
const HOOK = { sfx() { }, log() { }, onOver() { } };
const LIMIT = 720;            // секунд боя
const HOLD_NEED = 40;         // секунд удержания обоих ключевых рубежей
const ATK_INC = 1.5, ATK_PTS = 1.5;
const BASE = [{ x: 2350, y: 740 }, { x: 50, y: 740 }];

const mkAb = () => ({ drone: { ch: 3, cd: 0 }, fpv: { ch: 5, cd: 0 }, smoke: { ch: 3, cd: 0 }, arty: { ch: 2, cd: 0 } });
const AB_CD = { drone: 18, fpv: 10, smoke: 12, arty: 40 };

function newBattle(player, diffKey, forces) {
  const N = (n, f) => Array.from({ length: n }, f);
  S = {
    t: 0, player, aiSide: 1 - player, atk: 1, def: 0, diffKey, diff: DIFFS[diffKey], squads: [], byId: new Map(), nextId: 1, cnt: [0, 0], smokes: [], pend: [], drones: [], fpv: [], wrecks: [], craterQ: [],
    objs: MAP.objs.map(o => ({ ...o, ctrl: o.id === 0 ? 0 : -1, owner: o.id === 0 ? -1 : 0, w: [0, 0], contested: false })),
    pts: [140, 160], inc: [0, 0], queue: [], ab: [mkAb(), mkAb()], stats: { lost: [0, 0], kills: [0, 0], veh: [0, 0] },
    over: null, speed: 1, sel: new Set(), fog: new Uint8Array(GW * GH), fogDirty: true, tickN: 0, holdT: 0, aiT: [3, 3], autoplay: false, lastSpotLog: -9,
    deploying: false, bodies: [], bodyI: 0, tr: N(256, () => ({ on: false, x0: 0, y0: 0, x1: 0, y1: 0, t0: 0, life: .12, side: 0 })), trI: 0,
    ex: N(90, () => ({ on: false, x: 0, y: 0, r: 0, t0: 0, life: 1, kind: 0 })), exI: 0
  };
  deploy(forces); perception(); fogUpdate();
  return S;
}

/* ---------- подбор сил и расстановка ---------- */
const BUDGET = [1000, 1400], MAX_UNITS = 26;
const PRESET = [
  ['ua_rifle', 'ua_rifle', 'ua_rifle', 'mg_pkm', 'at_javelin', 'at_nlaw', 'sniper_ua', 'mortar_82', 'bradley'],
  ['ru_rifle', 'ru_rifle', 'ru_rifle', 'ru_rifle', 'mg_pkm', 'at_kornet', 'at_rpg', 'bmp2', 'btr82', 'tank_t72b3', 'mortar_82', 'sniper_ru']
];
const ZONE = [{ x0: 1380, x1: 2360, y0: 60, y1: 1440 }, { x0: 50, x1: 560, y0: 60, y1: 1440 }];
const DEF_SLOTS = {
  sniper: [[1815, 470], [1930, 470], [1990, 520], [1870, 530]],
  mg: [[1512, 760], [1895, 590], [1600, 670], [1700, 640], [1830, 640]],
  at: [[1556, 748], [1660, 742], [1620, 820], [1790, 790]],
  inf: [[1512, 690], [1512, 832], [1950, 566], [1600, 750], [1700, 860], [1760, 700], [1700, 742], [1880, 700], [1990, 640], [1930, 520], [1620, 640], [1740, 800], [1840, 760], [1810, 580], [1570, 880], [1570, 610]],
  rear: [[1760, 850], [1700, 940], [1820, 880], [1900, 780], [2040, 742], [2000, 830], [2100, 700], [2100, 800], [2160, 900], [2160, 600]]
};
function autoForce(side, budget) {
  const mix = AI_MIX[side === 1 ? 0 : 1], all = variantsFor(side), out = []; let left = budget;
  while (out.length < MAX_UNITS) {
    const ok = all.filter(v => v.cost <= left); if (!ok.length) break;
    const wt = v => mix[v.cls] / all.filter(x => x.cls === v.cls).length; let tot = 0; for (const v of ok) tot += wt(v); let r = Math.random() * tot, pick = ok[0];
    for (const v of ok) { r -= wt(v); if (r <= 0) { pick = v; break; } }
    out.push(pick.id); left -= pick.cost;
  }
  return out;
}
function placeForce(side, list) {
  const atk = side === S.atk, used = { sniper: 0, mg: 0, at: 0, inf: 0, rear: 0, tank: 0, ifv: 0, mortar: 0, r: 0 };
  const order = list.slice().sort((a, b) => TYPE_ORDER.indexOf(VARS[a].cls) - TYPE_ORDER.indexOf(VARS[b].cls));
  const take = (key, arr) => { const k = used[key]++; if (k < arr.length) return arr[k]; const b = arr[k % arr.length]; return [b[0] + rand(-60, 60), b[1] + rand(-60, 60)]; };
  for (const vid of order) {
    const v = VARS[vid], c = v.cls; let x, y, fort = false;
    if (!atk) {
      if (c === 'sniper') [x, y] = take('sniper', DEF_SLOTS.sniper), fort = true;
      else if (c === 'mg') [x, y] = take('mg', DEF_SLOTS.mg), fort = true;
      else if (c === 'at') [x, y] = take('at', DEF_SLOTS.at), fort = true;
      else if (c === 'rifle') [x, y] = take('inf', DEF_SLOTS.inf), fort = true;
      else [x, y] = take('rear', DEF_SLOTS.rear);
    } else {
      const k = (used['a_' + c] = (used['a_' + c] || 0) + 1) - 1;
      if (c === 'tank') { x = 120; y = 620 + (k % 5) * 70; } else if (c === 'ifv') { x = 165; y = 600 + (k % 6) * 56; } else if (c === 'mortar') { x = 80; y = 700 + k * 40; }
      else if (c === 'sniper') { x = 330; y = 540 + k * 60; } else { x = 215 + (k % 3) * 30 + ((k / 3) | 0) % 2 * 14; y = 600 + ((k / 3) | 0) * 50 % 380 + (k % 3) * 8; }
    }
    const q = mkSquad(side, vid, x, y);
    if (fort) { q.order = { kind: 'hold' }; q.fort = 1; q.post = { x: q.x, y: q.y }; }
    q.role = atk ? (q.t.veh ? 'escort' : 'assault') : 'post';
  }
}
function deploy(forces) {
  for (const side of [0, 1]) placeForce(side, (forces && forces[side] && forces[side].length ? forces[side] : autoForce(side, BUDGET[side === S.atk ? 1 : 0])));
}

const alive = s => !s.dead;
function coverOf(sq) { const tc = T_COVER[ter[cellIdx(sq.x, sq.y)]]; if (sq.t.veh) return tc * .4; return Math.min(.92, tc + .3 * sq.fort * (1 - tc * .6)); }
function isSpotted(e, s) { return e.side === s || S.t - e.seenAt[s] < 1; }
function effOf(sq) { return sq.rout ? 0 : (sq.t.veh && sq.hp < 35 ? .8 : 1); }
const sideName = s => SIDES[s].short;

/* ---------- события ---------- */
function ev(text, kind, x, y, side) { if (side === undefined || side === S.player || S.autoplay) HOOK.log(text, kind, x, y); }
function vis4player(sq) { return sq.side === S.player || isSpotted(sq, S.player); }
function addTracer(x0, y0, x1, y1, side) { const t = S.tr[S.trI = (S.trI + 1) & 255]; t.on = true; t.x0 = x0; t.y0 = y0; t.x1 = x1; t.y1 = y1; t.t0 = S.t; t.life = .1 + Math.random() * .06; t.side = side; }
function boom(x, y, r, kind = 0) { const e = S.ex[S.exI = (S.exI + 1) % 90]; e.on = true; e.x = x; e.y = y; e.r = r; e.t0 = S.t; e.life = kind === 2 ? 1.6 : .7 + r / 60; e.kind = kind; HOOK.sfx('boom', x, y, Math.min(1, r / 34)); }

/* ---------- приказы ---------- */
function issue(sqs, kind, x, y, targetId) {
  const sneak = kind === 'sneak'; if (sneak) kind = 'move';
  const live = sqs.filter(s => !s.dead && (!s.rout || kind === 'retreat') && !s.carried); let i = 0, failed = 0; const n = live.length;
  for (const sq of live) {
    let tx = x, ty = y; if (n > 1 && (kind === 'move' || kind === 'fight')) { const a = i * 2.4, r = Math.sqrt(i) * 26; tx += Math.cos(a) * r; ty += Math.sin(a) * r; } i++;
    sq.orderT = S.t; sq.sneak = false;
    if (kind === 'mount') { if (sq.t.veh || sq.carried) continue; sq.order = { kind: 'mount', targetId, repath: 0 }; sq.path = null; continue; }
    if (kind === 'hold') { sq.order = { kind: 'hold' }; sq.path = null; continue; }
    if (kind === 'retreat') { const b = BASE[sq.side]; sq.path = findPath(sq.x, sq.y, b.x, b.y, sq.t.veh) || [b]; sq.pi = 0; sq.order = { kind: 'retreat' }; continue; }
    if (kind === 'fire') { if (!sq.t.mortar) continue; sq.order = { kind: 'fire', x, y, salvos: 4, deploy: 0, next: 0 }; sq.path = null; continue; }
    if (kind === 'attack') { sq.order = { kind: 'attack', targetId, repath: 0, lost: 0 }; continue; }
    const p = findPath(sq.x, sq.y, tx, ty, sq.t.veh); if (!p) { failed++; continue; }
    sq.path = p; sq.pi = 0; sq.order = { kind, x: tx, y: ty }; sq.fort = 0; sq.sneak = sneak && kind === 'move';
  }
  return failed;
}
function advance(sq, dt, mult) { // true — путь пройден
  if (!sq.path || sq.pi >= sq.path.length) return true;
  const wp = sq.path[sq.pi], dx = wp.x - sq.x, dy = wp.y - sq.y, d = Math.hypot(dx, dy);
  const m = (sq.t.veh ? T_MV_V : T_MV_I)[ter[cellIdx(sq.x, sq.y)]] || .3;
  const sp = sq.t.speed * m * mult * (sq.supp > 75 && !sq.t.veh ? 0 : 1) * (sq.t.veh ? (sq.mob && sq.crew.some(c => c.ok && c.job === 'driver') ? (sq.hp < 40 ? .7 : 1) : 0) : .5 + .5 * clamp(sq.men / sq.max + .3, 0, 1));
  if (sp <= 0) return false;
  const st = sp * (sq.sneak ? .45 : 1) * dt; sq.moving = true; sq.fort = 0;
  const a = Math.atan2(dy, dx); let da = a - sq.fa; while (da > Math.PI) da -= TAU; while (da < -Math.PI) da += TAU; sq.fa += da * Math.min(1, dt * (sq.t.veh ? 4 : 8));
  if (d <= st) { sq.x = wp.x; sq.y = wp.y; sq.pi++; return sq.pi >= sq.path.length; }
  sq.x += dx / d * st; sq.y += dy / d * st; return false;
}

/* ---------- обнаружение ---------- */
function viewerRange(v) { let r = v.t.vision; if (hgt[cellIdx(v.x, v.y)] > .55) r *= 1.2; if (v.rout) r *= .8; if (v.supp > 60) r *= .85; return r; }
function conceal(e) {
  let m = 1; const tt = ter[cellIdx(e.x, e.y)];
  if (tt === T.FOREST) m = .55; else if (tt === T.BUILD) m = .5; else if (tt === T.TRENCH) m = .65; else if (tt === T.RUBBLE) m = .85;
  if (e.fort >= .9) m *= .85; if (e.sneak && e.moving) m *= .6; if (e.stance === 'ambush' && S.t - e.lastFire > 3) m *= .55; if (S.t - e.lastFire < 3) m = Math.min(1.5, m * 1.5); if (e.moving) m *= 1.1; if (e.t.veh) m *= 1.25; if (e.t.stealth) m *= e.t.stealth; return m;
}
function perception() {
  const sq = S.squads, now = S.t;
  for (let s = 0; s < 2; s++) for (const e of sq) {
    if (e.dead || e.side === s || e.carried) continue; let sp = false;
    for (const v of sq) { if (v.dead || v.side !== s || v.carried) continue; const dx = e.x - v.x, dy = e.y - v.y, r = viewerRange(v) * conceal(e); if (dx * dx + dy * dy > r * r) continue; if (los(v.x, v.y, e.x, e.y)) { sp = true; break; } }
    if (!sp) for (const d of S.drones) { if (d.side !== s || d.state === 'out') continue; const r = d.vision * (e.t.stealth ? e.t.stealth + .15 : 1) * (conceal(e) < .6 ? .8 : 1); if (dist(d.x, d.y, e.x, e.y) < r) { sp = true; break; } }
    if (sp) {
      if (now - e.seenAt[s] > 4 && s === S.player && now - S.lastSpotLog > 2.5) { S.lastSpotLog = now; HOOK.log('Контакт: ' + NM(e) + ' (' + sideName(e.side) + ')', 'info', e.x, e.y); }
      e.seenAt[s] = now; e.lk[s] = { x: e.x, y: e.y };
    }
  }
}
function castVision(x, y, R, rays) {
  const f = S.fog, c0 = cellIdx(x, y); f[c0] = 2;
  for (let k = 0; k < rays; k++) {
    const a = k / rays * TAU, ca = Math.cos(a), sa = Math.sin(a); let sum = 0, last = c0;
    for (let d = 10; d <= R; d += 10) { const px = x + ca * d, py = y + sa * d; if (px < 0 || py < 0 || px >= W || py >= H) break; const c = cellIdx(px, py); if (c !== last) { last = c; f[c] = 2; const o = T_OPAC[ter[c]]; if (o) { sum += o; if (sum >= 1) break; } } }
  }
}
function fogUpdate() {
  const f = S.fog, ps = S.player; for (let i = 0; i < f.length; i++) if (f[i] === 2) f[i] = 1;
  for (const v of S.squads) if (!v.dead && !v.carried && v.side === ps) castVision(v.x, v.y, viewerRange(v), 140);
  for (const d of S.drones) if (d.side === ps && d.state !== 'out') forCircle(d.x, d.y, d.vision, c => { f[c] = 2; });
  S.fogDirty = true;
}

/* ---------- цели захвата, подкрепление ---------- */
function updateObjs(dt) {
  const base = 2 * 1, own = [0, 0];
  for (const o of S.objs) {
    o.w[0] = o.w[1] = 0;
    for (const sq of S.squads) { if (sq.dead || sq.rout || sq.carried) continue; if (dist(sq.x, sq.y, o.x, o.y) <= o.r) o.w[sq.side] += sq.t.veh ? 1.2 : sq.men / sq.max; }
    const wu = o.w[0], wr = o.w[1]; o.contested = wu > 0 && wr > 0;
    if (wu > 0 && wr === 0) o.ctrl = Math.max(-1, o.ctrl - dt / 12 * Math.min(1.6, wu));
    else if (wr > 0 && wu === 0) o.ctrl = Math.min(1, o.ctrl + dt / 12 * Math.min(1.6, wr));
    else if (o.contested) o.ctrl = clamp(o.ctrl + clamp((wr - wu) * dt / 18, -dt / 8, dt / 8), -1, 1);
    const prev = o.owner; o.owner = o.ctrl <= -.5 ? 0 : o.ctrl >= .5 ? 1 : -1;
    if (prev !== o.owner && o.owner !== -1) ev(o.name + ' — под контролем: ' + SIDES[o.owner].name, o.owner === S.player ? 'good' : 'bad', o.x, o.y);
    else if (prev !== o.owner && prev !== -1) ev(o.name + ' потерян стороной ' + sideName(prev) + ', рубеж оспаривается', prev === S.player ? 'bad' : 'info', o.x, o.y);
    if (o.owner >= 0) own[o.owner]++;
  }
  for (let s = 0; s < 2; s++) { S.inc[s] = (base + own[s] * 1.4) * (s === S.atk ? ATK_INC : 1) * ((s === S.aiSide && !S.autoplay) ? S.diff.inc : 1); S.pts[s] += S.inc[s] * dt; }
  const keys = S.objs.filter(o => o.key);
  if (keys.every(o => o.owner === S.atk)) S.holdT += dt; else S.holdT = Math.max(0, S.holdT - dt * 2);
}
function buyUnit(side, type) {
  const t = VARS[type]; if (!t || S.pts[side] < t.cost) return false;
  S.pts[side] -= t.cost; S.queue.push({ side, type, at: S.t + t.delay, t0: S.t }); return true;
}
function processQueue() {
  for (let i = S.queue.length - 1; i >= 0; i--) {
    const q = S.queue[i]; if (S.t < q.at) continue; S.queue.splice(i, 1);
    const sq = mkSquad(q.side, q.type, BASE[q.side].x + (q.side ? 0 : 0), BASE[q.side].y + rand(-170, 170));
    sq.role = q.side === S.atk ? (sq.t.veh ? 'escort' : 'assault') : 'counter';
    ev('Подкрепление: ' + sq.name + ' (' + NM(sq) + ')', 'good', sq.x, sq.y, q.side);
  }
}

/* ---------- способности ---------- */
function canUse(side, k) { const a = S.ab[side][k]; return a.ch > 0 && a.cd <= 0; }
function nearestFriendly(side, x, y, maxD) { let b = null, bd = maxD; for (const s of S.squads) { if (s.dead || s.side !== side) continue; const d = dist(s.x, s.y, x, y); if (d < bd) { bd = d; b = s; } } return b; }
function useDrone(side, x, y) {
  if (!canUse(side, 'drone')) return 'Дрон ещё не готов'; const a = S.ab[side].drone; a.ch--; a.cd = AB_CD.drone;
  const sx = BASE[side].x, sy = clamp(y, 200, 1300); S.drones.push({ side, x: sx, y: sy, tx: x, ty: y, state: 'in', t: 0, vision: 430, life: 26 }); return null;
}
function useFpv(side, targetId) {
  if (!canUse(side, 'fpv')) return 'FPV ещё не готов'; const tg = S.byId.get(targetId); if (!tg || tg.dead || !isSpotted(tg, side)) return 'Цель не наблюдается';
  const op = nearestFriendly(side, tg.x, tg.y, 1000); if (!op) return 'Нет оператора в радиусе 1000 м';
  const a = S.ab[side].fpv; a.ch--; a.cd = AB_CD.fpv; S.fpv.push({ side, x: op.x, y: op.y, tid: targetId, t: 0, jam: Math.random() < .18, from: op.id }); return null;
}
function useSmoke(side, x, y) {
  if (!canUse(side, 'smoke')) return 'Дымы ещё не готовы'; if (!nearestFriendly(side, x, y, 900)) return 'Слишком далеко от своих';
  const a = S.ab[side].smoke; a.ch--; a.cd = AB_CD.smoke; S.smokes.push({ x, y, r: 1, R: 58, t0: S.t, t1: S.t + 24 }); HOOK.sfx('boom', x, y, .4); return null;
}
function updateAir(dt) {
  for (let i = S.drones.length - 1; i >= 0; i--) {
    const d = S.drones[i]; d.t += dt;
    if (d.state === 'in') { const dx = d.tx - d.x, dy = d.ty - d.y, L = Math.hypot(dx, dy), st = 70 * dt; if (L <= st) { d.state = 'loiter'; d.t = 0; } else { d.x += dx / L * st; d.y += dy / L * st; } }
    else if (d.state === 'loiter') { d.x += Math.cos(d.t * .8) * .6; d.y += Math.sin(d.t * .8) * .6; if (d.t > d.life) d.state = 'out'; }
    else { const b = BASE[d.side], dx = b.x - d.x, dy = b.y - d.y, L = Math.hypot(dx, dy), st = 80 * dt; if (L <= st) { S.drones.splice(i, 1); continue; } d.x += dx / L * st; d.y += dy / L * st; }
    for (const e of S.squads) { if (e.dead || e.carried || e.side === d.side || !(e.type === 'mg' || e.type === 'ifv' || e.type === 'rifle')) continue; if (dist(e.x, e.y, d.x, d.y) < 320 && Math.random() < dt * (e.type === 'ifv' ? .05 : e.type === 'mg' ? .04 : .012) * (e.supp > 50 ? .3 : 1)) { boom(d.x, d.y, 12, 1); ev('БПЛА сбит', d.side === S.player ? 'warn' : 'good', d.x, d.y); S.drones.splice(i, 1); break; } }
  }
  for (let i = S.fpv.length - 1; i >= 0; i--) {
    const f = S.fpv[i], tg = S.byId.get(f.tid); f.t += dt;
    if (!tg || tg.dead) { S.fpv.splice(i, 1); boom(f.x, f.y, 8, 1); continue; }
    const dx = tg.x - f.x, dy = tg.y - f.y, L = Math.hypot(dx, dy), st = 95 * dt;
    if (f.jam && f.t > 1.2 + Math.random() * .1) { S.fpv.splice(i, 1); boom(f.x, f.y, 8, 1); ev('FPV подавлен средствами РЭБ', f.side === S.player ? 'warn' : 'good', f.x, f.y); continue; }
    if (L <= Math.max(st, 8)) {
      S.fpv.splice(i, 1); boom(tg.x, tg.y, 26, 0); const src = S.byId.get(f.from) || { side: f.side };
      if (tg.t.veh) resolveHitVeh(tg, AMMO.fpv, f.x, f.y, src, 0); else { blastAt(tg.x, tg.y, AMMO.fpv.rad, AMMO.fpv.kill, src, tg); tg.supp = Math.min(100, tg.supp + 60); }
      tg.lastShot = S.t; continue;
    }
    f.x += dx / L * st; f.y += dy / L * st;
  }
  for (let i = S.smokes.length - 1; i >= 0; i--) { const s = S.smokes[i]; if (S.t > s.t1 + 2) { S.smokes.splice(i, 1); continue; } s.r = S.t > s.t1 ? s.R * (1 - (S.t - s.t1) / 2) : s.R * Math.min(1, (S.t - s.t0) / 2.5); }
  for (let s = 0; s < 2; s++) for (const k of ['drone', 'fpv', 'smoke', 'arty']) { const a = S.ab[s][k]; if (a.cd > 0) a.cd -= dt; }
}

/* ---------- шаг по отрядам ---------- */
function stepSquad(sq, dt) {
  const t = sq.t, now = S.t; sq.moving = false;
  if (sq.carried) { const v = S.byId.get(sq.carried); if (v && !v.dead) { sq.x = v.x; sq.y = v.y; sq.fa = v.fa; sq.tg = null; return; } sq.carried = 0; }
  if (!sq.order || sq.order.kind !== 'move') sq.sneak = false;
  // подавление, мораль
  if (now - sq.lastShot > 1.2) sq.supp = Math.max(0, sq.supp - 7 * dt);
  if (sq.supp > 65) sq.morale -= 1.2 * dt;
  else if (now - sq.lastHit > 4 && sq.supp < 25) sq.morale = Math.min(100, sq.morale + (.5 + coverOf(sq) * .5) * dt);
  if (!sq.rout && sq.morale < 22) { sq.rout = true; sq.order = { kind: 'retreat' }; sq.path = null; ev(sq.name + ' отступает: потеряна стойкость', sq.side === S.player ? 'warn' : 'good', sq.x, sq.y, sq.side === S.player ? undefined : (vis4player(sq) ? S.player : -1)); }
  if (sq.rout) { sq.morale = Math.min(100, sq.morale + 1.1 * dt); if (sq.morale > 48 && now - sq.lastHit > 6) { sq.rout = false; sq.order = null; sq.path = null; ev(sq.name + ' снова в строю', 'info', sq.x, sq.y, sq.side); } }
  // ресурсы
  if (sq.fireT) vehicleFire(sq);
  // приказ
  const o = sq.order;
  if (sq.rout) { if (!sq.path || sq.pi >= sq.path.length) { const b = BASE[sq.side]; sq.path = findPath(sq.x, sq.y, b.x, b.y, t.veh) || [b]; sq.pi = 0; } advance(sq, dt, 1.2); }
  else if (o) {
    switch (o.kind) {
      case 'move': if (advance(sq, dt, 1)) sq.order = null; break;
      case 'fight': { const tg = sq.tg; if (tg && !tg.dead && dist(sq.x, sq.y, tg.x, tg.y) <= (t.shot && tg.t.veh ? t.shot.range : t.range) * .98) sq.fa += angDiff(sq.fa, Math.atan2(tg.y - sq.y, tg.x - sq.x)) * Math.min(1, dt * 8); else if (advance(sq, dt, 1)) sq.order = null; break; }
      case 'attack': {
        const e = S.byId.get(o.targetId); if (!e || e.dead) { sq.order = null; break; }
        if (!isSpotted(e, sq.side)) { o.lost += dt; if (o.lost > 6) { sq.order = null; break; } } else o.lost = 0;
        const d = dist(sq.x, sq.y, e.x, e.y), reach = (t.shot && e.t.veh ? t.shot.range : t.range) * .85;
        if (d > reach || !los(sq.x, sq.y, e.x, e.y)) { o.repath -= dt; if (o.repath <= 0 || !sq.path) { const lk = e.lk[sq.side] || e; sq.path = findPath(sq.x, sq.y, lk.x, lk.y, t.veh); sq.pi = 0; o.repath = 2; } if (sq.path) advance(sq, dt, 1); } else sq.fa += angDiff(sq.fa, Math.atan2(e.y - sq.y, e.x - sq.x)) * Math.min(1, dt * 8);
        break;
      }
      case 'retreat': if (!sq.path) { const b = BASE[sq.side]; sq.path = findPath(sq.x, sq.y, b.x, b.y, t.veh) || [b]; sq.pi = 0; } if (advance(sq, dt, 1.15)) sq.order = null; break;
      case 'fire': mortarStep(sq, dt); break;
      case 'mount': { const v = S.byId.get(o.targetId); if (!v || v.dead || v.cargo || !v.t.cap || v.t.cap < sq.men || v.side !== sq.side) { sq.order = null; break; } o.repath -= dt; if (o.repath <= 0 || !sq.path) { sq.path = findPath(sq.x, sq.y, v.x, v.y, false); sq.pi = 0; o.repath = 1.5; } if (dist(sq.x, sq.y, v.x, v.y) < 26) { boardVeh(sq, v); break; } if (sq.path) advance(sq, dt, 1); break; }
    }
  }
  // окапывание
  if (!sq.moving && !t.veh && (!o || o.kind === 'hold' || o.kind === 'fire' || o.kind === 'fight')) sq.fort = Math.min(1, sq.fort + dt / (o && o.kind === 'hold' ? 6 : 14));
  // цель и огонь
  if ((S.tickN + sq.id) % 6 === 0 && !sq.rout) acquire(sq);
  const tg = sq.tg;
  if (tg && !sq.rout) {
    if (tg.dead || !isSpotted(tg, sq.side)) sq.tg = null;
    else {
      const d = dist(sq.x, sq.y, tg.x, tg.y);
      if (d > t.range * 1.05) sq.tg = null;
      else {
        if (!sq.moving) sq.fa += angDiff(sq.fa, Math.atan2(tg.y - sq.y, tg.x - sq.x)) * Math.min(1, dt * 8); sq.ta = Math.atan2(tg.y - sq.y, tg.x - sq.x);
        fireControl(sq, tg, d, dt);
      }
    }
  }
  if (t.veh && !sq.tg && !sq.moving) sq.ta += angDiff(sq.ta, sq.fa) * Math.min(1, dt * 3);
}
function angDiff(a, b) { let d = b - a; while (d > Math.PI) d -= TAU; while (d < -Math.PI) d += TAU; return d; }

function separate() {
  const sq = S.squads, n = sq.length;
  for (let i = 0; i < n; i++) { const a = sq[i]; if (a.dead || !a.moving || a.carried) continue; for (let j = 0; j < n; j++) { if (i === j) continue; const b = sq[j]; if (b.dead || b.side !== a.side || b.carried) continue; const dx = a.x - b.x, dy = a.y - b.y; if (dx > 18 || dx < -18 || dy > 18 || dy < -18) continue; const d = Math.hypot(dx, dy) || .01; if (d < 16) { const p = (16 - d) * .25, nx = a.x + dx / d * p, ny = a.y + dy / d * p; if ((a.t.veh ? T_MV_V : T_MV_I)[ter[cellIdx(nx, ny)]] > 0) { a.x = nx; a.y = ny; } } } }
}

/* ---------- главный шаг ---------- */
function step() {
  if (S.over) return; const dt = TICK; S.t += dt; S.tickN++;
  if (S.tickN % 4 === 0) perception();
  if (S.tickN % 6 === 0) fogUpdate();
  if (S.tickN % 30 === 15) aiTick();
  for (const sq of S.squads) if (!sq.dead) stepSquad(sq, dt);
  separate(); processPending(); updateAir(dt); processQueue(); updateObjs(dt);
  if (S.tickN % 20 === 0) { S.squads = S.squads.filter(s => { if (s.dead) { S.byId.delete(s.id); return false; } return true; }); checkEnd(); }
  for (const w of S.wrecks) if (S.t - w.t > 300) w.old = true;
}
function checkEnd() {
  const atk = S.atk, def = S.def;
  const cnt = [0, 0]; for (const s of S.squads) if (!s.dead) cnt[s.side]++;
  const cheapest = 60;
  let win = null, why = '';
  if (S.holdT >= HOLD_NEED) { win = atk; why = 'Оба рубежа удержаны ' + HOLD_NEED + ' секунд'; }
  else if (S.t >= LIMIT) { win = def; why = 'Время боя истекло, рубежи удержаны'; }
  else for (const s of [atk, def]) { if (cnt[s] === 0 && !S.queue.some(q => q.side === s) && S.pts[s] < cheapest) { win = 1 - s; why = 'У противника не осталось сил'; } }
  if (win !== null) { S.over = { winner: win, why }; HOOK.onOver(S.over); }
}
