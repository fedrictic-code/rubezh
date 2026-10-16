/* =====================  ИНТЕРФЕЙС И УПРАВЛЕНИЕ  ===================== */
const E = {};           // ссылки на элементы
const P = new Map();    // активные указатели
let gest = null, hintT = 0, lastHud = 0, selSig = '', deckSig = '', paused = false, side = 0, diff = 'normal', endTimer = 0;
const IC = { pause: '<svg viewBox="0 0 24 24"><path d="M8 5v14M16 5v14"/></svg>', play: '<svg viewBox="0 0 24 24"><path d="M7 4.5v15l12-7.5z"/></svg>' };

/* ---------- звук ---------- */
const SND = { ctx: null, on: true, buf: null, cnt: 0, t: 0 };
function sndInit() {
  if (SND.ctx) { if (SND.ctx.state === 'suspended') SND.ctx.resume(); return; }
  try { const C = window.AudioContext || window.webkitAudioContext; SND.ctx = new C(); const n = (SND.ctx.sampleRate * .7) | 0, b = SND.ctx.createBuffer(1, n, SND.ctx.sampleRate), d = b.getChannelData(0); for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1; SND.buf = b; } catch (e) { SND.ctx = null; }
}
HOOK.sfx = (type, x, y, vol) => {
  if (!SND.ctx || !SND.on || UI.menu || paused) return; const now = SND.ctx.currentTime; if (now - SND.t > .1) { SND.t = now; SND.cnt = 0; } if (++SND.cnt > 7) return;
  const d = dist(x, y, cam.x, cam.y), g0 = vol * Math.max(0, 1 - d / (1100 / Math.max(.6, cam.z * 1.3))) * .3; if (g0 < .012) return;
  const src = SND.ctx.createBufferSource(), f = SND.ctx.createBiquadFilter(), g = SND.ctx.createGain(); src.buffer = SND.buf;
  if (type === 'shot') { f.type = 'bandpass'; f.frequency.value = 1300 + Math.random() * 1000; f.Q.value = .9; g.gain.setValueAtTime(g0, now); g.gain.exponentialRampToValueAtTime(.001, now + .09); src.connect(f); f.connect(g); g.connect(SND.ctx.destination); src.start(now, Math.random() * .3, .1); }
  else { f.type = 'lowpass'; f.frequency.value = 240; g.gain.setValueAtTime(g0 * 2, now); g.gain.exponentialRampToValueAtTime(.001, now + .6); src.connect(f); f.connect(g); g.connect(SND.ctx.destination); src.start(now, Math.random() * .1, .65); }
};

/* ---------- журнал и подсказки ---------- */
HOOK.log = (text, kind, x, y) => {
  if (UI.menu || !E.log) return; const el = document.createElement('div'); el.className = 'it ' + (kind || 'info'); el.textContent = text; el.onclick = () => { cam.x = x; cam.y = y; clampCam(); };
  E.log.appendChild(el); while (E.log.children.length > 5) E.log.firstChild.remove();
  setTimeout(() => el.classList.add('out'), 6500); setTimeout(() => el.remove(), 7200);
};
function toast(msg, ms = 2600) { E.hint.textContent = msg; E.hint.hidden = false; E.hint._mode = false; hintT = performance.now() + ms; }
function setMode(m) {
  UI.mode = m; $$('.cmd', E.cmds).forEach(b => b.classList.toggle('on', b.dataset.cmd === m));
  $$('.ab', E.abil).forEach(b => b.classList.toggle('on', b.dataset.ab === m));
  const TX = { sneak: 'Коснитесь точки: отряды двинутся скрытно, медленно и тихо', mount: 'Коснитесь своего БМП или БТР, чтобы пехота села на технику', arty: 'Коснитесь точки для артиллерийского удара. С наблюдателем точнее', fight: 'Коснитесь точки: отряды пойдут туда и вступят в бой', fire: 'Коснитесь цели для миномёта. Без наблюдателя огонь неточный', drone: 'Коснитесь точки разведки', smoke: 'Коснитесь точки для дымовой завесы', fpv: 'Коснитесь видимого противника' };
  if (m) { toast(TX[m], 600000); E.hint._mode = true; } else if (E.hint._mode) { E.hint.hidden = true; E.hint._mode = false; }
}

/* ---------- выбор и приказы ---------- */
const selSquads = () => S ? [...S.sel].map(id => S.byId.get(id)).filter(q => q && !q.dead && !q.carried && q.side === S.player) : [];
function pick(sx, sy, touch) {
  let best = null, bd = touch ? 34 : 24;
  for (const q of S.squads) {
    if (q.dead || q.carried) continue; const enemy = q.side !== S.player; if (enemy && !isSpotted(q, S.player)) continue;
    const x = wsx(q.x), y = wsy(q.y), d = Math.min(Math.hypot(sx - x, sy - y), Math.hypot(sx - x, sy - (y - 20)) + 2) - (enemy ? 0 : 3);
    if (d < bd) { bd = d; best = { sq: q, enemy }; }
  }
  return best;
}
function selectOnly(q) { S.sel.clear(); if (q) S.sel.add(q.id); onSel(); }
function onSel() { if (UI.mode === 'fire' && !selSquads().some(q => q.t.mortar)) setMode(null); selSig = ''; }
function ping(x, y, kind) { UI.pings.push({ x, y, t: performance.now(), kind }); if (UI.pings.length > 8) UI.pings.shift(); }
UI.pings = [];
function orderAt(wx, wy, hit) {
  const sel = selSquads(); if (!sel.length) return;
  if (hit && hit.enemy) { const n = issue(sel, 'attack', wx, wy, hit.sq.id); ping(hit.sq.x, hit.sq.y, 'atk'); setMode(null); return; }
  let kind = UI.mode === 'fight' ? 'fight' : UI.mode === 'fire' ? 'fire' : UI.mode === 'sneak' ? 'sneak' : 'move';
  if (kind === 'fire') {
    const mq = sel.filter(q => q.t.mortar); if (!mq.length) { toast('Выберите миномётный расчёт'); return; }
    const c = cellIdx(wx, wy); if (S.fog[c] === 0) { toast('Нет данных о цели: сначала разведайте район'); return; }
    issue(mq, 'fire', wx, wy); ping(wx, wy, 'fire'); setMode(null); return;
  }
  const failed = issue(sel, kind, wx, wy); ping(wx, wy, kind); if (failed) toast('Путь не найден для ' + failed + ' отр.'); setMode(null);
}
function commandBtn(c) {
  if (!S) return; const sel = selSquads();
  if (c === 'deck') { toggleDeck(); return; }
  if (c === 'ambush' || c === 'cease') { if (!sel.length) { toast('Сначала выберите отряд'); return; } const st = c === 'ambush' ? 'ambush' : 'cease', all = sel.every(q => q.stance === st); setStance(sel, all ? 'free' : st); toast(all ? 'Огонь по готовности' : st === 'ambush' ? 'Засада: огонь откроют на 110 м или при обстреле' : 'Отряды не открывают огонь', 2000); selSig = ''; return; }
  if (c === 'dismount') { const vs = sel.filter(q => q.cargo); if (!vs.length) { toast('Нет пехоты на броне у выбранных машин'); return; } vs.forEach(dismountVeh); selSig = ''; return; }
  if (c === 'hold' || c === 'retreat') { if (!sel.length) { toast('Сначала выберите отряд'); return; } issue(sel, c); setMode(null); return; }
  if (!sel.length) { toast('Сначала выберите отряд'); return; }
  if (c === 'fire' && !sel.some(q => q.t.mortar)) return;
  if (c === 'mount' && !sel.some(q => !q.t.veh)) { toast('Выберите пехотный отряд'); return; }
  setMode(UI.mode === c ? null : (c === 'move' ? null : c)); if (c === 'move') toast('Коснитесь земли, чтобы отдать приказ о движении', 2200);
}
function abilityBtn(k) {
  if (!S) return; if (!canUse(S.player, k)) { const a = S.ab[S.player][k]; toast(a.ch <= 0 ? 'Запас исчерпан' : 'Перезарядка: ' + Math.ceil(a.cd) + ' с'); return; }
  setMode(UI.mode === k ? null : k);
}
function applyMode(wx, wy, hit) {
  const m = UI.mode; let err = null;
  if (m === 'drone') err = useDrone(S.player, wx, wy); else if (m === 'smoke') err = useSmoke(S.player, wx, wy);
  else if (m === 'fpv') { if (!hit || !hit.enemy) { toast('Нужна видимая цель'); return; } err = useFpv(S.player, hit.sq.id); }
  else if (m === 'arty') err = useArty(S.player, wx, wy);
  else if (m === 'mount') { if (!hit || hit.enemy || !hit.sq.t.cap) { toast('Нужна своя бронированная машина с десантом'); return; } const inf = selSquads().filter(q => !q.t.veh); if (inf.some(q => q.men > hit.sq.t.cap)) toast('Отряд не поместится'); else if (hit.sq.cargo) toast('Машина уже занята'); else { issue(inf.slice(0, 1), 'mount', hit.sq.x, hit.sq.y, hit.sq.id); ping(hit.sq.x, hit.sq.y, 'move'); setMode(null); } return; }
  else if (m === 'fight' || m === 'fire') { orderAt(wx, wy, hit); return; }
  if (err) toast(err); else { ping(wx, wy, m); setMode(null); }
}
function tap(p) {
  if (!S || S.over && false) return; const [wx, wy] = s2w(p.x, p.y), mouse = p.type === 'mouse', right = mouse && p.btn === 2, hit = pick(p.x, p.y, !mouse);
  if (S.deploying) { deployTap(wx, wy, hit); return; }
  if (UI.mode && UI.mode !== 'move') { if (UI.mode === 'sneak' && !right) { orderAt(wx, wy, hit && hit.enemy ? null : hit); return; } if (right) { setMode(null); return; } applyMode(wx, wy, hit); return; }
  if (right) { orderAt(wx, wy, hit); return; }
  if (hit && !hit.enemy) { if (mouse ? gestShift : UI.multi) { if (S.sel.has(hit.sq.id)) S.sel.delete(hit.sq.id); else S.sel.add(hit.sq.id); onSel(); } else selectOnly(hit.sq); return; }
  if (hit && hit.enemy) { if (selSquads().length) orderAt(wx, wy, hit); return; }
  if (selSquads().length && !mouse) { orderAt(wx, wy, null); return; }
  if (mouse && !gestShift) selectOnly(null);
}
let gestShift = false;
function finishBox(b) {
  const x0 = Math.min(b.x0, b.x1), x1 = Math.max(b.x0, b.x1), y0 = Math.min(b.y0, b.y1), y1 = Math.max(b.y0, b.y1); if ((x1 - x0) * (y1 - y0) < 60) return;
  if (!gestShift) S.sel.clear(); for (const q of S.squads) { if (q.dead || q.side !== S.player) continue; const x = wsx(q.x), y = wsy(q.y); if (x >= x0 && x <= x1 && y >= y0 && y <= y1) S.sel.add(q.id); } onSel();
}

/* ---------- указатели ---------- */
function bindInput() {
  cv.addEventListener('contextmenu', e => e.preventDefault());
  cv.addEventListener('pointerdown', e => {
    if (UI.menu) return; cv.setPointerCapture(e.pointerId); gestShift = e.shiftKey || e.ctrlKey || e.metaKey;
    P.set(e.pointerId, { x: e.offsetX, y: e.offsetY, sx: e.offsetX, sy: e.offsetY, type: e.pointerType, btn: e.button, moved: false });
    if (P.size === 2) { const [a, b] = [...P.values()]; gest = { mode: 'pinch', d0: Math.hypot(a.x - b.x, a.y - b.y) || 1, z0: cam.z, cx: (a.x + b.x) / 2, cy: (a.y + b.y) / 2, cam0: { x: cam.x, y: cam.y } }; for (const q of P.values()) q.moved = true; UI.box = null; }
    else if (P.size === 1) gest = { mode: null, cam0: { x: cam.x, y: cam.y } };
  });
  cv.addEventListener('pointermove', e => {
    const p = P.get(e.pointerId); const [wx, wy] = s2w(e.offsetX, e.offsetY); UI.ptr = { x: wx, y: wy };
    if (!p) { if (S && !UI.menu && e.pointerType === 'mouse') { const h = pick(e.offsetX, e.offsetY); UI.hover = h && h.enemy && selSquads().length ? { id: h.sq.id } : null; cv.style.cursor = UI.hover || UI.mode ? 'crosshair' : 'default'; } return; }
    p.x = e.offsetX; p.y = e.offsetY;
    if (gest && gest.mode === 'pinch' && P.size >= 2) { const [a, b] = [...P.values()]; const d = Math.hypot(a.x - b.x, a.y - b.y) || 1, cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2; const bf = s2w(gest.cx, gest.cy); cam.z = gest.z0 * d / gest.d0; clampCam(); const af = s2w(cx, cy); cam.x += bf[0] - af[0]; cam.y += bf[1] - af[1]; gest.cx = cx; gest.cy = cy; clampCam(); return; }
    if (P.size !== 1 || !gest) return; const dx = p.x - p.sx, dy = p.y - p.sy;
    if (!p.moved && Math.hypot(dx, dy) > 8) { p.moved = true; gest.mode = p.type === 'mouse' ? (p.btn === 0 && !UI.mode ? 'box' : 'pan') : 'pan'; if (gest.mode === 'box') UI.box = { x0: p.sx, y0: p.sy, x1: p.x, y1: p.y }; }
    if (gest.mode === 'pan') { cam.x = gest.cam0.x - dx / cam.z; cam.y = gest.cam0.y - dy / cam.z; clampCam(); } else if (gest.mode === 'box' && UI.box) { UI.box.x1 = p.x; UI.box.y1 = p.y; }
  });
  const up = e => {
    const p = P.get(e.pointerId); if (!p) return; P.delete(e.pointerId);
    if (gest && gest.mode === 'pinch') { if (P.size < 2) { for (const q of P.values()) { q.moved = true; q.sx = q.x; q.sy = q.y; } gest = P.size ? { mode: null, cam0: { x: cam.x, y: cam.y } } : null; } return; }
    if (!p.moved && e.type === 'pointerup') tap(p); else if (gest && gest.mode === 'box' && UI.box) finishBox(UI.box);
    UI.box = null; gest = null;
  };
  cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
  cv.addEventListener('wheel', e => { e.preventDefault(); if (UI.menu) return; const bf = s2w(e.offsetX, e.offsetY); cam.z *= Math.exp(-e.deltaY * .0012); clampCam(); const af = s2w(e.offsetX, e.offsetY); cam.x += bf[0] - af[0]; cam.y += bf[1] - af[1]; clampCam(); }, { passive: false });
  const mp = e => { const r = mini.getBoundingClientRect(); cam.x = (e.clientX - r.left) / r.width * W; cam.y = (e.clientY - r.top) / r.height * H; clampCam(); };
  mini.addEventListener('pointerdown', e => { mini.setPointerCapture(e.pointerId); mp(e); mini._d = true; }); mini.addEventListener('pointermove', e => { if (mini._d) mp(e); }); mini.addEventListener('pointerup', () => { mini._d = false; });
  const keys = new Set(); UI.keys = keys;
  addEventListener('keydown', e => {
    if (UI.menu || e.target.tagName === 'INPUT') return; const k = e.key.toLowerCase(); keys.add(k); if (k === 'shift') gestShift = true;
    if (!S) return; if (e.ctrlKey && k === 'a') { e.preventDefault(); selectAll(); return; }
    if (k === ' ') { e.preventDefault(); togglePause(); } else if (k === 'escape') { setMode(null); E.deck.hidden = true; } else if (k === 'm') commandBtn('move'); else if (k === 'a' && !e.ctrlKey) commandBtn('fight'); else if (k === 'h') commandBtn('hold'); else if (k === 'r') commandBtn('retreat'); else if (k === 'f') commandBtn('fire'); else if (k === 'b') toggleDeck(); else if (k === 'c') commandBtn('sneak'); else if (k === 'v') commandBtn('ambush'); else if (k === 'x') commandBtn('cease'); else if (k === 'g') commandBtn('mount'); else if (k === 'd') commandBtn('dismount'); else if (k === 't') abilityBtn('arty');
    else if (k === 'q') abilityBtn('drone'); else if (k === 'w' && false) abilityBtn('fpv'); else if (k === 'e') abilityBtn('smoke'); else if (k === '1' || k === '2' || k === '3') setSpeed([1, 2, 4][+k - 1]);
    else if (k === 'z') abilityBtn('fpv');
  });
  addEventListener('keyup', e => { UI.keys.delete(e.key.toLowerCase()); if (e.key === 'Shift') gestShift = false; });
  addEventListener('resize', () => { resizeView(); });
}
function selectAll() { if (!S) return; S.sel.clear(); for (const q of S.squads) if (!q.dead && q.side === S.player) S.sel.add(q.id); onSel(); }
function togglePause() { if (S && S.deploying) return; paused = !paused; E.bPause.innerHTML = paused ? IC.play : IC.pause; if (paused) toast('Пауза: приказы можно отдавать', 1800); }
function setSpeed(n) { if (!S) return; S.speed = n; $$('.sp').forEach(b => b.classList.toggle('on', +b.dataset.sp === n)); }

/* ---------- подкрепление ---------- */
function statBar(v) { return '<u style="display:block;height:4px;border-radius:2px;background:var(--amber);width:' + Math.round(clamp(v, .05, 1) * 100) + '%"></u>'; }
function toggleDeck() { E.deck.hidden = !E.deck.hidden; deckSig = ''; if (!E.deck.hidden) renderDeck(); }
function renderDeck() {
  if (E.deck.hidden || !S) return; const pts = Math.floor(S.pts[S.player]), q = S.queue.filter(x => x.side === S.player);
  const sig = pts + '|' + q.map(x => x.type + Math.ceil(x.at - S.t)).join(','); if (sig === deckSig) return; deckSig = sig;
  let h = '<h3>Подкрепление <span>◆ ' + pts + '</span><button class="x" data-close aria-label="Закрыть">×</button></h3><div class="grid">';
  for (const c of TYPE_ORDER) for (const T of variantsFor(S.player)) { if (T.cls !== c) continue; h += '<button class="uc" data-buy="' + T.id + '"' + (pts < T.cost ? ' disabled' : '') + '><img src="' + iconURL(T.cls, S.player) + '" alt=""><b>' + T.name + '</b><small>◆ ' + T.cost + '</small><p>' + T.desc + ' · ' + T.hint + ' · прибытие ' + T.delay + ' с</p></button>'; }
  h += '</div>'; if (q.length) h += '<div class="q">В пути: ' + q.map(x => '<i>' + VARS[x.type].name + ' · ' + Math.max(0, Math.ceil(x.at - S.t)) + ' с</i>').join('') + '</div>';
  E.deck.innerHTML = h;
}

/* ---------- HUD ---------- */
const bar = (name, v, col) => '<div class="bar3">' + name + '<div><u style="width:' + clamp(v, 0, 100).toFixed(0) + '%;background:' + col + '"></u></div></div>';
const mcol = v => v > 60 ? 'var(--ok)' : v > 35 ? 'var(--amber)' : 'var(--bad)';
function statusOf(q) {
  if (q.stance === 'ambush') return '<b style="color:var(--amber)">Засада</b> <s>· огонь по сигналу</s>'; if (q.stance === 'cease') return '<b style="color:var(--amber)">Огонь запрещён</b>'; if (q.cargo) return 'Везёт десант <s>· ' + (S.byId.get(q.cargo) ? S.byId.get(q.cargo).men : 0) + ' чел.</s>'; if (q.sneak) return 'Скрытное движение';
  if (q.rout) return '<b style="color:var(--bad)">Отступает</b>'; if (q.supp >= 75) return '<b style="color:var(--warn)">Прижаты огнём</b>'; const o = q.order;
  if (q.tg && !q.tg.dead) return 'Ведёт огонь <s>· ' + NM(q.tg).toLowerCase() + '</s>';
  if (o) { if (o.kind === 'move') return 'Движется'; if (o.kind === 'fight') return 'Атака <s>· идёт в бой</s>'; if (o.kind === 'attack') return 'Сближается с целью'; if (o.kind === 'hold') return q.fort > .9 ? 'Окопался <s>· защита повышена</s>' : 'Окапывается'; if (o.kind === 'retreat') return 'Отход'; if (o.kind === 'fire') return 'Миномётный огонь'; }
  return q.fort > .9 ? 'Окопался' : 'Ожидает приказа';
}
function renderSel() {
  const sel = selSquads(); let h = '', sg = '';
  if (!sel.length) { sg = 'e'; h = '<div class="empty">Коснитесь отряда на карте, чтобы выбрать его.<button class="lnk" data-act="all">Выбрать все отряды</button></div>'; }
  else if (sel.length === 1) {
    const q = sel[0], n = [q.t.name, q.t.desc]; let pips = ''; if (q.t.veh) pips = '<div style="flex:1;height:5px;border-radius:3px;background:rgba(255,255,255,.1);overflow:hidden"><u style="display:block;height:100%;width:' + (q.hp / q.hpMax * 100).toFixed(0) + '%;background:' + mcol(q.hp / q.hpMax * 100) + '"></u></div><em>' + Math.ceil(q.hp) + ' / ' + q.hpMax + '</em>'; else { for (let i = 0; i < q.max; i++) pips += '<i class="' + (i < q.men ? '' : 'd') + '"></i>'; pips += '<em>' + q.men + ' из ' + q.max + '</em>'; }
    sg = [q.id, q.men, Math.ceil(q.hp), q.morale | 0, q.supp | 0, q.ammo | 0, q.order && q.order.kind, q.rout, q.fort > .9, q.tg && q.tg.id, q.crew.reduce((s, m2) => s + m2.ws.reduce((t2, w2) => t2 + Object.values(w2.am).reduce((x, y) => x + y, 0), 0), 0)].join(',');
    h = '<div class="row"><img class="ico" src="' + iconURL(q.type, q.side) + '" alt=""><div class="meta" data-act="more"><b>' + q.name + '<small>' + n[0] + '</small></b><span>' + statusOf(q) + '</span></div><button class="x" data-act="clear" aria-label="Снять выбор">×</button></div><div class="men">' + pips + '</div><div class="bars">' + bar('Стойкость', q.morale, mcol(q.morale)) + bar('Подавление', q.supp, 'var(--warn)') + bar('Боезапас', q.ammo, 'var(--mut)') + '</div><div class="load">' + loadoutOf(q).map(e => '<span>' + e.n + (e.c > 1 ? ' ×' + e.c : '') + ' <b>' + (e.k === 'rifle' || e.k === 'mg' || e.k === 'hmg' ? '' : Object.keys(e.ammo).map(k => AMMO[k].n + ' ' + e.ammo[k]).join(', ')) + '</b></span>').join('') + '</div>';
  } else {
    sg = 'm' + sel.map(q => q.id + ':' + q.men + ':' + (q.rout ? 1 : 0)).join(',');
    h = '<div class="row"><div class="meta"><b>Выбрано отрядов: ' + sel.length + '</b><span>' + (UI.multi ? 'Режим добавления включён' : 'Приказ получат все') + '</span></div><button class="x" data-act="clear" aria-label="Снять выбор">×</button></div><div class="chips">' + sel.map(q => '<span class="chip"><img src="' + iconURL(q.type, q.side) + '" alt="">' + q.name + ' · ' + (q.t.veh ? Math.ceil(q.hp / q.hpMax * 100) + '%' : q.men) + '</span>').join('') + '</div>';
  }
  const full = sg + '|' + (UI.multi ? 1 : 0); if (full === selSig) return; selSig = full; E.sel.innerHTML = h + (sel.length === 0 ? '' : '');
  E.cmds.querySelector('[data-cmd="fire"]').hidden = !sel.some(q => q.t.mortar);
  E.cmds2.hidden = !sel.length; if (sel.length) { const cm = k => E.cmds2.querySelector('[data-cmd="' + k + '"]'); cm('ambush').classList.toggle('on', sel.every(q => q.stance === 'ambush')); cm('cease').classList.toggle('on', sel.every(q => q.stance === 'cease')); cm('sneak').hidden = sel.every(q => q.t.veh); cm('mount').hidden = sel.every(q => q.t.veh); cm('dismount').hidden = !sel.some(q => q.cargo); }
}
function renderHud(now) {
  if (!S) return; const left = LIMIT - S.t;
  E.clock.firstChild.nodeValue = fmtTime(left);
  const inc = S.inc[S.player]; E.pts.innerHTML = '◆ ' + Math.floor(S.pts[S.player]) + '<small>+' + inc.toFixed(1) + '/с</small>';
  let h = ''; for (const o of S.objs) { const own = o.owner >= 0 ? SIDES[o.owner].short : 'нейтрально'; const hold = o.key && S.holdT > 0 && S.objs.filter(x => x.key).every(x => x.owner === S.atk); h += '<div class="obj glass' + (hold ? ' hold' : '') + '"><b><span>' + o.name + '</span><i>' + (o.contested ? 'бой' : own) + '</i></b><div class="bar"><u style="width:' + ((1 - o.ctrl) * 50) + '%"></u><u style="width:' + ((1 + o.ctrl) * 50) + '%"></u></div></div>'; }
  if (S.holdT > 0) h += '<div class="obj glass hold"><b><span>Удержание</span><i>' + (S.atk === S.player ? 'цель' : 'угроза') + '</i></b><div class="bar" style="background:rgba(255,255,255,.1)"><u style="width:' + (S.holdT / HOLD_NEED * 100) + '%;background:var(--amber)"></u></div></div>';
  if (h !== E.objs._h) { E.objs.innerHTML = h; E.objs._h = h; }
  renderSel(); renderDeck();
  $$('.ab', E.abil).forEach(b => { const a = S.ab[S.player][b.dataset.ab]; b.querySelector('em').textContent = '×' + a.ch; b.querySelector('u').style.height = a.cd > 0 ? (a.cd / AB_CD[b.dataset.ab] * 100) + '%' : '0'; b.classList.toggle('off', a.ch <= 0); b.querySelector('span').textContent = { drone: 'Q', fpv: 'Z', smoke: 'E', arty: 'T' }[b.dataset.ab]; });
  $$('.cmd', E.cmds).forEach(b => { if (b.dataset.cmd === 'deck') b.classList.toggle('on', !E.deck.hidden); });
  if (!E.hint.hidden && now > hintT) E.hint.hidden = true;
  renderMini();
  if (UI.perf) E.perf.textContent = 'FPS ' + perf.fps.toFixed(0) + ' · шаг симуляции ' + perf.sim.toFixed(2) + ' мс · отрисовка ' + perf.render.toFixed(2) + ' мс · отрядов ' + S.squads.length;
}

/* ---------- старт, финиш ---------- */
function startBattle() {
  sndInit(); const fc = [null, null]; fc[side] = forceList(side); newBattle(side, diff, fc); buildTerrain(); fogCv = null; fogBig = null; paused = false; E.bPause.innerHTML = IC.pause; setSpeed(1); UI.mode = null; UI.menu = false; UI.pings.length = 0; selSig = ''; deckSig = ''; E.deck.hidden = true; E.log.innerHTML = '';
  E.menu.hidden = true; E.force.hidden = true; E.end.hidden = true; E.hud.hidden = false; setMode(null); S.deploying = true; paused = true; E.hud.classList.add('deploying'); E.deployBar.hidden = false;
  cam.z = clamp(VIEW.w / 1500, .38, .85); cam.x = side === 0 ? 1740 : 330; cam.y = 740; clampCam(); acc = 0;
  if (false) toast(side === S.atk ? 'Возьмите село Дубки и высоту 112 и держите их ' + HOLD_NEED + ' с. Выберите отряд и коснитесь карты.' : 'Продержитесь ' + (LIMIT / 60) + ' минут. Не отдавайте село Дубки и высоту 112.', 6000);
}
function beginBattle() {
  if (!S || !S.deploying) return; S.deploying = false; paused = false; E.hud.classList.remove('deploying'); E.deployBar.hidden = true; S.sel.clear(); selSig = '';
  toast(side === S.atk ? 'Возьмите село Дубки и высоту 112 и держите их ' + HOLD_NEED + ' с. Выберите отряд и коснитесь карты.' : 'Продержитесь ' + (LIMIT / 60) + ' минут. Не отдавайте село Дубки и высоту 112.', 6000);
}
function deployTap(wx, wy, hit) {
  const z = ZONE[S.player];
  if (hit && !hit.enemy) { selectOnly(hit.sq); return; }
  const sel = selSquads(); if (sel.length !== 1) { toast('Сначала коснитесь своего отряда'); return; }
  if (wx < z.x0 || wx > z.x1 || wy < z.y0 || wy > z.y1) { toast('Отряды ставятся только в подсвеченной зоне'); return; }
  const q = sel[0], mv = q.t.veh ? T_MV_V : T_MV_I; if (mv[ter[cellIdx(wx, wy)]] === 0) { toast('Сюда нельзя встать'); return; }
  q.x = wx; q.y = wy; q.path = null; if (q.order && q.order.kind === 'hold') q.post = { x: wx, y: wy }; ping(wx, wy, 'move'); perception(); fogUpdate();
}
/* ---------- подбор сил ---------- */
UI.force = [{}, {}];
const forceCost = c => Object.keys(c).reduce((s, k) => s + VARS[k].cost * c[k], 0), forceN = c => Object.keys(c).reduce((s, k) => s + c[k], 0);
function presetCounts(sd) { const c = {}; for (const id of PRESET[sd]) c[id] = (c[id] || 0) + 1; return c; }
function forceList(sd) { const c = UI.force[sd], out = []; for (const k in c) for (let i = 0; i < c[k]; i++) out.push(k); return out; }
function budgetOf(sd) { return BUDGET[sd === 1 ? 1 : 0]; }
function openForce() {
  if (!Object.keys(UI.force[side]).length) UI.force[side] = presetCounts(side);
  E.menu.hidden = true; E.force.hidden = false; renderForce();
}
function renderForce() {
  const c = UI.force[side], budget = budgetOf(side), used = forceCost(c), n = forceN(c), left = budget - used;
  E.fTitle.textContent = 'Подбор сил · ' + SIDES[side].name; E.fSub.textContent = (side === 1 ? 'Наступление' : 'Оборона') + ' · отрядов ' + n + ' из ' + MAX_UNITS;
  E.fBud.textContent = used + ' / ' + budget; E.fBar.style.width = Math.min(100, used / budget * 100) + '%';
  let h = ''; const names = { rifle: 'Пехота', mg: 'Пулемёты', at: 'Противотанковые', sniper: 'Снайперы', mortar: 'Миномёты', ifv: 'Боевые машины', tank: 'Танки' };
  for (const k of TYPE_ORDER) {
    const vs = variantsFor(side).filter(v => v.cls === k); if (!vs.length) continue; h += '<h4>' + names[k] + '</h4>';
    for (const v of vs) { const q = c[v.id] || 0; h += '<div class="fr"><img src="' + iconURL(v.cls, side) + '" alt=""><b>' + v.name + '</b><span class="c">◆ ' + v.cost + '</span><div class="st"><button data-f="' + v.id + '" data-d="-1"' + (q ? '' : ' disabled') + ' aria-label="Убрать">−</button><i>' + q + '</i><button data-f="' + v.id + '" data-d="1"' + (v.cost > left || n >= MAX_UNITS ? ' disabled' : '') + ' aria-label="Добавить">+</button></div><p>' + v.desc + ' · ' + v.hint + '</p></div>'; }
  }
  E.fList.innerHTML = h; $('#fGo').disabled = n === 0; $('#fGo').style.opacity = n ? 1 : .4;
}
HOOK.onOver = o => { clearTimeout(endTimer); endTimer = setTimeout(() => showEnd(o), 1400); };
function showEnd(o) {
  const win = o.winner === S.player; E.endRes.textContent = win ? 'Победа' : 'Поражение'; E.endRes.className = 'res ' + (win ? 'win' : 'lose'); E.endWhy.textContent = o.why + ' · ' + fmtTime(S.t) + ' боя';
  const m = S.player, e = 1 - m, st = S.stats;
  E.endStats.innerHTML = '<span class="h"></span><span class="h">Вы</span><span class="h">Противник</span><span>Потеряно бойцов</span><b>' + st.lost[m] + '</b><b>' + st.lost[e] + '</b><span>Потеряно техники</span><b>' + st.veh[m] + '</b><b>' + st.veh[e] + '</b><span>Рубежей под контролем</span><b>' + S.objs.filter(x => x.owner === m).length + '</b><b>' + S.objs.filter(x => x.owner === e).length + '</b>';
  E.end.hidden = false;
}

/* ---------- настройки и графика ---------- */
function renderArtList() {
  E.artList.innerHTML = ART_KEYS.map(([k, n, sz, d]) => '<div><span>' + n + ' <code>' + k + '</code></span>' + (ART[k] ? '<button data-rm="' + k + '">убрать</button>' : '<small style="color:var(--mut);justify-self:end">встроенная</small>') + '<small>' + sz + ' · ' + d + '</small></div>').join('');
}
async function addArtFiles(files) {
  let ok = 0, bad = [];
  for (const f of files) {
    const key = f.name.replace(/\.[^.]+$/, '').toLowerCase(); if (!ART_KEYS.some(a => a[0] === key)) { bad.push(f.name); continue; }
    const url = await new Promise(res => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = () => res(null); r.readAsDataURL(f); }); if (!url) { bad.push(f.name); continue; }
    if (await loadArt(key, url)) ok++; else bad.push(f.name);
  }
  for (const k in iconCache) delete iconCache[k]; selSig = ''; deckSig = ''; if (ART.map || ok) { buildTerrain(); }
  renderArtList(); if (bad.length) alert_(ok + ' применено. Не распознаны: ' + bad.join(', ')); else if (ok) alert_('Применено файлов: ' + ok);
}
function alert_(msg) { E.artNote.textContent = msg; }
function resetArt() { for (const k in ART) delete ART[k]; for (const k in iconCache) delete iconCache[k]; buildTerrain(); selSig = ''; deckSig = ''; renderArtList(); alert_('Графика сброшена'); }
function stress(n) {
  if (!S) return; S.autoplay = true; const atk = S.atk;
  for (let i = 0; i < n; i++) {
    const s = i % 2, vs = variantsFor(s).filter(v => v.cls !== 'tank' && v.cls !== 'mortar'), t = vs[(Math.random() * vs.length) | 0].id, x = s === 1 ? rand(150, 1000) : rand(1400, 2300), y = rand(150, 1350), q = mkSquad(s, t, x, y); q.role = s === atk ? 'assault' : 'counter';
  }
  toast('Добавлено отрядов: ' + n + '. ИИ управляет обеими сторонами', 4000);
}

/* ---------- главный цикл ---------- */
let last = 0, acc = 0; const perf = { sim: 0, render: 0, fps: 60 };
function frame(t) {
  requestAnimationFrame(frame); const dt = Math.min(.1, (t - last) / 1000 || .016); last = t; perf.fps = lerp(perf.fps, 1 / Math.max(dt, .001), .08);
  if (UI.menu) { cam.x = 1200 + Math.sin(t / 9000) * 500; cam.y = 750 + Math.cos(t / 11000) * 200; cam.z = Math.max(VIEW.w / W, VIEW.h / H) * 1.06; clampCam(); const r0 = performance.now(); render(); perf.render = lerp(perf.render, performance.now() - r0, .1); return; }
  if (S && !S.over && !paused) { acc += dt * S.speed; let n = 0; const t0 = performance.now(); while (acc >= TICK && n < 12) { step(); acc -= TICK; n++; } if (n === 12) acc = 0; if (n) perf.sim = lerp(perf.sim, (performance.now() - t0) / n, .1); }
  const k = UI.keys; if (k && k.size) { const sp = 700 / cam.z * dt; if (k.has('arrowleft') || (k.has('a') && false)) cam.x -= sp; if (k.has('arrowright')) cam.x += sp; if (k.has('arrowup')) cam.y -= sp; if (k.has('arrowdown')) cam.y += sp; clampCam(); }
  const r0 = performance.now(); render(); perf.render = lerp(perf.render, performance.now() - r0, .1);
  if (t - lastHud > 100) { lastHud = t; renderHud(t); }
}

/* ---------- запуск ---------- */
function boot() {
  ['view', 'mini', 'hud', 'log', 'hint', 'sel', 'cmds', 'cmds2', 'abil', 'force', 'fList', 'fBud', 'fBar', 'fSub', 'fTitle', 'deployBar', 'deck', 'menu', 'end', 'settings', 'perf', 'objs', 'clock', 'pts', 'bPause', 'endRes', 'endWhy', 'endStats', 'artList'].forEach(id => E[id] = document.getElementById(id));
  E.artNote = document.createElement('p'); E.artNote.style.cssText = 'margin:0;font-size:12px;color:var(--ok);min-height:16px'; E.artList.after(E.artNote);
  cv = E.view; ctx = cv.getContext('2d'); mini = E.mini; mctx = mini.getContext('2d'); E.bPause.innerHTML = IC.pause;
  genMap(); buildTerrain(); resizeView(); bindInput(); renderArtList(); cam.z = .45; loadPack().then(studioRestore);
  E.bPause.onclick = togglePause; $$('.sp').forEach(b => b.onclick = () => setSpeed(+b.dataset.sp));
  $$('#pickSide .side').forEach(b => b.onclick = () => { side = +b.dataset.side; $$('#pickSide .side').forEach(x => x.classList.toggle('on', x === b)); });
  $$('#pickDiff button').forEach(b => b.onclick = () => { diff = b.dataset.d; $$('#pickDiff button').forEach(x => x.classList.toggle('on', x === b)); });
  $('#bStart').onclick = openForce; $('#bAgain').onclick = startBattle; $('#bHow').onclick = () => { const d = $('#how'); d.open = !d.open; };
  $('#bMenu').onclick = () => { E.end.hidden = true; E.hud.hidden = true; E.menu.hidden = false; UI.menu = true; S = null; };
  $('#bWatch').onclick = () => { E.end.hidden = true; };
  const openSet = () => { renderArtList(); E.settings.hidden = false; }; $('#bSet').onclick = openSet; $('#bSet2').onclick = openSet; $('#bSetClose').onclick = () => { E.settings.hidden = true; };
  $('#swSnd').onclick = e => { SND.on = !SND.on; e.currentTarget.classList.toggle('on', SND.on); }; $('#swPerf').onclick = e => { UI.perf = !UI.perf; e.currentTarget.classList.toggle('on', UI.perf); E.perf.hidden = !UI.perf; };
  $('#bStress').onclick = () => { if (!S) { alert_('Сначала начните бой'); return; } E.settings.hidden = true; stress(120); UI.perf = true; E.perf.hidden = false; $('#swPerf').classList.add('on'); };
  $('#artFile').onchange = e => { studioOpen([...e.target.files]); e.target.value = ''; }; $('#bArtReset').onclick = artResetAll; E.artList.onclick = e => { const k = e.target.dataset && e.target.dataset.rm; if (k) artRemove(k); };
  E.fList.onclick = e => { const b = e.target.closest('[data-f]'); if (!b || b.disabled) return; const c = UI.force[side], id = b.dataset.f, d = +b.dataset.d; c[id] = Math.max(0, (c[id] || 0) + d); if (!c[id]) delete c[id]; const sc = E.fList.scrollTop; renderForce(); E.fList.scrollTop = sc; };
  $('#fAuto').onclick = () => { UI.force[side] = presetCounts(side); renderForce(); }; $('#fClear').onclick = () => { UI.force[side] = {}; renderForce(); };
  $('#fGo').onclick = () => { if (forceN(UI.force[side])) startBattle(); }; $('#fBack').onclick = () => { E.force.hidden = true; E.menu.hidden = false; }; $('#deployGo').onclick = beginBattle;
  E.cmds.onclick = e => { const b = e.target.closest('[data-cmd]'); if (b && !b.disabled) commandBtn(b.dataset.cmd); };
  E.abil.onclick = e => { const b = e.target.closest('[data-ab]'); if (b) abilityBtn(b.dataset.ab); };
  E.sel.onclick = e => { const a = e.target.closest('[data-act]'); if (!a) return; if (a.dataset.act === 'all') selectAll(); else if (a.dataset.act === 'clear') selectOnly(null); else if (a.dataset.act === 'more') E.sel.classList.toggle('open'); };
  E.deck.onclick = e => { if (e.target.closest('[data-close]')) { E.deck.hidden = true; return; } const b = e.target.closest('[data-buy]'); if (b && S) { if (buyUnit(S.player, b.dataset.buy)) { deckSig = ''; renderDeck(); } } };
  requestAnimationFrame(frame);
  window.__game = { get S() { return S; }, newBattle, step, startBattle, stress, issue, selectAll, cam, UI, perf, setSide: v => side = v, aiTick, genMap, ZONE, VIEW, w2s: (x, y) => [(x - cam.x) * cam.z + VIEW.w / 2, (y - cam.y) * cam.z + VIEW.h / 2] };
}
boot();
