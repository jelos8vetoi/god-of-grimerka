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
for (const d of [OUT, CMP]) fs.mkdirSync(d, { recursive: true });

const { SR, USED, REPORT, ff, f32, raw, RAWIN, src, onset, hit, dB, peak, rms, gain, norm, match, fade, env, mix, fx, convolve, limit, loud, level, wavBytes, stat, saveWav, saveOgg, readWav, tail } = require('./fn-audio-lib.cjs')(SRC, FF);

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
