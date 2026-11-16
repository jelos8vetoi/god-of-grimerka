// Звуковые эффекты для Godot-версии: синтез в WAV (44.1 кГц, моно, 16 бит), без сторонних библиотек.
// node tools/godot-sfx.js  →  godot/assets/audio/sfx_*.wav
const fs = require('fs'), path = require('path'), SR = 44100;
const out = path.join(__dirname, '..', 'godot', 'assets', 'audio'); fs.mkdirSync(out, { recursive: true });
let seed = 3; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
function wav(name, len, fn) {
  const n = Math.floor(SR * len), buf = Buffer.alloc(44 + n * 2), d = new Float32Array(n);
  for (let i = 0; i < n; i++) d[i] = fn(i / SR, i);
  let pk = 0; for (const v of d) pk = Math.max(pk, Math.abs(v)); const g = pk > 0 ? .9 / pk : 1;
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, d[i] * g)) * 32767), 44 + i * 2);
  fs.writeFileSync(path.join(out, 'sfx_' + name + '.wav'), buf);
}
const env = (t, a, d) => (t < a ? t / a : 1) * Math.exp(-(t - a) / d);
let lp = 0; const noise = (c) => { lp += (rnd() * 2 - 1 - lp) * c; return lp; };
// взмах: шипящий шум с подъёмом частоты
wav('swing', .28, t => { const c = .05 + .5 * Math.min(1, t / .18); return noise(c) * Math.sin(Math.PI * Math.min(1, t / .28)) * 1.2; });
// тяжёлый взмах
wav('swing_heavy', .45, t => { const c = .03 + .35 * Math.min(1, t / .3); return noise(c) * Math.sin(Math.PI * Math.min(1, t / .45)) + Math.sin(2 * Math.PI * (70 - 40 * t) * t) * .3 * env(t, .2, .2); });
// попадание: щелчок + глухой удар
wav('hit', .25, t => Math.sin(2 * Math.PI * (160 * Math.exp(-t * 18) + 60) * t) * env(t, .002, .08) + noise(.6) * env(t, .001, .02) * .8);
wav('hit_heavy', .5, t => Math.sin(2 * Math.PI * (110 * Math.exp(-t * 10) + 40) * t) * env(t, .002, .18) + noise(.4) * env(t, .001, .05) + Math.tanh(Math.sin(2 * Math.PI * 55 * t) * 3) * .3 * env(t, .01, .2));
// бутылка: стеклянный звон при ударе балоном
wav('glass', .6, t => [1, 2.76, 5.4, 8.9].reduce((s, m, i) => s + Math.sin(2 * Math.PI * 1240 * m * t) * env(t, .001, .25 / (i + 1)) / (i + 1), 0) + noise(.8) * env(t, .001, .01) * .5);
// перекат: шорох
wav('roll', .45, t => noise(.12) * Math.sin(Math.PI * t / .45) * .9);
// получил урон
wav('hurt', .35, t => Math.tanh(Math.sin(2 * Math.PI * (220 - 300 * t) * t) * 4) * env(t, .005, .1) * .7 + noise(.3) * env(t, .002, .05) * .5);
// блок / парирование
wav('block', .3, t => Math.sin(2 * Math.PI * 1800 * t) * env(t, .001, .06) * .6 + Math.sin(2 * Math.PI * 900 * t) * env(t, .001, .1) * .5);
wav('parry', .7, t => [1, 1.5, 2, 3].reduce((s, m) => s + Math.sin(2 * Math.PI * 880 * m * t), 0) * env(t, .002, .25) * .3);
// смерть врага: низкий спад + треск
wav('death', .8, t => Math.sin(2 * Math.PI * (180 * Math.exp(-t * 4) + 30) * t) * env(t, .005, .3) + noise(.35) * env(t, .002, .12) * .7);
// появление из-под земли
wav('spawn', .9, t => noise(.08) * env(t, .3, .3) + Math.sin(2 * Math.PI * (60 + 80 * t) * t) * .4 * env(t, .2, .3));
// выстрел хейтера: магический всплеск
wav('cast', .5, t => Math.sin(2 * Math.PI * (500 + 900 * t) * t) * env(t, .01, .15) * .6 + Math.sin(2 * Math.PI * (750 + 1300 * t) * t) * env(t, .01, .12) * .3);
// рез катаны
wav('slash', .35, t => noise(.7) * env(t, .005, .06) + Math.sin(2 * Math.PI * 3200 * t) * env(t, .001, .05) * .3);
// ПЕРЕГРУЗ: взрывной удар
wav('rage', 1.4, t => Math.sin(2 * Math.PI * (90 * Math.exp(-t * 2) + 35) * t) * env(t, .01, .5) + noise(.2) * env(t, .005, .35) + Math.sin(2 * Math.PI * 440 * t) * env(t, .3, .4) * .2);
// интерфейс
wav('ui', .12, t => Math.sin(2 * Math.PI * 1200 * t) * env(t, .002, .03));
wav('wave', 1.2, t => [0, .15, .3].reduce((s, d, i) => s + (t > d ? Math.sin(2 * Math.PI * [392, 523, 659][i] * (t - d)) * env(t - d, .005, .35) : 0), 0) * .6);
// удар балоном в землю: низкий бум с хвостом
wav('boom', .9, t => Math.sin(2 * Math.PI * (75 * Math.exp(-t * 7) + 32) * t) * env(t, .003, .28) * 1.2 + noise(.18) * env(t, .002, .12) * .9 + noise(.04) * env(t, .05, .3) * .5);
// тело упало
wav('thud', .35, t => Math.sin(2 * Math.PI * (95 * Math.exp(-t * 14) + 45) * t) * env(t, .002, .09) + noise(.25) * env(t, .001, .04) * .6);
// заряд полного замаха: нарастающий гул
wav('charge', 1.3, t => (Math.sin(2 * Math.PI * (70 + 130 * t * t) * t) * .6 + Math.sin(2 * Math.PI * (140 + 260 * t * t) * t) * .25 + noise(.05 + .25 * t) * .35) * Math.min(1, t / .25) * Math.min(1, (1.3 - t) / .15));
// хлёсткий «крэк» полного удара: сухой щелчок, стекло, низ
wav('crack', .55, t => noise(.9) * env(t, .0005, .012) * 1.4 + [1, 2.3, 3.7].reduce((s, m, i) => s + Math.sin(2 * Math.PI * 900 * m * t) * env(t, .001, .07 / (i + 1)) * .4, 0) + Math.sin(2 * Math.PI * (120 * Math.exp(-t * 12) + 38) * t) * env(t, .002, .2));
console.log('sfx ->', out);
