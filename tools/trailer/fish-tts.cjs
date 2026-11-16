// Озвучка трейлера через Fish Audio: строки из vo.json → vo1.wav … vo10.wav в той же папке.
// Ключ и голос — только через переменные окружения, в git не класть:
//   FISH_KEY=sk-fish-... FISH_REF=<id модели голоса> node fish-tts.cjs <папка с vo.json>
// После генерации: node speech.cjs <папка> и перенести строку SPEECH в compose-godot.html.
const fs = require('fs'), path = require('path');
const dir = process.argv[2] || __dirname, key = process.env.FISH_KEY, ref = process.env.FISH_REF;
if (!key || !ref) { console.error('нужны FISH_KEY и FISH_REF'); process.exit(1); }
const lines = JSON.parse(fs.readFileSync(path.join(dir, 'vo.json'), 'utf8'));
(async () => {
  for (const [n, t] of lines) {
    const r = await fetch('https://api.fish.audio/v1/tts', { method: 'POST',
      headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', model: process.env.FISH_MODEL || 's1' },
      body: JSON.stringify({ text: t, reference_id: ref, format: 'wav', sample_rate: 44100, normalize: true, latency: 'normal' }) });
    if (!r.ok) { console.error(n, r.status, await r.text()); process.exit(1); }
    const b = Buffer.from(await r.arrayBuffer()); fs.writeFileSync(path.join(dir, n + '.wav'), b); console.log(n, b.length);
  }
})();
