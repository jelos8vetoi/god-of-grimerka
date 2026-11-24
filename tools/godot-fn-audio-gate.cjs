// AUDIO QUALITY GATE «5 НОЧЕЙ С ПАХАНОМ»: шесть вариантов трёх звуков из настоящих записей (CC0).
//   node tools/godot-fn-audio-gate.cjs --src <папка исходников> [--ffmpeg <ffmpeg.exe>] [--only balon|cam|crawl]
// Исходники в репозиторий не входят: их список, страницы, авторы и лицензии — godot/docs/FIVE_NIGHTS_AUDIO_GATE.md.
// Здесь нет синтеза: ни генераторов тона, ни шума. Всё, что звучит, — вырезки из записей; обработка — монтаж, смена
// скорости ленты (высота вместе с длиной), фильтры, насыщение, свёртка с записанным ударом по металлу, ранние отражения,
// компрессор и ограничитель. Результат:
//   godot/assets/audio/fn/gate/balon_a.wav, balon_b.wav          — скример БАЛОНА (A — голос, B — удар)
//   godot/assets/audio/fn/gate/cam_a_1..4.wav, cam_b_1..4.wav    — переключение камеры (A — механика, B — сигнал)
//   godot/assets/audio/fn/gate/crawl_a_1..3.ogg, crawl_b_1..3.ogg — MADK1D в шахте (A — тяжёлый, B — осторожный)
//   docs/audio_quality_gate/*.wav                                — девять файлов для сравнения вне игры
// После сборки: Godot --headless --path godot --import.
const fs = require('fs'), path = require('path'), os = require('os'), { spawnSync } = require('child_process');
const opt = (k) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : ''; };
const SRC = opt('src'), FF = opt('ffmpeg') || process.env.FFMPEG || 'ffmpeg', ONLY = opt('only');
if (!SRC) { console.error('нужен --src <папка исходников>'); process.exit(1); }
const ROOT = path.join(__dirname, '..'), OUT = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'gate'), CMP = path.join(ROOT, 'docs', 'audio_quality_gate');
const ORIG = path.join(ROOT, 'godot', 'assets', 'audio', 'fn');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'fngate-'));
const SR = 44100;
for (const d of [OUT, CMP]) fs.mkdirSync(d, { recursive: true });

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

// ================= SOUND A — скример БАЛОНА =================
// Балон — баллон со сжатым воздухом. Оба варианта: живое горло + воздух под давлением + сталь.
// Длина 2,9 с — как у прежних (2,8–3,1 с): тряска кадра считается от длины крика и остаётся прежней.

// A1 «Organic Distortion»: впереди голос. Рык с хрипом связок (человек, без обработки) на замедленной ленте,
// под ним второй, ниже; мокрый горловой спазм в самом начале; всё это отзывается в стальном корпусе
// (свёртка с ударом по железным воротам), сверху — струя сжатого воздуха по алюминию.
function balonA() {
  const v1 = fade(src('bsb2110.wav', 0.03, 1.80, { rate: 0.84 }), 0.002, 0.2);
  const v2 = fade(src('bsb2107.wav', 0.03, 1.08, { rate: 0.667 }), 0.004, 0.3);
  const wet = fade(src('bsb2498.wav', 0.19, 0.58, { rate: 0.75 }), 0.003, 0.15);
  const end = fade(src('bsb2112.wav', 0.25, 0.85, { rate: 0.75 }), 0.1, 0.55);
  let vox = mix(3.0, [[norm(v1), 0, 0], [norm(v2), 0, -4], [norm(wet), 0.015, -6], [norm(end), 1.3, -5]]);
  vox = fx(vox, 'highpass=f=60,equalizer=f=170:t=q:w=0.9:g=3,equalizer=f=2600:t=q:w=1.2:g=2.5,lowpass=f=7500');
  const drive = fx(vox, 'volume=14dB,asoftclip=type=tanh,highpass=f=180,lowpass=f=4200');           // перегруз — параллельно, под чистым голосом
  vox = mix(3.0, [[vox, 0, 0], [match(drive, vox), 0, -5]]);
  const body = fade(src('bsb2360.wav', 0.245, 0.55, { rate: 0.8, af: 'highpass=f=140' }), 0.001, 0.4);
  const tank = match(convolve(vox, body), vox);
  const air1 = fade(src('bsb0748.wav', 4.05, 1.6, { af: 'highpass=f=800,lowpass=f=5200' }), 0.004, 0.5);
  const air2 = fade(src('bsb0748.wav', 14.29, 1.45, { af: 'highpass=f=900,lowpass=f=4500' }), 0.35, 0.9);
  const pop = fade(hit('bsb0551.wav', 0.71, 0.07, {}), 0.0005, 0.04);
  let m = mix(3.0, [[vox, 0, 0], [tank, 0, -9], [norm(env(air1, [[0, 4], [0.15, 2], [0.4, 0]])), 0, -12], [norm(air2), 1.35, -19], [norm(pop), 0, -5]]);
  m = fx(m, 'acompressor=threshold=-16dB:ratio=2.5:attack=6:release=140:makeup=1');
  m = env(m, [[0, 4], [0.12, 3], [0.3, 1], [0.7, 0], [1.25, -1.5], [1.9, -8], [2.5, -17], [2.9, -40]]);
  m = fx(norm(m, -1), 'volume=5dB,asoftclip=type=tanh');                  // пики голоса уходят в насыщение, а не в ограничитель
  return tail(m, 2.9, 0.06);
}
// A2 «Physical Impact»: впереди удар. Железные ворота захлопываются (на замедленной ленте — тяжелее), под ними
// глухой удар двери машины изнутри и выстрел газовой пушки; сразу за ударом — выброс сжатого воздуха; листовая
// сталь падает и дребезжит после; горло слышно только изнутри корпуса; низ держит раскат грома.
function balonB() {
  const slam = fade(hit('bsb2360.wav', 0.25, 1.3, { rate: 0.79 }), 0.0005, 0.5);
  const sub = fade(hit('bsb0655.wav', 0.2, 0.4, { af: 'lowpass=f=160' }), 0.001, 0.2);
  const boom = fade(src('bsb1808.wav', 0.0, 0.32, { af: 'lowpass=f=700' }), 0.0005, 0.15);
  const blast = env(fade(src('bsb0748.wav', 2.07, 1.45, { af: 'highpass=f=450,lowpass=f=4000' }), 0.003, 0.3), [[0, 0], [0.12, -2], [0.5, -10], [1.1, -22], [1.45, -34]]);
  const growl = fade(src('bsb2109.wav', 0.05, 2.0, { rate: 0.7, af: 'lowpass=f=1500' }), 0.03, 0.9);
  const r1 = fade(hit('bsb1777.wav', 0.07, 0.62, { rate: 0.667 }), 0.001, 0.4);
  const r2 = fade(hit('bsb1773.wav', 0.05, 0.75, { rate: 0.6 }), 0.001, 0.6);
  const rum = fade(src('bsb3113.wav', 1.03, 2.3, { af: 'lowpass=f=150' }), 0.01, 1.2);
  const leak = fade(src('bsb0748.wav', 8.58, 0.62, { af: 'highpass=f=900,lowpass=f=4500' }), 0.1, 0.45);
  const body = fade(src('bsb2360.wav', 0.245, 0.5, { rate: 0.79, af: 'highpass=f=120' }), 0.001, 0.35);
  const g = mix(3.0, [[norm(growl), 0, 0]]);
  let org = mix(3.0, [[g, 0, -3], [match(convolve(g, body), g), 0, 0]]);
  org = fx(org, 'volume=10dB,asoftclip=type=tanh,lowpass=f=2400');
  org = env(org, [[0, -6], [0.25, 0], [0.9, -3], [1.8, -14], [2.8, -40]]);
  let m = mix(3.0, [[norm(slam), 0, 0], [norm(sub), 0, -2], [norm(boom), 0, -5], [norm(blast), 0.02, -6], [norm(org), 0.05, -12],
    [norm(r1), 0.44, -8], [norm(r2), 0.93, -14], [norm(rum), 0.04, -12], [norm(leak), 1.55, -22]]);
  m = fx(m, 'highpass=f=32,equalizer=f=90:t=q:w=0.8:g=3,equalizer=f=3200:t=q:w=1.5:g=-2');
  m = fx(m, 'acompressor=threshold=-12dB:ratio=2:attack=12:release=160:makeup=1');
  m = env(m, [[0, 2], [0.15, 1], [0.4, -1.5], [1.0, -5], [1.6, -10], [2.3, -18], [2.9, -40]]);
  return tail(m, 2.9, 0.06);
}

// ================= SOUND B — переключение камеры =================
// Короткий (≤ 0,2 с), без тона и писка; у каждого варианта четыре дубля — подряд один и тот же не играет.

// B1 «Analog Relay»: щелчок контакта термостата, сразу за ним — клавиша и механизм видеомагнитофона (четыре разных
// нажатия), на контакте — короткая искра (дуговая сварка, очень тихо).
const VCR = [['bsb2688.wav', 4.085, 0.12, 0], ['bsb2690.wav', 1.425, 0.12, 0], ['bsb2688.wav', 28.44, 0.14, 1], ['bsb0571.wav', 14.13, 0.09, 1]];   // [запись, с, длина, искать ли начало удара]
const THUD = [['bsb2026.wav', 0.14], ['bsb2027.wav', 0.16], ['bsb2028.wav', 0.11], ['bsb2027.wav', 0.16]];
const ARC = [2.80, 2.86, 8.05, 2.92];
function camA(i) {
  const cl = fade((VCR[i][3] ? hit : src)(VCR[i][0], VCR[i][1], VCR[i][2], { af: 'highpass=f=140' }), 0.0008, 0.08);
  const th = fade(hit(THUD[i][0], THUD[i][1], 0.12, { af: 'lowpass=f=500' }), 0.001, 0.07);
  const rl = fade(src('bsb2191.wav', 0, 0.08, { af: 'highpass=f=300' }), 0.0005, 0.05);
  const arc = env(fade(src('bsb0952.wav', ARC[i], 0.08, { af: 'highpass=f=900,lowpass=f=6000' }), 0.002, 0.04), [[0, 0], [0.03, -4], [0.08, -18]]);
  const m = fx(mix(0.2, [[norm(rl), 0, -9], [norm(cl), 0.008, 0], [norm(th), 0.008, -10], [norm(arc), 0.012, -18]]), 'lowpass=f=9000');
  return tail(m, 0.19, 0.035);
}
// B2 «Signal Transition»: треск эфира при смене канала на приёмнике (четыре разных места записи), в конце —
// тихий щелчок старого выключателя: «картинка встала».
const CRK = [0.215, 1.085, 2.025, 0.6];
const TICK = [['bsb2688.wav', 168.71], ['bsb2688.wav', 172.31], ['bsb0571.wav', 3.63], ['bsb2688.wav', 164.18]];
function camB(i) {
  const cr = env(fade(src('bsb0313.wav', CRK[i], 0.14, { af: 'highpass=f=280,lowpass=f=5500' }), 0.002, 0.04), [[0, 0], [0.05, -2], [0.14, -14]]);
  const tk = fade(hit(TICK[i][0], TICK[i][1], 0.07, { af: 'highpass=f=200,lowpass=f=7000' }), 0.0005, 0.05);
  return tail(mix(0.22, [[norm(cr), 0, -3], [norm(tk), 0.105, -8]]), 0.2, 0.03);
}

// ================= SOUND C — MADK1D в шахте =================
// Не петля из одного удара: у каждого варианта три дубля по 10–11 с с паузами; игра берёт следующий дубль, когда
// кончился прежний. Движения собраны вручную из отдельных записанных ударов, волочения и скрипов жестяного шкафа.
const LH = [0.23, 0.63, 1.03, 1.42, 1.83, 2.24, 2.64, 3.04, 3.46, 3.85, 4.25, 4.65, 5.07, 5.48, 5.89];      // глухие удары (15 разных)
const LL = [0.13, 0.55, 0.94, 1.74, 2.13, 2.55, 2.95, 3.36, 4.16, 4.56, 4.94];                              // самые низкие удары
const DH = [0.24, 0.65, 1.10, 1.53, 1.95, 2.36, 2.78, 3.19];                                                // удары покороче и звонче
const CAB = [[0.42, 0.96], [2.55, 1.01], [5.09, 1.01], [7.23, 1.24], [9.80, 1.43], [13.38, 0.82], [16.62, 0.39], [18.15, 1.08], [20.62, 1.19]];   // жестяной шкаф: сдвиг и стук
const DR = [[0.73, 1.10], [3.60, 1.76], [6.62, 1.57], [9.33, 1.65]];                                         // металл волокут
const SC = [[0.58, 1.81], [2.67, 0.78], [3.94, 0.29], [4.44, 0.98], [5.63, 0.96], [6.74, 0.97], [8.70, 1.14]];   // скребут
const TP = [0.47, 0.97, 1.45, 1.93, 2.34, 2.89, 3.28, 3.62, 3.96, 4.73, 5.09];                              // лёгкие удары по металлу
const cache = {};
const memo = (k, f) => cache[k] || (cache[k] = f());
const PIECE = {
  thump: (i) => memo('th' + i, () => norm(mix(0.46, [[norm(fade(hit('oga/ws_low_hammering.wav', LH[i], 0.37, { rate: 0.8, af: 'highpass=f=40,lowpass=f=2400' }), 0.001, 0.2)), 0, 0],
    [norm(fade(hit('oga/ws_dull_hammering.wav', DH[i % DH.length], 0.3, { rate: 0.8, af: 'highpass=f=250,lowpass=f=2600' }), 0.001, 0.2)), 0, -6]]))),
  sub: (i) => memo('su' + i, () => norm(fade(hit('oga/ws_lower_hammering.wav', LL[i], 0.38, { af: 'lowpass=f=200' }), 0.002, 0.15))),
  knock: (i) => memo('kn' + i, () => norm(fade(hit('oga/ws_dull_hammering.wav', DH[i], 0.36, { rate: 0.85, af: 'lowpass=f=2400' }), 0.001, 0.12))),
  cab: ([i, rate, lp]) => memo('cb' + i + rate + lp, () => norm(fade(src('bsb0773.wav', CAB[i][0] - 0.03, CAB[i][1] + 0.1, { rate, af: `lowpass=f=${lp}` }), 0.01, 0.12))),
  drag: ([i, off, len]) => memo('dr' + i + off + len, () => norm(fade(src('oga/ws_dragging_metal.wav', DR[i][0] + off, len, { rate: 0.85, af: 'highpass=f=70,lowpass=f=2000' }), len * 0.3, len * 0.4))),
  scuff: ([i, off, len]) => memo('sc' + i + off + len, () => norm(fade(src('oga/ws_scrapes.wav', SC[i][0] + off, len, { af: 'highpass=f=250,lowpass=f=3600' }), len * 0.35, len * 0.45))),
  tap: (i) => memo('tp' + i, () => norm(fade(hit('oga/ws_metal_tapping.wav', TP[i], 0.07, { rate: 0.5, af: 'highpass=f=300,lowpass=f=3400' }), 0.0005, 0.12, 3))),
};
const stage = (len, ev) => mix(len, ev.map(([t, kind, arg, d]) => [PIECE[kind](arg), t, d * 0.5]));      // разброс громкости событий вдвое уже записанного в партитуре

// C1 «Heavy Duct Movement»: упор (удар и его низ) — подтянулся (волочение) — упор; паузы; иногда прогибается лист.
const HEAVY = [
  [10.6, [[0.00, 'thump', 10, 0], [0.00, 'sub', 2, -4], [0.52, 'thump', 3, -7], [0.78, 'drag', [0, 0.10, 0.75], -13], [1.72, 'thump', 12, -1], [1.72, 'sub', 7, -3], [2.08, 'knock', 4, -12],
    [3.65, 'cab', [1, 0.75, 2400], -6], [4.85, 'thump', 8, -3], [4.85, 'sub', 4, -6], [5.22, 'thump', 1, -10], [5.45, 'drag', [1, 0.30, 0.95], -12],
    [7.75, 'thump', 13, 0], [7.75, 'sub', 9, -3], [8.20, 'thump', 6, -6], [8.50, 'cab', [6, 0.75, 2400], -8], [9.35, 'thump', 4, -9]]],
  [11.2, [[0.00, 'cab', [4, 0.72, 2200], -5], [1.30, 'thump', 9, -2], [1.30, 'sub', 5, -4], [1.95, 'thump', 5, -8], [2.20, 'thump', 11, -3],
    [3.90, 'drag', [2, 0.20, 1.05], -11], [4.85, 'thump', 14, 0], [4.85, 'sub', 1, -3],
    [6.60, 'knock', 1, -11], [6.95, 'thump', 2, -8], [7.30, 'drag', [3, 0.40, 0.7], -13], [8.25, 'thump', 12, -2], [8.25, 'sub', 6, -4], [8.72, 'thump', 7, -7], [9.90, 'cab', [7, 0.75, 2300], -9]]],
  [9.9, [[0.00, 'thump', 7, -4], [0.33, 'thump', 13, 0], [0.33, 'sub', 3, -3], [1.05, 'drag', [1, 0.90, 0.8], -12],
    [2.85, 'thump', 4, -8], [3.20, 'cab', [2, 0.75, 2400], -6], [4.40, 'thump', 11, -1], [4.40, 'sub', 8, -4],
    [6.30, 'thump', 2, -9], [6.62, 'thump', 9, -4], [6.62, 'sub', 0, -6], [7.05, 'drag', [0, 0.35, 0.7], -13], [8.10, 'knock', 6, -12], [8.55, 'thump', 14, -1], [8.55, 'sub', 10, -4]]],
];
// C2 «Unnatural Crawling»: быстрые перебежки мелких касаний (слишком частые для рук и колен), долгое замирание,
// осторожное шуршание по стенке, один тихий упор.
const WARY = [
  [10.4, [[0.00, 'tap', 0, -4], [0.09, 'tap', 3, -8], [0.16, 'tap', 6, -5], [0.27, 'tap', 2, -9], [0.33, 'tap', 8, -6], [0.55, 'scuff', [0, 0.2, 0.55], -8],
    [2.30, 'cab', [6, 0.95, 3400], -9], [2.95, 'scuff', [3, 0.1, 0.7], -7], [3.80, 'tap', 5, -10], [3.92, 'tap', 1, -7], [4.07, 'tap', 9, -9],
    [5.95, 'scuff', [4, 0.1, 0.8], -6], [6.70, 'tap', 7, -6], [6.77, 'tap', 10, -9], [6.85, 'tap', 4, -7], [6.95, 'tap', 0, -5], [7.02, 'tap', 6, -8], [7.13, 'tap', 2, -6], [7.40, 'knock', 2, -14],
    [9.10, 'scuff', [6, 0.2, 0.5], -9], [9.55, 'tap', 3, -8]]],
  [10.9, [[0.00, 'scuff', [5, 0.1, 0.75], -6], [0.85, 'tap', 2, -7], [0.93, 'tap', 9, -9], [1.04, 'tap', 5, -6],
    [2.60, 'tap', 1, -5], [2.66, 'tap', 7, -8], [2.74, 'tap', 3, -6], [2.80, 'tap', 10, -9], [2.89, 'tap', 0, -5], [2.99, 'tap', 8, -7], [3.12, 'tap', 4, -9], [3.30, 'scuff', [1, 0.1, 0.6], -8],
    [5.10, 'cab', [3, 0.95, 3400], -10], [6.05, 'scuff', [0, 0.9, 0.7], -7],
    [7.90, 'tap', 6, -6], [8.01, 'tap', 2, -9], [8.09, 'tap', 9, -6], [8.30, 'knock', 5, -14], [8.75, 'scuff', [4, 0.5, 0.45], -9], [9.80, 'tap', 1, -9], [9.88, 'tap', 5, -7]]],
  [9.8, [[0.00, 'tap', 4, -6], [0.07, 'tap', 0, -5], [0.15, 'tap', 7, -8], [0.21, 'tap', 3, -6], [0.45, 'scuff', [6, 0.5, 0.5], -8],
    [1.90, 'scuff', [3, 0.2, 0.75], -6], [2.75, 'knock', 0, -13],
    [4.60, 'tap', 9, -7], [4.71, 'tap', 1, -9], [4.78, 'tap', 6, -6], [4.90, 'tap', 10, -8], [5.20, 'cab', [8, 0.95, 3400], -11],
    [7.30, 'scuff', [5, 0.4, 0.5], -7], [7.85, 'tap', 2, -5], [7.91, 'tap', 8, -8], [7.99, 'tap', 5, -6], [8.06, 'tap', 0, -7], [8.15, 'tap', 3, -9], [8.27, 'tap', 7, -6]]],
];
function crawl(set, heavy) {
  const duct = fade(src('bsb0773.wav', CAB[6][0] - 0.01, 0.3, { rate: heavy ? 0.75 : 1.0, af: 'highpass=f=200' }), 0.001, 0.22);    // отклик жестяной коробки
  return set.map(([len, ev]) => {
    let m = stage(len, ev);
    m = mix(len, [[m, 0, 0], [match(convolve(m, duct), m), 0, heavy ? -14 : -14]]);
    m = fx(m, heavy ? 'aecho=0.9:0.9:9|19|31:0.3|0.18|0.1,highpass=f=55,equalizer=f=900:t=q:w=0.7:g=4,lowpass=f=3000,acompressor=threshold=-14dB:ratio=2:attack=15:release=120:makeup=1'
      : 'aecho=0.9:0.9:6|13:0.25|0.15,highpass=f=120,lowpass=f=4400,acompressor=threshold=-16dB:ratio=2:attack=8:release=120:makeup=1');
    return fade(m, 0.003, 0.05);
  });
}

// ================= сборка =================
const want = (k) => !ONLY || ONLY === k;
const refs = {};
if (want('balon')) {
  const orig = [1, 2, 3].map((k) => readWav(path.join(ORIG, `scream_balon_${k}.wav`)));
  refs.balon = Math.max(...orig.map((o) => loud(o)[0]));
  const T = refs.balon;                                       // не громче прежнего: та же наибольшая мгновенная громкость
  const a = level(balonA(), T), b = level(balonB(), T);
  saveWav(OUT, 'balon_a.wav', a); saveWav(OUT, 'balon_b.wav', b);
  saveWav(CMP, 'balon_original.wav', orig[0]); saveWav(CMP, 'balon_a_organic.wav', a); saveWav(CMP, 'balon_b_physical.wav', b);
}
const seq = (xs, gap) => { const items = []; let t = 0.15; for (const x of xs) { items.push([x, t, 0]); t += gap; } return mix(t + 0.3, items); };
if (want('cam')) {
  const orig = opt('orig') && fs.existsSync(path.join(opt('orig'), 'cam_synth.wav')) ? readWav(path.join(opt('orig'), 'cam_synth.wav')) : null;
  refs.cam = orig ? loud(orig)[0] : -22;
  const T = refs.cam - 2.0;                                   // сдержаннее прежнего на 2 LU при той же громкости вызова
  const A = [0, 1, 2, 3].map((i) => level(camA(i), T, -1.5)), B = [0, 1, 2, 3].map((i) => level(camB(i), T, -1.5));
  A.forEach((x, i) => saveWav(OUT, `cam_a_${i + 1}.wav`, x)); B.forEach((x, i) => saveWav(OUT, `cam_b_${i + 1}.wav`, x));
  if (orig) saveWav(CMP, 'cctv_original.wav', seq([orig, orig, orig, orig], 0.7));
  saveWav(CMP, 'cctv_a_relay.wav', seq(A, 0.7)); saveWav(CMP, 'cctv_b_signal.wav', seq(B, 0.7));
}
if (want('crawl')) {
  const one = opt('orig') && fs.existsSync(path.join(opt('orig'), 'crawl_synth.wav')) ? readWav(path.join(opt('orig'), 'crawl_synth.wav')) : null;
  const orig = one ? mix(10.4, [0, 1, 2, 3, 4, 5].map((k) => [one, k * 1.6 + 0.2, 0])) : null;      // в игре 1,6 с играют подряд, без паузы
  refs.crawl = orig ? loud(orig)[0] : -22;
  const T = refs.crawl + 2.5;                                // звук реже прежнего: при равной мгновенной громкости в будке он терялся (замер в игре)
  const A = crawl(HEAVY, true).map((x) => level(x, T, -1.5)), B = crawl(WARY, false).map((x) => level(x, T + 1.5, -1.5));      // осторожный вариант реже и короче: +1,5 LU, чтобы в будке его было слышно не хуже
  A.forEach((x, i) => saveOgg(OUT, `crawl_a_${i + 1}.ogg`, x)); B.forEach((x, i) => saveOgg(OUT, `crawl_b_${i + 1}.ogg`, x));
  if (orig) saveWav(CMP, 'madk1d_original.wav', orig);
  saveWav(CMP, 'madk1d_a_heavy.wav', A[0]); saveWav(CMP, 'madk1d_b_unnatural.wav', B[0]);
}
console.log('опорная мгновенная громкость прежних звуков, LUFS:', JSON.stringify(refs));
console.table(REPORT);
fs.writeFileSync(path.join(TMP, 'used.json'), JSON.stringify(USED, null, 1));
console.log('использованные вырезки:', path.join(TMP, 'used.json'));
