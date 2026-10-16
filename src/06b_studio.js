/* =====================  СТУДИЯ ГРАФИКИ  =====================
   Загрузка своих картинок: поворот, удаление фона, обрезка, размер, корпус и башня отдельно.
   Результат хранится в браузере (IndexedDB) и подхватывается при следующем запуске. */
const SOL_KINDS = [['rifle', 'Стрелок'], ['lead', 'Командир'], ['gren', 'Гранатомётчик'], ['mg', 'Пулемётчик'], ['at', 'Противотанкист'], ['sniper', 'Снайпер']];
function artTargets() {
  const out = [], vs = Object.values(VARS).filter(v => v.veh), sn = ['ВСУ', 'ВС РФ'];
  const sd = v => v.side < 0 ? '' : ' (' + sn[v.side] + ')';
  for (const v of vs) out.push({ key: 'veh_' + v.id, label: v.name + sd(v) + ' — целиком', grp: 'Техника целиком (башня вместе с корпусом)', kind: 'veh', v, len: v.len });
  for (const v of vs) out.push({ key: 'veh_' + v.id + '_hull', label: v.name + sd(v) + ' — корпус', grp: 'Техника: корпус (башня отдельно, вращается)', kind: 'hull', v, len: v.len });
  for (const v of vs) out.push({ key: 'veh_' + v.id + '_turret', label: v.name + sd(v) + ' — башня', grp: 'Техника: башня (ось вращения — точка на картинке)', kind: 'turret', v, len: v.len * .9 });
  for (const [k, n] of SOL_KINDS) for (const s of [0, 1]) out.push({ key: 'sol_' + k + '_' + SIDES[s].id, label: n + ' (' + sn[s] + ')', grp: 'Пехота: вид сверху, смотрит вправо', kind: 'sol' });
  for (const s of [0, 1]) out.push({ key: 'soldier_' + SIDES[s].id, label: 'Любой боец (' + sn[s] + ')', grp: 'Пехота: вид сверху, смотрит вправо', kind: 'sol' });
  for (const a of ART_KEYS) if (a[0] === 'map') out.push({ key: 'map', label: 'Карта целиком', grp: 'Карта и значки', kind: 'map' }); else if (a[0].startsWith('icon_')) out.push({ key: a[0], label: a[1], grp: 'Карта и значки', kind: 'icon' });
  for (const a of ART_KEYS) if (a[0].startsWith('veh_')) out.push({ key: a[0], label: a[1] + ' (по классу)', grp: 'Техника по классу и стороне', kind: 'veh', len: a[0].includes('tank') ? 30 : 24 });
  return out;
}
const artTarget = key => artTargets().find(t => t.key === key);

/* ---------- хранилище ---------- */
const ARTDB = {
  open() { return this.p || (this.p = new Promise(res => { try { const r = indexedDB.open('rubezh-art', 1); r.onupgradeneeded = () => r.result.createObjectStore('a'); r.onsuccess = () => res(r.result); r.onerror = () => res(null); } catch (e) { res(null); } })); },
  async tx(mode, fn) { const db = await this.open(); if (!db) return null; return new Promise(res => { try { const t = db.transaction('a', mode), st = t.objectStore('a'), r = fn(st); t.oncomplete = () => res(r && 'result' in r ? r.result : true); t.onerror = t.onabort = () => res(null); } catch (e) { res(null); } }); },
  put(k, v) { return this.tx('readwrite', s => s.put(v, k)); }, del(k) { return this.tx('readwrite', s => s.delete(k)); }, clear() { return this.tx('readwrite', s => s.clear()); },
  async all() { const db = await this.open(); if (!db) return []; return new Promise(res => { try { const out = [], r = db.transaction('a').objectStore('a').openCursor(); r.onsuccess = () => { const c = r.result; if (c) { out.push([c.key, c.value]); c.continue(); } else res(out); }; r.onerror = () => res([]); } catch (e) { res([]); } }); }
};
async function loadPack() {
  if (typeof ART_PACK === 'undefined') return 0; let n = 0;
  for (const k in ART_PACK) { const v = ART_PACK[k]; if (await loadArt(k, v.url)) { ART[k].meta = v.meta || null; n++; } }
  if (n) { for (const c in iconCache) delete iconCache[c]; buildTerrain(); selSig = ''; deckSig = ''; renderArtList(); }
  return n;
}
async function studioRestore() {
  const all = await ARTDB.all(); let n = 0;
  for (const [k, v] of all) { if (await loadArt(k, v.url)) { ART[k].meta = v.meta || null; n++; } }
  if (n) { for (const c in iconCache) delete iconCache[c]; buildTerrain(); selSig = ''; deckSig = ''; renderArtList(); }
}
function artRemove(k) { delete ART[k]; ARTDB.del(k); for (const c in iconCache) delete iconCache[c]; if (k === 'map') buildTerrain(); selSig = ''; deckSig = ''; renderArtList(); }
function artResetAll() { for (const k in ART) delete ART[k]; ARTDB.clear(); for (const k in iconCache) delete iconCache[k]; buildTerrain(); selSig = ''; deckSig = ''; renderArtList(); alert_('Графика сброшена'); }
function artSil(a) { if (!a.sh) { const c = document.createElement('canvas'); c.width = a.w; c.height = a.h; c.getContext('2d').drawImage(a.img, 0, 0); a.sh = spCopy(c, 'source-in', '#000'); a.dead = spCopy(c, 'source-atop', 'rgba(16,12,10,.8)'); } return a; }
function renderArtList() {
  const keys = Object.keys(ART); const nm = k => { const t = artTarget(k); return t ? t.label : k; };
  E.artList.innerHTML = keys.length ? keys.map(k => '<div><span>' + nm(k) + ' <code>' + k + '</code></span><button data-rm="' + k + '">убрать</button></div>').join('') : '<div><small style="color:var(--mut)">Пока везде встроенная графика. Нажмите «Добавить файлы».</small></div>';
}

/* ---------- обработка изображения ---------- */
const STU = { q: [], cur: null, busy: 0 };
function stuMk(w, h) { const c = document.createElement('canvas'); c.width = Math.max(1, Math.round(w)); c.height = Math.max(1, Math.round(h)); return c; }
function removeBg(c, tol, picks) {
  const w = c.width, h = c.height, g = c.getContext('2d', { willReadFrequently: true }), id = g.getImageData(0, 0, w, h), d = id.data;
  const cols = new Map(), add = (x, y) => { const i = (y * w + x) * 4; if (d[i + 3] < 16) return; const k = (d[i] >> 4) << 8 | (d[i + 1] >> 4) << 4 | d[i + 2] >> 4; if (!cols.has(k)) cols.set(k, [d[i], d[i + 1], d[i + 2]]); };
  const q = Math.max(2, Math.min(8, Math.floor(Math.min(w, h) / 30)));
  for (const [cx, cy] of [[0, 0], [w - q, 0], [0, h - q], [w - q, h - q]]) for (let y = 0; y < q; y++) for (let x = 0; x < q; x++) add(cx + x, cy + y);
  const S = (picks && picks.length ? picks : [...cols.values()]).slice(0, 64), T2 = (tol * 1.9) ** 2, bg = new Uint8Array(w * h), stack = new Int32Array(w * h); let sp = 0;
  const match = p => { const i = p * 4; if (d[i + 3] < 16) return true; const r = d[i], gg = d[i + 1], b = d[i + 2]; for (let k = 0; k < S.length; k++) { const s = S[k], dr = r - s[0], dg = gg - s[1], db = b - s[2]; if (dr * dr + dg * dg + db * db <= T2) return true; } return false; };
  const push = p => { if (!bg[p] && match(p)) { bg[p] = 1; stack[sp++] = p; } };
  for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); } for (let y = 0; y < h; y++) { push(y * w); push(y * w + w - 1); }
  while (sp) { const p = stack[--sp], x = p % w; if (x > 0) push(p - 1); if (x < w - 1) push(p + 1); if (p >= w) push(p - w); if (p < w * (h - 1)) push(p + w); }
  // остаётся самая большая связная область
  const lab = new Int32Array(w * h); let best = 0, bestN = 0, nl = 0; const sizes = [0];
  for (let s0 = 0; s0 < w * h; s0++) { if (bg[s0] || lab[s0]) continue; nl++; let n = 0; sp = 0; stack[sp++] = s0; lab[s0] = nl; while (sp) { const p = stack[--sp]; n++; const x = p % w; if (x > 0 && !bg[p - 1] && !lab[p - 1]) { lab[p - 1] = nl; stack[sp++] = p - 1; } if (x < w - 1 && !bg[p + 1] && !lab[p + 1]) { lab[p + 1] = nl; stack[sp++] = p + 1; } if (p >= w && !bg[p - w] && !lab[p - w]) { lab[p - w] = nl; stack[sp++] = p - w; } if (p < w * (h - 1) && !bg[p + w] && !lab[p + w]) { lab[p + w] = nl; stack[sp++] = p + w; } } sizes[nl] = n; if (n > bestN) { bestN = n; best = nl; } }
  for (let p = 0; p < w * h; p++) if (lab[p] !== best) d[p * 4 + 3] = 0;
  // мягкий край: пиксели у прозрачных становятся полупрозрачными
  const a0 = new Uint8Array(w * h); for (let p = 0; p < w * h; p++) a0[p] = d[p * 4 + 3];
  for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) { const p = y * w + x; if (a0[p] && (!a0[p - 1] || !a0[p + 1] || !a0[p - w] || !a0[p + w])) d[p * 4 + 3] = 150; }
  g.putImageData(id, 0, 0); return c;
}
function stuBuild() {
  const c = STU.cur, T = artTarget(c.target), img = c.img, map = T && T.kind === 'map';
  const s0 = Math.min(1, (map ? 3000 : 1200) / Math.max(img.naturalWidth, img.naturalHeight)), w0 = img.naturalWidth * s0, h0 = img.naturalHeight * s0, ang = (c.rot + c.fine) * Math.PI / 180;
  const cw = Math.ceil(Math.abs(w0 * Math.cos(ang)) + Math.abs(h0 * Math.sin(ang))), ch = Math.ceil(Math.abs(w0 * Math.sin(ang)) + Math.abs(h0 * Math.cos(ang)));
  let A = stuMk(cw, ch), g = A.getContext('2d'); g.translate(cw / 2, ch / 2); g.rotate(ang); g.scale(c.flip ? -1 : 1, 1); g.drawImage(img, -w0 / 2, -h0 / 2, w0, h0);
  const cl = Math.round(cw * c.cl / 100), ct = Math.round(ch * c.ct / 100), cr = Math.round(cw * c.cr / 100), cb = Math.round(ch * c.cb / 100), bw = Math.max(4, cw - cl - cr), bh = Math.max(4, ch - ct - cb);
  let B = stuMk(bw, bh); B.getContext('2d').drawImage(A, cl, ct, bw, bh, 0, 0, bw, bh);
  const B0 = stuMk(bw, bh); B0.getContext('2d').drawImage(B, 0, 0); if (c.bg && !map) removeBg(B, c.tol, c.picks);
  let tx = 0, ty = 0, O = B;
  if (!map) { const id = B.getContext('2d', { willReadFrequently: true }).getImageData(0, 0, bw, bh).data; let x0 = bw, y0 = bh, x1 = -1, y1 = -1; for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) if (id[(y * bw + x) * 4 + 3] > 20) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; } if (x1 >= x0) { tx = x0; ty = y0; O = stuMk(x1 - x0 + 1, y1 - y0 + 1); O.getContext('2d').drawImage(B, -x0, -y0); } }
  let pv = { x: O.width / 2, y: O.height / 2 };
  if (c.pv) pv = { x: clamp(c.pv.x * bw - tx, 0, O.width), y: clamp(c.pv.y * bh - ty, 0, O.height) };
  if (T && T.kind === 'turret') { const W = 2 * Math.max(pv.x, O.width - pv.x), H = 2 * Math.max(pv.y, O.height - pv.y), P = stuMk(W, H); P.getContext('2d').drawImage(O, W / 2 - pv.x, H / 2 - pv.y); return { out: P, tx, ty, pv, bw, bh, O, B0 }; }
  return { out: O, tx, ty, pv, bw, bh, O, B0 };
}
function stuDefaultLen(T, out) {
  if (!T || !T.len) return 0; if (T.kind === 'turret') { const h = ART['veh_' + T.v.id + '_hull']; if (h && h.meta && STU.cur.same) return +(out.width / (h.w / h.meta.len)).toFixed(1); }
  return T.len;
}

/* ---------- окно студии ---------- */
function studioOpen(files) {
  STU.q = files.filter(f => /^image\//.test(f.type) || /\.(png|jpe?g|webp|gif|bmp)$/i.test(f.name)); STU.n = STU.q.length; STU.ok = 0; if (!STU.q.length) { alert_('Нужны изображения PNG, JPG или WebP'); return; }
  const el = $('#studio'); el.hidden = false; $('#settings').hidden = true; stuNext();
}
function stuClose() { $('#studio').hidden = true; $('#settings').hidden = false; renderArtList(); if (STU.ok) alert_('Применено: ' + STU.ok); STU.cur = null; }
function stuNext() {
  const f = STU.q.shift(); if (!f) { stuClose(); return; }
  const url = URL.createObjectURL(f), im = new Image();
  im.onload = () => {
    const base = f.name.replace(/\.[^.]+$/, '').toLowerCase(), tg = artTargets(), exact = tg.find(t => t.key === base);
    const g0 = stuMk(8, 8).getContext('2d'); const probe = stuMk(Math.min(64, im.naturalWidth), Math.min(64, im.naturalHeight)), pg = probe.getContext('2d', { willReadFrequently: true }); pg.drawImage(im, 0, 0, probe.width, probe.height); const pd = pg.getImageData(0, 0, probe.width, probe.height).data; let tr = 0; for (let i = 3; i < pd.length; i += 4) if (pd[i] < 16) tr++;
    const hasAlpha = tr > pd.length / 4 * .04;
    STU.cur = { img: im, name: f.name, target: exact ? exact.key : STU.last || tg[0].key, rot: 0, fine: 0, flip: false, bg: !hasAlpha && !(exact && exact.kind === 'map'), tol: 24, cl: 0, ct: 0, cr: 0, cb: 0, pv: null, picks: [], pick: false, len: null, ox: null, oy: null, same: false };
    stuForm(); stuDraw();
  };
  im.onerror = () => { URL.revokeObjectURL(url); stuNext(); }; im.src = url;
}
function stuForm() {
  const c = STU.cur, T = artTarget(c.target), grps = {}; for (const t of artTargets()) (grps[t.grp] = grps[t.grp] || []).push(t);
  const sel = Object.keys(grps).map(g => '<optgroup label="' + g + '">' + grps[g].map(t => '<option value="' + t.key + '"' + (t.key === c.target ? ' selected' : '') + '>' + t.label + '</option>').join('') + '</optgroup>').join('');
  const sl = (id, label, min, max, v, step = 1) => '<label class="sl"><span>' + label + '</span><input type="range" id="' + id + '" min="' + min + '" max="' + max + '" step="' + step + '" value="' + v + '"><b id="' + id + 'V">' + v + '</b></label>';
  const turret = T && T.kind === 'turret', veh = T && ['veh', 'hull', 'turret'].includes(T.kind), map = T && T.kind === 'map';
  $('#studio').innerHTML = '<div class="card wide stu"><div class="fhead"><div><h2 style="margin:0">Свои картинки</h2><p class="sub">' + c.name + ' · осталось файлов: ' + STU.q.length + '</p></div></div>' +
    '<div class="stuBody"><div class="stuPrev"><canvas id="stuCv" width="360" height="260"></canvas><p class="sub" id="stuInfo"></p></div><div class="stuCtl">' +
    '<label class="sl"><span>Назначение</span><select id="stuT">' + sel + '</select></label>' +
    (map ? '' : '<div class="row2" style="margin:2px 0 8px"><button class="ghost" data-r="-90">⟲ 90°</button><button class="ghost" data-r="90">⟳ 90°</button><button class="ghost" id="stuFlip">Отразить</button></div>' + sl('stuFine', 'Подгонка угла, °', -45, 45, c.fine) +
      '<label class="sl chk"><input type="checkbox" id="stuBg"' + (c.bg ? ' checked' : '') + '><span>Убрать фон (цвет — из углов или пипеткой)</span></label>' + sl('stuTol', 'Допуск цвета фона', 4, 80, c.tol) + '<div class="row2" style="margin:2px 0 8px"><button class="ghost' + (c.pick ? ' on' : '') + '" id="stuPick">Пипетка: ' + (c.pick ? 'нажимайте на фон' : 'выбрать цвет фона') + '</button><button class="ghost" id="stuPickClr">Сбросить цвета (' + c.picks.length + ')</button></div>') +
    sl('stuCl', 'Обрезка слева, %', 0, 45, c.cl) + sl('stuCr', 'Обрезка справа, %', 0, 45, c.cr) + sl('stuCt', 'Обрезка сверху, %', 0, 45, c.ct) + sl('stuCb', 'Обрезка снизу, %', 0, 45, c.cb) +
    (veh ? '<label class="sl"><span>Длина в игре, ед. <small>(пусто — стандартная)</small></span><input type="number" id="stuLen" min="4" max="80" step="0.5" value="' + (c.len || '') + '" placeholder="' + (T.len || '') + '"></label>' : '') +
    (turret ? '<p class="sub">Нажмите на предпросмотре в точку, вокруг которой башня вращается. Если не нажимать, осью станет центр картинки.</p><label class="sl chk"><input type="checkbox" id="stuSame"' + (c.same ? ' checked' : '') + '><span>Тот же масштаб, что у корпуса (вырезано из одной картинки)</span></label>' : '') +
    '</div></div><p class="sub">Машина должна смотреть вправо →. Боец тоже: взгляд и оружие вправо, вид строго сверху.</p>' +
    '<div class="row2"><button class="ghost" id="stuSkip">Пропустить</button><button class="ghost" id="stuCancel">Закрыть</button></div><button class="go" id="stuOk">Применить</button></div>';
  const bind = (id, fn) => { const e = $('#' + id); if (e) { e.oninput = e.onchange = () => { fn(e); }; } };
  bind('stuT', e => { c.target = STU.last = e.value; c.pv = null; stuForm(); stuDraw(); });
  $$('#studio [data-r]').forEach(b => b.onclick = () => { c.rot = (c.rot + +b.dataset.r + 360) % 360; c.pv = null; stuDraw(); });
  const fl = $('#stuFlip'); if (fl) fl.onclick = () => { c.flip = !c.flip; c.pv = null; stuDraw(); };
  for (const [id, k] of [['stuFine', 'fine'], ['stuTol', 'tol'], ['stuCl', 'cl'], ['stuCr', 'cr'], ['stuCt', 'ct'], ['stuCb', 'cb']]) bind(id, e => { c[k] = +e.value; $('#' + id + 'V').textContent = e.value; if (k !== 'tol') c.pv = null; stuDraw(true); });
  bind('stuBg', e => { c.bg = e.checked; stuDraw(); }); bind('stuLen', e => { c.len = +e.value || null; stuDraw(); }); bind('stuSame', e => { c.same = e.checked; stuDraw(); });
  const pk = $('#stuPick'); if (pk) { pk.onclick = () => { c.pick = !c.pick; stuForm(); stuDraw(); }; $('#stuPickClr').onclick = () => { c.picks = []; stuForm(); stuDraw(); }; }
  $('#stuSkip').onclick = stuNext; $('#stuCancel').onclick = () => { STU.q = []; stuClose(); }; $('#stuOk').onclick = stuApply;
  const cv = $('#stuCv'); cv.onclick = e => { const T2 = artTarget(c.target); if (!STU.last_ || !c.pick && (!T2 || T2.kind !== 'turret')) return; const r = cv.getBoundingClientRect(), L = STU.last_, px = (e.clientX - r.left) / r.width * cv.width, py = (e.clientY - r.top) / r.height * cv.height, ox = (px - L.dx) / L.s, oy = (py - L.dy) / L.s; if (ox < 0 || oy < 0 || ox > L.w || oy > L.h) return; if (c.pick) { const R = STU.res, x = Math.round(ox + L.tx), y = Math.round(oy + L.ty); if (R && R.B0 && x >= 0 && y >= 0 && x < R.bw && y < R.bh) { const p = R.B0.getContext('2d').getImageData(x, y, 1, 1).data; c.picks.push([p[0], p[1], p[2]]); stuForm(); stuDraw(); } return; } c.pv = { x: (ox + L.tx) / L.bw, y: (oy + L.ty) / L.bh }; stuDraw(); };
}
let stuTimer = 0;
function stuDraw(deb) {
  if (deb) { clearTimeout(stuTimer); stuTimer = setTimeout(stuDraw, 60); return; }
  const c = STU.cur; if (!c) return; const T = artTarget(c.target), R = stuBuild(), cv = $('#stuCv'), g = cv.getContext('2d');
  g.clearRect(0, 0, cv.width, cv.height); const O = ((T && T.kind === 'turret') || c.pick) ? R.O : R.out, s = Math.min((cv.width - 16) / O.width, (cv.height - 16) / O.height), dx = (cv.width - O.width * s) / 2, dy = (cv.height - O.height * s) / 2;
  g.fillStyle = '#4a5b3a'; g.fillRect(0, 0, cv.width, cv.height); g.drawImage(O, dx, dy, O.width * s, O.height * s);
  STU.last_ = (T && T.kind === 'turret') || c.pick ? { s, dx, dy, w: O.width, h: O.height, tx: R.tx, ty: R.ty, bw: R.bw, bh: R.bh } : null;
  if (T && T.kind === 'turret') { const px = dx + R.pv.x * s, py = dy + R.pv.y * s; g.strokeStyle = '#e3b341'; g.lineWidth = 2; g.beginPath(); g.moveTo(px - 12, py); g.lineTo(px + 12, py); g.moveTo(px, py - 12); g.lineTo(px, py + 12); g.stroke(); g.beginPath(); g.arc(px, py, 7, 0, TAU); g.stroke(); }
  if (T && ['veh', 'hull'].includes(T.kind)) { g.strokeStyle = 'rgba(227,179,65,.9)'; g.lineWidth = 2; g.beginPath(); g.moveTo(cv.width - 60, 18); g.lineTo(cv.width - 20, 18); g.lineTo(cv.width - 28, 11); g.moveTo(cv.width - 20, 18); g.lineTo(cv.width - 28, 25); g.stroke(); }
  $('#stuInfo').textContent = 'Итог: ' + R.out.width + '×' + R.out.height + ' px';
  STU.res = R;
}
async function stuApply() {
  const c = STU.cur, T = artTarget(c.target); if (!c || !T) return; stuDraw(); const R = STU.res, key = T.key, out = R.out;
  const url = out.toDataURL('image/png'); if (!await loadArt(key, url)) { alert_('Не удалось применить файл'); return; }
  let meta = null; if (['veh', 'hull', 'turret'].includes(T.kind)) { meta = { len: c.len || stuDefaultLen(T, out) || T.len }; if (T.kind === 'turret') meta.ox = T.v.len * .04, meta.oy = 0; }
  ART[key].meta = meta; await ARTDB.put(key, { url, meta });
  for (const k in iconCache) delete iconCache[k]; if (key === 'map') buildTerrain(); selSig = ''; deckSig = ''; STU.ok++; stuNext();
}
