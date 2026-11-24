// P1.2 «5 НОЧЕЙ С ПАХАНОМ»: скримеры остальных обитателей, планшет и сигнал камер, двери, заслонки, телефон,
// генератор, новые звуки здания — из настоящих записей (CC0).
//   node tools/godot-fn-audio-p1.cjs --src <папка исходников> --orig <папка прежних звуков> [--ffmpeg <ffmpeg.exe>] [--only screams|tablet|mech|amb]
// --orig: прежние синтезированные звуки, снятые из игры (FNSound.get_stream(id).save_to_wav), — по ним ровняется громкость
// и из них делаются файлы «old» для сравнения. Исходники и прежние звуки в репозиторий не входят; страницы, авторы и
// лицензии записей — godot/docs/FIVE_NIGHTS_AUDIO_P1.md. Синтеза нет: всё, что звучит, приходит из src().
// Результат: godot/assets/audio/fn/gate/*, сравнение — docs/audio_quality_gate/p1_2/<звук>_old.wav и <звук>_new.wav.
const fs = require('fs'), path = require('path'), os = require('os');
const opt = (k) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : ''; };
const SRC = opt('src'), OR = opt('orig'), FF = opt('ffmpeg') || process.env.FFMPEG || 'ffmpeg', ONLY = opt('only');
if (!SRC || !OR) { console.error('нужны --src <папка исходников> и --orig <папка прежних звуков>'); process.exit(1); }
const ROOT = path.join(__dirname, '..'), OUT = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'gate'), CMP = path.join(ROOT, 'docs', 'audio_quality_gate', 'p1_2');
const OLD = path.join(ROOT, 'godot', 'assets', 'audio', 'fn');
for (const d of [OUT, CMP]) fs.mkdirSync(d, { recursive: true });
const L = require('./fn-audio-lib.cjs')(SRC, FF);
const { SR, USED, REPORT, ff, f32, raw, RAWIN, src, hit, peak, gain, norm, match, fade, env, mix, fx, convolve, limit, loud, level, saveWav, saveOgg, readWav, tail } = L;
const want = (k) => !ONLY || ONLY === k;
const rev = (x) => Float32Array.from(x).reverse();
// прежний звук с высотой, с какой его играет игра
const old = (file, pitch = 1) => { const x = readWav(file); return pitch === 1 ? x : fx(x, `asetrate=${Math.round(SR * pitch)},aresample=${SR}`).subarray(0, Math.round(x.length / pitch)); };
const cmp = (name, o, n) => { if (o) saveWav(CMP, name + '_old.wav', o); saveWav(CMP, name + '_new.wav', n); };
const seq = (xs, gap) => { const items = []; let t = 0.1; for (const x of xs) { items.push([x, t, 0]); t += x.length / SR + gap; } return mix(t, items); };
const sat = (x, db) => fx(norm(x, -1), `volume=${db}dB,asoftclip=type=tanh`);

// ================= скримеры =================
// Длины — как у прежних записей каждого (тряска и свет считаются от них и от констант FNScare), громкость — не выше прежней.
// У каждого свой материал; общих голосов между ними нет.

// MADK1D: люк срывается — кошачий рёв и вой дерущихся котов из жестяной шахты, под ними детский визг на замедленной
// ленте; быстро гаснет.
function madk1d() {
  const hatch = fade(hit('bsb1777.wav', 0.07, 0.5, { rate: 0.8 }), 0.0005, 0.3);
  const thud = fade(hit('oga/ws_low_hammering.wav', 5.48, 0.37, { rate: 0.8, af: 'lowpass=f=1700' }), 0.001, 0.15);
  const roar = fade(src('bsb1883.wav', 0.02, 0.9, { rate: 0.85 }), 0.002, 0.25);
  const yowl = fade(src('bsb0817.wav', 1.25, 1.18, { rate: 0.8 }), 0.03, 0.5);
  const kid = fade(src('bsb1149.wav', 0.9, 0.7, { rate: 0.62, af: 'lowpass=f=3500' }), 0.01, 0.4);
  let org = mix(2.0, [[norm(roar), 0, -1], [norm(yowl), 0.12, -3], [norm(kid), 0.05, -9]]);
  org = fx(org, 'highpass=f=90,equalizer=f=1400:t=q:w=1.0:g=2');
  org = mix(2.0, [[org, 0, 0], [match(fx(org, 'volume=12dB,asoftclip=type=tanh,highpass=f=250,lowpass=f=4500'), org), 0, -6]]);
  const duct = fade(src('bsb0773.wav', 16.61, 0.3, { af: 'highpass=f=200' }), 0.001, 0.22);
  const rattle = fade(src('bsb0773.wav', 0.39, 1.0, { rate: 0.9, af: 'lowpass=f=3500' }), 0.01, 0.3);
  let m = mix(2.0, [[norm(hatch), 0, 0], [norm(thud), 0, -4], [org, 0.01, 0], [match(convolve(org, duct), org), 0.01, -6], [norm(rattle), 0.5, -11]]);
  m = fx(m, 'aecho=0.9:0.9:8|17:0.3|0.18,acompressor=threshold=-14dB:ratio=2.5:attack=5:release=120:makeup=1');
  m = env(m, [[0, 3], [0.1, 2], [0.5, 0], [0.9, -4], [1.3, -12], [1.9, -40]]);
  return tail(sat(m, 4), 1.9, 0.05);
}
// BOT: голоса нет вовсе. Удар железа, дуга сварки, очереди ударного гайковёрта, раскручивающаяся дрель, стон пружины
// и гул трансформатора; обрывается остановкой лебёдки и щелчком автомата.
function bot() {
  const clank = fade(hit('bsb2360.wav', 0.25, 0.6, { rate: 0.9 }), 0.0005, 0.35);
  const sub = fade(hit('bsb0655.wav', 0.2, 0.4, { af: 'lowpass=f=160' }), 0.001, 0.2);
  const arc1 = fade(src('bsb0952.wav', 2.79, 0.25, { af: 'highpass=f=600' }), 0.001, 0.1), arc2 = fade(src('bsb0952.wav', 8.04, 0.19, { af: 'highpass=f=600' }), 0.001, 0.08);
  const w1 = fade(src('bsb0964.wav', 2.51, 0.28), 0.002, 0.04), w2 = fade(src('bsb0964.wav', 4.28, 0.38), 0.002, 0.05), w3 = fade(src('bsb0964.wav', 6.41, 0.49, { rate: 0.85 }), 0.002, 0.08);
  const drill = env(fade(src('bsb0184.wav', 0.35, 1.6, { rate: 0.7 }), 0.01, 0.05), [[0, -10], [0.5, -3], [1.5, 0], [1.6, -30]]);
  const spring = fade(src('bsb0206.wav', 8.21, 0.4, { rate: 0.7 }), 0.003, 0.25);
  const hum = fade(src('bsb2118.wav', 1.0, 1.75, { af: 'lowpass=f=400' }), 0.01, 0.03);
  const stop = fade(src('bsb0708.wav', 3.55, 0.5, { rate: 0.8 }), 0.01, 0.3);
  const brk = fade(hit('bsb1092.wav', 0.3, 0.12), 0.0005, 0.08);
  let m = mix(2.3, [[norm(clank), 0, 0], [norm(sub), 0, -3], [norm(arc1), 0, -6], [norm(arc2), 0.9, -9], [norm(w1), 0.05, -3], [norm(w2), 0.55, -4], [norm(w3), 1.05, -5],
    [norm(drill), 0, -7], [norm(spring), 0.35, -8], [norm(hum), 0, -12], [norm(stop), 1.6, -6], [norm(brk), 1.62, -6]]);
  m = fx(m, 'highpass=f=35,acompressor=threshold=-14dB:ratio=2.5:attack=6:release=120:makeup=1');
  m = env(m, [[0, 2], [0.2, 0], [1.5, -2], [1.75, -9], [2.2, -40]]);
  return tail(sat(m, 4), 2.2, 0.05);
}
// CLIPPER: клинок по клинку, ножницы, быстрые неровные проходы ножа по бруску, мотор машинки для стрижки с провалами,
// звон листовой стали. Короткий.
function clipper() {
  const shing = fade(src('bsb0129.wav', 0.19, 0.28), 0.001, 0.1);
  const st = [[6.15, 0.2, 1.0], [8.33, 0.22, 0.92], [8.96, 0.29, 1.0], [10.32, 0.3, 0.9]].map(([t, d, r]) => norm(fade(hit('bsb0832.wav', t, d, { rate: r }), 0.001, 0.06)));
  const snip1 = fade(src('bsb0008.wav', 2.81, 0.44), 0.002, 0.1), snip2 = fade(src('bsb0008.wav', 4.63, 0.5), 0.002, 0.15);
  const buzz = env(fade(src('bsb0891.wav', 2.0, 1.1, { af: 'highpass=f=300' }), 0.005, 0.1), [[0, 0], [0.3, -2], [0.32, -30], [0.4, -30], [0.42, 0], [0.8, -3], [1.1, -25]]);
  const ring = fade(hit('bsb1771.wav', 0.05, 0.6, { rate: 1.1 }), 0.0005, 0.4);
  const hiss = fade(src('bsb1882.wav', 0.02, 0.6, { rate: 1.15 }), 0.002, 0.3);
  let m = mix(1.3, [[norm(shing), 0, 0], [st[0], 0.1, -4], [st[1], 0.24, -3], [st[2], 0.36, -2], [st[3], 0.52, -4], [norm(snip1), 0.03, -5], [norm(snip2), 0.62, -6],
    [norm(buzz), 0, -9], [norm(ring), 0, -8], [norm(hiss), 0.02, -8]]);
  m = fx(m, 'highpass=f=120,lowpass=f=9500,acompressor=threshold=-14dB:ratio=2.5:attack=3:release=80:makeup=1');
  m = env(m, [[0, 3], [0.15, 1], [0.7, -2], [1.0, -12], [1.2, -40]]);
  return tail(sat(m, 4), 1.2, 0.04);
}
// GHOST: не крик, а провал пространства. Низ раската грома, детский крик на вдвое замедленной ленте и он же задом
// наперёд, облако шёпота — всё это пропущено через тот же раскат (свёртка: «глубина», которой в будке быть не может).
function ghost() {
  const boom = fade(src('bsb3113.wav', 1.03, 3.0, { af: 'lowpass=f=220' }), 0.004, 1.5);
  const cry = fade(src('bsb1149.wav', 0.32, 1.0, { rate: 0.5, af: 'lowpass=f=2800' }), 0.004, 0.8);
  const back = rev(fade(src('bsb1149.wav', 1.6, 1.4, { rate: 0.45, af: 'lowpass=f=2500' }), 0.02, 1.2));
  const w1 = fade(src('bsb3256.wav', 2.0, 4.0, { rate: 0.8 }), 0.05, 1.5), w2 = fade(src('bsb3255.wav', 5.0, 4.0, { rate: 0.65 }), 0.3, 2.0), w3 = rev(fade(src('bsb3256.wav', 8.0, 3.0), 0.05, 1.0));
  const cloud = mix(6.2, [[norm(w1), 0, 0], [norm(w2), 0.2, -2], [norm(w3), 2.4, -3], [norm(cry), 0, 0], [norm(back), 1.6, -5]]);
  const space = fade(src('bsb3113.wav', 1.05, 1.6, { af: 'highpass=f=100' }), 0.001, 1.2);
  const deep = match(convolve(cloud, space), cloud);
  let m = mix(6.2, [[norm(boom), 0, -2], [norm(cry), 0, -3], [norm(back), 1.6, -9], [deep, 0, -2], [cloud, 0, -10]]);
  m = fx(m, 'highpass=f=30,lowpass=f=5000,acompressor=threshold=-16dB:ratio=2:attack=10:release=250:makeup=1');
  m = env(m, [[0, 2], [0.3, 0], [2.0, -1], [3.0, -6], [4.5, -14], [6.0, -40]]);
  return tail(sat(m, 3), 6.0, 0.08);
}
// MOD: аппаратура сходит с ума. Автомат щёлкает, модем на телефонной линии воет и рвётся, в провалы лезет треск эфира,
// кассета с голосом мотается на перемотке, свистит настройка приёмника; в конце — гул и щелчок реле.
function mod() {
  const clack = fade(hit('bsb1092.wav', 0.3, 0.1), 0.0005, 0.06);
  const modem = env(fade(src('bsb0158.wav', 2.95, 1.3), 0.002, 0.1), [[0, 0], [0.45, 0], [0.47, -40], [0.56, -40], [0.58, -1], [1.0, -2], [1.02, -40], [1.08, -40], [1.1, -3], [1.3, -8]]);
  const cr1 = fade(src('bsb0313.wav', 0.6, 0.63), 0.002, 0.2), cr2 = fade(src('bsb0313.wav', 2.0, 0.3), 0.002, 0.1);
  const tape = fade(src('bsb2157.wav', 0.07, 0.8, { rate: 0.5, af: 'lowpass=f=6000' }), 0.01, 0.4);
  const whistle = fade(src('bsb0311.wav', 1.2, 1.2, { af: 'highpass=f=500,lowpass=f=4000' }), 0.05, 0.4);
  const hum = fade(src('bsb2118.wav', 3.0, 2.05, { af: 'lowpass=f=500' }), 0.01, 0.02);
  const line = fade(src('bsb0158.wav', 5.6, 0.5), 0.05, 0.35);
  const relay = fade(src('bsb2191.wav', 0, 0.08), 0.0005, 0.05);
  let m = mix(2.4, [[norm(clack), 0, 0], [norm(modem), 0.02, 0], [norm(cr2), 0, -3], [norm(cr1), 0.45, -4], [norm(cr2), 1.0, -4], [norm(tape), 0.5, -5], [norm(whistle), 0.2, -9],
    [norm(hum), 0, -10], [norm(line), 1.6, -8], [norm(relay), 2.05, -8]]);
  m = fx(m, 'highpass=f=60,lowpass=f=8000,acompressor=threshold=-14dB:ratio=2.5:attack=4:release=100:makeup=1');
  m = env(m, [[0, 4], [0.15, 2], [0.3, 0], [1.6, -3], [2.05, -8], [2.3, -40]]);
  return tail(sat(m, 4), 2.3, 0.04);
}
// DARK: питания нет — ни тока, ни железа. Вплотную, сухо: медленный низкий рык, хрипящие вдохи-выдохи (ослиный рёв на
// вдвое замедленной ленте), воздух, один глухой удар в начале.
function dark() {
  const growl = fade(src('bsb2106.wav', 10.65, 2.18, { rate: 0.6 }), 0.01, 1.2);
  const bray1 = fade(src('bsb1551.wav', 4.1, 0.66, { rate: 0.5 }), 0.01, 0.4), bray2 = fade(src('bsb1551.wav', 4.9, 0.59, { rate: 0.5 }), 0.02, 0.5);
  const inh = fade(src('bsb1551.wav', 3.5, 0.45, { rate: 0.6 }), 0.05, 0.2);
  const thump = fade(hit('bsb0655.wav', 3.67, 0.4, { af: 'lowpass=f=180' }), 0.001, 0.2), boom = fade(src('bsb1808.wav', 0, 0.32, { af: 'lowpass=f=500' }), 0.0005, 0.15);
  const air = env(fade(src('bsb0747.wav', 5.0, 2.6, { af: 'highpass=f=400,lowpass=f=3500' }), 0.003, 1.0), [[0, 0], [0.2, -3], [1.2, -8], [2.6, -20]]);
  let v = mix(3.2, [[norm(growl), 0.03, 0], [norm(bray1), 0.1, -6], [norm(bray2), 1.5, -7], [norm(inh), 1.25, -9]]);
  v = fx(v, 'highpass=f=45,equalizer=f=140:t=q:w=0.9:g=3,lowpass=f=6000');
  v = mix(3.2, [[v, 0, 0], [match(fx(v, 'volume=12dB,asoftclip=type=tanh,highpass=f=150,lowpass=f=3500'), v), 0, -6]]);
  let m = mix(3.2, [[v, 0, 0], [norm(thump), 0, -2], [norm(boom), 0, -5], [norm(air), 0, -10]]);
  m = fx(m, 'acompressor=threshold=-16dB:ratio=2.5:attack=6:release=160:makeup=1');
  m = env(m, [[0, 3], [0.15, 1], [1.2, 0], [2.0, -5], [2.6, -14], [3.1, -40]]);
  return tail(sat(m, 4), 3.1, 0.06);
}
if (want('screams')) {
  for (const [k, f] of [['madk1d', madk1d], ['bot', bot], ['clipper', clipper], ['ghost', ghost], ['mod', mod], ['dark', dark]]) {
    const o = readWav(path.join(OLD, `scream_${k}_1.wav`));
    const T = Math.max(...[1, 2, 3].map((i) => loud(readWav(path.join(OLD, `scream_${k}_${i}.wav`)))[0])) - 0.5;      // не громче прежнего
    const n = level(f(), T);
    saveWav(OUT, `scream_${k}.wav`, n); cmp('scream_' + k, o, n);
  }
}

// ================= планшет и сигнал =================
if (want('tablet')) {
  const cam = path.join(OR, 'cam_synth.wav'), st = path.join(OR, 'static_synth.wav'), ping = path.join(OR, 'ping_synth.wav'), pd = path.join(OLD, 'sfx', 'power_down_1.ogg');
  // подъём и опускание: корпус кассетной деки в руках — не щелчок камеры на другой высоте
  const upO = old(cam, 0.8), dnO = old(cam, 0.6), T = loud(upO)[0] - 2;
  const up = level(tail(mix(0.5, [[norm(fade(src('bsb0571.wav', 27.83, 0.46, { af: 'highpass=f=120,lowpass=f=7000' }), 0.004, 0.1)), 0, 0], [norm(fade(hit('bsb2026.wav', 0.14, 0.12, { af: 'lowpass=f=500' }), 0.001, 0.07)), 0.19, -8]]), 0.44, 0.06), T, -1.5);
  const dn = level(tail(mix(0.5, [[norm(fade(src('bsb0571.wav', 14.11, 0.36, { af: 'highpass=f=80,lowpass=f=6000' }), 0.003, 0.15)), 0, 0], [norm(fade(hit('bsb2028.wav', 0.11, 0.12, { af: 'lowpass=f=500' }), 0.001, 0.07)), 0.02, -6]]), 0.4, 0.1), T, -1.5);
  saveWav(OUT, 'tablet_up.wav', up); cmp('tablet_up', upO, up); saveWav(OUT, 'tablet_down.wav', dn); cmp('tablet_down', dnO, dn);
  // экран включился: реле и короткий гул дросселя
  const on = level(tail(mix(0.5, [[norm(fade(src('bsb2191.wav', 0, 0.08), 0.0005, 0.05)), 0, -4], [norm(env(fade(src('bsb2118.wav', 5.0, 0.42, { af: 'highpass=f=90,lowpass=f=2500' }), 0.02, 0.2), [[0, -12], [0.06, 0], [0.2, -4], [0.42, -16]])), 0.01, -3]]), 0.42, 0.12), T - 4, -1.5);
  saveWav(OUT, 'screen_on.wav', on); cmp('screen_on', null, on);
  // помехи: шум эфира между станциями и треск при смене канала; три дубля по 1,1 с — как прежняя «static»
  const stO = old(st), Ts = loud(stO)[0] - 1;
  const NOISE = 'highpass=f=200,lowpass=f=6000';
  const blips = [[1.62, 0.21, 0.55], [2.31, 1.085, 0.4], [3.5, 2.0, 0.85]].map(([a, b, d]) => level(env(mix(1.1, [[norm(fade(src('bsb0312.wav', a, d, { af: NOISE }), 0.003, 0.15)), 0, 0], [norm(fade(src('bsb0313.wav', b, 0.3, { af: 'highpass=f=280,lowpass=f=5500' }), 0.002, 0.1)), 0, -4]]), [[0, -30], [0.03, 0], [0.65, 0], [1.1, -40]]), Ts, -1.5));
  blips.forEach((x, i) => saveWav(OUT, `static_${i + 1}.wav`, x)); cmp('signal_blip', stO, blips[0]);
  // сигнал пропал: треск, шум гаснет, остаётся гул и обрывается щелчком
  const lostO = old(pd, 2.6), Tl = loud(lostO)[0];
  const lost = level(tail(mix(1.0, [[norm(fade(src('bsb0313.wav', 0.215, 0.2, { af: 'highpass=f=280,lowpass=f=5500' }), 0.002, 0.08)), 0, 0], [norm(env(src('bsb0312.wav', 3.6, 0.6, { af: NOISE }), [[0, 0], [0.15, -3], [0.5, -26], [0.6, -40]])), 0.03, -3],
    [norm(fade(src('bsb2118.wav', 7.0, 0.5, { af: 'lowpass=f=600' }), 0.1, 0.02)), 0.2, -8], [norm(fade(hit('bsb1092.wav', 4.05, 0.1), 0.0005, 0.06)), 0.7, -4]]), 0.9, 0.08), Tl, -1.5);
  saveWav(OUT, 'signal_lost.wav', lost); cmp('signal_lost', lostO, lost);
  // картинка вернулась: реле, короткий всплеск шума, щелчок клавиши
  const backO = old(ping, 1.3), Tb = loud(backO)[0] - 2;
  const back = level(tail(mix(0.5, [[norm(fade(src('bsb2191.wav', 0, 0.08), 0.0005, 0.05)), 0, -3], [norm(env(src('bsb0312.wav', 2.35, 0.16, { af: NOISE }), [[0, 0], [0.05, -3], [0.16, -30]])), 0.01, -5], [norm(fade(hit('bsb2688.wav', 168.71, 0.07), 0.0005, 0.05)), 0.17, -4]]), 0.36, 0.06), Tb, -1.5);
  saveWav(OUT, 'signal_back.wav', back); cmp('signal_back', backO, back);
  // перезапуск: автомат выключился, механизм видеомагнитофона отработал загрузку, реле включилось
  const rstO = old(pd, 1.8), Tr = loud(rstO)[0];
  const rst = level(tail(mix(1.4, [[norm(fade(hit('bsb1092.wav', 0.3, 0.12), 0.0005, 0.08)), 0, -2], [norm(fade(src('bsb2690.wav', 1.36, 0.62, { af: 'highpass=f=120' }), 0.01, 0.1)), 0.22, 0], [norm(fade(src('bsb2191.wav', 0, 0.08), 0.0005, 0.05)), 1.0, -9],
    [norm(env(fade(src('bsb2118.wav', 2.0, 0.3, { af: 'highpass=f=90,lowpass=f=2500' }), 0.02, 0.15), [[0, -10], [0.05, 0], [0.3, -14]])), 1.01, -13]]), 1.3, 0.1), Tr, -1.5);
  saveWav(OUT, 'cam_restart.wav', rst); cmp('cam_restart', rstO, rst);
}

// ================= оборудование =================
if (want('mech')) {
  // --- двери: ставня падает за 0,18 с и поднимается за 0,31 с (FNOffice). Части лежат отдельно — для будущей анимации.
  const dStart = norm(fade(hit('bsb1092.wav', 9.39, 0.1), 0.0005, 0.06));                                                    // защёлка: автомат
  const dMove = norm(fade(src('bsb2475.wav', 3.0, 0.42, { rate: 0.8, af: 'highpass=f=70' }), 0.02, 0.1));                    // полотно катится (рольставня)
  const dEndC = norm(mix(1.0, [[norm(fade(hit('bsb2358.wav', 1.87, 0.8, { rate: 0.85 }), 0.0005, 0.5)), 0, 0], [norm(fade(hit('bsb0655.wav', 6.95, 0.4, { af: 'lowpass=f=160' }), 0.001, 0.2)), 0, -3]]));   // удар о пол
  const dEndO = norm(mix(0.5, [[norm(fade(hit('bsb2475.wav', 10.16, 0.2, { rate: 0.8 }), 0.0005, 0.12)), 0, 0], [norm(fade(hit('bsb2027.wav', 0.16, 0.14, { af: 'lowpass=f=500' }), 0.001, 0.08)), 0, -4]]));   // упор наверху
  const motor = norm(fade(src('bsb0708.wav', 0.22, 0.4, { af: 'highpass=f=150,lowpass=f=5000' }), 0.02, 0.1));               // привод: лебёдка
  const dnO = readWav(path.join(OLD, 'sfx', 'door_down_1.ogg')), upO = readWav(path.join(OLD, 'sfx', 'door_up_1.ogg'));
  const down = level(tail(mix(1.3, [[dStart, 0, -6], [fade(dMove.subarray(0, Math.round(0.2 * SR)), 0.01, 0.05), 0.01, -7], [dEndC, 0.18, 0]]), 1.15, 0.1), loud(dnO)[0], -1.5);
  const up = level(tail(mix(1.0, [[dStart, 0, -5], [motor, 0.01, -8], [fade(dMove.subarray(0, Math.round(0.33 * SR)), 0.02, 0.06), 0.01, -3], [dEndO, 0.31, -2]]), 0.8, 0.1), loud(upO)[0], -1.5);
  for (const [n, x] of [['door_start', dStart], ['door_move', dMove], ['door_end_close', dEndC], ['door_end_open', dEndO]]) saveWav(OUT, n + '.wav', level(x, loud(dnO)[0] - 3, -1.5));
  saveWav(OUT, 'door_down.wav', down); cmp('door_close', dnO, down); saveWav(OUT, 'door_up.wav', up); cmp('door_open', upO, up);
  // --- заслонки: клапан падает 0,36 с, привод поднимает 0,52 с; упор — отдельный звук
  const dcO = old(path.join(OR, 'damper_close_synth.wav')), doO = old(path.join(OR, 'damper_open_synth.wav')), dsO = old(path.join(OR, 'damper_stop_synth.wav')), vbO = old(path.join(OR, 'vent_bang_synth.wav'));
  const dClose = level(tail(norm(fade(src('bsb0773.wav', 5.06, 0.4, { af: 'highpass=f=150,lowpass=f=6000' }), 0.01, 0.06)), 0.38, 0.05), loud(dcO)[0], -1.5);        // лист скользит (ящик жестяного шкафа)
  const dOpen = level(tail(mix(0.6, [[norm(fade(src('bsb0708.wav', 2.36, 0.52, { af: 'highpass=f=200,lowpass=f=5000' }), 0.03, 0.08)), 0, 0], [norm(fade(src('bsb0901.wav', 3.0, 0.5, { rate: 0.8, af: 'highpass=f=400' }), 0.03, 0.08)), 0, -8]]), 0.54, 0.06), loud(doO)[0], -1.5);   // привод: лебёдка и храповик
  const stops = [[16.61, 0.13, 1.0], [13.93, 0.13, 0.92]].map(([t, d, r]) => level(tail(mix(0.5, [[norm(fade(hit('bsb0773.wav', t + 0.02, d, { rate: r, af: 'lowpass=f=4000' }), 0.0005, 0.1)), 0, 0], [norm(fade(hit('oga/ws_low_hammering.wav', 4.65, 0.3, { af: 'lowpass=f=900' }), 0.001, 0.15)), 0, -5]]), 0.34, 0.08), loud(dsO)[0], -1.5));
  const bangs = [['bsb1777.wav', 0.07, 0.75], ['bsb1773.wav', 0.05, 0.8]].map(([f, t, r], i) => level(tail(mix(1.0, [[norm(fade(hit(f, t, 0.6, { rate: r }), 0.0005, 0.45)), 0, 0], [norm(fade(hit('oga/ws_low_hammering.wav', i ? 5.07 : 5.89, 0.37, { rate: 0.8, af: 'lowpass=f=1500' }), 0.001, 0.15)), 0, -2],
    [norm(fade(src('bsb0773.wav', i ? 18.13 : 20.6, 0.7, { rate: 0.9, af: 'lowpass=f=3500' }), 0.01, 0.3)), 0.08, -9]]), 0.9, 0.2), loud(vbO)[0] - 1, -1.5));
  saveWav(OUT, 'damper_close.wav', dClose); cmp('damper_close', dcO, dClose); saveWav(OUT, 'damper_open.wav', dOpen); cmp('damper_open', doO, dOpen);
  stops.forEach((x, i) => saveWav(OUT, `damper_stop_${i + 1}.wav`, x)); cmp('damper_stop', dsO, stops[0]);
  bangs.forEach((x, i) => saveWav(OUT, `vent_bang_${i + 1}.wav`, x)); cmp('vent_bang', vbO, bangs[0]);
  // --- телефон: звонок дискового аппарата и трубка на рычаге
  const ringO = old(path.join(OR, 'ring_synth.wav'));
  const ring = level(tail(fade(src('bsb0001.wav', 5.15, 2.25, { af: 'highpass=f=250' }), 0.003, 0.12), 2.2, 0.1), loud(ringO)[0] - 1, -1.5);
  const hookS = level(tail(norm(fade(src('bsb0001.wav', 15.78, 0.3), 0.002, 0.1)), 0.28, 0.06), loud(ringO)[0] - 6, -1.5);
  saveWav(OUT, 'phone_ring.wav', ring); cmp('phone_ring', ringO, ring); saveWav(OUT, 'phone_hook.wav', hookS); cmp('phone_hook', null, hookS);
  // --- генератор: рукоятка ручной лебёдки, четыре дубля по одному нажатию
  const crO = old(path.join(OR, 'crank_synth.wav'));
  const cranks = [2.4, 3.3, 4.6, 5.9].map((t, i) => level(tail(mix(0.3, [[norm(fade(src('bsb0901.wav', t, 0.3, { rate: 0.8, af: 'highpass=f=250,lowpass=f=6500' }), 0.004, 0.08)), 0, 0], [norm(fade(hit('oga/ws_lower_hammering.wav', [0.13, 0.55, 1.74, 2.13][i], 0.25, { af: 'lowpass=f=220' }), 0.002, 0.12)), 0, -6]]), 0.27, 0.05), loud(crO)[0] - 1, -1.5));
  cranks.forEach((x, i) => saveWav(OUT, `crank_${i + 1}.wav`, x)); cmp('generator_crank', seq([crO, crO, crO, crO], 0.1), seq(cranks, 0.1));
}

// ================= звуки здания (средний и дальний план) =================
if (want('amb')) {
  // трубы остывают: одиночные щелчки расширения металла, два дубля; вода пошла по трубе; далеко работает привод ворот
  const tick = (ts) => tail(fx(mix(2.6, ts.map(([t, at, d]) => [norm(fade(hit('bsb3093.wav', t, 0.12), 0.0005, 0.08)), at, d])), 'aecho=0.8:0.7:23|51:0.35|0.2,lowpass=f=5000'), 2.4, 0.4);
  const t1 = level(tick([[3.52, 0.05, 0], [7.62, 0.9, -4], [11.96, 1.55, -7]]), -30, -6), t2 = level(tick([[11.96, 0.05, 0], [3.52, 1.2, -5]]), -30, -6);
  const flow = level(tail(fade(src('bsb1219.wav', 20.0, 4.2, { af: 'highpass=f=150,lowpass=f=1800,aecho=0.8:0.6:40|90:0.3|0.2' }), 1.2, 2.0), 4.2, 1.0), -32, -6);
  const far = level(tail(fade(src('bsb1497.wav', 9.0, 5.0, { af: 'highpass=f=45,lowpass=f=380,aecho=0.8:0.6:140|290:0.4|0.25' }), 1.5, 2.5), 5.0, 1.0), -32, -6);
  saveOgg(OUT, 'amb_pipe_tick_1.ogg', t1); saveOgg(OUT, 'amb_pipe_tick_2.ogg', t2); saveOgg(OUT, 'amb_pipe_flow_1.ogg', flow); saveOgg(OUT, 'amb_far_motor_1.ogg', far);
  cmp('amb_pipe_tick', null, t1); cmp('amb_pipe_flow', null, flow); cmp('amb_far_motor', null, far);
}
console.table(REPORT.map((r) => ({ file: r.file, len: r.len, peak: r.peak, M: r.M })));
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'fnp1-')); fs.writeFileSync(path.join(TMP, 'used.json'), JSON.stringify(USED, null, 1)); console.log('использованные вырезки:', path.join(TMP, 'used.json'));
