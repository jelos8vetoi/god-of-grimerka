// Музыка и окружение для Godot-версии: всё синтезируется здесь, бесплатно и офлайн, без сторонних библиотек.
//   node tools/godot-music.cjs [имя…]   →   godot/assets/music/*.wav (32 кГц, моно, 16 бит)
// Каждая локация и каждый босс — своя композиция: темп, лад, аккорды, мотив (повторяемый, запоминающийся), рисунок ударных.
// Музыка пишется слоями одной длины, чтобы игра могла включать их по ходу:
//   loc_<локация>_base  — исследование (гармония, мелодия),   loc_<локация>_drive — бой (ударные, бас);
//   boss_<id>_p1 / _p2 / _p3 — фазы босса (каждая следующая добавляется к предыдущим);
//   boss_<id>_intro, boss_<id>_win — вступление и победа;  defeat — поражение;
//   amb_<локация> — фон окружения (петля),  os_<имя> — одиночные звуки, которые игра расставляет в пространстве.
// Один и тот же seed всегда даёт одну и ту же музыку. Новая локация или босс — новая запись в LOCS / BOSSES.
const fs = require('fs'), path = require('path'), SR = 32000;
const OUT = path.join(__dirname, '..', 'godot', 'assets', 'music'); fs.mkdirSync(OUT, { recursive: true });
const rng = s => { let a = s >>> 0; return () => { a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; };
const mtof = m => 440 * Math.pow(2, (m - 69) / 12), TAU = 2 * Math.PI;
const SC = { minor: [0, 2, 3, 5, 7, 8, 10], major: [0, 2, 4, 5, 7, 9, 11], phryg: [0, 1, 3, 5, 7, 8, 10], harm: [0, 2, 3, 5, 7, 8, 11], dorian: [0, 2, 3, 5, 7, 9, 10] };
const osc = (w, p) => { p -= Math.floor(p); return w === 'saw' ? 2 * p - 1 : w === 'sq' ? (p < .5 ? 1 : -1) : w === 'tri' ? 4 * Math.abs(p - .5) - 1 : Math.sin(TAU * p); };
let NR = rng(7); const white = () => NR() * 2 - 1;

// ---------- инструменты (пишут в буфер b со времени t, сек) ----------
function note(b, t, f, d, o = {}) {
  const { w = 'saw', v = .2, a = .005, r = .08, cut = 4000, cenv = 0, det = 0, uni = 1, vib = 0, glide = 0, dec = 0 } = o;
  const s = Math.floor(t * SR), n = Math.floor(d * SR); let l1 = 0, l2 = 0; const ph = []; for (let k = 0; k < uni; k++) ph.push(k * .37);
  for (let i = 0; i < n && s + i < b.length; i++) {
    const tt = i / SR, e = Math.min(1, i / (a * SR)) * Math.min(1, (n - i) / (r * SR)) * (dec ? Math.exp(-tt * dec) : 1);
    const ff = (glide ? f * Math.pow(glide, Math.max(0, 1 - tt / .09)) : f) * (1 + vib * Math.sin(TAU * 5.3 * tt));
    let x = 0; for (let k = 0; k < uni; k++) { ph[k] += ff * (1 + det * (k - (uni - 1) / 2)) / SR; x += osc(w, ph[k]); } x /= uni;
    const c = 1 - Math.exp(-TAU * Math.min(SR * .45, cut * (1 + cenv * Math.exp(-tt * 9))) / SR);
    l1 += (x - l1) * c; l2 += (l1 - l2) * c; b[s + i] += l2 * e * v;
  }
}
function bell(b, t, f, d, o = {}) { // FM: колокольчик, клавиши
  const { v = .2, ratio = 3.5, idx = 2, dec = 3 } = o, s = Math.floor(t * SR), n = Math.floor(d * SR);
  for (let i = 0; i < n && s + i < b.length; i++) { const tt = i / SR, e = Math.exp(-tt * dec) * Math.min(1, i / 60) * Math.min(1, (n - i) / 400); b[s + i] += Math.sin(TAU * f * tt + idx * Math.exp(-tt * dec * 1.5) * Math.sin(TAU * f * ratio * tt)) * e * v; }
}
function choir(b, t, f, d, v = .1) { // «а-а-а»: гармоники с вибрато и медленной атакой
  const H = [1, .6, .45, .5, .3, .12, .08, .05], s = Math.floor(t * SR), n = Math.floor(d * SR);
  for (let i = 0; i < n && s + i < b.length; i++) { const tt = i / SR, e = Math.min(1, tt / .35) * Math.min(1, (n - i) / (SR * .5)), vb = 1 + .006 * Math.sin(TAU * 5 * tt + f); let x = 0; for (let h = 0; h < H.length; h++) x += H[h] * Math.sin(TAU * f * (h + 1) * vb * tt); b[s + i] += x * e * v * .3; }
}
function kick(b, t, o = {}) {
  const { v = .9, f0 = 150, f1 = 44, d = .3, drive = 1.6 } = o, s = Math.floor(t * SR), n = Math.floor(d * SR * 2.2); let ph = 0;
  for (let i = 0; i < n && s + i < b.length; i++) { const tt = i / SR; ph += (f1 + (f0 - f1) * Math.exp(-tt * 40)) / SR; b[s + i] += Math.tanh(Math.sin(TAU * ph) * drive) * Math.exp(-tt / d * 2.4) * v; }
}
function nz(b, t, o = {}) { // шумовой удар: малый барабан, хэт, хлопок
  const { v = .3, d = .1, hp = .6, lp = 1, tone = 0, tf = 190 } = o, s = Math.floor(t * SR), n = Math.floor(d * SR * 3); let l = 0, h = 0;
  for (let i = 0; i < n && s + i < b.length; i++) { const tt = i / SR, x = white(); l += (x - l) * lp; h += (l - h) * (1 - hp) ; const y = hp > 0 ? l - h : l; b[s + i] += (y + tone * Math.sin(TAU * tf * tt) * Math.exp(-tt * 18)) * Math.exp(-tt / d * 2.6) * v; }
}
const hat = (b, t, v = .12, open = false) => nz(b, t, { v, d: open ? .16 : .028, hp: .93, lp: 1 });
const snare = (b, t, v = .5) => nz(b, t, { v, d: .13, hp: .5, lp: .7, tone: .7, tf: 195 });
const clap = (b, t, v = .4) => { for (const dt of [0, .011, .023]) nz(b, t + dt, { v: v * .6, d: .02, hp: .7, lp: .6 }); nz(b, t + .03, { v, d: .1, hp: .7, lp: .6 }); };
const rim = (b, t, v = .25) => { note(b, t, 1750, .03, { w: 'tri', v, r: .02, cut: 9000 }); };
const cow = (b, t, f, v = .22) => { for (const m of [1, 1.48]) note(b, t, f * m, .28, { w: 'sq', v: v * .5, cut: 2600, dec: 9, r: .05 }); }; // фонковый ковбелл
const tom = (b, t, f, v = .5) => kick(b, t, { v, f0: f * 1.8, f1: f, d: .28, drive: 1.1 });
function b808(b, t, f, d, o = {}) { // 808: синус с подъездом и перегрузом
  const { v = .7, drive = 2.2, glide = 0 } = o, s = Math.floor(t * SR), n = Math.floor(d * SR); let ph = 0;
  for (let i = 0; i < n && s + i < b.length; i++) { const tt = i / SR; ph += f * (glide ? Math.pow(glide, Math.max(0, 1 - tt / .12)) : 1) * (1 + .5 * Math.exp(-tt * 60)) / SR; b[s + i] += Math.tanh(Math.sin(TAU * ph) * drive) * Math.min(1, i / 40) * Math.min(1, (n - i) / (SR * .04)) * Math.exp(-tt * 1.6) * v; }
}
// ---------- обработка ----------
function reverb(b, mix, size = 1, damp = .4) {
  const o = new Float32Array(b.length);
  for (const c of [1557, 1617, 1491, 1422, 1277]) { const L = Math.floor(c * size * SR / 44100), q = new Float32Array(L); let p = 0, l = 0; for (let i = 0; i < b.length; i++) { const y = q[p]; l += (y - l) * (1 - damp); q[p] = b[i] + l * .86; o[i] += y * .2; if (++p >= L) p = 0; } }
  for (const c of [225, 556]) { const L = Math.floor(c * SR / 44100), q = new Float32Array(L); let p = 0; for (let i = 0; i < o.length; i++) { const y = q[p], x = o[i]; q[p] = x + y * .5; o[i] = y - x * .5; if (++p >= L) p = 0; } }
  for (let i = 0; i < b.length; i++) b[i] = b[i] * (1 - mix * .25) + o[i] * mix;
}
function delay(b, sec, fb, mix) { const L = Math.floor(sec * SR), w = new Float32Array(b.length); for (let i = L; i < b.length; i++) { w[i] = b[i - L] + w[i - L] * fb; b[i] += w[i] * mix; } }
function lowp(b, fc) { const c = 1 - Math.exp(-TAU * fc / SR); let l = 0; for (let i = 0; i < b.length; i++) { l += (b[i] - l) * c; b[i] = l; } }
function highp(b, fc) { const c = 1 - Math.exp(-TAU * fc / SR); let l = 0; for (let i = 0; i < b.length; i++) { l += (b[i] - l) * c; b[i] -= l; } }
const fold = (b, n) => { const o = new Float32Array(n); for (let i = 0; i < b.length; i++) o[i % n] += b[i]; return o; }; // хвост реверберации заворачивается в начало: петля без шва
function save(name, b, g = 1) {
  const n = b.length, buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  let pk = 0, sq = 0; for (let i = 0; i < n; i++) { const x = Math.tanh(b[i] * g); pk = Math.max(pk, Math.abs(x)); sq += x * x; buf.writeInt16LE(Math.round(x * 32767), 44 + i * 2); }
  fs.writeFileSync(path.join(OUT, name + '.wav'), buf);
  return { name, sec: +(n / SR).toFixed(1), peak: +(20 * Math.log10(pk + 1e-9)).toFixed(1), rms: +(10 * Math.log10(sq / n + 1e-12)).toFixed(1) };
}
const rms = b => { let s = 0; for (let i = 0; i < b.length; i++) s += b[i] * b[i]; return Math.sqrt(s / b.length); };

// ---------- сочинение ----------
// d: bpm, root (нота MIDI тоники), scale, prog (ступени аккордов по тактам), seed, pad, lead, drums, bass, arp, dens (плотность мелодии), sw (свинг)
function compose(d, boss) {
  NR = rng(d.seed * 31 + 5); const R = rng(d.seed), bars = d.bars || 8, beat = 60 / d.bpm, bar = beat * 4, st = beat / 4, n = Math.floor(bar * bars * SR), mk = () => new Float32Array(n + SR * 3);
  const S = { base: mk(), drive: mk(), p2: mk(), p3: mk() }, sc = SC[d.scale], deg = (k, o = 0) => d.root + sc[((k % 7) + 7) % 7] + 12 * (Math.floor(k / 7) + o), ch = i => d.prog[i % d.prog.length];
  const pick = a => a[Math.floor(R() * a.length)];
  // мотив: два такта A и два такта B, форма A A' B A — узнаваемая мелодия, а не случайные ноты
  const motif = () => { const m = []; let p = pick([0, 2, 4]); for (let s = 0; s < 32; s += 2) { const strong = s % 8 === 0; if (R() < (strong ? .9 : d.dens || .45)) { p += pick(strong ? [0, 0, 2, -2] : [-1, 1, -2, 2, 0]); p = Math.max(-3, Math.min(7, p)); const len = pick([2, 2, 4, 4, 6]); m.push([s, len, p]); s += len - 2; } } return m; };
  const A = motif(), B = motif(), A2 = A.map((x, i) => i === A.length - 1 ? [x[0], x[1], x[2] + pick([-2, 2, 3])] : x), form = [A, A2, B, A];
  const lead = (b, t, f, dur, v) => {
    switch (d.lead) {
      case 'bell': return bell(b, t, f, Math.max(dur, .5), { v: v * 1.1, ratio: 3.5, idx: 1.6, dec: 3.2 });
      case 'keys': return bell(b, t, f, Math.max(dur, .4), { v: v * 1.2, ratio: 1, idx: 1.1, dec: 4.5 });
      case 'pluck': return note(b, t, f, Math.max(dur, .18), { w: 'saw', v, cut: 900, cenv: 5, dec: 7, r: .05 });
      case 'sq': return note(b, t, f, dur, { w: 'sq', v: v * .6, cut: 2400, vib: .004, r: .05 });
      case 'saw': return note(b, t, f, dur, { w: 'saw', v: v * .8, cut: 2800, uni: 3, det: .008, vib: .003, r: .06 });
      case 'cow': return cow(b, t, f, v * 1.2);
    }
  };
  for (let i = 0; i < bars; i++) {
    const t0 = i * bar, c = ch(i), tri = [deg(c, 0), deg(c + 2, 0), deg(c + 4, 0), deg(c + 6, 0)];
    // гармония
    const pv = d.padv || 1;
    if (d.pad === 'choir') for (const m of tri.slice(0, 3)) choir(S.base, t0, mtof(m + 12), bar * 1.02, .2 * pv);
    else if (d.pad === 'organ') for (const m of tri.slice(0, 3)) note(S.base, t0, mtof(m), bar * 1.02, { w: 'sq', v: .07 * pv, cut: 1500, a: .03, r: .2, uni: 2, det: .004 });
    else if (d.pad) for (const m of (d.pad === 'glass' ? tri : tri.slice(0, 3))) note(S.base, t0, mtof(m + (d.pad === 'glass' ? 12 : 0)), bar * 1.05, { w: d.pad === 'glass' ? 'tri' : 'saw', v: (d.pad === 'dark' ? .1 : .085) * pv, cut: d.pad === 'dark' ? 520 : d.pad === 'strings' ? 2100 : 1300, a: d.pad === 'strings' ? .12 : .5, r: .7, uni: 3, det: .007 });
    // мелодия
    if (d.lead) for (const [s, len, p] of form[Math.floor(i / 2) % 4].filter(x => (x[0] >= 16) === (i % 2 === 1))) lead(S.base, t0 + (s % 16) * st, mtof(deg(c + p, (d.lo || 0) + 1)), len * st * .95, .16);
    // арпеджио
    if (d.arp) for (let s = 0; s < 16; s += d.arp) note(boss ? S.p2 : S.base, t0 + s * st, mtof(tri[(s / d.arp) % 3 | 0] + 12 + (s % 8 === 6 ? 12 : 0)), st * d.arp * .9, { w: 'saw', v: boss ? .09 : .05, cut: 1400, cenv: 4, dec: 6, r: .04 });
    // ударные и бас — слой боя
    const D = S.drive, sw = s => t0 + s * st + (s % 2 ? (d.sw || 0) * st : 0), last = i % 4 === 3; let bm = deg(c, 0); while (bm > 40) bm -= 12; while (bm < 28) bm += 12; const root = mtof(bm);
    const K = { trap: [0, 10], drill: [0, 7, 10], boombap: [0, 10], four: [0, 4, 8, 12], hyper: [0, 4, 8, 10, 12], phonk: [0, 6, 10], half: [0], stomp: [0, 4], ticks: [0, 11] }[d.drums] || [];
    const SN = { trap: [8], drill: [8, 14], boombap: [4, 12], four: [4, 12], hyper: [4, 12], phonk: [4, 12], half: [8], stomp: [8], ticks: [] }[d.drums] || [];
    const ks = K.concat(d.drums && R() < .5 ? [pick([6, 7, 14, 15])] : []);
    for (const s of ks) kick(D, sw(s), { v: .95, d: d.drums === 'four' ? .22 : .3 });
    for (const s of SN) (d.drums === 'four' || d.drums === 'phonk' || d.drums === 'stomp' || d.drums === 'hyper' ? clap : snare)(D, sw(s), .42);
    if (d.drums === 'ticks') for (const s of [6, 14]) rim(D, sw(s), .2);
    if (d.drums === 'stomp' && last) for (let s = 12; s < 16; s++) tom(D, sw(s), 140 - (s - 12) * 20, .4);
    if (d.drums && d.drums !== 'half' && d.drums !== 'stomp') for (let s = 0; s < 16; s += (d.drums === 'four' || d.drums === 'hyper') ? 1 : 2) {
      const off = s % 4 === 2; hat(D, sw(s), d.drums === 'four' ? (off ? .16 : .05) : (s % 4 === 0 ? .13 : .09), d.drums === 'four' && off && R() < .3);
      if ((d.drums === 'trap' || d.drums === 'drill') && R() < .16) for (let k = 1; k < 4; k++) hat(D, sw(s) + k * st / 2, .07); // дроби хэтов
    }
    if (d.bass === '808') for (const s of ks) b808(D, sw(s), root, st * 5, { v: .6, drive: d.dist || 2.2, glide: R() < .25 ? pick([.75, 1.5]) : 0 });
    else if (d.bass === 'sub') for (const s of K) note(D, sw(s), root * 2, st * 3.5, { w: 'tri', v: .42, cut: 500, r: .08 });
    else if (d.bass === 'acid') for (let s = 0; s < 16; s++) if (s % 4 !== 0) note(D, sw(s), root * (s % 8 === 6 ? 4 : 2), st * .85, { w: 'saw', v: .2, cut: 380, cenv: 6 + 3 * Math.sin(i), dec: 5, r: .02 });
    else if (d.bass === 'off') for (const s of [2, 6, 10, 14]) note(D, sw(s), root * 2, st * 1.6, { w: 'saw', v: .26, cut: 600, cenv: 3, r: .03 });
    // босс: вторая фаза — контрмелодия и плотные ударные, третья — хор, удары и разгон
    if (boss) {
      for (const [s, len, p] of form[(Math.floor(i / 2) + 2) % 4].filter(x => (x[0] >= 16) === (i % 2 === 1))) note(S.p2, t0 + (s % 16) * st, mtof(deg(c + p + 2, 1)), len * st * .9, { w: 'saw', v: .11, cut: 3200, uni: 3, det: .009, r: .05 });
      for (let s = 1; s < 16; s += 2) hat(S.p2, sw(s), .07);
      if (d.cowp) for (const s of [0, 3, 6, 8, 11, 14]) cow(S.p2, sw(s), mtof(deg(c + pick([0, 2, 4]), 1)), .16);
      for (const m of tri.slice(0, 3)) choir(S.p3, t0, mtof(m + 12), bar * 1.02, .2);
      for (const s of [0, 6, 12]) { for (const m of tri.slice(0, 3)) note(S.p3, sw(s), mtof(m + 12), st * 1.6, { w: 'saw', v: .1, cut: 3000, uni: 3, det: .01, r: .04 }); }
      tom(S.p3, t0, 62, .5); if (last) for (let s = 8; s < 16; s++) snare(S.p3, sw(s), .12 + s * .02);
    }
  }
  reverb(S.base, d.rev || .35, d.size || 1.2); if (d.dly) delay(S.base, beat * .75, .35, d.dly);
  reverb(S.drive, .08, .6); reverb(S.p2, .25, 1); reverb(S.p3, .4, 1.4); highp(S.base, 90); highp(S.p2, 150); highp(S.p3, 120);
  const out = {}; for (const k in S) out[k] = fold(S[k], n);
  // у каждого слоя свой целевой уровень: исследование слышно и без ударных, слои фаз заметны поверх боя
  const lv = { base: .1, drive: .17, p2: .085, p3: .1 }; out.g = {}; for (const k in lv) out.g[k] = lv[k] / (rms(out[k]) + 1e-9);
  out.n = n; out.beat = beat; return out;
}
// короткие отбивки в ладу босса
function stinger(d, kind) {
  NR = rng(d.seed + 99); const b = new Float32Array(SR * (kind === 'intro' ? 5 : 6)), sc = SC[kind === 'win' ? 'major' : d.scale], deg = (k, o = 0) => d.root + sc[((k % 7) + 7) % 7] + 12 * (Math.floor(k / 7) + o);
  if (kind === 'intro') { // нарастающий шум, провал и удар аккордом
    for (let i = 0; i < SR * 2.2; i++) { const k = i / (SR * 2.2); b[i] += white() * k * k * .16; }
    lowp(b, 3000); kick(b, 2.2, { v: 1, f0: 110, f1: 30, d: .9, drive: 2.5 }); for (const k of [0, 2, 4]) { note(b, 2.2, mtof(deg(k, -1)), 2.4, { w: 'saw', v: .12, cut: 1800, uni: 3, det: .01, a: .01, r: 1.2 }); choir(b, 2.2, mtof(deg(k)), 2.4, .22); }
    for (let s = 0; s < 8; s++) tom(b, 1.2 + s * .12, 70 + s * 8, .2 + s * .05);
  } else if (kind === 'win') { [0, 2, 4, 7, 9, 11, 14].forEach((k, i) => bell(b, i * .16, mtof(deg(k)), 2.5, { v: .22, dec: 2 })); for (const k of [0, 2, 4, 7]) { note(b, 1.2, mtof(deg(k, -1)), 3.5, { w: 'saw', v: .09, cut: 2400, uni: 3, det: .008, a: .05, r: 1.5 }); choir(b, 1.2, mtof(deg(k)), 3.5, .2); } kick(b, 1.2, { v: .8, d: .5 }); clap(b, 1.2, .3); }
  else { [7, 5, 4, 2, 0].forEach((k, i) => bell(b, i * .42, mtof(deg(k, -1)), 2.2, { v: .22, ratio: 1, idx: 1.4, dec: 2 })); for (const k of [0, 2, 4]) note(b, 2.1, mtof(deg(k, -2)), 3.2, { w: 'saw', v: .11, cut: 600, uni: 3, det: .01, a: .2, r: 1.5 }); kick(b, 2.1, { v: .9, f0: 80, f1: 28, d: 1.0 }); }
  reverb(b, .45, 1.5); return b;
}
// ---------- локации и боссы ----------
const N = { C: 48, Cs: 49, D: 50, Ds: 51, E: 52, F: 53, Fs: 54, G: 55, Gs: 56, A: 57, As: 58, B: 59 };
const LOCS = {
  hall: { bpm: 60, root: N.D, scale: 'minor', prog: [0, 0, 5, 3], seed: 11, pad: 'dark', lead: 'keys', dens: .2, rev: .5, size: 1.6, lo: 0, bars: 8 },                       // подъезд: почти тишина, редкое пианино
  snow: { bpm: 140, root: N.A - 12, scale: 'minor', prog: [0, 0, 5, 5, 3, 3, 4, 4], seed: 21, pad: 'glass', lead: 'bell', drums: 'trap', bass: '808', dens: .4, rev: .45, dly: .25, lo: 1 }, // Томск: холодный медленный трэп, колокольчики
  basement: { bpm: 88, root: N.E, scale: 'dorian', prog: [0, 3, 0, 4], seed: 32, pad: 'dark', lead: 'keys', drums: 'boombap', bass: 'sub', sw: .32, dens: .5, rev: .3 },               // подземка: грязный бум-бэп
  neon: { bpm: 160, root: N.Fs - 12, scale: 'minor', prog: [0, 5, 2, 6], seed: 43, pad: 'saw', lead: 'saw', drums: 'hyper', bass: 'off', arp: 2, dens: .6, rev: .3, dly: .2, lo: 1 },      // лента: быстрый гиперпоп
  swamp: { bpm: 112, root: N.C, scale: 'phryg', prog: [0, 0, 1, 0], seed: 54, pad: 'dark', lead: 'cow', drums: 'phonk', bass: '808', dist: 4, dens: .5, rev: .35, lo: 1 },               // болото: вязкий фонк
  glass: { bpm: 132, root: N.D, scale: 'harm', prog: [0, 5, 3, 4], seed: 65, pad: 'strings', lead: 'sq', drums: 'trap', bass: '808', dens: .45, rev: .45, size: 1.6 },                  // башня: оркестровый трэп
  grave: { bpm: 76, root: N.B - 12, scale: 'minor', prog: [0, 3, 5, 4], seed: 76, pad: 'glass', lead: 'bell', drums: 'half', bass: 'sub', dens: .25, rev: .6, size: 1.8, dly: .3, lo: 1 }, // кладбище: эмбиент с обрывками мелодий
  server: { bpm: 128, root: N.G - 12, scale: 'minor', prog: [0, 0, 3, 5], seed: 87, pad: 'dark', lead: 'pluck', drums: 'four', bass: 'acid', arp: 1, dens: .4, rev: .25, lo: 1 },        // ботоферма: механичное техно
  chart: { bpm: 150, root: N.C, scale: 'major', prog: [0, 4, 5, 3], seed: 98, pad: 'saw', lead: 'saw', drums: 'stomp', bass: 'off', dens: .55, rev: .4, lo: 1 },                       // чарты: победный стадионный бит
  core: { bpm: 100, root: N.E - 12, scale: 'phryg', prog: [0, 1, 0, 5], seed: 109, pad: 'choir', lead: 'bell', drums: 'ticks', bass: 'sub', dens: .3, rev: .55, size: 1.8, lo: 1 },       // ядро: холодный минимал, хор
};
const BOSSES = {
  courier: { bpm: 142, root: N.A - 12, scale: 'harm', prog: [0, 0, 5, 4], seed: 201, pad: 'dark', lead: 'bell', drums: 'drill', bass: '808', dens: .5, rev: .3, lo: 1 },                 // Лил Дрей: сухой дрилл
  golem: { bpm: 92, root: N.E, scale: 'minor', prog: [0, 5, 3, 4], seed: 212, pad: 'organ', lead: 'keys', drums: 'boombap', bass: 'sub', sw: .3, dens: .55, rev: .3 },                  // Первый Король: тяжёлый бум-бэп
  hype: { bpm: 172, root: N.Fs - 12, scale: 'minor', prog: [0, 5, 6, 4], seed: 223, pad: 'saw', lead: 'saw', drums: 'hyper', bass: 'off', arp: 1, dens: .7, rev: .25, lo: 1 },          // Леди Хайп: ускоренный гиперпоп
  dislike: { bpm: 122, root: N.C, scale: 'phryg', prog: [0, 1, 0, 6], seed: 234, pad: 'dark', lead: 'cow', drums: 'phonk', bass: '808', dist: 5, cowp: 1, dens: .6, rev: .3, lo: 1 },   // Король Дизлайк: фонк с перегруженным басом
  major: { bpm: 138, root: N.D, scale: 'harm', prog: [0, 3, 5, 4], seed: 245, pad: 'strings', lead: 'sq', drums: 'trap', bass: '808', arp: 2, dens: .5, rev: .45, size: 1.6 },          // Мейджор: оркестр и трэп
  strike: { bpm: 160, root: N.B - 12, scale: 'harm', prog: [0, 0, 3, 4], seed: 256, pad: 'organ', lead: 'sq', drums: 'trap', bass: '808', dens: .4, rev: .55, size: 1.8, lo: 1 },       // Серёга Рплюс: орган и удары
  botlord: { bpm: 138, root: N.G - 12, scale: 'minor', prog: [0, 0, 5, 3], seed: 267, pad: 'dark', lead: 'pluck', drums: 'four', bass: 'acid', arp: 1, dens: .5, rev: .2, lo: 1 },      // Анар Абдулаев: машинное техно
  ghostv: { bpm: 150, root: N.A - 12, scale: 'minor', prog: [0, 0, 5, 5, 3, 3, 4, 4], seed: 21, pad: 'dark', lead: 'bell', drums: 'phonk', bass: '808', dist: 6, cowp: 1, dens: .4, rev: .35, lo: 1 }, // Denya8: искажённая тема Пахана (тот же мотив, что в Томске)
  algo: { bpm: 126, root: N.E - 12, scale: 'phryg', prog: [0, 1, 5, 4], seed: 289, pad: 'choir', lead: 'bell', drums: 'four', bass: 'acid', arp: 2, dens: .45, rev: .5, size: 1.8, lo: 1 }, // 9mice: хор и минимал, в финале — всё вместе
};
// ---------- окружение ----------
function ambient(kind) {
  NR = rng(kind.length * 977 + kind.charCodeAt(0)); const R = rng(kind.charCodeAt(1) * 13), n = SR * 12, b = new Float32Array(n);
  const wind = (fc, depth, v, rate = .13) => { let l = 0, l2 = 0; for (let i = 0; i < n; i++) { const t = i / SR, f = fc * (1 + depth * Math.sin(TAU * rate * t) * Math.sin(TAU * rate * .37 * t + 1)), c = 1 - Math.exp(-TAU * f / SR); l += (white() - l) * c; l2 += (l - l2) * c; b[i] += l2 * v * (0.7 + .3 * Math.sin(TAU * rate * .5 * t)); } };
  const hum = (f, v) => { for (let i = 0; i < n; i++) b[i] += (Math.sin(TAU * f * i / SR) + .4 * Math.sin(TAU * f * 2 * i / SR) + .2 * Math.sin(TAU * f * 3 * i / SR)) * v; };
  const blips = (cnt, f0, f1, v, d) => { for (let k = 0; k < cnt; k++) note(b, R() * 11, f0 + R() * (f1 - f0), d, { w: 'sin', v, glide: .8 + R() * .6, dec: 14, cut: 9000 }); };
  switch (kind) {
    case 'hall': hum(50, .05); hum(100, .018); wind(500, .3, .5); break;
    case 'snow': wind(600, .7, 2.2, .1); wind(1800, .5, .5, .23); break;
    case 'basement': hum(60, .04); wind(180, .2, 1.6, .07); break;
    case 'neon': hum(120, .02); wind(2600, .3, .35, .5); wind(900, .5, .5, .9); break;
    case 'swamp': wind(300, .3, 1.2, .08); blips(40, 200, 700, .05, .12); for (let i = 0; i < n; i++) b[i] += white() * .012 * Math.max(0, Math.sin(TAU * 17 * i / SR)) * Math.max(0, Math.sin(TAU * .7 * i / SR)); break;
    case 'glass': wind(1300, .25, .9, .17); wind(260, .4, 1.3, .06); break;
    case 'grave': wind(380, .6, 1.5, .09); for (let i = 0; i < n; i++) if (R() < .0006) b[i] += white() * .15; break;
    case 'server': wind(2200, .05, .6, .02); hum(100, .03); for (let k = 0; k < 96; k++) rim(b, k * .125, .03); break;
    case 'chart': wind(700, .4, 1.6, .21); wind(1500, .5, .8, .33); break;
    case 'core': hum(41, .09); wind(3200, .3, .2, .11); for (let k = 0; k < 6; k++) note(b, k * 2, 82, 1.2, { w: 'sin', v: .1, a: .3, r: .8 }); break;
  }
  const x = SR; for (let i = 0; i < x; i++) { const k = i / x; b[i] = b[i] * k + b[n - x + i] * (1 - k); } // стык петли: конец вливается в начало
  return b.subarray(0, n - x);
}
function oneshot(kind) {
  NR = rng(kind.length * 311); const b = new Float32Array(SR * 2);
  switch (kind) {
    case 'drip': note(b, 0, 1900, .09, { w: 'sin', v: .5, glide: .55, dec: 30, cut: 9000 }); note(b, .05, 2600, .06, { w: 'sin', v: .25, glide: .7, dec: 40, cut: 9000 }); reverb(b, .5, 1.4); break;
    case 'creak': note(b, 0, 520, .7, { w: 'saw', v: .18, cut: 1400, vib: .05, glide: 1.4, a: .08, r: .3 }); reverb(b, .3, 1); break;
    case 'gust': { let l = 0; for (let i = 0; i < SR * 1.8; i++) { const k = i / (SR * 1.8); l += (white() - l) * (.02 + .08 * Math.sin(Math.PI * k)); b[i] += l * Math.sin(Math.PI * k) * 2.2; } break; }
    case 'blip': bell(b, 0, 1318, .25, { v: .3, dec: 9 }); bell(b, .12, 1760, .3, { v: .3, dec: 8 }); break;
    case 'bubble': for (let k = 0; k < 3; k++) note(b, k * .09, 300 + k * 90, .1, { w: 'sin', v: .4, glide: .6, dec: 20, cut: 9000 }); break;
    case 'relay': rim(b, 0, .5); rim(b, .07, .3); nz(b, .1, { v: .15, d: .2, hp: .2, lp: .3 }); break;
    case 'cheer': { let l = 0; for (let i = 0; i < SR * 1.6; i++) { const k = i / (SR * 1.6); l += (white() - l) * .12; b[i] += l * Math.sin(Math.PI * k) * (1 + .4 * Math.sin(TAU * 9 * k)) * 1.4; } highp(b, 300); break; }
    case 'pulse': note(b, 0, 55, 1.4, { w: 'sin', v: .6, a: .05, r: 1.0 }); bell(b, 0, 880, 1.2, { v: .08, dec: 3 }); reverb(b, .4, 1.6); break;
    case 'static': for (let i = 0; i < SR * .5; i++) b[i] += (NR() < .2 ? white() : 0) * .3 * Math.sin(Math.PI * i / (SR * .5)); break;
  }
  return b;
}
// ---------- запуск ----------
const only = process.argv.slice(2), want = k => !only.length || only.some(o => k.includes(o)), rows = [];
for (const k in LOCS) if (want('loc_' + k)) { const s = compose(LOCS[k], false); rows.push(save('loc_' + k + '_base', s.base, s.g.base)); if (LOCS[k].drums) rows.push(save('loc_' + k + '_drive', s.drive, s.g.drive)); }
for (const k in BOSSES) if (want('boss_' + k)) {
  const d = BOSSES[k], s = compose(d, true), p1 = new Float32Array(s.n); for (let i = 0; i < s.n; i++) p1[i] = s.base[i] * s.g.base + s.drive[i] * s.g.drive;
  rows.push(save('boss_' + k + '_p1', p1, 1), save('boss_' + k + '_p2', s.p2, s.g.p2), save('boss_' + k + '_p3', s.p3, s.g.p3));
  for (const kind of ['intro', 'win']) { const b = stinger(d, kind); rows.push(save('boss_' + k + '_' + kind, b, .16 / (rms(b) + 1e-9))); }
}
if (want('defeat')) { const b = stinger({ root: N.D, scale: 'minor', seed: 5 }, 'lose'); rows.push(save('defeat', b, .16 / (rms(b) + 1e-9))); }
for (const k in LOCS) if (want('amb_' + k)) { const b = ambient(k); rows.push(save('amb_' + k, b, .08 / (rms(b) + 1e-9))); }
for (const k of ['drip', 'creak', 'gust', 'blip', 'bubble', 'relay', 'cheer', 'pulse', 'static']) if (want('os_' + k)) { const b = oneshot(k); rows.push(save('os_' + k, b, .12 / (rms(b) + 1e-9))); }
for (const r of rows) console.log(r.name.padEnd(24), String(r.sec).padStart(5) + ' с', ('пик ' + r.peak).padStart(10), ('rms ' + r.rms).padStart(10));
console.log('файлов: ' + rows.length + ' → ' + OUT);
