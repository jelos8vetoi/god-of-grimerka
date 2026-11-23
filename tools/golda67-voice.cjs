// Озвучка приквела «ГОЛДА 67», глава 1 — через Voice Studio Pro (локальный MCP) моделями владельца.
//
//   node tools/golda67-voice.cjs            — выгрузить реплики, обновить манифест, сгенерировать недостающее, проверить
//   node tools/golda67-voice.cjs --plan     — только выгрузить реплики и обновить манифест (без генерации)
//   node tools/golda67-voice.cjs --retry    — заново сгенерировать реплики со статусом failed
//   node tools/golda67-voice.cjs --only=KROT — только один персонаж (тег из G67Voice.SPEAKERS)
//   node tools/golda67-voice.cjs --docs     — пересобрать документы по манифесту (список реплик, модели, отчёт)
//   node tools/golda67-voice.cjs --retrim   — переобрезать тишину у готовых файлов (без новой генерации)
//   node tools/golda67-voice.cjs --dehum=G1 — срезать «хм» перед фразой у персонажа (код говорящего)
//
// Идемпотентно: готовые реплики не трогаются. Новая реплика — в очередь; изменился текст — новая реплика (старая
// помечается obsolete, её файл остаётся); сменилась модель персонажа — перегенерируются только его реплики.
// Модели голосов НЕ создаются и не меняются: берутся из list_voices по ID из voice_models.json или по имени.
// Нет модели — реплики персонажа получают статус voice_model_missing, остальная работа идёт дальше.
// Адрес MCP — из настроек приложения (%APPDATA%/VoiceStudio Pro/backend.json), можно задать VSP_URL.
const fs = require('fs'), path = require('path'), os = require('os'), cp = require('child_process');
const ROOT = path.resolve(__dirname, '..');
const GODOT = process.env.GODOT || path.join(ROOT, 'tools/godot/Godot_v4.7.2-stable_win64_console.exe');
const CH = path.join(ROOT, 'godot/Audio/Voice/Golda67/Chapter_01');
const RES = 'res://Audio/Voice/Golda67/Chapter_01/';
const MANIFEST = path.join(CH, 'manifest.json');
const MODELS = path.join(CH, 'voice_models.json');
const TMP = path.join(os.tmpdir(), 'golda67-voice');
const args = process.argv.slice(2);
const ONLY = (args.find(a => a.startsWith('--only=')) || '').slice(7).toUpperCase();
const PLAN = args.includes('--plan'), RETRY = args.includes('--retry'), DOCS = args.includes('--docs'), RETRIM = args.includes('--retrim');
const DOCDIR = path.join(ROOT, 'godot/docs/golda67');
const STEPS = 32;                       // качество диффузии (8 — черновик, 32 — качество)
const MATCH_OK = 0.62;                  // сходство распознанного текста с исходным, чтобы считать реплику проверенной

// ---------------------------------------------------------------- MCP
function mcpUrl() {
  if (process.env.VSP_URL) return process.env.VSP_URL;
  try { return JSON.parse(fs.readFileSync(path.join(process.env.APPDATA, 'VoiceStudio Pro', 'backend.json'), 'utf8')).url.replace(/\/$/, '') + '/mcp/'; }
  catch (e) { return 'http://127.0.0.1:3802/mcp/'; }
}
let SID = null, NID = 1;
async function rpc(method, params, notify) {
  const body = notify ? { jsonrpc: '2.0', method, params } : { jsonrpc: '2.0', id: NID++, method, params };
  const h = { 'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream' };
  if (SID) h['mcp-session-id'] = SID;
  const r = await fetch(mcpUrl(), { method: 'POST', headers: h, body: JSON.stringify(body) });
  if (!SID && r.headers.get('mcp-session-id')) SID = r.headers.get('mcp-session-id');
  if (notify) return null;
  const t = await r.text();
  let msg = null;
  if ((r.headers.get('content-type') || '').includes('event-stream')) {
    for (const ln of t.split('\n')) if (ln.startsWith('data:')) { const m = JSON.parse(ln.slice(5)); if (m.id === body.id) msg = m; }
  } else msg = JSON.parse(t);
  if (!msg) throw new Error('пустой ответ MCP');
  if (msg.error) throw new Error(JSON.stringify(msg.error));
  return msg.result;
}
async function tool(name, a) {
  const r = await rpc('tools/call', { name, arguments: a || {} });
  if (r.isError) throw new Error((r.content || []).map(c => c.text).join(' ').slice(0, 400));
  const txt = (r.content || []).map(c => c.text || '').join('');
  try { return JSON.parse(txt); } catch (e) { return txt; }
}
async function connect() {
  await rpc('initialize', { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'claude-code', version: '1.0' } });
  await rpc('notifications/initialized', {}, true);
}

// ---------------------------------------------------------------- WAV: тишина, громкость
function readWav(buf) {
  let p = 12, fmt = null, data = null;
  while (p + 8 <= buf.length) {
    const id = buf.toString('ascii', p, p + 4), sz = buf.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = { ch: buf.readUInt16LE(p + 10), rate: buf.readUInt32LE(p + 12), bits: buf.readUInt16LE(p + 22) };
    if (id === 'data') data = buf.subarray(p + 8, p + 8 + sz);
    p += 8 + sz + (sz & 1);
  }
  if (!fmt || !data || fmt.bits !== 16) throw new Error('WAV не 16-бит PCM');
  const n = Math.floor(data.length / 2 / fmt.ch), s = new Float32Array(n);
  for (let i = 0; i < n; i++) { let v = 0; for (let c = 0; c < fmt.ch; c++) v += data.readInt16LE((i * fmt.ch + c) * 2); s[i] = v / fmt.ch / 32768; }
  return { rate: fmt.rate, s };
}
function writeWav(rate, s) {
  const b = Buffer.alloc(44 + s.length * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + s.length * 2, 4); b.write('WAVE', 8); b.write('fmt ', 12);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28);
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(s.length * 2, 40);
  for (let i = 0; i < s.length; i++) b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(s[i] * 32767))), 44 + i * 2);
  return b;
}
// обрезать тишину по краям, привести громкость к −20 dBFS RMS речи, пик не выше −1 dBFS.
// Начало речи — первое место, где громкость держится выше 12 % пика хотя бы 60 мс (тихий вдох и шум перед фразой
// отрезаются), перед ним остаётся 25 мс; конец — последнее место выше 8 % пика, после него 80 мс (затухание слова).
const LEAD_MS = 25, TAIL_MS = 80, ON_K = 0.12, OFF_K = 0.08, HOLD_MS = 60;
function polish(w) {
  const { rate, s } = w, win = Math.floor(rate * 0.01);
  const rmsAt = i => { let a = 0, n = 0; for (let k = i; k < Math.min(s.length, i + win); k++) { a += s[k] * s[k]; n++; } return n ? Math.sqrt(a / n) : 0; };
  const env = []; for (let i = 0; i < s.length; i += win) env.push(rmsAt(i));
  const pk = Math.max(...env, 1e-6);
  const hold = Math.max(1, Math.round(HOLD_MS / 10));
  let on = 0;
  while (on < env.length) { let ok = true; for (let k = 0; k < hold; k++) if ((env[on + k] || 0) < pk * ON_K) { ok = false; break; } if (ok) break; on++; }
  // от устойчивого начала — назад, пока ещё слышно хоть немного (мягкая первая согласная)
  while (on > 0 && env[on - 1] >= pk * 0.05) on--;
  let off = env.length - 1;
  while (off > on && env[off] < pk * OFF_K) off--;
  let a = Math.max(0, on * win - Math.floor(rate * LEAD_MS / 1000));
  let b = Math.min(s.length, (off + 1) * win + Math.floor(rate * TAIL_MS / 1000));
  const t = s.slice(a, b);
  let sum = 0, cnt = 0, peak = 0;
  for (let i = on; i <= off; i++) if (env[i] > pk * OFF_K) { sum += env[i] * env[i]; cnt++; }
  for (let i = 0; i < t.length; i++) peak = Math.max(peak, Math.abs(t[i]));
  const speech = cnt ? Math.sqrt(sum / cnt) : 0;
  let g = speech > 0 ? Math.pow(10, -20 / 20) / speech : 1;
  if (peak * g > 0.89) g = 0.89 / peak;
  for (let i = 0; i < t.length; i++) t[i] *= g;
  const f = Math.floor(rate * 0.006);          // плавные края 6 мс — без щелчка
  for (let i = 0; i < f && i < t.length; i++) { t[i] *= i / f; t[t.length - 1 - i] *= i / f; }
  return { rate, s: t, dur: t.length / rate, speech_db: speech ? 20 * Math.log10(speech * g) : -99, cut_ms: Math.round(a / rate * 1000) };
}
// «хм» перед фразой (у модели Миши): короткий звук ≤ 280 мс в самом начале, за ним пауза ≥ 70 мс — срезается до
// начала следующего звука (минус 25 мс). Возвращает срезанные мс или 0.
function dehum(e) {
  if (e.check && e.check.dehum_ms) return -1;            // уже очищено — второй раз не резать
  const dst = path.join(ROOT, 'godot', e.path.replace('res://', ''));
  if (!fs.existsSync(dst)) return 0;
  const r = cp.spawnSync(ffmpeg(), ['-loglevel', 'error', '-i', dst, '-f', 's16le', '-ac', '1', '-ar', '24000', '-'], { maxBuffer: 1 << 28 });
  if (r.status !== 0) return 0;
  const n = r.stdout.length / 2, sm = new Float32Array(n);
  for (let i = 0; i < n; i++) sm[i] = r.stdout.readInt16LE(i * 2) / 32768;
  const win = 240, env = [];
  for (let i = 0; i < n; i += win) { let a = 0; for (let k = i; k < Math.min(n, i + win); k++) a += sm[k] * sm[k]; env.push(Math.sqrt(a / win)); }
  const pk = Math.max(...env);
  const segs = []; let on = -1, gap = 0;
  for (let i = 0; i < env.length; i++) {
    if (env[i] >= pk * 0.1) { if (on < 0) on = i; gap = 0; }
    else if (on >= 0) { gap++; if (gap >= 6) { segs.push([on, i - gap + 1]); on = -1; gap = 0; } }
  }
  if (on >= 0) segs.push([on, env.length]);
  let cut = -1;
  if (segs.length >= 2 && segs[0][1] - segs[0][0] <= 28 && segs[1][0] - segs[0][1] >= 7) cut = Math.max(0, segs[1][0] * win - 600);
  else {
    // второй случай: громкий короткий звук (≤ 220 мс) в начале, сразу за ним тише — по порогу 25 % пика
    const s2 = []; let o2 = -1, g2 = 0;
    for (let i = 0; i < env.length; i++) {
      if (env[i] >= pk * 0.25) { if (o2 < 0) o2 = i; g2 = 0; }
      else if (o2 >= 0) { g2++; if (g2 >= 3) { s2.push([o2, i - g2 + 1]); o2 = -1; g2 = 0; } }
    }
    if (o2 >= 0) s2.push([o2, env.length]);
    if (s2.length >= 2 && s2[0][0] <= 15 && s2[0][1] - s2[0][0] <= 22 && s2[1][0] - s2[0][1] >= 3) cut = (s2[0][1] + 1) * win;
  }
  if (cut < 0) return 0;
  const t0 = sm.slice(cut);
  const f = 240;
  for (let i = 0; i < f && i < t0.length; i++) t0[i] *= i / f;
  const t = polish({ rate: 24000, s: t0 }).s;            // без «хм» пик ниже — громкость заново
  const tmp = path.join(TMP, e.id + '_dh.wav');
  fs.mkdirSync(TMP, { recursive: true });
  fs.writeFileSync(tmp, writeWav(24000, t));
  const r2 = cp.spawnSync(ffmpeg(), ['-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '6', '-ac', '1', dst], { encoding: 'utf8' });
  fs.rmSync(tmp, { force: true });
  if (r2.status !== 0) return 0;
  const ms = Math.round(cut / 24);
  e.check = Object.assign({}, e.check, { duration_s: +(t.length / 24000).toFixed(2), bytes: fs.statSync(dst).size, dehum_ms: ms });
  return ms;
}
// уже готовый .ogg: раскодировать, переобрезать, закодировать обратно (без новой генерации)
function retrim(e) {
  const dst = path.join(ROOT, 'godot', e.path.replace('res://', ''));
  if (!fs.existsSync(dst)) return false;
  const r = cp.spawnSync(ffmpeg(), ['-loglevel', 'error', '-i', dst, '-f', 's16le', '-ac', '1', '-ar', '24000', '-'], { maxBuffer: 1 << 28 });
  if (r.status !== 0) return false;
  const n = r.stdout.length / 2, sm = new Float32Array(n);
  for (let i = 0; i < n; i++) sm[i] = r.stdout.readInt16LE(i * 2) / 32768;
  const p = polish({ rate: 24000, s: sm });
  const tmp = path.join(TMP, e.id + '_rt.wav');
  fs.mkdirSync(TMP, { recursive: true });
  fs.writeFileSync(tmp, writeWav(p.rate, p.s));
  const r2 = cp.spawnSync(ffmpeg(), ['-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '6', '-ac', '1', dst], { encoding: 'utf8' });
  fs.rmSync(tmp, { force: true });
  if (r2.status !== 0) return false;
  e.check = Object.assign({}, e.check, { duration_s: +p.dur.toFixed(2), bytes: fs.statSync(dst).size, trim: `${LEAD_MS}/${TAIL_MS}` });
  return p.cut_ms;
}
// madk1d: Fish Audio (тот же голос, что в кампании), mp3 → PCM 24 кГц через ffmpeg
function ffmpeg() {
  const base = path.join(process.env.APPDATA || '', 'VoiceStudioPro', 'media_tools');
  try { for (const d of fs.readdirSync(base)) for (const sub of ['win32', '']) { const f = path.join(base, d, sub, 'ffmpeg.exe'); if (fs.existsSync(f)) return f; } } catch (e) {}
  return 'ffmpeg';
}

// ---------------------------------------------------------------- сравнение текста
function norm(t) { return t.toLowerCase().replace(/ё/g, 'е').replace(/[^a-zа-я0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim(); }
function similarity(a, b) {
  a = norm(a); b = norm(b);
  if (!a.length && !b.length) return 1;
  const m = a.length, n = b.length, d = Array.from({ length: m + 1 }, (_, i) => [i]);
  for (let j = 1; j <= n; j++) d[0][j] = j;
  for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++) d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return 1 - d[m][n] / Math.max(m, n);
}

// ---------------------------------------------------------------- манифест
function exportLines() {
  const out = path.join(TMP, 'lines.json');
  fs.mkdirSync(TMP, { recursive: true });
  const r = cp.spawnSync(GODOT, ['--headless', '--path', path.join(ROOT, 'godot'), '--script', 'res://scripts/golda67/g67_voice_export.gd', '--', out], { encoding: 'utf8' });
  if (!fs.existsSync(out)) throw new Error('выгрузка реплик не удалась:\n' + (r.stdout || '') + (r.stderr || ''));
  return JSON.parse(fs.readFileSync(out, 'utf8'));
}
function loadJson(p, d) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { return d; } }
function save(man) {
  man.updated = new Date().toISOString();
  fs.writeFileSync(MANIFEST, JSON.stringify(man, null, '\t') + '\n');
}
function merge(man, exp) {
  const byKey = new Map(man.lines.map(e => [e.code + '|' + e.text, e]));
  const seen = new Set();
  const next = {};
  for (const e of man.lines) { const m = /_(\d+)$/.exec(e.id); if (m) next[e.code] = Math.max(next[e.code] || 0, +m[1]); }
  let added = 0;
  for (const l of exp.lines) {
    const key = l.code + '|' + l.text;
    if (seen.has(key)) continue;          // одна и та же строка в двух сценах — один файл
    seen.add(key);
    const sp = exp.speakers[l.code];
    let e = byKey.get(key);
    if (!e) {
      next[l.code] = (next[l.code] || 0) + 1;
      const id = `CH01_${sp.tag}_${String(next[l.code]).padStart(3, '0')}`;
      e = { id, code: l.code, char: sp.char, char_name: sp.name, text: l.text, voice_id: '', path: `${RES}${sp.folder}/${id}.ogg`, status: 'pending', check: {}, gen: 0 };
      man.lines.push(e); added++;
    }
    e.scene = l.scene; e.order = l.order; e.when = l.when; e.emotion = l.emotion; e.speed = l.speed;
    if (e.status === 'obsolete') e.status = 'pending';
  }
  let gone = 0;
  for (const e of man.lines) if (!seen.has(e.code + '|' + e.text) && e.status !== 'obsolete') { e.status = 'obsolete'; gone++; }
  return { added, gone };
}

// ---------------------------------------------------------------- модели
const NAME_HINTS = { M: /madk/i, V: /паш|пахан|pahan/i, KR: /крот|krot/i, DJ: /flurr|flürr|флюр/i, G1: /миша|misha|минасян/i,
  WH: /whyousolonely/i, FT: /fortuna/i, KX: /королев|korolev/i, BS: /бустер|buster/i };
// голоса не из моделей владельца: ведущие — встроенные пресеты Voice Studio Pro (решение владельца).
// Весь приквел озвучивается только через Voice Studio Pro (решение владельца от 2026-11-22): madk1d — его модель MADK1D.
const FIXED = { DK: { id: 'preset:energetic', name: 'пресет Energetic (Voice Studio Pro)' }, AN: { id: 'preset:narrator', name: 'пресет Narrator (Voice Studio Pro)' }, PH: { id: 'preset:casual', name: 'пресет Casual (Voice Studio Pro)' },
  LS: { id: 'preset:corporate', name: 'пресет Corporate (Voice Studio Pro)' },
  BB: { id: 'preset:storyteller', name: 'пресет Storyteller (Voice Studio Pro)' }, TX: { id: 'preset:casual', name: 'пресет Casual (Voice Studio Pro)' }, US: { id: 'preset:narrator', name: 'пресет Narrator (Voice Studio Pro)' },
  SC: { id: 'preset:energetic', name: 'пресет Energetic (Voice Studio Pro)' }, Z1: { id: 'preset:corporate', name: 'пресет Corporate (Voice Studio Pro)' }, Z2: { id: 'preset:news_anchor', name: 'пресет News Anchor (Voice Studio Pro)' },
  ZW: { id: 'preset:audiobook_uk_narrator', name: 'пресет Audiobook UK Narrator, женский (Voice Studio Pro)' }, SH: { id: 'preset:energetic', name: 'пресет Energetic (Voice Studio Pro)' }, RD: { id: 'preset:news_anchor', name: 'пресет News Anchor (Voice Studio Pro)' }, DM: { id: 'preset:corporate', name: 'пресет Corporate (Voice Studio Pro)' }, DP: { id: 'preset:audiobook_uk_narrator', name: 'пресет Audiobook UK Narrator, женский (Voice Studio Pro)' } };
async function resolveModels(exp) {
  const cfg = loadJson(MODELS, { note: 'ID моделей Voice Studio Pro по коду говорящего. Пусто — ищется по имени модели.', models: {} });
  let voices = [];
  try { voices = await tool('list_voices', {}); } catch (e) { console.log('VOICE list_voices: ' + e.message); }
  const out = {};
  for (const code of Object.keys(exp.speakers)) {
    let id = (cfg.models[code] || {}).id || '';
    let v = voices.find(x => x.id === id);
    if (!v && FIXED[code]) {
      const f = FIXED[code];
      v = { id: f.id, name: f.name };
    }
    if (!v) v = voices.find(x => !x.is_demo && NAME_HINTS[code] && NAME_HINTS[code].test(x.name));
    out[code] = v ? { id: v.id, name: v.name, engine: v.engine || 'vsp' } : null;
    cfg.models[code] = { character: exp.speakers[code].name, id: v ? v.id : '', voice_name: v ? v.name : '', status: v ? 'found' : 'voice_model_missing' };
  }
  fs.writeFileSync(MODELS, JSON.stringify(cfg, null, '\t') + '\n');
  return out;
}

// ---------------------------------------------------------------- генерация и проверка одной реплики
async function produce(e, model) {
  fs.mkdirSync(TMP, { recursive: true });
  let best = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    let raw;
    {
      const r = await tool('generate_speech', { text: e.text, profile_id: model.id, language: 'ru', speed: e.speed || 1.0, steps: STEPS, format: 'wav' });
      const b64 = r.wav_base64 || r.audio_base64;
      if (!b64) throw new Error('генератор не вернул звук: ' + JSON.stringify(r).slice(0, 200));
      raw = readWav(Buffer.from(b64, 'base64'));
    }
    const p = polish(raw);
    const wav = writeWav(p.rate, p.s);
    let heard = '', score = 0;
    try { const tr = await tool('transcribe', { audio_base64: wav.toString('base64'), language: 'ru' }); heard = tr.text || ''; score = similarity(e.text, heard); }
    catch (err) { heard = '(распознавание недоступно: ' + err.message.slice(0, 80) + ')'; score = -1; }
    const words = norm(e.text).split(' ').length;
    const audible = p.dur >= 0.25 && p.speech_db > -45;
    const cand = { wav, p, heard, score, audible };
    if (!best || (cand.audible && (!best.audible || cand.score > best.score))) best = cand;
    const enough = score < 0 ? audible : (score >= MATCH_OK || (words <= 2 && score >= 0.34));
    if (audible && enough) break;
    console.log(`  повтор ${e.id}: слышно «${heard}» (сходство ${score.toFixed(2)})`);
  }
  const tmpWav = path.join(TMP, e.id + '.wav');
  fs.writeFileSync(tmpWav, best.wav);
  const dst = path.join(ROOT, 'godot', e.path.replace('res://', ''));
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  const r = cp.spawnSync(ffmpeg(), ['-y', '-loglevel', 'error', '-i', tmpWav, '-c:a', 'libvorbis', '-q:a', '6', '-ac', '1', dst], { encoding: 'utf8' });
  fs.rmSync(tmpWav, { force: true });
  if (r.status !== 0 || !fs.existsSync(dst) || fs.statSync(dst).size < 1500) throw new Error('OGG не записан: ' + (r.stderr || '').slice(0, 200));
  e.voice_id = model.id;
  e.gen = (e.gen || 0) + 1;
  e.check = { duration_s: +best.p.dur.toFixed(2), speech_db: +best.p.speech_db.toFixed(1), heard: best.heard, match: +best.score.toFixed(2), bytes: fs.statSync(dst).size };
  const words = norm(e.text).split(' ').length;
  if (!best.audible) e.status = 'failed';
  else if (best.score >= MATCH_OK || (words <= 2 && best.score >= 0.34)) e.status = 'validated';
  else e.status = 'generated';          // звук есть, распознавание расходится (сленг, имена) — слушать вручную
}

// ---------------------------------------------------------------- главное
(async () => {
  if (DOCS) return docs();
  const DH = (args.find(x => x.startsWith('--dehum=')) || '').slice(8);
  if (DH) {
    const man = loadJson(MANIFEST, { lines: [] });
    await connect();
    for (const e of man.lines) if (e.code === DH && ['generated', 'validated'].includes(e.status)) {
      const ms = dehum(e);
      if (ms < 0) { console.log(`VOICE ${e.id}: уже очищено (${e.check.dehum_ms} мс)`); continue; }
      if (!ms) { console.log(`VOICE ${e.id}: «хм» не найдено`); continue; }
      // распознать заново: первое слово должно остаться
      const dst = path.join(ROOT, 'godot', e.path.replace('res://', ''));
      const w = cp.spawnSync(ffmpeg(), ['-loglevel', 'error', '-i', dst, '-f', 'wav', '-ac', '1', '-ar', '24000', '-'], { maxBuffer: 1 << 28 });
      const tr = await tool('transcribe', { audio_base64: w.stdout.toString('base64'), language: 'ru' });
      const sc = similarity(e.text, tr.text || '');
      e.check.heard = tr.text || ''; e.check.match = +sc.toFixed(2);
      console.log(`VOICE ${e.id}: срезано «хм» ${ms} мс → «${(tr.text || '').slice(0, 50)}» (${sc.toFixed(2)})`);
    }
    save(man);
    return;
  }
  if (RETRIM) {
    const man = loadJson(MANIFEST, { lines: [] });
    let n = 0;
    for (const e of man.lines) if (['generated', 'validated'].includes(e.status)) { const c = retrim(e); if (c !== false) { n++; console.log(`VOICE переобрезан ${e.id}: срезано в начале ${c} мс, длина ${e.check.duration_s} с`); } }
    save(man);
    return console.log(`VOICE переобрезано файлов: ${n}`);
  }
  fs.mkdirSync(CH, { recursive: true });
  const exp = exportLines();
  const man = loadJson(MANIFEST, { chapter: 'golda67_ch01', note: 'Озвучка главы 1 «ГОЛДА 67». Собирает tools/golda67-voice.cjs, читает G67Voice.', lines: [] });
  const mg = merge(man, exp);
  console.log(`VOICE реплик главы 1: ${exp.lines.length} (уникальных ${man.lines.filter(e => e.status !== 'obsolete').length}); новых ${mg.added}, устарело ${mg.gone}`);
  let models = {};
  try { await connect(); const h = await tool('check_health', {}); console.log('VOICE Voice Studio Pro: ' + JSON.stringify(h)); models = await resolveModels(exp); }
  catch (e) { console.log('VOICE Voice Studio Pro недоступен: ' + e.message + ' — очередь сохранена, генерация в следующий запуск'); }
  for (const e of man.lines) {
    if (e.status === 'obsolete') continue;
    const m = models[e.code];
    if (Object.keys(models).length && !m) e.status = 'voice_model_missing';
    else if (m && e.voice_id && e.voice_id !== m.id && ['generated', 'validated'].includes(e.status)) e.status = 'pending';    // сменилась модель
    else if (e.status === 'voice_model_missing' && m) e.status = 'pending';
    else if (['generated', 'validated'].includes(e.status) && !fs.existsSync(path.join(ROOT, 'godot', e.path.replace('res://', '')))) e.status = 'pending';
    else if (e.status === 'generating') e.status = 'pending';
  }
  save(man);
  if (PLAN || !Object.keys(models).length) return report(man);
  const todo = man.lines.filter(e => (e.status === 'pending' || (RETRY && e.status === 'failed')) && (!ONLY || exp.speakers[e.code].tag === ONLY) && models[e.code]);
  console.log(`VOICE к генерации: ${todo.length}`);
  let i = 0;
  for (const e of todo) {
    i++;
    e.status = 'generating'; save(man);
    try {
      await produce(e, models[e.code]);
      console.log(`VOICE ${i}/${todo.length} ${e.id} ${e.status} ${e.check.duration_s}с «${e.text.slice(0, 50)}» → «${(e.check.heard || '').slice(0, 50)}» (${e.check.match})`);
    } catch (err) {
      e.status = 'failed'; e.check = { error: err.message.slice(0, 300) };
      console.log(`VOICE ${i}/${todo.length} ${e.id} ОШИБКА ${err.message.slice(0, 200)}`);
    }
    save(man);
  }
  report(man);
})().catch(e => { console.error('VOICE ОШИБКА', e.stack || e.message); process.exit(1); });

function report(man) {
  const c = {};
  for (const e of man.lines) c[e.status] = (c[e.status] || 0) + 1;
  console.log('VOICE итог: ' + JSON.stringify(c));
}

// ---------------------------------------------------------------- документы
function docs() {
  const man = loadJson(MANIFEST, { lines: [] });
  const models = loadJson(MODELS, { models: {} }).models;
  const L = man.lines.filter(e => e.status !== 'obsolete');
  const SCN = {
    krot_krot1: 'КРОТ, встреча 1 «ДРУЗЬЯ ИЗ FORBES» — ДВОР, очередь у «ШАУРМА 67»', krot_krot2: 'КРОТ, встреча 2 «ЛЮСТРА» — ПОДЪЕЗД',
    krot_krot3: 'КРОТ, встреча 3 «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО» — ДВОР, детская площадка',
    flurr_state0: 'DJ FLÜRR — знакомство (КРОТ ещё не встречен)', flurr_state1: 'DJ FLÜRR — после встречи 1', flurr_state2: 'DJ FLÜRR — после встречи 2',
    flurr_state3: 'DJ FLÜRR — после встречи 3', flurr_wait: 'DJ FLÜRR — короткие фразы до следующей встречи', flurr_intro_alt: 'DJ FLÜRR — связка знакомства, если КРОТ уже встречен',
    misha_intro: 'Миша Минасян — выход с трона', misha_phase2: 'Миша Минасян — фаза 2', misha_phase3: 'Миша Минасян — фаза 3',
  };
  const BARK = { bark_heat: 'HEAT [E]', bark_rage: 'ПЕРЕГРУЗ [R]', bark_parry: 'парирование', bark_hurt: 'получил удар', bark_finish: 'добивание' };
  const scene = s => SCN[s] || (s.startsWith('bark_') ? 'Боевые выкрики Пахана — ' + (BARK[s] || s) : s);
  const ST = { validated: 'проверена', generated: 'есть, послушать вручную', failed: 'ошибка', pending: 'в очереди', voice_model_missing: 'нет модели', generating: 'генерируется' };
  const st = e => ST[e.status] || e.status;
  const esc = t => String(t).replace(/\|/g, '\\|');
  const by = {};
  for (const e of L) (by[e.char_name] = by[e.char_name] || []).push(e);
  const cnt = k => L.filter(e => e.status === k).length;
  // 1. полный список
  let a = '# ГОЛДА 67 — озвучка главы 1: все реплики\n\n';
  a += 'Собрано из данных игры (`G67Voice.chapter1_lines()`, выгрузка `g67_voice_export.gd`); документ пересобирает\n`node tools/golda67-voice.cjs --docs`. Голос подбирается по строке «код|текст», ID реплики постоянный.\n\n';
  a += '## Границы главы 1\n\n';
  a += 'Глава 1 в нынешней игре — вход в режим «ГОЛДА 67» и подъезд (хаб) → забег по району ДВОР (шесть зон: у подъезда,\n';
  a += 'гаражи, детская площадка, парковка у «ШАУРМА 67», беседка, коробка) → босс Миша Минасян → возвращение в подъезд.\n';
  a += 'Отдельной сцены «конец главы» и перехода к следующей главе в игре пока нет: после Миши открывается Водяра и игрок\n';
  a += 'возвращается в подъезд. Вступительного ролика с репликами тоже нет — режим начинается прямо в подъезде.\n\n';
  a += 'Говорят в главе 1 четверо: Пахан, КРОТ, DJ FLÜRR, Миша Минасян. Жители двора, очередь, зрители и madk1d в главе 1\n';
  a += 'ничего не говорят (madk1d до первой концовки — житель подъезда, его выкрики в приквеле выключены).\n\n';
  a += '| Персонаж | Код в строке | Реплик |\n|---|---|---:|\n';
  for (const n of Object.keys(by)) a += `| ${n} | ${by[n][0].code} | ${by[n].length} |\n`;
  a += `| **Всего** | | **${L.length}** |\n\n`;
  const scenes = [...new Set(L.map(e => e.scene))];
  for (const sc of scenes) {
    const rows = L.filter(e => e.scene === sc).sort((x, y) => x.order - y.order);
    a += `## ${scene(sc)}\n\nКогда звучит: ${rows[0].when}.\n\n| № | ID | Кто | Реплика | Подача | Файл | Статус |\n|---:|---|---|---|---|---|---|\n`;
    for (const e of rows) a += `| ${e.order + 1} | ${e.id} | ${e.char_name} | ${esc(e.text)} | ${e.emotion}${e.speed !== 1 ? ', темп ' + e.speed : ''} | \`${e.path.replace(RES, '')}\` | ${st(e)} |\n`;
    a += '\n';
  }
  fs.writeFileSync(path.join(DOCDIR, 'VOICE_ACTING_CHAPTER_1.md'), a);
  // 2. модели
  let b = '# ГОЛДА 67 — голосовые модели для главы 1\n\n';
  b += 'Модели создаёт владелец в Voice Studio Pro. Инструмент их только находит (по ID из\n`godot/Audio/Voice/Golda67/Chapter_01/voice_models.json` или по имени модели) и ничего в них не меняет.\n\n';
  b += '| Персонаж | Реплик | Модель Voice Studio Pro | ID | Статус |\n|---|---:|---|---|---|\n';
  for (const code of Object.keys(models)) {
    const m = models[code], n = L.filter(e => e.code === code).length;
    b += `| ${m.character} | ${n} | ${m.voice_name || '—'} | ${m.id || '—'} | ${m.status === 'found' ? 'есть' : '**нужно создать**'} |\n`;
  }
  const miss = Object.values(models).filter(m => m.status !== 'found');
  b += '\n' + (miss.length ? 'Ещё нужно создать: ' + miss.map(m => m.character).join(', ') + '.' : '**Все модели для главы 1 уже есть — создавать ничего не нужно.**') + '\n\n';
  b += 'madk1d в главе 1 не говорит: для него оставлен голос из игры, новая модель не нужна.\n';
  fs.writeFileSync(path.join(DOCDIR, 'VOICE_MODELS_REQUIRED.md'), b);
  // 3. отчёт
  const fails = L.filter(e => e.status === 'failed'), listen = L.filter(e => e.status === 'generated');
  let c = '# ГОЛДА 67 — отчёт по озвучке главы 1\n\n## Персонажи и модели\n\n';
  c += '| Персонаж | Модель | ID | Реплик | Проверено | Послушать вручную | Ошибок |\n|---|---|---|---:|---:|---:|---:|\n';
  for (const code of Object.keys(models)) {
    const m = models[code], r = L.filter(e => e.code === code);
    c += `| ${m.character} | ${m.voice_name || '—'} | ${m.id || '—'} | ${r.length} | ${r.filter(e => e.status === 'validated').length} | ${r.filter(e => e.status === 'generated').length} | ${r.filter(e => e.status === 'failed').length} |\n`;
  }
  c += '\n## Реплики\n\n';
  c += `- найдено: **${L.length}**\n- сгенерировано: **${cnt('validated') + cnt('generated')}**\n- проверено обратным распознаванием: **${cnt('validated')}**\n`;
  c += `- звук есть, но распознанный текст расходится — послушать: **${cnt('generated')}**\n`;
  c += `- подключено к игре: **${cnt('validated') + cnt('generated')}** (все сгенерированные; играют через манифест)\n`;
  c += `- ждут голосовую модель: **${cnt('voice_model_missing')}**\n- ошибкой: **${cnt('failed')}**\n\n`;
  if (listen.length) {
    c += '### Послушать вручную\n\n| ID | Реплика | Распознано | Сходство |\n|---|---|---|---:|\n';
    for (const e of listen) c += `| ${e.id} | ${esc(e.text)} | ${esc(e.check.heard || '')} | ${e.check.match} |\n`;
    c += '\n';
  }
  if (fails.length) {
    c += '### Ошибки\n\n| ID | Реплика | Причина |\n|---|---|---|\n';
    for (const e of fails) c += `| ${e.id} | ${esc(e.text)} | ${esc((e.check && (e.check.error || 'нет речи')) || '')} |\n`;
    c += '\n';
  }
  c += '## Как это устроено\n\n';
  c += '- **Список реплик** — `G67Voice.chapter1_lines()` (`godot/scripts/golda67/g67_voice.gd`) берёт реплики из тех же данных, что играет игра:\n';
  c += '  встречи КРОТА главы 1 (`G67Data.KROT`), состояния DJ FLÜRR 0–3, короткие фразы ожидания и связку знакомства (`G67Flurr`,\n';
  c += '  `G67Data.FLURR_BRIDGE`), выход и смены фаз Миши (`G67Data.BOSS_INTRO`, `BOSSES.g67_misha.barks`) и боевые выкрики Пахана,\n';
  c += '  которые звучат в приквеле (`data/barks.json`: heat, rage, parry, hurt, finish).\n';
  c += '- **Манифест** — `godot/Audio/Voice/Golda67/Chapter_01/manifest.json`: ID, персонаж, модель, текст, путь к .ogg, статус (`pending`,\n';
  c += '  `voice_model_missing`, `generating`, `generated`, `validated`, `failed`, `obsolete`), результат проверки, номер генерации.\n';
  c += '- **Генерация** — `node tools/golda67-voice.cjs`: выгружает реплики, дописывает новые в очередь, генерирует только недостающие через\n';
  c += '  MCP Voice Studio Pro (адрес — из настроек приложения), обрезает тишину по краям, выравнивает громкость (речь −20 dBFS, пик не\n';
  c += '  выше −1 dBFS), кодирует в OGG Vorbis (ffmpeg из Voice Studio), проверяет обратным распознаванием (`transcribe`) и до двух раз\n';
  c += '  повторяет неудачные. Временные WAV — во временной папке системы, в проект не попадают. Повторный запуск готового не трогает;\n';
  c += '  изменился текст — генерируется только эта реплика; сменилась модель персонажа — только его реплики.\n';
  c += '  `--retry` — заново только ошибки, `--only=KROT` — один персонаж, `--plan` — только очередь, `--docs` — эти документы.\n';
  c += '- **В игре** — `game._voice_path`: в приквеле сначала спрашивает `G67Voice.path("КОД|текст")`; звучат только реплики generated /\n';
  c += '  validated с файлом на месте, иначе — прежний путь (голос кампании или текст без голоса). Остальное — прежняя система диалога:\n';
  c += '  реплику обрывает следующая (`_dlg_advance`), пропуск на Tab и закрытие (`_dlg_finish`) глушат голос, на паузе звук стоит,\n';
  c += '  выкрики не накладываются (`_speaking` / `_hush`). Нет файла — в отладочной сборке печатается «VOICE G67 <ID> …: голоса нет».\n';
  c += '- **Новая реплика главы 1** — добавить её в данные игры, затем `node tools/golda67-voice.cjs` и `--docs`.\n\n';
  c += '## Что сознательно не входило\n\n';
  c += '- Встречи КРОТА 4–10, состояния DJ FLÜRR 4–10 и фразы «после всех встреч» — следующие главы.\n';
  c += '- Сцены конца главы и перехода к следующей в игре пока нет — озвучивать нечего.\n';
  c += '- madk1d в главе 1 не говорит; его голос из игры не менялся. Голос кампании не менялся тоже: выкрики Пахана в приквеле\n';
  c += '  играют из папки главы 1, в кампании — прежние.\n';
  c += '- Подача: в Voice Studio Pro параметр `instruct` задаёт пол, возраст и высоту голоса, а не эмоцию, — для клонированной модели он\n';
  c += '  сбил бы тембр. Эмоция задаётся темпом и знаками препинания самого сценария; текст не менялся.\n';
  c += '- Распознавание иногда ошибается на сленге и именах (Forbes, FLÜRR, рилсы) — такие реплики помечены «послушать вручную»,\n';
  c += '  текст не правился.\n';
  fs.writeFileSync(path.join(DOCDIR, 'VOICE_ACTING_CHAPTER_1_REPORT.md'), c);
  console.log('VOICE документы обновлены');
}
