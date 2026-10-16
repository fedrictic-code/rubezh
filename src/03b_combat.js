/* =====================  БОЕВАЯ МОДЕЛЬ: бойцы, оружие, броня  =====================
   Каждый боец и член экипажа — отдельный объект со своим оружием и боезапасом.
   Выстрелы считаются по реальному оружию; пробитие брони зависит от типа снаряда,
   дальности, стороны и угла попадания. Техника может потерять экипаж, ход, орудие,
   загореться или взорваться вместе с боекомплектом. */
const QPI = Math.PI / 4, HPI = Math.PI / 2;
const SUPP_K = 9;           // перевод подавления от пуль в шкалу 0–100

/* ---------- создание отряда ---------- */
function mkWI(id, a) {
  const w = WPN[id], am = {}; for (const k of w.a) if (a[k] > 0) am[k] = a[k];
  const init = {}; for (const k in am) init[k] = am[k];
  return { id, w, am, init, cur: null, mag: 0, next: S.t + rand(0, 1.2), burst: 0 };
}
function mkSquad(side, vid, x, y) {
  const t = VARS[vid], c = S.cnt[side]++, calls = SIDES[side].calls, crew = [];
  for (const md of t.men) {
    const a = Math.random() * TAU, r = t.veh ? 0 : 3 + Math.random() * 11;
    crew.push({ job: md.job, ws: md.w.map(id => mkWI(id, md.a)), ok: true, dx: Math.cos(a) * r, dy: Math.sin(a) * r, spare: md.a });
  }
  // запасные патроны, которые несёт расчёт, добавляем к оружию, которому они подходят
  for (const man of crew) for (const k in man.spare) {
    if (man.ws.some(wi => wi.w.a.includes(k))) continue;
    const to = crew.flatMap(m2 => m2.ws).find(wi => wi.w.a.includes(k)); if (to) { to.am[k] = (to.am[k] || 0) + man.spare[k]; to.init[k] = (to.init[k] || 0) + man.spare[k]; }
  }
  const sq = {
    id: S.nextId++, side, type: t.cls, vid, t, x, y, fa: side === 1 ? 0 : Math.PI, ta: 0, crew, men: crew.length, max: crew.length,
    hp: t.veh ? 100 : 0, hpMax: t.veh ? 100 : 0, mob: 1, gunOut: false, fireT: 0, morale: t.morale, supp: 0, ammo: 100, order: null, path: null, pi: 0,
    tg: null, role: '', post: null, fort: 0, moving: false, rout: false, lastFire: -99, lastHit: -99, lastShot: -99, fxT: 0,
    seenAt: [-99, -99], lk: [null, null], dead: false, smoking: false, name: calls[c % calls.length] + '-' + (1 + Math.floor(c / calls.length)),
    offs: crew.map(m2 => [m2.dx, m2.dy]), cooldown: 0, hurtLog: false, born: S.t, orderT: 0, reload: 0
  };
  const cell = cellIdx(x, y), mv = t.veh ? T_MV_V : T_MV_I;
  if (mv[ter[cell]] === 0) { const n = nearestPassable(cell, mv); sq.x = (n % GW + .5) * CELL; sq.y = ((n / GW | 0) + .5) * CELL; }
  S.squads.push(sq); S.byId.set(sq.id, sq); return sq;
}
const NM = sq => sq.t.name;
function ammoPct(sq) {
  let s = 0, n = 0;
  for (const man of sq.crew) for (const wi of man.ws) { if (wi.w.k === 'mg' && wi.w.coax) continue; let c = 0, i = 0; for (const k in wi.init) { c += wi.am[k] || 0; i += wi.init[k]; } if (i > 0) { s += c / i; n++; } }
  return n ? s / n * 100 : 100;
}

/* ---------- потери ---------- */
function addBody(sq, man) { const b = S.bodies[S.bodyI = (S.bodyI + 1) % 420] = { x: sq.x + man.dx, y: sq.y + man.dy, side: sq.side, t: S.t, veh: false }; return b; }
function inherit(sq, man) { // оружие расчёта переходит к живому бойцу
  for (const wi of man.ws) {
    if (!['mg', 'hmg', 'rocket', 'atgm'].includes(wi.w.k)) continue; let n = 0; for (const k in wi.am) n += wi.am[k]; if (n <= 0) continue;
    const to = sq.crew.find(m2 => m2.ok && !m2.ws.some(x => x.w.k === wi.w.k)); if (to) { to.ws.push(wi); wi.next = S.t + 3; }
  }
}
function outMan(sq, man, src) {
  if (!man.ok || sq.dead) return; man.ok = false; sq.men--; sq.morale -= sq.t.veh ? 3 : 7; sq.lastHit = S.t; S.stats.lost[sq.side]++; if (src) S.stats.kills[src.side]++;
  if (!sq.t.veh) { addBody(sq, man); inherit(sq, man); }
  if (!sq.hurtLog && sq.men <= sq.max / 2 && sq.men > 0) { sq.hurtLog = true; ev(sq.name + ' понесло потери', sq.side === S.player ? 'warn' : 'info', sq.x, sq.y, sq.side === S.player ? undefined : (vis4player(sq) ? S.player : -1)); }
  if (sq.t.veh) updateVehHp(sq);
  if (sq.men <= 0) destroySquad(sq, src, sq.t.veh ? 'crew' : '');
}
function casualty(sq, src) {
  if (sq.dead || sq.men <= 0) return; let k = (Math.random() * sq.men) | 0;
  for (const man of sq.crew) if (man.ok) { if (k-- === 0) { outMan(sq, man, src); return; } }
}
const killMan = casualty;
function updateVehHp(sq) {
  const crew = sq.men / sq.max; sq.hp = Math.max(1, 100 * (.45 * crew + .3 * (sq.mob ? 1 : 0) + .25 * (sq.gunOut ? 0 : 1)));
  if (sq.fireT) sq.hp = Math.min(sq.hp, 28);
}
function destroySquad(sq, src, why) {
  if (sq.dead) return; sq.dead = true; S.sel.delete(sq.id);
  if (sq.cargo) { const inf = S.byId.get(sq.cargo); if (inf && !inf.dead) { inf.carried = 0; sq.cargo = 0; inf.x = sq.x; inf.y = sq.y; inf.supp = 70; inf.morale -= 14; const p = why === 'ammo' ? .85 : why === 'fire' ? 0 : .35; for (const man of inf.crew) if (man.ok && Math.random() < p) outMan(inf, man, src); } }
  if (sq.t.veh) { S.stats.veh[sq.side]++; if (src) S.stats.kills[src.side] += 0; S.wrecks.push({ x: sq.x, y: sq.y, fa: sq.fa, type: sq.type, side: sq.side, t: S.t, vt: sq.t }); boom(sq.x, sq.y, 38, 2); }
  sq.men = 0;
  const mine = sq.side === S.player, why2 = why === 'ammo' ? ' · детонация боекомплекта' : why === 'fire' ? ' · пожар' : '';
  if (mine) ev('Потеряно: ' + sq.name + ' (' + NM(sq) + ')' + why2, 'bad', sq.x, sq.y);
  else if (vis4player(sq) || S.autoplay) ev('Уничтожено: ' + NM(sq) + ' ' + sideName(sq.side) + why2, 'good', sq.x, sq.y);
}

/* ---------- броня и пробитие ---------- */
function penAt(a, d) { return a.k === 'HEAT' || a.k === 'ATGM' ? a.pen[0] : lerp(a.pen[0], a.pen[1], Math.min(1, d / 1000)); }
function armourFace(tg, ax, ay, a) {
  const arm = tg.t.arm, ce = a.k === 'HEAT' || a.k === 'ATGM';
  if (a.top) return { face: 't', th: arm.t[ce ? 1 : 0] };
  const rel = Math.abs(angDiff(tg.fa, Math.atan2(ay - tg.y, ax - tg.x)));
  let face, theta; if (rel < QPI * 1.1) { face = 'f'; theta = rel; } else if (rel > QPI * 2.9) { face = 'r'; theta = Math.PI - rel; } else { face = 's'; theta = Math.abs(rel - HPI); }
  return { face, th: arm[face][ce ? 1 : 0] / Math.pow(Math.cos(Math.min(theta, 1.1)), ce ? .6 : 1) };
}
function bestAmmo(wi, tg, sx, sy, d) { // какой боеприпас выбрать против цели
  let best = null, bs = -1e9, w = wi.w;
  for (const k in wi.am) {
    if (wi.am[k] <= 0) continue; const a = AMMO[k]; if (a.k === 'SMK') continue; let sc;
    if (tg.t.veh) {
      const af = armourFace(tg, sx, sy, a), pen = penAt(a, d);
      if (a.k === 'SA') { if (pen < af.th * .6) continue; sc = pen / af.th; }
      else if (a.k === 'HE') { if (w.k === 'ugl') continue; if (pen < af.th * .5) continue; sc = pen / af.th * .8; }
      else sc = 1 + pen / af.th;
    } else {
      if (a.k === 'HEAT' || a.k === 'ATGM') { if (w.k === 'rocket' || w.k === 'atgm') continue; sc = .2; }
      else if (a.k === 'HE') sc = 3; else if (a.k === 'AP') sc = .6; else sc = 1;
    }
    if (sc > bs) { bs = sc; best = k; }
  }
  return best;
}
function resolveHitVeh(tg, a, ax, ay, src, d, zoneHint) {
  if (tg.dead || !tg.t.arm) return; const af = armourFace(tg, ax, ay, a), pen = penAt(a, d) * rand(.93, 1.07), big = a.k !== 'SA' && (a.cal >= 57 || a.k === 'HEAT' || a.k === 'ATGM');
  tg.lastShot = S.t; tg.lastHit = S.t;
  const turret = zoneHint !== undefined ? zoneHint : (tg.t.cls === 'tank' || tg.t.cls === 'ifv') && Math.random() < .42;
  if (pen >= af.th) { penetrate(tg, a, turret, pen / af.th, big, src); return; }
  tg.supp = Math.min(100, tg.supp + (big ? 14 : 3));
  if (big && a.k !== 'HE' && Math.random() < (af.face === 's' ? .1 : .04) && tg.mob) { tg.mob = 0; updateVehHp(tg); ev(NM(tg) + ' потерял ход', tg.side === S.player ? 'warn' : 'good', tg.x, tg.y, tg.side === S.player ? undefined : (vis4player(tg) ? S.player : -1)); }
}
function penetrate(tg, a, turret, margin, big, src) {
  let pk = a.k === 'SA' ? .06 : big ? (a.k === 'HE' ? .22 : .42) : .13; if (margin > 1.6) pk += .15;
  const jobs = turret ? ['commander', 'gunner', 'loader'] : ['driver', 'loader'];
  for (const man of tg.crew) if (man.ok && (jobs.includes(man.job) || (big && Math.random() < .2)) && Math.random() < pk) outMan(tg, man, src);
  if (tg.dead) return;
  if (big) {
    const vis = tg.side === S.player ? undefined : (vis4player(tg) ? S.player : -1);
    if (Math.random() < tg.t.vuln * (turret ? 1 : .65) * (a.k === 'HE' ? .3 : 1)) { destroySquad(tg, src, 'ammo'); boom(tg.x, tg.y, 60, 2); return; }
    if (!tg.fireT && Math.random() < .28) { tg.fireT = S.t + .001; tg.smoking = true; ev(NM(tg) + ' горит', tg.side === S.player ? 'warn' : 'good', tg.x, tg.y, vis); }
    if (!turret && tg.mob && Math.random() < .35) { tg.mob = 0; ev(NM(tg) + ' потерял ход', tg.side === S.player ? 'warn' : 'good', tg.x, tg.y, vis); }
    if (turret && !tg.gunOut && Math.random() < .3) { tg.gunOut = true; ev(NM(tg) + ': орудие выведено из строя', tg.side === S.player ? 'warn' : 'good', tg.x, tg.y, vis); }
  }
  updateVehHp(tg);
}

/* ---------- взрывы ---------- */
function blastAt(x, y, rad, kill, src, onlySq) {
  for (const sq of S.squads) {
    if (sq.dead || sq.carried || (onlySq && sq !== onlySq)) continue; const dd = dist(sq.x, sq.y, x, y); if (dd > rad + 24) continue;
    if (sq.t.veh) continue;
    const cov = coverOf(sq) * .55;
    for (const man of sq.crew) { if (!man.ok) continue; const r = Math.hypot(sq.x + man.dx - x, sq.y + man.dy - y); if (r >= rad) continue; const p = kill * Math.pow(1 - r / rad, 1.2) * (1 - cov); if (Math.random() < p) outMan(sq, man, src); if (sq.dead) break; }
  }
}
function suppressArea(x, y, R, amt, vehFactor = .3) {
  for (const sq of S.squads) { if (sq.dead || sq.carried) continue; const d = dist(sq.x, sq.y, x, y); if (d > R) continue; sq.supp = Math.min(100, sq.supp + amt * (1 - d / R) * (sq.t.veh ? vehFactor : 1)); sq.morale -= 2.5 * (1 - d / R) * (sq.t.veh ? .3 : 1); sq.lastShot = S.t; sq.lastHit = Math.max(sq.lastHit, S.t - 2); }
}
function shellLand(x, y, src, ammoId = 'he82') {
  const a = AMMO[ammoId]; boom(x, y, 34, 0); S.craterQ.push([x, y, rand(6, 10)]);
  blastAt(x, y, a.rad, a.kill, src);
  for (const sq of S.squads) if (!sq.dead && sq.t.veh && dist(sq.x, sq.y, x, y) < 9 + sq.t.len * .3) resolveHitVeh(sq, { ...a, top: true }, x, y, src, 0, false);
  suppressArea(x, y, a.rad * 2.6, a.supp * 2.2);
}

/* ---------- прицеливание ---------- */
function acquire(sq) {
  const t = sq.t; if (t.mortar) { sq.tg = null; return; }
  const o = sq.order;
  if (o && o.kind === 'attack') { const e = S.byId.get(o.targetId); if (e && !e.dead && isSpotted(e, sq.side) && dist(sq.x, sq.y, e.x, e.y) <= t.range && los(sq.x, sq.y, e.x, e.y)) { sq.tg = e; return; } }
  let best = null, bs = -1e9;
  for (const e of S.squads) {
    if (e.dead || e.carried || e.side === sq.side || !isSpotted(e, sq.side)) continue;
    const d = dist(sq.x, sq.y, e.x, e.y); if (d > t.range) continue;
    let sc = -d;
    if (e.t.veh) { if (t.shot && d <= t.shot.range && t.atPen >= minArm(e)) sc += 450; else if (d <= t.sr && t.saPen >= minArm(e) * .6) sc += 0; else continue; }
    else { if (t.cls === 'at' && d > t.sr) continue; if (d > Math.max(t.sr, t.cls === 'at' ? 0 : 0)) continue; if (e.type === 'at' || e.type === 'mg') sc += 90; if (e.t.mortar) sc += 40; }
    if (sc <= bs) continue; if (!los(sq.x, sq.y, e.x, e.y)) continue; best = e; bs = sc;
  }
  sq.tg = best;
}
const minArm = e => Math.min(e.t.arm.s[0], e.t.arm.r[0]);

/* ---------- стрельба ---------- */
function operatorFactor(sq, man, wi) {
  if (sq.t.veh) {
    if (wi.w.job === 'gunner' || wi.w.coax) { if (sq.gunOut && wi.w.job !== 'commander') return 0; }
    if (man.ok) return 1;
    if (man.job === 'gunner' && sq.crew.some(m2 => m2.ok && m2.job === 'commander')) return .5;
    return 0;
  }
  return man.ok ? 1 : 0;
}
function fireControl(sq, tg, d, dt) {
  const eff = effOf(sq), t = sq.t, veh = t.veh, now = S.t;
  if (eff <= 0 || sq.stance === 'cease') return;
  if (sq.stance === 'ambush') { if (d > 110 && now - sq.lastHit > 3) return; sq.stance = 'free'; ev(sq.name + ': засада сработала', sq.side === S.player ? 'info' : 'warn', sq.x, sq.y, sq.side === S.player ? undefined : (vis4player(sq) ? S.player : -1)); }
  if (sq.sneak && sq.moving && d > 90) return;
  const noLoader = veh && t.cls === 'tank' && t.men.length > 3 ? !sq.crew.some(m2 => m2.ok && m2.job === 'loader') : false;
  let fired = false;
  for (const man of sq.crew) {
    for (const wi of man.ws) {
      const w = wi.w; if (w.k === 'mortar') continue; if (d > w.rng || (w.minR && d < w.minR)) continue;
      if (veh && w.coax && tg.t.veh && !(tg.t.arm.s[0] < 14)) continue;                 // пулемёт в спарке по броне не работает
      const op = operatorFactor(sq, man, wi); if (op <= 0) continue;
      if (now < wi.next) continue;
      if (sq.moving && ['rocket', 'atgm', 'sniper', 'ugl'].includes(w.k)) continue;
      if (sq.moving && w.setup) { wi.next = now + w.setup; continue; }
      if (sq.moving && w.k === 'cannon' && t.cls !== 'tank') continue;
      const ak = bestAmmo(wi, tg, sq.x, sq.y, d); if (!ak) continue;
      fireWeapon(sq, man, wi, ak, tg, d, eff * op, noLoader); fired = true;
    }
  }
  if (fired) sq.lastFire = now;
}
function fireWeapon(sq, man, wi, ak, tg, d, eff, noLoader) {
  const w = wi.w, a = AMMO[ak], now = S.t, t = sq.t, tv = tg.t.veh;
  const sx = sq.x + man.dx, sy = sq.y + man.dy;
  const rangeF = 1 - Math.pow(Math.min(1, d / w.rng), 1.4) * .6, diff = (sq.side === S.aiSide || S.autoplay) ? S.diff.acc : 1;
  const suppF = 1 - sq.supp / 100 * (t.veh ? .3 : .7), mvF = sq.moving ? (t.moveFire * (w.k === 'mg' || w.k === 'hmg' ? .5 : 1)) : 1;
  const cov = tv ? coverOf(tg) : coverOf(tg) * (1 - (a.k === 'AP' && w.k === 'sniper' ? .55 : 0));
  const covF = 1 - cov * .65, shotRate = w.rpm / 60;
  const base = w.acc * rangeF * suppF * mvF * diff * (w.k === 'atgm' ? 1 : covF) * (tg.moving && ['rocket', 'cannon'].includes(w.k) ? .8 : 1);
  if (w.k === 'cannon' || w.k === 'rocket' || w.k === 'atgm' || w.k === 'ugl') {
    // одиночный выстрел с временем полёта
    const interval = (w.rl * (noLoader && w.loader ? 1.8 : 1)) / Math.max(.4, eff), fl = .25 + d / (a.spd || 400);
    wi.am[ak]--; wi.next = now + interval;
    S.pend.push({ kind: 'shot', at: now + fl, from: sq.id, to: tg.id, am: ak, hit: Math.random() < base, ax: sx, ay: sy, x1: tg.x, y1: tg.y, t0: now, d });
    sq.ammo = ammoPct(sq); HOOK.sfx('shot', sx, sy, 1.25); if (w.k !== 'ugl') boom(sx + Math.cos(sq.fa) * 10, sy + Math.sin(sq.fa) * 10, 6, 1);
    return;
  }
  // очередь или одиночные выстрелы: считаем пачками за ~0,3 с
  let n = a.burst ? 4 : (w.k === 'mg' || w.k === 'hmg') ? 4 : w.k === 'sniper' ? 1 : (w.k === 'acan' ? 4 : 1);
  n = Math.min(n, wi.am[ak]); if (n <= 0) return;
  wi.am[ak] -= n; wi.next = now + n / (shotRate * Math.max(.4, eff)) + (w.k === 'sniper' ? 0 : 0);
  if (w.k !== 'sniper' && (++wi.burst % Math.max(2, Math.round(w.mag / n))) === 0 && w.k !== 'acan') wi.next += w.rl * .35;
  let hits = 0; for (let i = 0; i < n; i++) if (Math.random() < base) hits++;
  const near = (1 - Math.min(1, d / w.rng) * .6) * .9 + .1;
  tg.supp = Math.min(100, tg.supp + (a.supp || .4) * n * near * SUPP_K * (tv ? .12 : 1) * (hits ? 1 : .7) * eff * .5); tg.lastShot = now;
  for (let i = 0; i < hits; i++) {
    if (tg.dead) break;
    if (tv) { if (a.k === 'SA') { if (penAt(a, d) * rand(.9, 1.1) >= armourFace(tg, sx, sy, a).th) resolveHitVeh(tg, a, sx, sy, sq, d, false); } else resolveHitVeh(tg, a, sx, sy, sq, d); }
    else if (a.k === 'HE') blastAt(tg.x + rand(-4, 4), tg.y + rand(-4, 4), a.rad, a.kill, sq, tg);
    else if (Math.random() < a.kill) casualty(tg, sq);
  }
  sq.fxT -= .25; if (sq.fxT <= 0) { sq.fxT = rand(.12, .3); const sp = d * .04; addTracer(sx, sy, tg.x + rand(-sp, sp), tg.y + rand(-sp, sp), sq.side); HOOK.sfx('shot', sx, sy, w.k === 'rifle' ? .55 : 1); }
  if (!(now - sq.lastAmmoCalc < 1)) { sq.lastAmmoCalc = now; sq.ammo = ammoPct(sq); }
}
function processPending() {
  for (let i = S.pend.length - 1; i >= 0; i--) {
    const p = S.pend[i]; if (S.t < p.at) continue; S.pend.splice(i, 1);
    const from = S.byId.get(p.from);
    if (p.kind === 'shell') shellLand(p.x, p.y, from, p.am || 'he82');
    else if (p.kind === 'shot') {
      const a = AMMO[p.am], tg = S.byId.get(p.to);
      if (!tg || tg.dead) { boom(p.x1, p.y1, a.k === 'HE' ? 18 : 12, 1); if (a.k === 'HE') blastAt(p.x1, p.y1, a.rad, a.kill, from); continue; }
      if (p.hit) {
        boom(tg.x, tg.y, a.k === 'HE' ? 26 : 20, 0);
        if (tg.t.veh) { resolveHitVeh(tg, a, p.ax, p.ay, from, p.d); if (a.k === 'HE') suppressArea(tg.x, tg.y, a.rad * 2, a.supp); }
        else { blastAt(tg.x, tg.y, a.rad || 3, a.kill || .5, from, tg); if (!(a.k === 'HE') && Math.random() < .5) casualty(tg, from); tg.supp = Math.min(100, tg.supp + 35); }
      } else {
        const ox = tg.x + rand(-34, 34), oy = tg.y + rand(-34, 34); boom(ox, oy, a.k === 'HE' ? 22 : 14, 1);
        if (a.k === 'HE') { blastAt(ox, oy, a.rad, a.kill, from); suppressArea(ox, oy, a.rad * 2.4, a.supp); } else tg.supp = Math.min(100, tg.supp + 22);
      }
      tg.lastShot = S.t;
    }
  }
}

/* ---------- миномёт ---------- */
function mortarStep(sq, dt) {
  const o = sq.order; if (!o || o.kind !== 'fire') return;
  const wi = sq.crew.flatMap(m2 => m2.ok ? m2.ws : []).find(x => x.w.k === 'mortar'); if (!wi) { sq.order = null; return; }
  const d = dist(sq.x, sq.y, o.x, o.y);
  if (d > wi.w.rng || d < wi.w.minR) { sq.order = null; ev(sq.name + ': цель вне досягаемости', 'warn', sq.x, sq.y, sq.side); return; }
  const he = wi.am.he82 || 0; if (he < 3) { sq.order = null; ev(sq.name + ': нет мин', 'warn', sq.x, sq.y, sq.side); return; }
  sq.fa = Math.atan2(o.y - sq.y, o.x - sq.x); o.deploy += dt; if (o.deploy < 3) return;
  o.next -= dt; if (o.next > 0) return; o.next = 7;
  const blind = !S.squads.some(e => !e.dead && e.side !== sq.side && isSpotted(e, sq.side) && dist(e.x, e.y, o.x, o.y) < 130);
  const sigma = (22 + d * .03) * (blind ? 2.2 : 1);
  for (let i = 0; i < 3; i++) { const a = Math.random() * TAU, r = Math.abs((Math.random() + Math.random() + Math.random() - 1.5)) * sigma * 1.6; S.pend.push({ kind: 'shell', at: S.t + 2.2 + d / 700 + i * .6, x: o.x + Math.cos(a) * r, y: o.y + Math.sin(a) * r, from: sq.id, am: 'he82' }); }
  wi.am.he82 -= 3; sq.ammo = ammoPct(sq); sq.lastFire = S.t; HOOK.sfx('shot', sq.x, sq.y, 1.5); boom(sq.x, sq.y, 8, 1);
  if (--o.salvos <= 0) sq.order = null;
}

/* ---------- пожар на технике ---------- */
function vehicleFire(sq) {
  if (!sq.fireT || sq.dead) return;
  const age = S.t - sq.fireT;
  if (age > 9 + (sq.id % 5)) { // экипаж покидает горящую машину
    destroySquad(sq, null, 'fire'); boom(sq.x, sq.y, 44, 2);
  }
}

/* ---------- сводка вооружения для карточки отряда ---------- */
function loadoutOf(sq) {
  const map = new Map();
  for (const man of sq.crew) { if (!man.ok && !sq.t.veh) continue; for (const wi of man.ws) { if (!wi.w) continue; let r = 0; for (const k in wi.am) r += wi.am[k]; const e = map.get(wi.w.n) || { n: wi.w.n, c: 0, r: 0, k: wi.w.k, ammo: {} }; e.c++; e.r += r; for (const k in wi.am) e.ammo[k] = (e.ammo[k] || 0) + wi.am[k]; map.set(wi.w.n, e); } }
  return [...map.values()];
}

/* ---------- посадка и высадка ---------- */
function boardVeh(inf, v) {
  if (v.cargo || inf.carried) return; v.cargo = inf.id; inf.carried = v.id; inf.order = null; inf.path = null; inf.tg = null; S.sel.delete(inf.id);
  ev(inf.name + ' села на ' + NM(v), 'info', v.x, v.y, inf.side);
}
function dismountVeh(v) {
  const inf = S.byId.get(v.cargo); if (!inf || inf.dead) { v.cargo = 0; return false; }
  inf.carried = 0; v.cargo = 0; const a = v.fa + Math.PI; inf.x = v.x + Math.cos(a) * 22; inf.y = v.y + Math.sin(a) * 22; inf.fa = v.fa; inf.order = null; inf.path = null; inf.supp = Math.max(inf.supp, 12);
  const mv = T_MV_I; if (mv[ter[cellIdx(inf.x, inf.y)]] === 0) { inf.x = v.x; inf.y = v.y; }
  ev(inf.name + ' высадилась из ' + NM(v), 'info', v.x, v.y, inf.side); return true;
}
function setStance(sqs, st) { for (const q of sqs) { if (q.dead || q.t.mortar) continue; q.stance = st; if (st === 'ambush') { q.order = { kind: 'hold' }; q.path = null; q.fort = Math.max(q.fort, .3); } } }

/* ---------- артиллерийская поддержка ---------- */
function useArty(side, x, y) {
  if (!canUse(side, 'arty')) return 'Артиллерия ещё не готова';
  if (side === S.player && S.fog[cellIdx(x, y)] === 0) return 'Нет данных о районе: сначала разведайте его';
  const obs = S.squads.some(e => !e.dead && e.side !== side && !e.carried && isSpotted(e, side) && dist(e.x, e.y, x, y) < 160), a = S.ab[side].arty;
  a.ch--; a.cd = AB_CD.arty; const sg = obs ? 34 : 70;
  for (let i = 0; i < 6; i++) { const ang = Math.random() * TAU, r = Math.abs(Math.random() + Math.random() + Math.random() - 1.5) * sg * 1.5; S.pend.push({ kind: 'shell', at: S.t + 9 + i * .55, x: x + Math.cos(ang) * r, y: y + Math.sin(ang) * r, from: 0, am: 'he152' }); }
  ev('Артиллерия: огонь на поражение, подлётное время 9 с', 'info', x, y, side); HOOK.sfx('shot', BASE[side].x, BASE[side].y, 1); return null;
}
