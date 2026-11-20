// Крики скримеров «5 НОЧЕЙ С ПАХАНОМ»: синтез без записей — godot/assets/audio/fn/scream_<кто>_<вариант>.wav.
//   node tools/godot-screams.cjs [--only=balon,ghost] [--variants=3]
// У каждого обитателя свой крик, каждый — из пяти слоёв, сведённых в один файл (так они точно совпадают по времени
// и не перегружают тракт):
//   1) голос — формантный синтез: связки (пила + импульс, дрожь, срывы, подтон), рот (четыре полосы формант, которые
//      «раскрываются» за первые десятки миллисекунд), хрип шумом;
//   2) удар — щелчок и шумовая вспышка в первые 30 мс (атака меньше миллисекунды: крик начинается сразу);
//   3) низкий импульс — синус, падающий с ~90 до ~35 Гц;
//   4) искажение — своё у каждого (перегруз, дробление разрядности, кольцевая модуляция, заикание, выпадения ленты);
//   5) хвост — короткая реверберация (у GHOST — длинная).
// Громкость: каждый файл сведён к одной средней громкости первых 0,6 с и ограничен по пику −1 дБ — без клиппинга.
// После генерации: Godot --headless --path godot --import. Файлы кладутся в git (их немного, они короткие).
const fs = require('fs'), path = require('path');
const SR = 44100, OUT = path.join(__dirname, '..', 'godot', 'assets', 'audio', 'fn');
const args = process.argv.slice(2);
const only = (args.find(a => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const VARIANTS = +((args.find(a => a.startsWith('--variants=')) || '').slice(11)) || 3;

// ---------- случайность с зерном ----------
function rngOf(seed) { let s = seed >>> 0; return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const lerp = (a, b, k) => a + (b - a) * k, clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const smooth = (a, b, x) => { const k = clamp((x - a) / (b - a), 0, 1); return k * k * (3 - 2 * k); };
// кусочно-линейная кривая по точкам [[t, v], …]
function curve(pts, t) { if (t <= pts[0][0]) return pts[0][1]; for (let i = 1; i < pts.length; i++) if (t <= pts[i][0]) { const [t0, v0] = pts[i - 1], [t1, v1] = pts[i]; return lerp(v0, v1, (t - t0) / (t1 - t0)); } return pts[pts.length - 1][1]; }

// ---------- фильтры ----------
class Biquad {
  constructor() { this.x1 = this.x2 = this.y1 = this.y2 = 0; this.b0 = 1; this.b1 = this.b2 = this.a1 = this.a2 = 0; }
  set(type, f, q) {
    const w = 2 * Math.PI * clamp(f, 20, SR * 0.45) / SR, c = Math.cos(w), al = Math.sin(w) / (2 * q); let b0, b1, b2, a0, a1, a2;
    if (type === 'bp') { b0 = al; b1 = 0; b2 = -al; } else if (type === 'lp') { b0 = (1 - c) / 2; b1 = 1 - c; b2 = (1 - c) / 2; } else { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = (1 + c) / 2; }
    a0 = 1 + al; a1 = -2 * c; a2 = 1 - al;
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0; this.a1 = a1 / a0; this.a2 = a2 / a0; return this;
  }
  run(x) { const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2; this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y; return y; }
}
function filt(buf, type, f, q = 0.7) { const b = new Biquad().set(type, f, q), o = new Float32Array(buf.length); for (let i = 0; i < buf.length; i++) o[i] = b.run(buf[i]); return o; }
// реверберация: 6 гребёнок и 3 всепропускающих (по мотивам Freeverb), один канал
function reverb(buf, size, damp, tailSec) {
  const n = buf.length + Math.floor(tailSec * SR), out = new Float32Array(n), src = new Float32Array(n); src.set(buf);
  const combs = [1557, 1617, 1491, 1422, 1277, 1356].map(d => ({ d: Math.floor(d * size), b: null, i: 0, lp: 0 }));
  for (const c of combs) c.b = new Float32Array(c.d);
  const fb = clamp(0.72 + size * 0.12, 0, 0.93);
  for (let i = 0; i < n; i++) { let s = 0; for (const c of combs) { const y = c.b[c.i]; c.lp = y * (1 - damp) + c.lp * damp; c.b[c.i] = src[i] + c.lp * fb; c.i = (c.i + 1) % c.d; s += y; } out[i] = s / combs.length; }
  for (const d of [225, 556, 441]) { const b = new Float32Array(d); let k = 0; for (let i = 0; i < n; i++) { const y = b[k], x = out[i]; b[k] = x + y * 0.5; out[i] = y - x * 0.5; k = (k + 1) % d; } }
  return out;
}
const sat = (x, k) => Math.tanh(x * k) / Math.tanh(k);

// ---------- слои ----------
// голос: P = { len, f0: [[t, Гц]…], form (множитель формант), vow: [[t, F1], …] (раскрытие рта), rough (подтон и рык 0..1),
//   breath (шум), vib [Гц, глубина], jit, drive, cracks (срывы голоса в секунду), env [[t, a]…] }
function voice(P, rnd) {
  const n = Math.floor(P.len * SR), out = new Float32Array(n);
  const F = [[1, 1.0, 5], [1.55, 0.75, 7], [3.1, 0.5, 9], [4.4, 0.32, 10]];     // [доля от F1-опоры, вес, добротность]
  const bq = F.map(() => new Biquad());
  let ph = 0, ph2 = 0, jit = 0, crack = 1, crackT = 0, vibPh = rnd() * 6.28, lpN = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    jit += (rnd() - 0.5) * P.jit; jit *= 0.995;
    if (P.cracks && rnd() < P.cracks / SR) { crack = rnd() < 0.5 ? 2 : 0.5; crackT = 0.03 + rnd() * 0.08; }
    if (crackT > 0) { crackT -= 1 / SR; if (crackT <= 0) crack = 1; }
    vibPh += 2 * Math.PI * P.vib[0] / SR;
    const f0 = curve(P.f0, t) * (1 + jit) * crack * (1 + Math.sin(vibPh) * P.vib[1] * smooth(0.08, 0.5, t));
    ph += f0 / SR; if (ph >= 1) ph -= 1; ph2 += f0 * 0.5 / SR; if (ph2 >= 1) ph2 -= 1;
    // связки: пила с более резким фронтом + подтон на октаву ниже (рык)
    let src = (2 * ph - 1) * 0.8 + (ph < 0.12 ? 1 : -0.14) * 0.5;
    src += ((2 * ph2 - 1) * 0.9 + (ph2 < 0.2 ? 1 : -0.25) * 0.4) * P.rough;
    src *= 1 - P.rough * 0.35 * (0.5 + 0.5 * Math.sin(2 * Math.PI * (38 + 20 * P.rough) * t));      // шероховатость
    const nz = rnd() * 2 - 1; lpN += (nz - lpN) * 0.5;
    src += (nz - lpN) * P.breath * (0.6 + 0.4 * (ph < 0.5 ? 1 : 0.3));
    const f1 = curve(P.vow, t) * P.form;
    let y = 0;
    if ((i & 31) === 0) for (let k = 0; k < F.length; k++) bq[k].set('bp', k === 0 ? f1 : 520 * F[k][0] * P.form * (1 + 0.05 * Math.sin(t * 7 + k)), F[k][2]);
    for (let k = 0; k < F.length; k++) y += bq[k].run(src) * F[k][1];
    out[i] = sat(y * 6 + src * 0.12, P.drive) * curve(P.env, t);
  }
  return out;
}
// удар: щелчок и шумовая вспышка
function impact(len, rnd, bright = 1) { const n = Math.floor(len * SR), o = new Float32Array(n); let lp = 0; for (let i = 0; i < n; i++) { const t = i / SR, nz = rnd() * 2 - 1; lp += (nz - lp) * 0.35; const e = Math.exp(-t * 90) + 0.5 * Math.exp(-t * 22); o[i] = (nz * bright + lp * (2 - bright)) * e * (i < 20 ? i / 20 : 1) + Math.sin(2 * Math.PI * 180 * t) * Math.exp(-t * 60) * 0.9; } return o; }
// низкий импульс
function sub(len, f0, f1, rnd) { const n = Math.floor(len * SR), o = new Float32Array(n); let ph = 0; for (let i = 0; i < n; i++) { const t = i / SR, f = f1 + (f0 - f1) * Math.exp(-t * 9); ph += f / SR; o[i] = sat(Math.sin(2 * Math.PI * ph) * 1.6, 1.4) * Math.exp(-t * (3.2 / len)) * (i < 40 ? i / 40 : 1); } return o; }
function mixInto(dst, src, gain, at = 0) { const o = Math.floor(at * SR); for (let i = 0; i < src.length && i + o < dst.length; i++) dst[i + o] += src[i] * gain; }
// дробление разрядности и частоты
function crush(buf, bits, hold, amount, rnd, gate) { const o = new Float32Array(buf.length), q = Math.pow(2, bits - 1); let h = 0; for (let i = 0; i < buf.length; i++) { if (i % hold === 0) h = Math.round(buf[i] * q) / q; const g = gate ? gate(i / SR) : 1; o[i] = lerp(buf[i], h, amount * g); } return o; }
// заикание: куски повторяются
function stutter(buf, rnd, from, count, slice) { const o = Float32Array.from(buf); let p = Math.floor(from * SR); for (let k = 0; k < count; k++) { const sl = Math.floor(slice * (0.6 + rnd() * 0.8) * SR), reps = 2 + Math.floor(rnd() * 3); for (let r = 1; r <= reps; r++) for (let i = 0; i < sl && p + r * sl + i < o.length; i++) o[p + r * sl + i] = buf[p + i] * (1 - 0.12 * r); p += sl * (reps + 1) + Math.floor(rnd() * 0.12 * SR); if (p >= o.length) break; } return o; }

// «резь»: верх голоса отдельно перегружен и подмешан — крик режет, а не гудит
function rasp(buf, from, k) { const h = filt(buf, 'hp', from, 0.8), o = new Float32Array(buf.length); for (let i = 0; i < o.length; i++) o[i] = sat(h[i] * k, 2.5); return o; }

// ---------- обитатели ----------
// v — вариант 0..N−1: сдвиг высоты, длины и случайных мест; у каждого 3 разных на слух крика
const WHO = {
  // БАЛОН — низкий искажённый звериный вопль с шипением вентиля
  balon(v, rnd) {
    const len = 2.2 + v * 0.15, k = [1, 0.9, 1.12][v % 3];
    let a = voice({ len, f0: [[0, 150 * k], [0.05, 118 * k], [0.7, 96 * k], [len, 62 * k]], form: 0.7, vow: [[0, 420], [0.05, 820], [1.2, 760], [len, 520]], rough: 0.95, breath: 0.5, vib: [5.2, 0.05], jit: 0.0009, drive: 3.4, cracks: 1.2,
      env: [[0, 0], [0.004, 1], [0.9, 0.95], [len - 0.5, 0.6], [len, 0]] }, rnd);
    a = filt(a, 'hp', 55);
    const hiss = new Float32Array(a.length); for (let i = 0; i < hiss.length; i++) { const t = i / SR; hiss[i] = (rnd() * 2 - 1) * Math.exp(-t * 2.2) * (0.6 + 0.4 * Math.sin(2 * Math.PI * 31 * t)); }
    return { parts: [[a, 1.0], [filt(hiss, 'bp', 5200, 0.8), 0.35], [impact(0.2, rnd, 0.6), 1.1], [sub(0.8, 95, 32, rnd), 1.9]], wet: 0.16, size: 1.1, tail: 0.6 };
  },
  // MADK1D — резкий агрессивный крик с цифровыми помехами
  madk1d(v, rnd) {
    const len = 1.5 + v * 0.1, k = [1, 1.1, 0.92][v % 3];
    let a = voice({ len, f0: [[0, 520 * k], [0.04, 660 * k], [0.5, 610 * k], [len, 380 * k]], form: 1.08, vow: [[0, 600], [0.03, 1050], [len, 900]], rough: 0.45, breath: 0.35, vib: [7.5, 0.035], jit: 0.0014, drive: 3.0, cracks: 3.5,
      env: [[0, 0], [0.003, 1], [0.6, 1], [len - 0.25, 0.7], [len, 0]] }, rnd);
    a = crush(a, 5, 6 + v * 2, 0.75, rnd, t => (Math.sin(2 * Math.PI * (13 + v * 4) * t) > 0.2 ? 1 : 0.15));
    a = stutter(a, rnd, 0.55 + v * 0.1, 3, 0.035);
    const glitch = new Float32Array(a.length); for (let i = 0; i < glitch.length; i++) { const t = i / SR, st = Math.floor(t * 46); glitch[i] = Math.sign(Math.sin(2 * Math.PI * (900 + ((st * 733) % 2600)) * t)) * (((st * 7) % 5) < 2 ? 1 : 0) * Math.exp(-t * 2.5); }
    return { parts: [[a, 1.0], [rasp(a, 2600, 5), 0.35], [glitch, 0.22], [impact(0.12, rnd, 1.4), 1.2], [sub(0.4, 110, 42, rnd), 0.7]], wet: 0.1, size: 0.8, tail: 0.35 };
  },
  // BOT — механический визг, смешанный с человеческим криком
  bot(v, rnd) {
    const len = 1.7 + v * 0.12, k = [1, 0.88, 1.15][v % 3];
    const a = voice({ len, f0: [[0, 300 * k], [0.06, 360 * k], [len, 250 * k]], form: 0.95, vow: [[0, 500], [0.05, 900], [len, 780]], rough: 0.55, breath: 0.3, vib: [6, 0.03], jit: 0.0008, drive: 2.6, cracks: 1.5,
      env: [[0, 0], [0.004, 1], [len - 0.3, 0.8], [len, 0]] }, rnd);
    const mech = new Float32Array(a.length); let ph = 0;
    for (let i = 0; i < a.length; i++) { const t = i / SR, f = lerp(1250, 3300 + v * 300, smooth(0, len * 0.8, t)) * (1 + 0.06 * Math.sin(2 * Math.PI * 43 * t)); ph += f / SR;
      const gate = Math.sin(2 * Math.PI * (27 + v * 5) * t) > -0.3 ? 1 : 0.2; mech[i] = Math.sin(2 * Math.PI * ph + 2.4 * Math.sin(2 * Math.PI * ph * 0.31)) * gate * Math.exp(-t * 0.9); a[i] *= 0.55 + 0.45 * Math.sin(2 * Math.PI * (1900 * k) * t); }
    return { parts: [[a, 1.0], [mech, 0.7], [rasp(a, 2400, 4), 0.25], [impact(0.15, rnd, 1.2), 1.1], [sub(0.5, 100, 38, rnd), 0.8]], wet: 0.14, size: 0.9, tail: 0.45 };
  },
  // CLIPPER — короткий пронзительный крик и звон лезвия
  clipper(v, rnd) {
    const len = 0.85 + v * 0.08, k = [1, 1.14, 0.9][v % 3];
    const a = voice({ len, f0: [[0, 880 * k], [0.03, 1320 * k], [0.3, 1250 * k], [len, 900 * k]], form: 1.3, vow: [[0, 700], [0.02, 1250], [len, 1100]], rough: 0.2, breath: 0.4, vib: [9, 0.025], jit: 0.0016, drive: 2.8, cracks: 4,
      env: [[0, 0], [0.002, 1], [len - 0.3, 0.9], [len, 0]] }, rnd);
    const blade = new Float32Array(a.length); for (let i = 0; i < blade.length; i++) { const t = i / SR; let s = 0; for (const f of [3120, 4410, 5870, 7230]) s += Math.sin(2 * Math.PI * f * k * t) / 4; blade[i] = s * Math.exp(-t * 6); }
    return { parts: [[filt(a, 'hp', 420), 1.2], [rasp(a, 2800, 6), 0.6], [blade, 0.85], [impact(0.08, rnd, 1.8), 1.3], [sub(0.25, 120, 55, rnd), 0.3]], wet: 0.12, size: 0.7, tail: 0.3 };
  },
  // GHOST — сверхъестественный вопль в два голоса, с эхом
  ghost(v, rnd) {
    const len = 2.6 + v * 0.2, k = [1, 0.84, 1.2][v % 3];
    const P = c => ({ len, f0: [[0, 430 * k * c], [0.08, 520 * k * c], [1.2, 610 * k * c], [len, 300 * k * c]], form: 1.0, vow: [[0, 380], [0.06, 760], [1.5, 900], [len, 420]], rough: 0.15, breath: 0.6, vib: [5.5, 0.07], jit: 0.0006, drive: 1.8, cracks: 0.8,
      env: [[0, 0], [0.004, 1], [1.4, 0.9], [len, 0]] });
    const a = voice(P(1), rnd), b = voice(P(1.011 * (v === 1 ? 1.5 : 1)), rnd), c2 = voice(P(0.5), rnd);
    const mix = new Float32Array(a.length); for (let i = 0; i < mix.length; i++) mix[i] = a[i] * 0.6 + b[i] * 0.5 + c2[i] * 0.35;
    const echo = new Float32Array(mix.length + SR); for (const [d, g] of [[0.19, 0.5], [0.38, 0.3], [0.57, 0.18]]) mixInto(echo, mix, g, d);
    return { parts: [[filt(mix, 'hp', 180), 1.3], [filt(echo, 'hp', 220), 0.7], [rasp(mix, 2200, 3), 0.2], [impact(0.18, rnd, 0.9), 1.0], [sub(0.6, 80, 34, rnd), 0.4]], wet: 0.5, size: 1.6, tail: 2.2, wetHp: 200 };
  },
  // MOD — резкий искажённый голос, повреждённая запись: выпадения, плывущая высота, заикание
  mod(v, rnd) {
    const len = 1.9 + v * 0.12, k = [1, 1.18, 0.86][v % 3];
    const wob = t => 1 + 0.08 * Math.sin(2 * Math.PI * 3.1 * t) + (Math.floor(t * 9) % 4 === 3 ? 0.12 : 0);
    const f0 = []; for (let t = 0; t <= len; t += 0.05) f0.push([t, lerp(210, 280, smooth(0, 0.3, t)) * k * wob(t)]);
    let a = voice({ len, f0, form: 0.92, vow: [[0, 450], [0.04, 880], [len, 700]], rough: 0.6, breath: 0.3, vib: [4, 0.02], jit: 0.002, drive: 3.6, cracks: 2.5,
      env: [[0, 0], [0.003, 1], [len - 0.2, 0.85], [len, 0]] }, rnd);
    a = filt(filt(a, 'hp', 320), 'lp', 3600);                 // «из плохой записи»
    for (let i = 0; i < a.length; i++) { const t = i / SR, slot = Math.floor(t * 17); if (t > 0.12 && ((slot * 53 + v * 11) % 7) === 0) a[i] *= 0.06; }      // выпадения ленты
    a = crush(a, 4, 9, 0.6, rnd);
    a = stutter(a, rnd, 0.3 + v * 0.15, 4, 0.05);
    const hum = new Float32Array(a.length); for (let i = 0; i < hum.length; i++) { const t = i / SR; hum[i] = Math.sign(Math.sin(2 * Math.PI * 50 * t)) * 0.5 + (rnd() * 2 - 1) * 0.4 * (Math.floor(t * 23) % 3 === 0 ? 1 : 0); }
    return { parts: [[a, 1.0], [filt(hum, 'bp', 1800, 0.6), 0.2], [impact(0.12, rnd, 1.3), 1.2], [sub(0.45, 95, 40, rnd), 0.85]], wet: 0.08, size: 0.7, tail: 0.3 };
  },
  // ПАХАН — человеческий внезапный крик (секретный скример)
  pahan(v, rnd) {
    const len = 1.25 + v * 0.1, k = [1, 0.93, 1.08][v % 3];
    const a = voice({ len, f0: [[0, 230 * k], [0.05, 340 * k], [0.5, 320 * k], [len, 190 * k]], form: 1.0, vow: [[0, 520], [0.04, 880], [0.8, 820], [len, 560]], rough: 0.5, breath: 0.25, vib: [6, 0.03], jit: 0.0012, drive: 2.4, cracks: 2,
      env: [[0, 0], [0.004, 1], [0.7, 0.95], [len, 0]] }, rnd);
    const slap = new Float32Array(a.length + SR / 4); mixInto(slap, a, 0.4, 0.11);
    return { parts: [[filt(a, 'hp', 140), 1.1], [slap, 0.5], [rasp(a, 2300, 3), 0.25], [impact(0.12, rnd, 1.0), 1.0], [sub(0.35, 100, 48, rnd), 0.35]], wet: 0.18, size: 1.0, tail: 0.5 };
  },
  // ТЕМНОТА — кто-то в полной темноте: низкий рёв с шёпотом
  dark(v, rnd) {
    const len = 2.0 + v * 0.15, k = [1, 0.88, 1.1][v % 3];
    const a = voice({ len, f0: [[0, 120 * k], [0.06, 96 * k], [len, 58 * k]], form: 0.62, vow: [[0, 380], [0.06, 700], [len, 480]], rough: 1.0, breath: 0.8, vib: [4.5, 0.06], jit: 0.001, drive: 3.8, cracks: 1,
      env: [[0, 0], [0.004, 1], [len - 0.5, 0.7], [len, 0]] }, rnd);
    return { parts: [[filt(a, 'hp', 45), 1.0], [impact(0.25, rnd, 0.5), 1.2], [sub(0.9, 85, 30, rnd), 1.8]], wet: 0.3, size: 1.4, tail: 1.0 };
  },
};

// ---------- сведение ----------
function build(id, v) {
  const rnd = rngOf(id.split('').reduce((a, c) => a * 31 + c.charCodeAt(0), 7) + v * 977);
  const R = WHO[id](v, rnd);
  let n = 0; for (const [b] of R.parts) n = Math.max(n, b.length);
  let dry = new Float32Array(n); for (const [b, g] of R.parts) mixInto(dry, b, g);
  let wet = reverb(dry, R.size, 0.35, R.tail);
  if (R.wetHp) wet = filt(wet, 'hp', R.wetHp);
  const out = new Float32Array(wet.length); for (let i = 0; i < out.length; i++) out[i] = (i < dry.length ? dry[i] : 0) + wet[i] * R.wet * 2.2;
  // одна средняя громкость первых 0,6 с у всех (−13 дБ), затем мягкий ограничитель и пик −1 дБ
  let sq = 0; const m = Math.min(out.length, Math.floor(0.6 * SR)); for (let i = 0; i < m; i++) sq += out[i] * out[i];
  const g = 0.224 / Math.sqrt(sq / m + 1e-9);
  let peak = 0; for (let i = 0; i < out.length; i++) { out[i] = sat(out[i] * g * 1.15, 1.25) * 0.9; peak = Math.max(peak, Math.abs(out[i])); }
  if (peak > 0.891) for (let i = 0; i < out.length; i++) out[i] *= 0.891 / peak;
  // конец без щелчка
  const f = Math.floor(0.05 * SR); for (let i = 0; i < f; i++) out[out.length - 1 - i] *= i / f;
  // замеры: когда достигается половина пика (резкость начала), пик, средняя громкость
  let pk = 0, at = 0; for (let i = 0; i < out.length; i++) pk = Math.max(pk, Math.abs(out[i]));
  for (let i = 0; i < out.length; i++) if (Math.abs(out[i]) >= pk * 0.5) { at = i; break; }
  let s2 = 0; for (let i = 0; i < m; i++) s2 += out[i] * out[i];
  return { out, len: out.length / SR, peakDb: 20 * Math.log10(pk), rmsDb: 10 * Math.log10(s2 / m), attackMs: at / SR * 1000 };
}
function wav(buf) {
  const b = Buffer.alloc(44 + buf.length * 2); b.write('RIFF', 0); b.writeUInt32LE(36 + buf.length * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
  b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(buf.length * 2, 40);
  for (let i = 0; i < buf.length; i++) b.writeInt16LE(Math.round(clamp(buf[i], -1, 1) * 32767), 44 + i * 2); return b;
}
fs.mkdirSync(OUT, { recursive: true });
const meta = {};
for (const id of Object.keys(WHO)) {
  if (only.length && !only.includes(id)) continue;
  meta[id] = [];
  for (let v = 0; v < VARIANTS; v++) {
    const r = build(id, v), name = `scream_${id}_${v + 1}.wav`;
    fs.writeFileSync(path.join(OUT, name), wav(r.out));
    meta[id].push({ file: name, len: +r.len.toFixed(2) });
    console.log(`${name}: ${r.len.toFixed(2)} с, пик ${r.peakDb.toFixed(1)} дБ, средняя (0,6 с) ${r.rmsDb.toFixed(1)} дБ, до половины пика ${r.attackMs.toFixed(1)} мс`);
  }
}
if (!only.length) fs.writeFileSync(path.join(OUT, 'screams.json'), JSON.stringify(meta, null, 1));
