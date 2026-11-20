// Озвучка трейлера мини-игр через Fish Audio: строки tools/trailer/vo-mini.json → <папка>/<имя>.wav.
// Голоса — те же, что в игре: V Пахан, M madk1d, N рассказчик, FN начальник смены, C1…C4 коллекторы.
// Ключ и голоса берутся из окружения или из .env в корне репозитория (он в .gitignore) — в файлы и git не пишутся.
//   node tools/trailer/fish-mini.cjs <папка кадров --trailermini> [--force]
// Уже готовые файлы не трогает (кроме --force). Печатает длительность каждой реплики и пишет vo-dur.json:
// длительности реплик трейлера и игровых реплик, которые звучат в трейлере — по ним реплики в compose-mini.html
// расставлены так, чтобы никто никого не перебивал.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const root = path.join(__dirname, '..', '..');
const envFile = path.join(root, '.env');
if (fs.existsSync(envFile)) for (const l of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
  const m = l.match(/^([A-Z_0-9]+)=(.*)$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim();
}
const key = process.env.FISH_KEY, ref = c => process.env['FISH_REF_' + c];
const out = process.argv[2]; if (!out) { console.error('укажи папку'); process.exit(1); }
const force = process.argv.includes('--force');
const lines = JSON.parse(fs.readFileSync(path.join(__dirname, 'vo-mini.json'), 'utf8'));
const wavDur = b => { let o = 12, sr = 44100, ch = 1, bits = 16; while (o < b.length - 8) { const id = b.toString('ascii', o, o + 4), sz = b.readUInt32LE(o + 4);
  if (id === 'fmt ') { ch = b.readUInt16LE(o + 10); sr = b.readUInt32LE(o + 12); bits = b.readUInt16LE(o + 22); }
  if (id === 'data') return Math.min(sz, b.length - o - 8) / (sr * ch * bits / 8); o += 8 + sz + (sz & 1); } return 0; };
// игровые реплики, которые звучат в трейлере: [код, текст] — файл godot/assets/voice/<код>_<md5 «код|текст»>.mp3 (64 кбит/с)
const GAME = [
  ['C3', 'Алло. Это «Срочно Финанс». Срочно.'], ['C1', 'Мы ценим каждого клиента. Особенно должников.'],
  ['C4', 'Пахан, это Гена из «Решим вопрос». Помнишь меня?'], ['C2', 'Репутация клиента — наш главный актив. Ваша — тает.'],
  ['C2', 'Мы готовы обсудить, если вы готовы платить.'],
  ['FN', 'Алло, Павел? Это Семёныч, начальник смены. Короче, всё просто.'],
  ['FN', 'Сидишь в будке, смотришь камеры до шести. Двери не открывай незнакомым.'],
  ['FN', 'И это… Только не трогай Балона, у него сегодня выходной.'],
  ['FN', 'Если услышишь, как тебя зовут из вентиляции… не отвечай. Всё, удачи.'],
  ['V', 'Ну, начали. Камеры, двери, свет. Не сложнее, чем бит свести.'],
  ['V', 'Да вы заебали, я вообще-то на смене.'], ['V', 'Шесть. Шесть, бля. Живой.'],
];
(async () => {
  const dur = {};
  for (const [n, who, text] of lines) {
    const f = path.join(out, n + '.wav');
    if (!fs.existsSync(f) || force) {
      if (!key || !ref(who)) { console.error('нужны FISH_KEY и FISH_REF_' + who + ' (в окружении или в .env)'); process.exit(1); }
      const r = await fetch('https://api.fish.audio/v1/tts', { method: 'POST',
        headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', model: process.env.FISH_MODEL || 's1' },
        body: JSON.stringify({ text, reference_id: ref(who), format: 'wav', sample_rate: 44100, normalize: true, latency: 'normal' }) });
      if (!r.ok) { console.error(n, r.status, (await r.text()).slice(0, 200)); process.exit(1); }
      fs.writeFileSync(f, Buffer.from(await r.arrayBuffer()));
    }
    dur[n] = +wavDur(fs.readFileSync(f)).toFixed(2);
    console.log(n, who, dur[n] + ' с', text);
  }
  for (const [code, text] of GAME) {
    const name = code + '_' + crypto.createHash('md5').update(code + '|' + text, 'utf8').digest('hex').slice(0, 10);
    const f = path.join(root, 'godot', 'assets', 'voice', name + '.mp3');
    if (!fs.existsSync(f)) { console.error('нет игровой реплики', name, text); process.exit(1); }
    dur[name] = +(fs.statSync(f).size * 8 / 64000).toFixed(2);
    console.log(name, code, dur[name] + ' с', text);
  }
  fs.writeFileSync(path.join(out, 'vo-dur.json'), JSON.stringify(dur, null, 1));
})();
