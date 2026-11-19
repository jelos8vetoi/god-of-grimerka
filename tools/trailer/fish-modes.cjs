// Озвучка трейлера режимов через Fish Audio: строки tools/trailer/vo-modes.json → <папка>/voNN.wav.
// Ключ и голоса берутся из окружения или из .env в корне репозитория (он в .gitignore) — в файлы и git не пишутся:
//   FISH_KEY=sk-fish-...  FISH_REF_V=<голос Пахана>  FISH_REF_M=<голос madk1d>
//   node tools/trailer/fish-modes.cjs <папка кадров --trailermodes>
// Печатает длительность каждой реплики — по ним выставляются времена в VO_FILE (compose-modes.html).
const fs = require('fs'), path = require('path');
const envFile = path.join(__dirname, '..', '..', '.env');
if (fs.existsSync(envFile)) for (const l of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
  const m = l.match(/^([A-Z_]+)=(.*)$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim();
}
const key = process.env.FISH_KEY, refs = { V: process.env.FISH_REF_V, M: process.env.FISH_REF_M };
if (!key || !refs.V || !refs.M) { console.error('нужны FISH_KEY, FISH_REF_V и FISH_REF_M (в окружении или в .env)'); process.exit(1); }
const out = process.argv[2]; if (!out) { console.error('укажи папку'); process.exit(1); }
const lines = JSON.parse(fs.readFileSync(path.join(__dirname, 'vo-modes.json'), 'utf8'));
const dur = b => { let o = 12, sr = 44100, ch = 1, bits = 16; while (o < b.length) { const id = b.toString('ascii', o, o + 4), sz = b.readUInt32LE(o + 4); if (id === 'fmt ') { ch = b.readUInt16LE(o + 10); sr = b.readUInt32LE(o + 12); bits = b.readUInt16LE(o + 22); } if (id === 'data') return Math.min(sz, b.length - o - 8) / (sr * ch * bits / 8); o += 8 + sz + (sz & 1); } return 0; };
(async () => {
  for (const [n, who, text] of lines) {
    const r = await fetch('https://api.fish.audio/v1/tts', { method: 'POST',
      headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', model: process.env.FISH_MODEL || 's1' },
      body: JSON.stringify({ text, reference_id: refs[who], format: 'wav', sample_rate: 44100, normalize: true, latency: 'normal' }) });
    if (!r.ok) { console.error(n, r.status, (await r.text()).slice(0, 200)); process.exit(1); }
    const b = Buffer.from(await r.arrayBuffer());
    fs.writeFileSync(path.join(out, n + '.wav'), b);
    console.log(n, who, dur(b).toFixed(2) + ' с', text);
  }
})();
