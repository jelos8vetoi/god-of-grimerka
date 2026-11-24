// Общие инструменты сборки звука «5 НОЧЕЙ» из записей (tools/godot-fn-audio-gate.cjs, tools/godot-fn-audio-p1.cjs):
// вырезка из исходника через ffmpeg, монтажный стол, огибающие, свёртка, ограничитель, замер громкости, запись WAV и OGG.
// Синтеза здесь нет: всё, что попадает в результат, приходит из src().
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process');
module.exports = (SRC, FF) => {
const SR = 44100;
// ---------- ffmpeg и буферы ----------
function ff(args, input, verbose) {
  const r = spawnSync(FF, ['-hide_banner', '-nostats', '-v', verbose ? 'info' : 'error', '-y', ...args], { input, maxBuffer: 1 << 30 });
  if (r.status !== 0) throw new Error('ffmpeg: ' + String(r.stderr).slice(-700));
  return r;
}
const f32 = (b) => new Float32Array(b.buffer.slice(b.byteOffset, b.byteOffset + (b.length & ~3)));
const raw = (x) => Buffer.from(x.buffer, x.byteOffset, x.byteLength);
const RAWIN = ['-f', 'f32le', '-ar', String(SR), '-ac', '1'];
const USED = {};                                   // что и откуда взято — для документа
function note(name, ss, t, o) { (USED[name] = USED[name] || []).push(`${(+ss).toFixed(2)}+${(+t).toFixed(2)} с` + (o.rate && o.rate !== 1 ? `, скорость ×${o.rate}` : '') + (o.af ? `, ${o.af}` : '')); }
// вырезка из записи: ss, t — в секундах исходника; o.rate — скорость ленты (0.8 = ниже и длиннее), o.af — фильтры ffmpeg
function src(name, ss, t, o = {}) {
  const af = [];
  if (o.rate && o.rate !== 1) af.push(`aresample=48000,asetrate=${Math.round(48000 * o.rate)},aresample=${SR}`);
  if (o.af) af.push(o.af);
  const r = ff(['-ss', String(Math.max(0, ss)), '-t', String(t), '-i', path.join(SRC, name), ...(af.length ? ['-af', af.join(',')] : []), '-f', 'f32le', '-ac', '1', '-ar', String(SR), '-']);
  note(name, ss, t, o);
  return f32(r.stdout);
}
// точное начало удара рядом с t: первый отсчёт выше 12 % пика окна
function onset(name, t, win = 0.04) {
  const a = Math.max(0, t - win), x = f32(ff(['-ss', String(a), '-t', String(win * 2 + 0.02), '-i', path.join(SRC, name), '-f', 'f32le', '-ac', '1', '-ar', String(SR), '-']).stdout);
  const p = peak(x); for (let i = 0; i < x.length; i++) if (Math.abs(x[i]) > p * 0.12) return a + i / SR;
  return t;
}
const hit = (name, t, len, o) => src(name, onset(name, t) - 0.002, len, o);
const dB = (d) => Math.pow(10, d / 20);
function peak(x) { let p = 0; for (let i = 0; i < x.length; i++) { const a = x[i] < 0 ? -x[i] : x[i]; if (a > p) p = a; } return p; }
function rms(x) { let s = 0; for (let i = 0; i < x.length; i++) s += x[i] * x[i]; return Math.sqrt(s / Math.max(1, x.length)); }
function gain(x, d) { const g = dB(d), y = new Float32Array(x.length); for (let i = 0; i < x.length; i++) y[i] = x[i] * g; return y; }
function norm(x, pk = -3) { const p = peak(x); return p > 0 ? gain(x, pk - 20 * Math.log10(p)) : x; }
function match(x, ref) { const a = rms(x), b = rms(ref); return a > 0 ? gain(x, 20 * Math.log10(b / a)) : x; }
function fade(x, fi, fo, shape = 2) {
  const y = Float32Array.from(x), a = Math.min(y.length, Math.round(fi * SR)), b = Math.min(y.length, Math.round(fo * SR));
  for (let i = 0; i < a; i++) y[i] *= 0.5 - 0.5 * Math.cos(Math.PI * i / a);
  for (let i = 0; i < b; i++) y[y.length - 1 - i] *= Math.pow(i / b, shape);
  return y;
}
// огибающая громкости по точкам [[с, дБ], …]
function env(x, pts) {
  const y = new Float32Array(x.length); let j = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / SR; while (j < pts.length - 2 && t > pts[j + 1][0]) j++;
    const [t0, d0] = pts[j], [t1, d1] = pts[Math.min(j + 1, pts.length - 1)], k = t1 > t0 ? Math.min(1, Math.max(0, (t - t0) / (t1 - t0))) : 1;
    y[i] = x[i] * dB(d0 + (d1 - d0) * k);
  }
  return y;
}
// монтажный стол: [[буфер, начало с, дБ], …]
function mix(len, items) {
  const y = new Float32Array(Math.round(len * SR));
  for (const [x, t, d = 0] of items) { const o = Math.round(t * SR), g = dB(d); for (let i = 0; i < x.length && o + i < y.length; i++) if (o + i >= 0) y[o + i] += x[i] * g; }
  return y;
}
function fx(x, af) { const y = f32(ff([...RAWIN, '-i', 'pipe:0', '-af', af, '-f', 'f32le', '-ac', '1', '-ar', String(SR), '-'], raw(x)).stdout); return y.length === x.length ? y : (() => { const z = new Float32Array(x.length); z.set(y.subarray(0, x.length)); return z; })(); }
function fft(re, im, inv) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) { let b = n >> 1; for (; j & b; b >>= 1) j ^= b; j ^= b; if (i < j) { let t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; } }
  for (let len = 2; len <= n; len <<= 1) {
    const a = (inv ? 2 : -2) * Math.PI / len, wr = Math.cos(a), wi = Math.sin(a);
    for (let i = 0; i < n; i += len) { let cr = 1, ci = 0; for (let k = 0; k < len / 2; k++) { const p = i + k, q = p + len / 2, xr = re[q] * cr - im[q] * ci, xi = re[q] * ci + im[q] * cr; re[q] = re[p] - xr; im[q] = im[p] - xi; re[p] += xr; im[p] += xi; const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t; } }
  }
  if (inv) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
}
// свёртка с записанным откликом (удар по металлу): звук «внутри» этого металла
function convolve(x, ir) {
  let n = 1; while (n < x.length + ir.length) n <<= 1;
  const ar = new Float64Array(n), ai = new Float64Array(n), br = new Float64Array(n), bi = new Float64Array(n);
  ar.set(x); br.set(ir); fft(ar, ai); fft(br, bi);
  for (let i = 0; i < n; i++) { const r = ar[i] * br[i] - ai[i] * bi[i]; ai[i] = ar[i] * bi[i] + ai[i] * br[i]; ar[i] = r; }
  fft(ar, ai, true);
  const y = new Float32Array(x.length); for (let i = 0; i < y.length; i++) y[i] = ar[i];
  return y;
}
// ограничитель с опережением: пик не выше ceil, без сдвига по времени
function limit(x, ceilDb = -1, look = 0.003, rel = 0.09) {
  const c = dB(ceilDb), n = x.length, L = Math.max(1, Math.round(look * SR)), g = new Float32Array(n).fill(1);
  for (let i = 0; i < n; i++) { const a = Math.abs(x[i]); if (a > c) { const need = c / a; for (let k = Math.max(0, i - L); k <= i; k++) { const v = need + (1 - need) * ((i - k) / L); if (v < g[k]) g[k] = v; } } }
  const kr = Math.exp(-1 / (rel * SR)), y = new Float32Array(n); let cur = 1;
  for (let i = 0; i < n; i++) { cur = Math.min(g[i], 1 - (1 - cur) * kr); y[i] = x[i] * cur; }
  return y;
}
// громкость по EBU R128: [наибольшая мгновенная (400 мс), интегральная], LUFS
function loud(x) {
  const p = new Float32Array(x.length + SR * 2); p.set(x, SR);
  const log = String(ff([...RAWIN, '-i', 'pipe:0', '-af', 'ebur128', '-f', 'null', '-'], raw(p), true).stderr);
  let m = -120; for (const q of log.matchAll(/ M:\s*(-?[\d.]+)/g)) m = Math.max(m, +q[1]);
  const i = (log.match(/I:\s*(-?[\d.]+) LUFS\s+Threshold/) || [, '-120'])[1];
  return [m, +i];
}
// довести наибольшую мгновенную громкость до цели, пик — не выше ceil
function level(x, targetM, ceilDb = -1) {
  let y = x; for (let k = 0; k < 4; k++) { const [m] = loud(y); if (Math.abs(m - targetM) < 0.15) break; y = limit(gain(y, targetM - m), ceilDb); }
  return y;
}
function wavBytes(x, rate = SR) {
  const n = x.length, b = Buffer.alloc(44 + n * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
  b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * 2, 40);
  let s = 12345; const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
  for (let i = 0; i < n; i++) b.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(x[i] * 32767 + (x[i] !== 0 ? rnd() - rnd() : 0)))), 44 + i * 2);   // треугольный дизеринг
  return b;
}
const REPORT = [];
function stat(name, x) { const [m, i] = loud(x); REPORT.push({ file: name, len: +(x.length / SR).toFixed(2), peak: +(20 * Math.log10(peak(x) || 1e-9)).toFixed(1), rms: +(20 * Math.log10(rms(x) || 1e-9)).toFixed(1), M: m, I: i }); }
function saveWav(dir, name, x) { fs.writeFileSync(path.join(dir, name), wavBytes(x)); stat(name, x); }
function saveOgg(dir, name, x) { ff([...RAWIN, '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '6', '-map_metadata', '-1', '-bitexact', path.join(dir, name)], raw(x)); stat(name, x); }
function readWav(file) { return f32(ff(['-i', file, '-f', 'f32le', '-ac', '1', '-ar', String(SR), '-']).stdout); }
const tail = (x, len, fo) => { const y = new Float32Array(Math.round(len * SR)); y.set(x.subarray(0, y.length)); return fade(y, 0, fo); };
return { SR, USED, REPORT, ff, f32, raw, RAWIN, src, onset, hit, dB, peak, rms, gain, norm, match, fade, env, mix, fx, convolve, limit, loud, level, wavBytes, stat, saveWav, saveOgg, readWav, tail };
};
