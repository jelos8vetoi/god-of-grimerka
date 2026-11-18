// Генерация 3D-моделей окружения через Tripo AI (официальный API v3, аккаунт владельца проекта).
//   node tools/tripo-gen.cjs [--dry] [имя…]
// Ключ — только из переменной окружения TRIPO_API_KEY или из файла .env в корне репозитория (.env в git не идёт).
// Список моделей и промпты — tools/tripo-models.json (общий стиль — поле "style", добавляется к каждому промпту).
// Готовые модели сохраняются сразу после генерации в godot/assets/racing/<имя>.glb, описание — в manifest.json рядом.
// Уже скачанные модели не генерируются повторно. Перед запуском печатается стоимость и остаток кредитов;
// если после генерации останется меньше "reserve" кредитов — отказ (кредиты не докупаются).
const fs = require('fs'), path = require('path'), https = require('https');
const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'godot', 'assets', 'racing');
const CFG = JSON.parse(fs.readFileSync(path.join(__dirname, 'tripo-models.json'), 'utf8'));
const API = 'https://api.tripo3d.ai';            // баланс — /v2/openapi/user/balance
const V3 = 'https://openapi.tripo3d.ai/v3';      // генерация и задачи

function key() {
  if (process.env.TRIPO_API_KEY) return process.env.TRIPO_API_KEY.trim();
  const env = path.join(ROOT, '.env');
  if (fs.existsSync(env)) {
    const m = fs.readFileSync(env, 'utf8').match(/^\s*TRIPO_API_KEY\s*=\s*(.+)\s*$/m);
    if (m) return m[1].trim();
  }
  console.error('Нет ключа: задай TRIPO_API_KEY в окружении или в .env (в git не попадает).');
  process.exit(1);
}
const KEY = key();

function req(method, url, body) {
  return new Promise((ok, fail) => {
    const u = new URL(url);
    const data = body ? JSON.stringify(body) : null;
    const r = https.request({ method, hostname: u.hostname, path: u.pathname + u.search, headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json', ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}) } }, res => {
      let s = ''; res.on('data', c => s += c); res.on('end', () => { try { ok({ status: res.statusCode, json: JSON.parse(s), headers: res.headers }); } catch (e) { ok({ status: res.statusCode, json: null, text: s }); } });
    });
    r.on('error', fail); r.setTimeout(60000, () => r.destroy(new Error('timeout')));
    if (data) r.write(data); r.end();
  });
}
function download(url, file) {
  return new Promise((ok, fail) => {
    https.get(url, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) return download(res.headers.location, file).then(ok, fail);
      if (res.statusCode !== 200) return fail(new Error('HTTP ' + res.statusCode));
      const tmp = file + '.part'; const w = fs.createWriteStream(tmp);
      res.pipe(w); w.on('finish', () => { w.close(() => { fs.renameSync(tmp, file); ok(); }); }); w.on('error', fail);
    }).on('error', fail);
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function balance() {
  const r = await req('GET', API + '/v2/openapi/user/balance');
  if (!r.json || r.json.code !== 0) throw new Error('баланс не получен: ' + JSON.stringify(r.json || r.text).slice(0, 200));
  return r.json.data.balance;
}

async function make(m) {
  const body = { prompt: (m.prompt + ' ' + CFG.style).slice(0, 1024), negative_prompt: CFG.negative.slice(0, 255), model: CFG.model,
    texture: true, pbr: true, texture_quality: CFG.texture_quality, smart_low_poly: true, face_limit: m.faces || CFG.faces, auto_size: true };
  let r;
  for (let a = 0; a < 6; a++) {
    r = await req('POST', V3 + '/generation/text-to-model', body);
    if (r.status === 429) { await sleep(5000 * (a + 1)); continue; }
    break;
  }
  if (!r.json || r.json.code !== 0) throw new Error('задача не создана: ' + JSON.stringify(r.json || r.text).slice(0, 300));
  const id = r.json.data.task_id;
  console.log(`  ${m.id}: задача ${id}`);
  const t0 = Date.now();
  while (Date.now() - t0 < 20 * 60000) {
    await sleep(3000);
    const q = await req('GET', V3 + '/tasks/' + id);
    const d = q.json && q.json.data;
    if (!d) continue;
    if (d.status === 'success') {
      const url = d.output && (d.output.pbr_model_url || d.output.model_url || d.output.model);
      if (!url) throw new Error('нет ссылки на модель: ' + JSON.stringify(d.output).slice(0, 300));
      const file = path.join(OUT, m.id + '.glb');
      await download(url, file);
      if (d.output.rendered_image_url) { try { await download(d.output.rendered_image_url, path.join(OUT, 'preview', m.id + '.webp')); } catch (e) {} }
      return { id: m.id, task: id, credits: d.credits_consumed, bytes: fs.statSync(file).size };
    }
    if (['failed', 'cancelled', 'banned', 'expired'].includes(d.status)) throw new Error(`задача ${d.status}: ${d.error_code || ''} ${d.error_message || ''}`);
  }
  throw new Error('задача не закончилась за 20 минут');
}

(async () => {
  fs.mkdirSync(path.join(OUT, 'preview'), { recursive: true });
  const args = process.argv.slice(2), dry = args.includes('--dry'), only = args.filter(a => !a.startsWith('--'));
  const manPath = path.join(OUT, 'manifest.json');
  const man = fs.existsSync(manPath) ? JSON.parse(fs.readFileSync(manPath, 'utf8')) : { style: CFG.style, models: {} };
  const todo = CFG.models.filter(m => (!only.length || only.includes(m.id)) && !fs.existsSync(path.join(OUT, m.id + '.glb')));
  const cost = todo.length * CFG.cost_each;
  const bal = await balance();
  console.log(`Tripo: остаток ${bal} кредитов; к генерации ${todo.length} моделей ≈ ${cost} кредитов (по ${CFG.cost_each}); запас ${CFG.reserve}`);
  if (dry || !todo.length) return;
  if (bal - cost < CFG.reserve) { console.error(`Отказ: после генерации осталось бы ${bal - cost} < запаса ${CFG.reserve}. Кредиты не докупаются — сократи список.`); process.exit(2); }
  const queue = todo.slice(); let spent = 0, done = 0;
  async function worker() {
    while (queue.length) {
      const m = queue.shift();
      try {
        const r = await make(m);
        spent += r.credits || CFG.cost_each; done++;
        man.models[m.id] = { prompt: m.prompt, size: m.size, task: r.task, credits: r.credits, bytes: r.bytes, model: CFG.model, date: new Date().toISOString().slice(0, 10) };
        fs.writeFileSync(manPath, JSON.stringify(man, null, 2));
        console.log(`✓ ${m.id}: ${(r.bytes / 1048576).toFixed(1)} МБ, ${r.credits} кредитов`);
      } catch (e) { console.log(`✗ ${m.id}: ${e.message}`); }
    }
  }
  await Promise.all(Array.from({ length: CFG.concurrency }, worker));
  console.log(`Готово: ${done} из ${todo.length}, потрачено ≈ ${spent}; остаток ${await balance()}`);
})().catch(e => { console.error(e.message); process.exit(1); });
