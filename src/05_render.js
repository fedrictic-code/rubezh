/* =====================  ОТРИСОВКА  ===================== */
const cam = { x: 1200, y: 750, z: .5 };
const VIEW = { w: 800, h: 600, dpr: 1 };
let cv = null, ctx = null, mini = null, mctx = null, fogCv = null, fogCtx = null, fogImg = null;
const UI = { mode: null, ptr: null, box: null, menu: true, time: 0, hover: null, perf: false };
const wsx = x => (x - cam.x) * cam.z + VIEW.w / 2, wsy = y => (y - cam.y) * cam.z + VIEW.h / 2;
const s2w = (sx, sy) => [(sx - VIEW.w / 2) / cam.z + cam.x, (sy - VIEW.h / 2) / cam.z + cam.y];

function resizeView() {
  const r = cv.getBoundingClientRect(); VIEW.dpr = Math.min(2, window.devicePixelRatio || 1); VIEW.w = Math.max(1, r.width); VIEW.h = Math.max(1, r.height);
  cv.width = Math.round(VIEW.w * VIEW.dpr); cv.height = Math.round(VIEW.h * VIEW.dpr); clampCam();
}
function clampCam() {
  const minZ = Math.max(VIEW.w / W, VIEW.h / H); cam.z = clamp(cam.z, minZ, 2.2);
  const hw = VIEW.w / 2 / cam.z, hh = VIEW.h / 2 / cam.z;
  cam.x = hw * 2 >= W ? W / 2 : clamp(cam.x, hw, W - hw); cam.y = hh * 2 >= H ? H / 2 : clamp(cam.y, hh, H - hh);
}
let fogMid = null, fogBig = null;
function fogPaint() {
  if (!fogCv) {
    fogCv = document.createElement('canvas'); fogCv.width = GW; fogCv.height = GH; fogCtx = fogCv.getContext('2d'); fogImg = fogCtx.createImageData(GW, GH);
    for (let i = 0; i < GW * GH; i++) { fogImg.data[i * 4] = 6; fogImg.data[i * 4 + 1] = 10; fogImg.data[i * 4 + 2] = 14; }
    fogMid = document.createElement('canvas'); fogMid.width = GW * 2; fogMid.height = GH * 2; fogBig = document.createElement('canvas'); fogBig.width = GW * 5; fogBig.height = GH * 5;
  }
  const f = S.fog, d = fogImg.data; for (let i = 0; i < f.length; i++) d[i * 4 + 3] = f[i] === 2 ? 0 : f[i] === 1 ? 92 : 190;
  fogCtx.putImageData(fogImg, 0, 0);
  // двухступенчатое сглаживание: края тумана без «ступенек»
  const m = fogMid.getContext('2d'); m.imageSmoothingEnabled = true; m.clearRect(0, 0, fogMid.width, fogMid.height); m.drawImage(fogCv, 0, 0, fogMid.width, fogMid.height);
  const b = fogBig.getContext('2d'); b.imageSmoothingEnabled = true; b.clearRect(0, 0, fogBig.width, fogBig.height);
  try { b.filter = 'blur(5px)'; } catch (e) { } b.drawImage(fogMid, 0, 0, fogBig.width, fogBig.height); try { b.filter = 'none'; } catch (e) { }
  S.fogDirty = false;
}
const FOGV = c => S.fog[c] === 2;

/* ---------- юниты ---------- */
const BODY = ['#3b6a9c', '#8e3d36'], HELM = ['#7fb0e0', '#e08c82'];
function drawMen(g, sq) {
  const s = sq.side, rad = Math.max(3.7, 3.0 / cam.z), sid = SIDES[s].id, ca = Math.cos(sq.fa), sa = Math.sin(sq.fa);
  for (let i = 0; i < sq.crew.length; i++) {
    const cm = sq.crew[i]; if (!cm.ok) continue;
    const o = [cm.dx, cm.dy], bob = sq.moving ? Math.sin(S.t * 9 + i * 1.7) * .7 : 0, px = sq.x + o[0] + bob * sa, py = sq.y + o[1] - bob * ca;
    g.fillStyle = 'rgba(0,0,0,.28)'; g.beginPath(); g.ellipse(px + 1.6, py + 2, rad, rad * .8, 0, 0, TAU); g.fill();
    const k = cm.k || (cm.k = soldierKind(cm)), a = art('sol_' + k + '_' + sid) || art('soldier_' + sid);
    if (a) { const w = rad * 3.6, h = w * a.h / a.w; g.save(); g.translate(px, py); g.rotate(sq.fa); g.drawImage(a.img, -w / 2, -h / 2, w, h); g.restore(); continue; }
    { const sp = soldierSprite(s, k), u = rad * .95; g.save(); g.translate(px, py); g.rotate(sq.fa); g.drawImage(sp.c, -sp.X * u, -sp.X * u, sp.X * 2 * u, sp.X * 2 * u); g.restore(); continue; }
    g.strokeStyle = '#1b1f22'; g.lineWidth = rad * .5; g.beginPath(); g.moveTo(px, py); g.lineTo(px + ca * rad * 2.4, py + sa * rad * 2.4); g.stroke();
    g.fillStyle = BODY[s]; g.beginPath(); g.arc(px, py, rad, 0, TAU); g.fill(); g.fillStyle = HELM[s]; g.beginPath(); g.arc(px - ca * rad * .1, py - sa * rad * .1, rad * .58, 0, TAU); g.fill();
  }
  if (sq.type === 'mortar') { g.strokeStyle = '#2a2f33'; g.lineWidth = 2; g.beginPath(); g.moveTo(sq.x - 4, sq.y + 3); g.lineTo(sq.x + Math.cos(sq.fa) * 9, sq.y + Math.sin(sq.fa) * 9 - 3); g.stroke(); g.fillStyle = '#3a4045'; g.beginPath(); g.arc(sq.x - 4, sq.y + 3, 3.4, 0, TAU); g.fill(); }
  if (sq.fort > .6 && !sq.moving) { g.strokeStyle = 'rgba(70,56,36,.55)'; g.lineWidth = 2; g.beginPath(); g.arc(sq.x, sq.y, 17, Math.PI * .1 + sq.fa, Math.PI * .9 + sq.fa); g.stroke(); }
}
function drawVeh(g, sq, wreck) {
  const t = sq.t || TYPES[sq.type], L = t.len, Wd = t.wid, s = sq.side, a = art('veh_' + sq.type + '_' + SIDES[s].id);
  const aw = art('veh_' + t.id) || art('veh_' + sq.type + '_' + SIDES[s].id), ah = aw ? null : art('veh_' + t.id + '_hull'), at = ah ? art('veh_' + t.id + '_turret') : null;
  if (aw || ah) {
    const a = artSil(aw || ah), len = ((a.meta && a.meta.len) || L) * 1.3, hh = len * a.h / a.w;
    g.save(); g.translate(sq.x + 2.6, sq.y + 3.6); g.rotate(sq.fa); g.globalAlpha = .32; g.drawImage(a.sh, -len / 2, -hh / 2, len, hh); g.restore();
    g.save(); g.translate(sq.x, sq.y); g.rotate(sq.fa); g.drawImage(wreck ? a.dead : a.img, -len / 2, -hh / 2, len, hh);
    if (at) { const b = artSil(at), tl = ((b.meta && b.meta.len) || L * .9) * 1.3, th = tl * b.h / b.w, m = b.meta || {}; g.translate((m.ox ?? L * .04) * 1.3, (m.oy || 0) * 1.3); g.rotate((wreck ? sq.fa + .5 : (sq.ta || sq.fa)) - sq.fa); g.drawImage(wreck ? b.dead : b.img, -tl / 2, -th / 2, tl, th); }
    g.restore(); return;
  }
  if (!SPC.off) {
    const sp = vehSprite(t, s), ta = wreck ? sq.fa + .5 : (sq.ta || sq.fa);
    g.save(); g.translate(sq.x + 2.6, sq.y + 3.6); g.rotate(sq.fa); g.scale(1.3, 1.3); g.globalAlpha = .32; g.drawImage(sp.hullSh, -sp.hw / 2, -sp.hh / 2, sp.hw, sp.hh); g.restore();
    g.save(); g.translate(sq.x, sq.y); g.rotate(sq.fa); g.scale(1.3, 1.3); g.drawImage(wreck ? sp.hullDead : sp.hull, -sp.hw / 2, -sp.hh / 2, sp.hw, sp.hh); g.translate(sp.tx, sp.ty); g.rotate(ta - sq.fa);
    g.save(); g.translate(2.2, 2.8); g.globalAlpha = .28; g.drawImage(sp.turSh, -sp.tur.w / 2, -sp.tur.h / 2, sp.tur.w, sp.tur.h); g.restore();
    g.drawImage(wreck ? sp.turDead : sp.tur.c, -sp.tur.w / 2, -sp.tur.h / 2, sp.tur.w, sp.tur.h); g.restore(); return;
  }
  g.save(); g.translate(sq.x, sq.y); g.rotate(sq.fa);
  g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(-L / 2 + 3, -Wd / 2 + 4, L, Wd);
  if (a) { const ww = L * a.h / a.w * (L / L); g.drawImage(a.img, -L / 2, -ww / 2, L, ww); if (wreck) { g.fillStyle = 'rgba(15,12,10,.6)'; g.fillRect(-L / 2, -ww / 2, L, ww); } g.restore(); return; }
  g.fillStyle = '#20252a'; g.fillRect(-L / 2, -Wd / 2, L, Wd * .26); g.fillRect(-L / 2, Wd / 2 - Wd * .26, L, Wd * .26);
  g.fillStyle = wreck ? '#2b2724' : '#566048'; g.beginPath(); g.roundRect(-L / 2 + 1, -Wd / 2 + Wd * .16, L - 2, Wd * .68, 2); g.fill();
  if (!wreck) { g.fillStyle = SIDES[s].color; g.fillRect(-L * .34, -Wd * .16, L * .2, Wd * .32); g.fillStyle = SIDES[s].accent; g.fillRect(-L * .34, -Wd * .16, L * .05, Wd * .32); }
  g.restore();
  g.save(); g.translate(sq.x, sq.y); const ta = wreck ? sq.fa + .5 : (sq.ta || sq.fa); g.rotate(ta);
  g.fillStyle = wreck ? '#1c1a18' : '#4a5440'; g.beginPath(); g.arc(L * .06, 0, Wd * .36, 0, TAU); g.fill();
  g.strokeStyle = wreck ? '#1c1a18' : '#2b3128'; g.lineWidth = sq.type === 'tank' ? 2.4 : 1.6; g.beginPath(); g.moveTo(L * .1, 0); g.lineTo(L * (sq.type === 'tank' ? .72 : .52), 0); g.stroke();
  g.restore();
}
function drawPlates(g, sq, enemy, sel) {
  const sx = wsx(sq.x), sy = wsy(sq.y); if (sx < -40 || sy < -40 || sx > VIEW.w + 40 || sy > VIEW.h + 40) return;
  const c = SIDES[sq.side], px = sx - 15, py = sy - Math.min(30, 14 + 10 * cam.z) - (sq.t.veh ? 4 : 0);
  if (sel) { g.strokeStyle = '#e3b341'; g.lineWidth = 2; g.beginPath(); g.arc(sx, sy, 17 + (sq.t.veh ? 4 : 0), 0, TAU); g.stroke(); g.fillStyle = 'rgba(227,179,65,.10)'; g.fill(); }
  g.fillStyle = c.dark; g.globalAlpha = .94; g.beginPath(); g.roundRect(px, py, 30, 15, 4); g.fill(); g.globalAlpha = 1;
  g.strokeStyle = sel ? '#e3b341' : c.color; g.lineWidth = sel ? 2 : 1.4; g.stroke();
  const ic = art('icon_' + sq.type); if (ic) g.drawImage(ic.img, px + 2, py + 1.5, 12, 12); else drawGlyph(g, sq.type, px + 8.5, py + 7.5, 9, '#f1f3f4');
  if (!enemy && sq.no) { g.fillStyle = sel ? '#e3b341' : '#0c1013'; g.strokeStyle = sel ? '#e3b341' : c.color; g.lineWidth = 1.4; g.beginPath(); g.arc(px - 2, py + 2, 7, 0, TAU); g.fill(); g.stroke(); g.fillStyle = sel ? '#17130a' : '#eef1f3'; g.font = '700 9px "IBM Plex Mono",monospace'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(sq.no + '', px - 2, py + 2.5); }
  if (!enemy) { g.fillStyle = '#eef1f3'; g.font = '600 10px "IBM Plex Mono",monospace'; g.textAlign = 'right'; g.textBaseline = 'middle'; g.fillText(sq.t.veh ? Math.max(1, Math.ceil(sq.hp / sq.hpMax * 100)) + '' : sq.men + '', px + 28, py + 8); }
  if (sq.cargo) { g.fillStyle = '#e3b341'; g.font = '700 9px "IBM Plex Mono",monospace'; g.textAlign = 'left'; g.fillText('+' + (S.byId.get(sq.cargo) ? S.byId.get(sq.cargo).men : ''), px + 2, py - 4); }
  if (!enemy && (sq.stance === 'ambush' || sq.stance === 'cease' || sq.sneak)) { g.fillStyle = '#e3b341'; g.font = '700 9px "IBM Plex Mono",monospace'; g.textAlign = 'right'; g.fillText(sq.stance === 'ambush' ? 'ЗАСАДА' : sq.stance === 'cease' ? 'ТИХО' : 'СКРЫТНО', px + 30, py - 4); }
  if (!enemy) {
    const m = clamp(sq.morale / 100, 0, 1); g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(px, py + 17, 30, 3); g.fillStyle = m > .6 ? '#7ec27a' : m > .35 ? '#e8b04a' : '#e0584a'; g.fillRect(px, py + 17, 30 * m, 3);
    if (sq.supp > 4) { g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(px, py + 21, 30, 2.5); g.fillStyle = '#ee8a3a'; g.fillRect(px, py + 21, 30 * sq.supp / 100, 2.5); }
  }
  if (sq.rout) { g.fillStyle = '#e0584a'; g.font = '700 9px "IBM Plex Sans",sans-serif'; g.textAlign = 'center'; g.fillText('ОТХОД', sx, py - 5); }
  else if (!enemy && sq.supp >= 75) { g.fillStyle = '#ee8a3a'; g.font = '700 9px "IBM Plex Sans",sans-serif'; g.textAlign = 'center'; g.fillText('ПРИЖАТЫ', sx, py - 5); }
  if ((sel || cam.z > .85) && !enemy) { g.fillStyle = 'rgba(240,244,246,.92)'; g.font = '500 10px "IBM Plex Sans",sans-serif'; g.textAlign = 'center'; g.textBaseline = 'top'; g.strokeStyle = 'rgba(0,0,0,.7)'; g.lineWidth = 3; g.strokeText(sq.name, sx, sy + 17); g.fillText(sq.name, sx, sy + 17); }
}

/* ---------- кадр ---------- */
function render() {
  const g = ctx, dpr = VIEW.dpr; g.setTransform(1, 0, 0, 1, 0, 0); g.fillStyle = '#0b0f12'; g.fillRect(0, 0, cv.width, cv.height);
  const k = cam.z * dpr; g.setTransform(k, 0, 0, k, (VIEW.w / 2 - cam.x * cam.z) * dpr, (VIEW.h / 2 - cam.y * cam.z) * dpr);
  g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'medium';
  const x0 = clamp(cam.x - VIEW.w / 2 / cam.z, 0, W), x1 = clamp(cam.x + VIEW.w / 2 / cam.z, 0, W), y0 = clamp(cam.y - VIEW.h / 2 / cam.z, 0, H), y1 = clamp(cam.y + VIEW.h / 2 / cam.z, 0, H);
  if (terrainCanvas) {
    if (S) while (S.craterQ.length) { const [cx, cy, r] = S.craterQ.pop(), tg = terrainCanvas.getContext('2d'); tg.save(); tg.scale(TS, TS); tg.fillStyle = 'rgba(55,42,28,.55)'; tg.beginPath(); tg.ellipse(cx, cy, r + 3, r * .8 + 3, 0, 0, TAU); tg.fill(); tg.fillStyle = '#36291a'; tg.beginPath(); tg.ellipse(cx, cy, r, r * .78, 0, 0, TAU); tg.fill(); tg.restore(); }
    g.drawImage(terrainCanvas, x0 * TS, y0 * TS, (x1 - x0) * TS, (y1 - y0) * TS, x0, y0, x1 - x0, y1 - y0);
  }
  if (!S) return;
  if (S.fogDirty || !fogCv) fogPaint(); g.drawImage(fogBig, 0, 0, W, H);
  const vx0 = x0 - 60, vx1 = x1 + 60, vy0 = y0 - 60, vy1 = y1 + 60, inV = e => e.x > vx0 && e.x < vx1 && e.y > vy0 && e.y < vy1;
  // рубежи
  for (const o of S.objs) {
    const col = o.owner === 0 ? SIDES[0].color : o.owner === 1 ? SIDES[1].color : '#d8dde0';
    g.fillStyle = o.owner >= 0 ? col + '18' : 'rgba(216,221,224,.06)'; g.beginPath(); g.arc(o.x, o.y, o.r, 0, TAU); g.fill();
    g.setLineDash([10, 8]); g.strokeStyle = col; g.globalAlpha = .75; g.lineWidth = 2 / cam.z * .9 + .6; g.beginPath(); g.arc(o.x, o.y, o.r, 0, TAU); g.stroke(); g.setLineDash([]); g.globalAlpha = 1;
    if (Math.abs(o.ctrl) > .02) { const sd = o.ctrl > 0 ? 1 : 0; g.strokeStyle = SIDES[sd].color; g.lineWidth = 4 / cam.z * .8 + 1.5; g.lineCap = 'round'; g.beginPath(); g.arc(o.x, o.y, o.r - 6, -Math.PI / 2, -Math.PI / 2 + TAU * Math.abs(o.ctrl)); g.stroke(); g.lineCap = 'butt'; }
  }
  // отметки приказов
  { const nowp = performance.now(); for (let i = UI.pings.length - 1; i >= 0; i--) { const q = UI.pings[i], a = (nowp - q.t) / 900; if (a > 1) { UI.pings.splice(i, 1); continue; } g.strokeStyle = (q.kind === 'atk' || q.kind === 'fight' || q.kind === 'fire' ? 'rgba(238,138,58,' : 'rgba(227,179,65,') + (1 - a).toFixed(2) + ')'; g.lineWidth = 2.2 / cam.z * .9; g.beginPath(); g.arc(q.x, q.y, (7 + a * 24) / Math.max(.55, cam.z * .9), 0, TAU); g.stroke(); } }
  // следы техники и обломки
  for (const b of S.bodies) { if (!b || b.x < vx0 || b.x > vx1 || b.y < vy0 || b.y > vy1) continue; if (S.fog[cellIdx(b.x, b.y)] === 0) continue; g.fillStyle = b.side === 0 ? 'rgba(40,70,110,.75)' : 'rgba(110,45,40,.75)'; g.beginPath(); g.ellipse(b.x, b.y, 2.6, 1.5, b.x, 0, TAU); g.fill(); }
  for (const w of S.wrecks) { if (w.x < vx0 || w.x > vx1 || w.y < vy0 || w.y > vy1) continue; const cc = cellIdx(w.x, w.y); if (S.fog[cc] === 0) continue; drawVeh(g, { x: w.x, y: w.y, fa: w.fa, type: w.type, side: w.side, t: w.vt }, true); if (S.t - w.t < 240) { g.fillStyle = 'rgba(60,55,52,' + (.35 - (S.t - w.t) / 800) + ')'; const ph = S.t * .6; for (let i = 0; i < 3; i++) { const q = (ph + i / 3) % 1; g.beginPath(); g.arc(w.x + Math.sin(q * 5 + i) * 4, w.y - q * 26, 5 + q * 8, 0, TAU); g.fill(); } } }
  // маршруты выделенных
  g.lineWidth = 1.6 / cam.z; g.setLineDash([6 / cam.z, 6 / cam.z]);
  for (const id of S.sel) {
    const sq = S.byId.get(id); if (!sq || sq.dead || !sq.order) continue; const o = sq.order;
    if (o.kind === 'attack') { const e = S.byId.get(o.targetId); if (e && !e.dead) { g.strokeStyle = 'rgba(224,88,74,.85)'; g.beginPath(); g.moveTo(sq.x, sq.y); g.lineTo(e.x, e.y); g.stroke(); } continue; }
    if (o.kind === 'fire') { g.strokeStyle = 'rgba(238,138,58,.9)'; g.beginPath(); g.moveTo(sq.x, sq.y); g.lineTo(o.x, o.y); g.stroke(); g.beginPath(); g.arc(o.x, o.y, 40, 0, TAU); g.stroke(); continue; }
    if (!sq.path || sq.pi >= sq.path.length) continue;
    g.strokeStyle = o.kind === 'fight' ? 'rgba(238,138,58,.9)' : o.kind === 'retreat' ? 'rgba(160,170,178,.8)' : 'rgba(227,179,65,.85)'; g.beginPath(); g.moveTo(sq.x, sq.y); for (let i = sq.pi; i < sq.path.length; i++) g.lineTo(sq.path[i].x, sq.path[i].y); g.stroke();
    const e = sq.path[sq.path.length - 1]; g.save(); g.setLineDash([]); g.translate(e.x, e.y); g.rotate(Math.PI / 4); const r = 5 / cam.z * .9 + 2; g.strokeRect(-r, -r, 2 * r, 2 * r); g.restore();
  }
  g.setLineDash([]);
  // отряды
  const vis = [];
  if (S.deploying) { const z = ZONE[S.player]; g.fillStyle = 'rgba(227,179,65,.08)'; g.fillRect(z.x0, z.y0, z.x1 - z.x0, z.y1 - z.y0); g.strokeStyle = 'rgba(227,179,65,.7)'; g.lineWidth = 2 / cam.z; g.setLineDash([10 / cam.z, 8 / cam.z]); g.strokeRect(z.x0, z.y0, z.x1 - z.x0, z.y1 - z.y0); g.setLineDash([]); }
  for (const sq of S.squads) { if (sq.dead || sq.carried || !inV(sq)) continue; const mine = sq.side === S.player, seen = mine || isSpotted(sq, S.player); if (!seen) continue; vis.push(sq); if (sq.t.veh) drawVeh(g, sq, false); else drawMen(g, sq); }
  // дым горящей техники
  for (const sq of vis) if (sq.t.veh && sq.smoking) { g.fillStyle = 'rgba(40,38,36,.35)'; const ph = S.t * .8 + sq.id; for (let i = 0; i < 3; i++) { const q = (ph + i / 3) % 1; g.beginPath(); g.arc(sq.x + Math.sin(q * 6 + i) * 3, sq.y - q * 24, 4 + q * 7, 0, TAU); g.fill(); } }
  // трассеры
  g.lineCap = 'round';
  for (const t of S.tr) {
    if (!t.on) continue; const age = S.t - t.t0; if (age > t.life) { t.on = false; continue; } if (!(FOGV(cellIdx(t.x1, t.y1)) || FOGV(cellIdx(t.x0, t.y0)))) continue;
    const f = age / t.life, a = Math.max(0, f - .4), b = Math.min(1, f + .15); g.strokeStyle = t.side === 0 ? 'rgba(255,238,170,.95)' : 'rgba(255,170,130,.95)'; g.lineWidth = Math.max(.9, 1.3 / cam.z * .8);
    g.beginPath(); g.moveTo(lerp(t.x0, t.x1, a), lerp(t.y0, t.y1, a)); g.lineTo(lerp(t.x0, t.x1, b), lerp(t.y0, t.y1, b)); g.stroke();
  }
  for (const p of S.pend) if (p.kind === 'shot' && S.t < p.at) { const f = (S.t - p.t0) / (p.at - p.t0), x = lerp(p.ax, p.x1, f), y = lerp(p.ay, p.y1, f); if (!(FOGV(cellIdx(x, y)) || FOGV(cellIdx(p.ax, p.ay)))) continue; g.strokeStyle = 'rgba(255,236,190,.85)'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(lerp(p.ax, p.x1, Math.max(0, f - .12)), lerp(p.ay, p.y1, Math.max(0, f - .12))); g.lineTo(x, y); g.stroke(); }
  g.lineCap = 'butt';
  // взрывы
  for (const e of S.ex) {
    if (!e.on) continue; const age = S.t - e.t0; if (age > e.life) { e.on = false; continue; } if (!FOGV(cellIdx(e.x, e.y))) continue; const p = age / e.life;
    if (e.kind === 1) { g.fillStyle = 'rgba(255,224,150,' + (1 - p) * .9 + ')'; g.beginPath(); g.arc(e.x, e.y, e.r * (.6 + p), 0, TAU); g.fill(); continue; }
    g.fillStyle = 'rgba(70,60,52,' + (1 - p) * .5 + ')'; g.beginPath(); g.arc(e.x, e.y - p * 8, e.r * (.7 + p * 1.1), 0, TAU); g.fill();
    if (p < .5) { g.fillStyle = 'rgba(255,190,90,' + (1 - p * 2) * .9 + ')'; g.beginPath(); g.arc(e.x, e.y, e.r * (.4 + p * 1.1), 0, TAU); g.fill(); }
  }
  // дым
  for (const s of S.smokes) { if (s.x < vx0 - 80 || s.x > vx1 + 80 || s.y < vy0 - 80 || s.y > vy1 + 80) continue; for (let i = 0; i < 9; i++) { const a = i * 2.4 + S.t * .12 * (i % 2 ? 1 : -1), r = s.r * (.2 + (i % 4) * .17); g.fillStyle = 'rgba(224,228,230,' + (.34 - (i % 3) * .05) + ')'; g.beginPath(); g.arc(s.x + Math.cos(a) * r, s.y + Math.sin(a) * r, s.r * (.34 + (i % 3) * .06), 0, TAU); g.fill(); } }
  // дроны
  for (const d of S.drones) {
    if (d.side !== S.player && !FOGV(cellIdx(d.x, d.y))) continue; const c = SIDES[d.side].color;
    if (d.side === S.player) { g.setLineDash([8, 8]); g.strokeStyle = c; g.globalAlpha = .5; g.lineWidth = 1.4 / cam.z * .8; g.beginPath(); g.arc(d.x, d.y, d.vision, 0, TAU); g.stroke(); g.setLineDash([]); g.globalAlpha = 1; }
    g.save(); g.translate(d.x, d.y); g.rotate(S.t * 6); g.strokeStyle = '#111'; g.lineWidth = 2; g.beginPath(); g.moveTo(-7, -7); g.lineTo(7, 7); g.moveTo(7, -7); g.lineTo(-7, 7); g.stroke(); g.fillStyle = c; g.beginPath(); g.arc(0, 0, 3, 0, TAU); g.fill(); g.restore();
  }
  for (const f of S.fpv) { if (f.side !== S.player && !FOGV(cellIdx(f.x, f.y))) continue; const tg = S.byId.get(f.tid); if (tg) { g.strokeStyle = SIDES[f.side].color; g.globalAlpha = .55; g.lineWidth = 1; g.beginPath(); g.moveTo(f.x, f.y); g.lineTo(tg.x, tg.y); g.stroke(); g.globalAlpha = 1; } g.fillStyle = '#fff'; g.beginPath(); g.arc(f.x, f.y, 2.6, 0, TAU); g.fill(); g.fillStyle = SIDES[f.side].color; g.beginPath(); g.arc(f.x, f.y, 1.6, 0, TAU); g.fill(); }
  // прицел способности
  if (UI.ptr && UI.mode) {
    const m = UI.mode, p = UI.ptr; g.setLineDash([8, 6]); g.lineWidth = 2 / cam.z * .9; g.strokeStyle = '#e3b341';
    if (m === 'drone') { g.beginPath(); g.arc(p.x, p.y, 430, 0, TAU); g.stroke(); }
    else if (m === 'smoke') { g.beginPath(); g.arc(p.x, p.y, 58, 0, TAU); g.stroke(); }
    else if (m === 'fire') { g.strokeStyle = '#ee8a3a'; g.beginPath(); g.arc(p.x, p.y, 40, 0, TAU); g.stroke(); for (const id of S.sel) { const sq = S.byId.get(id); if (sq && sq.t.mortar) { g.globalAlpha = .35; g.beginPath(); g.arc(sq.x, sq.y, sq.t.range, 0, TAU); g.stroke(); g.beginPath(); g.arc(sq.x, sq.y, sq.t.minRange, 0, TAU); g.stroke(); g.globalAlpha = 1; } } }
    g.setLineDash([]);
  }
  // экранные элементы
  g.setTransform(dpr, 0, 0, dpr, 0, 0); g.lineJoin = 'round';
  for (const o of S.objs) { const sx = wsx(o.x), sy = wsy(o.y - o.r); if (sx < -80 || sx > VIEW.w + 80 || sy < -40 || sy > VIEW.h + 40) continue; g.font = '600 11px "Oswald","IBM Plex Sans",sans-serif'; g.textAlign = 'center'; g.textBaseline = 'bottom'; g.strokeStyle = 'rgba(0,0,0,.75)'; g.lineWidth = 3.5; g.strokeText(o.name.toUpperCase(), sx, sy - 2); g.fillStyle = o.owner >= 0 ? '#fff' : '#cfd5d9'; g.fillText(o.name.toUpperCase(), sx, sy - 2); }
  // призраки
  for (const e of S.squads) {
    if (e.dead || e.side === S.player || isSpotted(e, S.player)) continue; const lk = e.lk[S.player]; if (!lk || S.t - e.seenAt[S.player] > 10) continue;
    const sx = wsx(lk.x), sy = wsy(lk.y); if (sx < -30 || sy < -30 || sx > VIEW.w + 30 || sy > VIEW.h + 30) continue; g.globalAlpha = .55 * (1 - (S.t - e.seenAt[S.player]) / 10); g.setLineDash([3, 3]); g.strokeStyle = SIDES[e.side].color; g.lineWidth = 1.4; g.beginPath(); g.roundRect(sx - 15, sy - 24, 30, 15, 4); g.stroke(); g.setLineDash([]); drawGlyph(g, e.type, sx, sy - 16.5, 9, SIDES[e.side].color); g.globalAlpha = 1;
  }
  for (const sq of vis) drawPlates(g, sq, sq.side !== S.player, S.sel.has(sq.id));
  if (UI.hover && UI.hover.id) { const e = S.byId.get(UI.hover.id); if (e && !e.dead) { g.strokeStyle = '#e0584a'; g.lineWidth = 1.6; g.beginPath(); g.arc(wsx(e.x), wsy(e.y), 20, 0, TAU); g.stroke(); } }
  if (UI.box) { const b = UI.box; g.fillStyle = 'rgba(227,179,65,.12)'; g.strokeStyle = '#e3b341'; g.lineWidth = 1.2; g.fillRect(Math.min(b.x0, b.x1), Math.min(b.y0, b.y1), Math.abs(b.x1 - b.x0), Math.abs(b.y1 - b.y0)); g.strokeRect(Math.min(b.x0, b.x1), Math.min(b.y0, b.y1), Math.abs(b.x1 - b.x0), Math.abs(b.y1 - b.y0)); }
}

/* ---------- мини-карта ---------- */
function renderMini() {
  if (!mctx || !miniBase) return; const w = mini.width, h = mini.height, g = mctx; g.clearRect(0, 0, w, h); g.drawImage(miniBase, 0, 0, w, h);
  if (!S) return; if (fogBig) g.drawImage(fogBig, 0, 0, w, h); const sx = w / W, sy = h / H;
  for (const o of S.objs) { g.strokeStyle = o.owner === 0 ? SIDES[0].color : o.owner === 1 ? SIDES[1].color : '#ddd'; g.lineWidth = 1.5; g.beginPath(); g.arc(o.x * sx, o.y * sy, Math.max(4, o.r * sx), 0, TAU); g.stroke(); }
  for (const sq of S.squads) { if (sq.dead || sq.carried) continue; const mine = sq.side === S.player; if (!mine && !isSpotted(sq, S.player)) continue; g.fillStyle = SIDES[sq.side].color; const r = sq.t.veh ? 3 : 2.3; g.fillRect(sq.x * sx - r, sq.y * sy - r, r * 2, r * 2); if (S.sel.has(sq.id)) { g.strokeStyle = '#e3b341'; g.lineWidth = 1; g.strokeRect(sq.x * sx - r - 1, sq.y * sy - r - 1, r * 2 + 2, r * 2 + 2); } }
  for (const d of S.drones) if (d.side === S.player) { g.fillStyle = '#fff'; g.fillRect(d.x * sx - 1.5, d.y * sy - 1.5, 3, 3); }
  const hw = VIEW.w / 2 / cam.z, hh = VIEW.h / 2 / cam.z; g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 1.2; g.strokeRect((cam.x - hw) * sx, (cam.y - hh) * sy, hw * 2 * sx, hh * 2 * sy);
}
