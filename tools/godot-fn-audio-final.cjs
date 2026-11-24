// P1 FINAL «5 НОЧЕЙ С ПАХАНОМ»: утверждённый C1 Heavy Duct Movement, разложенный на события шахты P0, и свои звуки
// подъёма и опускания планшета. Материал тот же, что в дублях C1 (tools/godot-fn-audio-gate.cjs): удары и волочение из
// «68 Workshop Sounds» (bart, CC0) и жестяной шкаф BigSoundBank #0773 (CC0); планшет — кассетная дека #0571 и тумблер
// #2026/#2028 (CC0). Синтеза нет.
//   node tools/godot-fn-audio-final.cjs --src <папка исходников> [--ffmpeg <ffmpeg.exe>] [--orig <папка с cam_synth.wav>]
// Результат: godot/assets/audio/fn/sfx/madk_{far,hit,drag,near,presence}_N.ogg, godot/assets/audio/fn/gate/tablet_{up,down}.wav.
const fs = require('fs'), path = require('path');
const opt = (k) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : ''; };
const SRC = opt('src'), FF = opt('ffmpeg') || process.env.FFMPEG || 'ffmpeg', OR = opt('orig');
if (!SRC) { console.error('нужен --src <папка исходников>'); process.exit(1); }
const ROOT = path.join(__dirname, '..'), SFX = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'sfx'), GATE = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'gate');
const { SR, REPORT, src, hit, norm, match, fade, mix, fx, convolve, level, saveWav, saveOgg, readWav, tail, loud } = require('./fn-audio-lib.cjs')(SRC, FF);

// те же вырезки, что в C1
const LH = [0.23, 0.63, 1.03, 1.42, 1.83, 2.24, 2.64, 3.04, 3.46, 3.85, 4.25, 4.65, 5.07, 5.48, 5.89];
const LL = [0.13, 0.55, 0.94, 1.74, 2.13, 2.55, 2.95, 3.36, 4.16, 4.56, 4.94];
const DH = [0.24, 0.65, 1.10, 1.53, 1.95, 2.36, 2.78, 3.19];
const CAB = [[0.42, 0.96], [2.55, 1.01], [5.09, 1.01], [7.23, 1.24], [9.80, 1.43], [13.38, 0.82], [16.62, 0.39], [18.15, 1.08], [20.62, 1.19]];
const DR = [[0.73, 1.10], [3.60, 1.76], [6.62, 1.57], [9.33, 1.65]];
const thump = (i) => norm(mix(0.46, [[norm(fade(hit('oga/ws_low_hammering.wav', LH[i], 0.37, { rate: 0.8, af: 'highpass=f=40,lowpass=f=2400' }), 0.001, 0.2)), 0, 0],
  [norm(fade(hit('oga/ws_dull_hammering.wav', DH[i % DH.length], 0.3, { rate: 0.8, af: 'highpass=f=250,lowpass=f=2600' }), 0.001, 0.2)), 0, -6]]));
const sub = (i) => norm(fade(hit('oga/ws_lower_hammering.wav', LL[i], 0.38, { af: 'lowpass=f=200' }), 0.002, 0.15));
const cab = (i, rate, lp) => norm(fade(src('bsb0773.wav', CAB[i][0] - 0.03, CAB[i][1] + 0.1, { rate, af: `lowpass=f=${lp}` }), 0.01, 0.12));
const drag = (i, off, len) => norm(fade(src('oga/ws_dragging_metal.wav', DR[i][0] + off, len, { rate: 0.85, af: 'highpass=f=70,lowpass=f=2000' }), len * 0.25, len * 0.4));
const box = fade(src('bsb0773.wav', CAB[6][0] - 0.01, 0.3, { rate: 0.75, af: 'highpass=f=200' }), 0.001, 0.22);         // отклик жестяной коробки
// шахта: свёртка с откликом коробки и короткие отражения; far — дальний конец (глуше, с эхом длинной трубы)
const duct = (m, kind) => {
  const y = mix(m.length / SR, [[m, 0, 0], [match(convolve(m, box), m), 0, kind === 'near' ? -16 : -13]]);
  const chain = { far: 'aecho=0.8:0.7:90|190|310:0.45|0.3|0.2,highpass=f=55,lowpass=f=800', mid: 'aecho=0.9:0.9:9|19|31:0.3|0.18|0.1,highpass=f=55,equalizer=f=900:t=q:w=0.7:g=4,lowpass=f=2600',
    near: 'aecho=0.9:0.9:7|15:0.22|0.12,highpass=f=50,equalizer=f=1100:t=q:w=0.7:g=4,lowpass=f=3600' }[kind];
  return fx(y, chain);
};
const out = (name, list, M, len, fo) => list.forEach((x, i) => saveOgg(SFX, `${name}_${i + 1}.ogg`, level(tail(x, len[i] || len[0], fo), M, -3)));

// далёкое движение в шахте: один-два глухих удара из дальнего конца
out('madk_far', [duct(mix(1.3, [[thump(9), 0, 0], [sub(4), 0, -3]]), 'far'), duct(mix(1.3, [[thump(4), 0, -2], [thump(12), 0.34, 0], [sub(7), 0.34, -3]]), 'far'),
  duct(mix(1.3, [[thump(13), 0, 0], [sub(1), 0, -4], [thump(2), 0.47, -5]]), 'far'), duct(mix(1.3, [[thump(7), 0, 0], [sub(9), 0, -3]]), 'far')], -21.5, [1.2], 0.5);
// глухие удары по стенкам: по одному упору на файл, шесть разных
out('madk_hit', [[10, 2], [3, 5], [12, 7], [8, 4], [6, 0], [14, 10]].map(([a, b]) => duct(mix(0.7, [[thump(a), 0, 0], [sub(b), 0, -5]]), 'mid')), -21, [0.6], 0.2);
// тяжёлое волочение: тело подтягивается по листу, в начале — тихий упор
out('madk_drag', [[0, 0.10, 0.85, 5], [1, 0.30, 1.05, 1], [2, 0.20, 0.95, 11]].map(([i, off, len, t]) => duct(mix(1.4, [[drag(i, off, len), 0.05, 0], [thump(t), 0, -8]]), 'mid')), -22, [1.2, 1.4, 1.3], 0.3);
// у самой решётки: удар ближе и суше, под ним прогибается лист
out('madk_near', [[13, 3, 6], [11, 8, 2], [9, 6, 6], [14, 1, 5]].map(([a, b, c]) => duct(mix(0.9, [[thump(a), 0, 0], [sub(b), 0, -3], [fade(cab(c, 0.75, 2600).subarray(0, Math.round(0.5 * SR)), 0.005, 0.25), 0.03, -9]]), 'near')), -20.5, [0.8], 0.25);
// присутствие за решёткой: вес переносится, лист подаётся — без удара
out('madk_presence', [[1, 4], [4, 6], [7, 0], [2, 8]].map(([c, s]) => duct(mix(1.6, [[cab(c, 0.72, 2200), 0, 0], [sub(s), 0.25, -10]]), 'near')), -23, [1.4, 1.6, 1.3, 1.3], 0.3);

// планшет: корпус кассетной деки в руках и низ тумблера; ровняется по прежнему «cam» на той высоте, с какой его играла игра
const camO = OR && fs.existsSync(path.join(OR, 'cam_synth.wav')) ? readWav(path.join(OR, 'cam_synth.wav')) : null;
const T = (camO ? loud(fx(camO, `asetrate=${Math.round(SR * 0.8)},aresample=${SR}`))[0] : -18.4) - 2;
saveWav(GATE, 'tablet_up.wav', level(tail(mix(0.5, [[norm(fade(src('bsb0571.wav', 27.83, 0.46, { af: 'highpass=f=120,lowpass=f=7000' }), 0.004, 0.1)), 0, 0], [norm(fade(hit('bsb2026.wav', 0.14, 0.12, { af: 'lowpass=f=500' }), 0.001, 0.07)), 0.19, -8]]), 0.44, 0.06), T, -1.5));
saveWav(GATE, 'tablet_down.wav', level(tail(mix(0.5, [[norm(fade(src('bsb0571.wav', 14.11, 0.36, { af: 'highpass=f=80,lowpass=f=6000' }), 0.003, 0.15)), 0, 0], [norm(fade(hit('bsb2028.wav', 0.11, 0.12, { af: 'lowpass=f=500' }), 0.001, 0.07)), 0.02, -6]]), 0.4, 0.1), T, -1.5));
console.table(REPORT.map((r) => ({ file: r.file, len: r.len, peak: r.peak, M: r.M })));
