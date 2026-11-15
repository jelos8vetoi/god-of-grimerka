// Съёмка кадров для трейлера GOD OF GRIMERKA. Выполняется в странице игры (index.html?q=hi, 1280×720),
// открытой через dev-сервер, который принимает PUT /__save?name=файл и кладёт кадры в папку frames.
// Игровой цикл останавливается (__manual), время идёт ровно 1/30 c на кадр (__clock), интерфейс скрыт (__noHud).
// Возвращает журнал: что снято и в каком состоянии была игра.
(async () => {
  const sl = ms => new Promise(r => setTimeout(r, ms)), log = [];
  const k = c => { dispatchEvent(new KeyboardEvent('keydown', { code: c })); dispatchEvent(new KeyboardEvent('keyup', { code: c })); };
  const cv = document.getElementById('c'), gl = document.getElementById('gl'); cv.requestPointerLock = null;
  const md = b => cv.dispatchEvent(new MouseEvent('mousedown', { button: b, clientX: 640, clientY: 300, bubbles: true }));
  const mu = b => dispatchEvent(new MouseEvent('mouseup', { button: b }));
  for (let i = 0; i < 80 && !(window.GOC && document.querySelector('[data-d="1"]')); i++) await sl(250);
  await sl(2500);
  localStorage.clear();
  window.__clock = 1000; window.__manual = true; window.__noHud = true;
  const o = document.createElement('canvas'); o.width = 1280; o.height = 720; const ox = o.getContext('2d');
  const cap = async (name, overlay) => { ox.drawImage(gl, 0, 0, 1280, 720); if (overlay !== false) ox.drawImage(cv, 0, 0, 1280, 720); await fetch('/__save?name=' + name, { method: 'PUT', body: o.toDataURL('image/jpeg', .9) }); };
  let SLOW = 1;   // 2 — замедление вдвое: на кадр уходит половина игрового времени
  const step = nr => { window.__clock += 1 / 30 / SLOW; GOC.tick(2 / SLOW, nr); };
  const shoot = async (p, n, drv, overlay) => { for (let i = 0; i < n; i++) { if (drv) drv(i); step(); await cap(p + String(i).padStart(3, '0') + '.jpg', overlay); } log.push(p + ' ' + n + ' ' + GOC.state().mode + ' ens=' + GOC.ens().length); };
  const warm = (n, drv) => { for (let i = 0; i < n; i++) { if (drv) drv(i); step(true); } };
  // всё, что не бой: диалоги, обучение, выбор усилений — проматываем
  const unstick = () => {
    const m = GOC.state().mode;
    if (m === 'dlg') GOC.skip();
    else if (m === 'title') { window.__clock += .5; GOC.tick(30, true); }
    else if (m !== 'fight') { for (const id of ['guideSkip', 'guideGo']) { const b = document.getElementById(id); if (b && !b.hidden && b.offsetParent) { b.click(); return m; } }
      const b = [...document.querySelectorAll('.ov')].filter(v => getComputedStyle(v).display !== 'none').map(v => v.querySelector('button')).find(Boolean); if (b) b.click(); else k('Enter'); }
    return m;
  };
  const toFight = ch => { GOC.goto(ch); for (let g = 0; g < 900; g++) { const s = GOC.state(); if (s.mode !== 'fight') unstick(); else if (s.fs) break; else { GOC.auto(); step(true); } } GOC.all(); GOC.god(); };
  const toBoss = () => { for (let g = 0; g < 4000; g++) { const s = GOC.state(); if (s.mode !== 'fight') { unstick(); continue; } if (GOC.dbg().cine) return true; if (GOC.ens().length) GOC.kill(); GOC.auto(); step(true); if (GOC.dbg().cine) return true; } return false; };
  // водитель боя: смотрит на ближайшего врага, бьёт, заряжает тяжёлый, жмёт руну/ад-либ/бросок/ульту, кувыркается
  const fight = q => { q = q || {}; let hv = 0, yaw = GOC.dbg().camYaw; return i => {
    const s = GOC.state(); if (s.mode !== 'fight') { unstick(); return; } if (q.w && i % 30 === 0) k('Digit' + q.w); if (q.pit) GOC.pit(q.pit); if (q.gold) GOC.full();
    if (q.walk) { const es0 = GOC.ens(); if (es0.length) { let n0 = es0[0], d0 = 1e9; for (const e of es0) { const d = Math.hypot(e.x - s.x, e.y - s.y); if (d < d0) { d0 = d; n0 = e; } } let dd = Math.atan2(n0.y - s.y, n0.x - s.x) - yaw; while (dd > Math.PI) dd -= Math.PI * 2; while (dd < -Math.PI) dd += Math.PI * 2; yaw += dd * .05; GOC.yaw(yaw); } GOC.god(); dispatchEvent(new KeyboardEvent(d0w(i) ? 'keydown' : 'keyup', { code: 'KeyW' })); if (q.r != null && i === q.r) k('KeyR'); return; }
    const es = GOC.ens(); if (!es.length) { mu(0); return; }
    let n = es[0], nd = 1e9; for (const e of es) { const d = Math.hypot(e.x - s.x, e.y - s.y) - e.r; if (d < nd) { nd = d; n = e; } }
    const fin = es.find(e => e.fin && Math.hypot(e.x - s.x, e.y - s.y) < 160), t = fin || n;
    let dd = Math.atan2(t.y - s.y, t.x - s.x) - yaw + (q.off || 0); while (dd > Math.PI) dd -= Math.PI * 2; while (dd < -Math.PI) dd += Math.PI * 2; yaw += dd * (q.turn || .12); GOC.yaw(yaw); GOC.god();
    dispatchEvent(new KeyboardEvent(nd > 90 && !hv ? 'keydown' : 'keyup', { code: 'KeyW' }));
    if (q.roll && i % q.roll === q.roll - 1) { dispatchEvent(new KeyboardEvent('keydown', { code: q.rk || 'KeyD' })); GOC.roll(); dispatchEvent(new KeyboardEvent('keyup', { code: q.rk || 'KeyD' })); return; }
    if (hv > 0) { hv--; if (hv === 0) mu(2); return; } if (q.heavy && i % q.heavy === q.heavy - 1) { mu(0); md(2); hv = 14; return; }
    if (nd < 140) md(0); else mu(0); if (fin) k('KeyF'); if (q.q && i % q.q === 5) k('KeyQ'); if (q.e && i % q.e === 9) k('KeyE'); if (q.c && i % q.c === 3) k('KeyC');
    if (q.r != null && i === q.r) { GOC.full(); k('KeyR'); } if (q.r2 && i === q.r2) k('KeyR'); }; };
  const d0w = i => i % 3 !== 2;
  const safe = async (name, f) => { try { await f(); } catch (e) { log.push(name + ' ERR ' + e.message); } };

  document.querySelector('[data-d="1"]').click(); await sl(300);
  // W — проход с золотой аурой (замедленно, камера снизу), G — аура вспыхивает ПЕРЕГРУЗОМ
  await safe('W', async () => { toFight(4); GOC.full(); const d = fight({ walk: 1, gold: 1, pit: .13 }); warm(10, d); GOC.clearFx(); SLOW = 2; await shoot('W', 110, i => d(i + 10)); SLOW = 1; });
  await safe('G', async () => { GOC.full(); const d = fight({ walk: 1, pit: .16, r: 24 }); SLOW = 2; await shoot('G', 100, i => { if (i < 24) GOC.full(); d(i); }); SLOW = 1; GOC.pit(.36); });
  // R — перекаты (замедленно)
  await safe('R', async () => { toFight(1); const d = fight({ w: 1, roll: 22, off: .5, gold: 1 }); warm(20, d); GOC.clearFx(); SLOW = 2; await shoot('R', 90, i => d(i + 20)); SLOW = 1; });
  // K — последний враг в комнате: замедление
  await safe('K', async () => { toFight(2); const d = fight({ w: 1, heavy: 16 }); warm(30, d); GOC.clearFx(); await shoot('K', 12, i => d(i + 30)); GOC.kill(); await shoot('Kb', 45); });
  // по главам: D — бой (в ПЕРЕГРУЗЕ или с золотой аурой), H — заставка босса, I — бой с боссом
  const SET = { 0: { w: 1, heavy: 18, gold: 1 }, 1: { w: 1, heavy: 16, e: 20, r: 3 }, 2: { w: 2, heavy: 18, e: 12, q: 30, gold: 1 }, 3: { w: 3, heavy: 20, e: 15, c: 40, r: 3 }, 4: { w: 1, heavy: 14, e: 10, gold: 1 }, 5: { w: 2, heavy: 15, e: 14, q: 22, r: 3 }, 6: { w: 3, heavy: 17, e: 9, gold: 1 }, 7: { w: 1, heavy: 13, e: 12, r: 3, r2: 30 }, 8: { w: 2, heavy: 16, e: 10, q: 18, roll: 23, r: 3 } };
  for (let ch = 0; ch <= 8; ch++) {
    await safe('D' + ch, async () => { toFight(ch); const d = fight(SET[ch]); warm(26, d); GOC.clearFx(); await shoot('D' + ch + '_', 46, i => d(i + 26)); });
    await safe('H' + ch, async () => { if (!toBoss()) { log.push('H' + ch + ' no boss'); return; } GOC.clearFx(); await shoot('H' + ch + '_', 60);
      for (let g = 0; g < 200 && (GOC.dbg().cine || GOC.state().mode !== 'fight'); g++) { if (GOC.state().mode !== 'fight') unstick(); else { k('Enter'); step(true); } }
      GOC.all(); GOC.god(); const d = fight({ w: 1 + ch % 3, heavy: 14, e: 8, q: 20, r: 2, r2: ch === 8 ? 40 : 0, turn: .2 }); warm(8, d); if (ch === 8) SLOW = 2; await shoot('I' + ch + '_', ch === 8 ? 110 : 44, i => d(i + 8)); SLOW = 1; });
  }
  return log;
})()
