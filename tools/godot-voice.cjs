// Озвучка Godot-версии через Fish Audio: Пахан, madk1d, рассказчик, Лил Дрей, начальник смены, коллекторы.
// Берёт реплики V (Пахан), M и MV (madk1d), N (рассказчик), B1 (Лил Дрей) из godot/data/story.json,
// боевые выкрики из godot/data/barks.json, звонки коллекторов «Микрозаймов» (коды C1…C4, ml_data.gd)
// и «5 НОЧЕЙ С ПАХАНОМ» из godot/scripts/five_nights/fn_data.gd: звонки начальника смены (код FN — массив CALLS)
// и мысли Пахана на смене (код V — словарь PAHAN),
// кладёт по файлу на реплику в godot/assets/voice/<код>_<md5 строки, 10 знаков>.mp3 — игра ищет файл по тому же имени.
// Уже готовые файлы не трогает, файлы от удалённых реплик стирает.
// Ключ и голоса — только через переменные окружения, в git их не класть:
//   FISH_KEY=sk-fish-... FISH_REF_V=<Пахан> FISH_REF_M=<madk1d> FISH_REF_B1=<Лил Дрей> FISH_REF_FN=<Семёныч>
//   FISH_REF_N=<рассказчик> FISH_REF_C1=… FISH_REF_C4=<коллекторы> node tools/godot-voice.cjs [--limit=N] [--dry]
// Можно задать только часть голосов: остальные реплики будут пропущены, готовые файлы не тронутся.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const root = path.join(__dirname, '..', 'godot');
const out = path.join(root, 'assets', 'voice');
// кого озвучиваем и из какой переменной окружения берётся голос (id модели Fish Audio)
// N — рассказчик кампании; C1…C4 — коллекторы четырёх контор «Микрозаймов» (по порядку MLData.LENDER_ORDER)
const VOICED = { V: 'FISH_REF_V', M: 'FISH_REF_M', MV: 'FISH_REF_M', B1: 'FISH_REF_B1', FN: 'FISH_REF_FN', N: 'FISH_REF_N',
  C1: 'FISH_REF_C1', C2: 'FISH_REF_C2', C3: 'FISH_REF_C3', C4: 'FISH_REF_C4' };
const key = process.env.FISH_KEY, refs = {};
for (const c in VOICED) refs[c] = process.env[VOICED[c]];
const dry = process.argv.includes('--dry');
const limit = +(process.argv.find(a => a.startsWith('--limit=')) || '').slice(8) || 1e9;
if (!dry && !key) { console.error('нужен FISH_KEY и голоса: ' + [...new Set(Object.values(VOICED))].join(', ')); process.exit(1); }
fs.mkdirSync(out, { recursive: true });

const story = JSON.parse(fs.readFileSync(path.join(root, 'data', 'story.json'), 'utf8'));
const barks = JSON.parse(fs.readFileSync(path.join(root, 'data', 'barks.json'), 'utf8'));
const lines = new Set();
for (const ch of story.CH) for (const st of ch.steps) if (st.t === 'dlg') for (const l of st.l) lines.add(l);
for (const k of ['ENDING_A', 'ENDING_B']) for (const l of story[k] || []) lines.add(l);
for (const k in barks) for (const l of barks[k]) lines.add(l);
// фразы боссов при смене фазы — голосом их говорящего
for (const id in story.BOSS) for (const b of story.BOSS[id].barks || []) if (b) lines.add(story.BOSS[id].sp + '|' + b);

// звонки «5 ночей»: строки массива CALLS прямо из скрипта данных (от «const CALLS := [» до закрывающей «]» в начале строки)
const fnSrc = fs.readFileSync(path.join(root, 'scripts', 'five_nights', 'fn_data.gd'), 'utf8').replace(/\r/g, '');
const fnBlock = /\nconst CALLS := \[\n([\s\S]*?)\n\]\n/.exec(fnSrc);
if (!fnBlock) { console.error('не найден массив CALLS в fn_data.gd'); process.exit(1); }
for (const m of fnBlock[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)) lines.add('FN|' + m[1].replace(/\\"/g, '"'));
// мысли Пахана на смене (словарь PAHAN там же) — его обычным голосом (код V): берём строки из массивов, ключи разделов пропускаем
const fnPahan = /\nconst PAHAN := \{\n([\s\S]*?)\n\}\n/.exec(fnSrc);
if (!fnPahan) { console.error('не найден словарь PAHAN в fn_data.gd'); process.exit(1); }
for (const row of fnPahan[1].split('\n')) {
  const arr = /:\s*\[(.*)\]\s*,?\s*$/.exec(row);
  if (arr) for (const m of arr[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)) lines.add('V|' + m[1].replace(/\\"/g, '"'));
}

// «Микрозаймы»: звонок коллектора (godot/scripts/microloans/ml_data.gd). У каждой конторы свои фразы ("voice" в LENDERS)
// и общие для всех ответы (словарь COLLECTOR) — каждая контора говорит их своим голосом: код C<номер по LENDER_ORDER>
const mlSrc = fs.readFileSync(path.join(root, 'scripts', 'microloans', 'ml_data.gd'), 'utf8').replace(/\r/g, '');
const strs = s => [...s.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map(m => m[1].replace(/\\"/g, '"'));
const mlOrder = /\nconst LENDER_ORDER := \[(.*?)\]/.exec(mlSrc);
const mlCommon = /\nconst COLLECTOR := \{\n([\s\S]*?)\n\}\n/.exec(mlSrc);
if (!mlOrder || !mlCommon) { console.error('не найдены LENDER_ORDER или COLLECTOR в ml_data.gd'); process.exit(1); }
const common = [];
for (const row of mlCommon[1].split('\n')) { const arr = /:\s*\[(.*)\]\s*,?\s*$/.exec(row); if (arr) common.push(...strs(arr[1])); }
strs(mlOrder[1]).forEach((id, i) => {
  const own = new RegExp('\\n\\t"' + id + '": \\{[\\s\\S]*?"voice": \\[(.*?)\\]\\}').exec(mlSrc);
  if (!own) { console.error('не найдены фразы конторы ' + id + ' в ml_data.gd'); process.exit(1); }
  for (const t of [...strs(own[1]), ...common]) lines.add('C' + (i + 1) + '|' + t);
});

// как в игре (_clean): без эмодзи и значков
const clean = s => [...s].filter(ch => { const c = ch.codePointAt(0); return c < 0x1F000 && !(c >= 0x2600 && c <= 0x27BF) && c !== 0xFE0F; }).join('').trim();
const jobs = [];
for (const l of lines) {
  const p = l.indexOf('|'), code = l.slice(0, p);
  if (!VOICED.hasOwnProperty(code)) continue;
  let text = clean(l.slice(p + 1)).replace(/\[[^\]]*\]/g, '').trim();   // [гудки], [помехи] — ремарки, их не читаем
  if (!/[a-zа-яё]/i.test(text)) continue;             // «...» и подобное не озвучиваем
  if (!/[.!?…]$/.test(text)) text += '.';
  const name = code + '_' + crypto.createHash('md5').update(l, 'utf8').digest('hex').slice(0, 10) + '.mp3';
  jobs.push({ code, text, name });
}
const want = new Set(jobs.map(j => j.name));
for (const f of fs.readdirSync(out)) if (f.endsWith('.mp3') && !want.has(f)) { fs.unlinkSync(path.join(out, f)); try { fs.unlinkSync(path.join(out, f + '.import')); } catch (e) {} console.log('удалён лишний', f); }
const missing = jobs.filter(j => !fs.existsSync(path.join(out, j.name)));
const skipped = missing.filter(j => !refs[j.code]);
if (skipped.length) console.log('без голоса (не задана переменная): ' + [...new Set(skipped.map(j => VOICED[j.code]))].join(', ') + ' — ' + skipped.length + ' реплик пропущено');
const todo = missing.filter(j => refs[j.code]).slice(0, limit);
const chars = todo.reduce((s, j) => s + j.text.length, 0);
console.log(`реплик: ${jobs.length}, осталось сделать: ${todo.length}, знаков: ${chars}`);
if (dry) { for (const j of todo.slice(0, 12)) console.log(j.name, j.text); process.exit(0); }

async function tts(j, attempt = 0) {
  const r = await fetch('https://api.fish.audio/v1/tts', { method: 'POST',
    headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', model: process.env.FISH_MODEL || 's1' },
    body: JSON.stringify({ text: j.text, reference_id: refs[j.code], format: 'mp3', mp3_bitrate: 64, normalize: true, latency: 'normal' }) });
  if (!r.ok) {
    const msg = (await r.text()).slice(0, 200);
    if ((r.status === 429 || r.status >= 500) && attempt < 4) { await new Promise(res => setTimeout(res, 2000 * (attempt + 1))); return tts(j, attempt + 1); }
    throw new Error(j.name + ' ' + r.status + ' ' + msg);
  }
  const b = Buffer.from(await r.arrayBuffer());
  if (b.length < 800) throw new Error(j.name + ' пустой ответ');
  fs.writeFileSync(path.join(out, j.name), b);
  console.log(j.name, b.length, j.text.slice(0, 50));
}
(async () => {
  let i = 0, fail = 0;
  const worker = async () => { while (i < todo.length) { const j = todo[i++]; try { await tts(j); } catch (e) { fail++; console.error('ОШИБКА', e.message); } } };
  await Promise.all([worker(), worker(), worker()]);
  console.log(`готово, ошибок: ${fail}`);
  process.exit(fail ? 1 : 0);
})();
