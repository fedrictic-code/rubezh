/* =====================  ИИ ПРОТИВНИКА  ===================== */
const AI_MIX = [
  { rifle: .30, mg: .10, at: .12, sniper: .06, mortar: .07, ifv: .20, tank: .15 },   // наступающие
  { rifle: .30, mg: .15, at: .20, sniper: .08, mortar: .10, ifv: .12, tank: .05 }    // обороняющиеся
];
function aiTick() { const sides = S.autoplay ? [0, 1] : [S.aiSide]; for (const s of sides) aiThink(s); }

function aiThink(s) {
  const atk = s === S.atk, mine = S.squads.filter(q => !q.dead && q.side === s && !q.rout && !q.carried);
  aiBuy(s); aiAbilities(s, atk, mine);
  // цель наступающих: первая цель, не находящаяся под их контролем
  let goal = null; if (atk) { for (const o of S.objs) if (o.owner !== s) { goal = o; break; } if (!goal) goal = S.objs[1]; }
  const inf = mine.filter(q => !q.t.veh && q.role === 'assault' && q.wave !== 'gather'), xs = inf.map(q => q.x).sort((a, b) => a - b), infX = xs.length ? xs[Math.floor(xs.length * .7)] : null;
  // волны подкрепления: сбор у рубежа развёртывания, затем общий бросок
  const asm = { x: 880, y: 740 }, gath = mine.filter(q => q.wave === 'gather');
  if (atk) {
    for (const q of mine) if (q.wave === undefined && q.role === 'assault' && S.t - q.born > 1 && !q.mountTo) { if (S.t > 20 && dist(q.x, q.y, asm.x, asm.y) > 260) { q.wave = 'gather'; issue([q], 'move', asm.x + rand(-60, 60), asm.y + rand(-80, 80)); } else q.wave = 'go'; }
    const there = gath.filter(q => dist(q.x, q.y, asm.x, asm.y) < 200);
    const old = gath.some(q => S.t - q.born > 70);
    if (there.length >= 4 || (old && there.length >= 2)) for (const q of gath) { q.wave = 'go'; q.order = null; }
  }
  if (atk && S.t < 8 && !S.mountDone) { // наступающие едут на броне: пехота садится в БМП/БТР
    S.mountDone = true;
    const carriers = mine.filter(q => q.t.cap && !q.cargo), troops = mine.filter(q => !q.t.veh && q.type === 'rifle' && q.role === 'assault');
    for (const v of carriers) { let best = null, bd = 1e9; for (const tp of troops) { if (tp.mountTo || tp.men > v.t.cap) continue; const d = dist(tp.x, tp.y, v.x, v.y); if (d < bd) { bd = d; best = tp; } } if (best) { best.mountTo = v.id; issue([best], 'mount', v.x, v.y, v.id); } }
  }
  for (const v of S.squads) if (!v.dead && v.side === s && v.cargo && goal) { if (dist(v.x, v.y, goal.x, goal.y) < goal.r + 260 || v.supp > 40 || v.hp < 55) dismountVeh(v); }
  for (const q of mine) {
    if (q.cargo && goal) { if (!q.order || q.order.kind !== 'fight' || S.t - q.orderT > 25) { const dx = goal.x - q.x, dy = goal.y - q.y, d = Math.hypot(dx, dy), k = Math.max(0, d - 200) / (d || 1); issue([q], 'fight', q.x + dx * k, q.y + dy * k); } continue; }
    if (q.t.mortar) { if (atk && !q.post && S.t > 15) { q.post = { x: 760, y: 700 + rand(-40, 40) }; issue([q], 'move', q.post.x, q.post.y); } aiMortar(q, s); continue; }
    if (q.wave === 'gather') continue;
    if (atk) {
      if (S.t < 6) continue;
      if (q.type === 'sniper') { if (!q.post) { q.post = { x: 960 + rand(-30, 30), y: 610 + rand(-30, 30) }; issue([q], 'move', q.post.x, q.post.y); } else if (!q.order) issue([q], 'hold'); continue; }
      if (q.role === 'escort') {
        if (infX !== null && q.x > infX + 90 && goal) { if (!q.order || q.order.kind !== 'hold') issue([q], 'hold'); continue; }
        if (q.order && q.order.kind === 'fight' && S.t - q.orderT < 25) continue;
        if (goal) { const dx = goal.x - q.x, dy = goal.y - q.y, d = Math.hypot(dx, dy), k = Math.max(0, d - 230) / (d || 1); issue([q], 'fight', q.x + dx * k, q.y + dy * k); }
        continue;
      }
      if (!q.order || (q.order.kind === 'fight' && S.t - q.orderT > 25) || q.order.kind === 'hold' && q.role === 'assault') {
        if (goal) { const a = Math.random() * TAU, r = Math.random() * goal.r * .6; issue([q], 'fight', goal.x + Math.cos(a) * r, goal.y + Math.sin(a) * r); }
      }
    } else {
      if (q.role === 'counter') {
        if (q.order && q.order.kind === 'fight' && S.t - q.orderT < 20) continue;
        if (q.order && q.order.kind === 'hold' && S.t - q.orderT < 40) continue;
        // самый напряжённый рубеж: где больше противника, иначе ключевой с наименьшим числом своих
        let best = null, bs = -1e9; for (const o of S.objs) { const sc = o.w[S.atk] * 3 - o.w[s] + (o.owner !== s ? 2 : 0) + (o.key ? 1 : 0); if (sc > bs) { bs = sc; best = o; } }
        if (best) { const a = Math.random() * TAU, r = Math.random() * best.r * .7; const x = best.x + Math.cos(a) * r, y = best.y + Math.sin(a) * r; if (best.owner !== s || best.contested) issue([q], 'fight', x, y); else { issue([q], 'move', x, y); q.post = { x, y }; } }
      } else if (q.post) {
        if (!q.order) { if (dist(q.x, q.y, q.post.x, q.post.y) > 30) issue([q], 'move', q.post.x, q.post.y); else issue([q], 'hold'); }
      }
    }
  }
}
function aiBuy(s) {
  if (S.queue.filter(q => q.side === s).length >= 3) return;
  const mix = AI_MIX[s === S.atk ? 0 : 1], vs = variantsFor(s).filter(v => v.cost <= S.pts[s]); if (!vs.length) return;
  if (S.pts[s] < 140 && Math.random() < .5) return;
  let tot = 0; for (const v of vs) tot += mix[v.cls] / variantsFor(s).filter(x => x.cls === v.cls).length; let r = Math.random() * tot, pick = vs[0];
  for (const v of vs) { r -= mix[v.cls] / variantsFor(s).filter(x => x.cls === v.cls).length; if (r <= 0) { pick = v; break; } }
  buyUnit(s, pick.id);
}
function aiMortar(q, s) {
  if (q.order && q.order.kind === 'fire') return; if (q.ammo < 8 || S.t - q.orderT < 10) return;
  let best = null, bs = 0;
  for (const e of S.squads) {
    if (e.dead || e.side === s || !isSpotted(e, s)) continue; const d = dist(q.x, q.y, e.x, e.y); if (d > q.t.range * .95 || d < q.t.minRange * 1.1) continue;
    if (S.squads.some(f => !f.dead && f.side === s && dist(f.x, f.y, e.x, e.y) < 95)) continue;
    let sc = 1; for (const o of S.squads) if (!o.dead && o.side === e.side && o !== e && dist(o.x, o.y, e.x, e.y) < 80) sc += .6; if (!e.t.veh) sc += 1; if (!e.moving) sc += .5;
    if (sc > bs) { bs = sc; best = e; }
  }
  if (best) issue([q], 'fire', best.x, best.y);
}
function aiAbilities(s, atk, mine) {
  if (canUse(s, 'drone') && S.t > 20 && Math.random() < .3) {
    let tx, ty; const foes = S.squads.filter(e => !e.dead && e.side !== s && e.lk[s] && S.t - e.seenAt[s] < 40);
    if (foes.length && Math.random() < .5) { const f = foes[(Math.random() * foes.length) | 0]; tx = f.lk[s].x; ty = f.lk[s].y; } else { const o = atk ? (S.objs.find(o => o.owner !== s) || S.objs[1]) : S.objs[0]; tx = o.x + rand(-120, 120); ty = o.y + rand(-120, 120); }
    useDrone(s, tx, ty);
  }
  if (canUse(s, 'fpv') && Math.random() < .45) {
    let best = null, bs = -1; for (const e of S.squads) { if (e.dead || e.side === s || !isSpotted(e, s)) continue; const sc = (e.t.veh ? 3 : 0) + (e.t.shot ? 1.5 : 0) + (e.type === 'mg' ? 1 : 0) + Math.random(); if (sc > bs) { bs = sc; best = e; } }
    if (best) useFpv(s, best.id);
  }
  if (canUse(s, 'arty') && S.t > 40 && Math.random() < .2) {
    let best = null, bs = 0; for (const e of S.squads) { if (e.dead || e.carried || e.side === s || !isSpotted(e, s)) continue; if (S.squads.some(f => !f.dead && f.side === s && dist(f.x, f.y, e.x, e.y) < 120)) continue; let sc = 1; for (const o of S.squads) if (!o.dead && o.side === e.side && o !== e && dist(o.x, o.y, e.x, e.y) < 90) sc += 1; if (!e.t.veh) sc += .5; if (sc > bs) { bs = sc; best = e; } }
    if (best && bs >= 2.5) useArty(s, best.x, best.y);
  }
  if (atk && canUse(s, 'smoke') && Math.random() < .12) {
    const near = mine.find(q => !q.t.veh && dist(q.x, q.y, 1150, 740) < 220); if (near && S.squads.some(e => !e.dead && e.side !== s && isSpotted(e, s))) useSmoke(s, 1230, 740);
  }
}
