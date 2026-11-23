#!/usr/bin/env node
// Sketchfab: поиск и загрузка ассетов (только CC0 и CC-BY) для «ГОЛДА 67».
//   node tools/sketchfab-get.cjs --search "<запрос>" [--count 24]
//   node tools/sketchfab-get.cjs --get <uid> --as <наше_имя> [--changed "что изменено"]
//   node tools/sketchfab-get.cjs --credits
// Токен — SKETCHFAB_TOKEN в .env (в git не идёт, нигде не печатается). Лицензия проверяется по ответу API на саму модель.
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');

const ROOT = path.join(__dirname, '..');
const ASSETS = path.join(ROOT, 'godot', 'assets', 'golda67');
const SRC = path.join(ASSETS, 'blender_source', 'sketchfab_src');
const CREDITS_JSON = path.join(ASSETS, 'CREDITS_SKETCHFAB.json');
const CREDITS_MD = path.join(ROOT, 'godot', 'docs', 'CREDITS_SKETCHFAB.md');
const THUMBS = path.join(process.env.TEMP || os.tmpdir(), 'sf_thumbs');
const CACHE = path.join(process.env.TEMP || os.tmpdir(), 'sf_cache');
const ALLOWED = { cc0: 'CC0 1.0', by: 'CC Attribution (CC-BY)' };

function token() {
  if (process.env.SKETCHFAB_TOKEN) return process.env.SKETCHFAB_TOKEN;
  const env = fs.readFileSync(path.join(ROOT, '.env'), 'utf8');
  const m = env.match(/^SKETCHFAB_TOKEN=(.+)$/m);
  if (!m) throw new Error('SKETCHFAB_TOKEN не найден в .env');
  return m[1].trim().replace(/^["']|["']$/g, '');
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(url, auth = true) {
  fs.mkdirSync(CACHE, { recursive: true });
  const key = path.join(CACHE, Buffer.from(url).toString('base64').replace(/[\/+=]/g, '_').slice(0, 150) + '.json');
  if (!auth || !url.includes('/download')) {
    if (fs.existsSync(key) && Date.now() - fs.statSync(key).mtimeMs < 6 * 3600 * 1000) return JSON.parse(fs.readFileSync(key, 'utf8'));
  }
  for (let attempt = 0; attempt < 6; attempt++) {
    const r = await fetch(url, { headers: auth ? { Authorization: 'Token ' + token() } : {} });
    if (r.status === 429) {
      const wait = Number(r.headers.get('retry-after') || 5) * 1000;
      console.error('429 — пауза', wait / 1000, 'с');
      await sleep(wait);
      continue;
    }
    if (!r.ok) throw new Error('HTTP ' + r.status + ' ' + url.split('?')[0]);
    const j = await r.json();
    if (!url.includes('/download')) fs.writeFileSync(key, JSON.stringify(j));
    return j;
  }
  throw new Error('слишком много 429');
}

async function download(url, dest) {
  const r = await fetch(url);
  if (!r.ok) throw new Error('загрузка не удалась: HTTP ' + r.status);
  fs.writeFileSync(dest, Buffer.from(await r.arrayBuffer()));
}

function args() {
  const a = process.argv.slice(2);
  const o = {};
  for (let i = 0; i < a.length; i++) {
    if (a[i].startsWith('--')) {
      const k = a[i].slice(2);
      o[k] = a[i + 1] && !a[i + 1].startsWith('--') ? a[++i] : true;
    }
  }
  return o;
}

async function search(q, count, maxfaces, sheet) {
  fs.mkdirSync(THUMBS, { recursive: true });
  const rows = [];
  let url = 'https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=' + encodeURIComponent(q) + '&count=' + Math.min(24, count);
  while (url && rows.length < count) {
    const j = await api(url);
    for (const m of j.results || []) rows.push(m);
    url = j.next && rows.length < count ? j.next : null;
  }
  console.log('# | uid | имя | автор | лицензия | граней');
  let idx = 0;
  const sel = [];
  for (const m of rows.slice(0, count)) {
    const lab = (m.license && (m.license.slug || m.license.label)) || '?'; const lic = m.license && m.license.slug ? m.license.slug : (lab === 'CC Attribution' ? 'by' : (/^CC0/.test(lab) ? 'cc0' : lab));
    const ok = ALLOWED[lic] ? '' : ' [ОТКАЗ: лицензия]';
    if (ok || (maxfaces && m.faceCount > maxfaces)) continue;
    idx++;
    sel.push(m.uid + ':' + idx + ' ' + String(m.name).slice(0, 22) + ' ' + Math.round(m.faceCount / 100) / 10 + 'k');
    console.log([idx, m.uid, m.name, m.user && m.user.displayName, lic, m.faceCount].join(' | '));
    const th = (m.thumbnails && m.thumbnails.images || []).slice().sort((a, b) => Math.abs(a.width - 400) - Math.abs(b.width - 400))[0];
    const dest = path.join(THUMBS, m.uid + '.jpg');
    if (th && !fs.existsSync(dest)) { try { await download(th.url, dest); } catch (e) { /* превью необязательно */ } }
  }
  console.log('превью:', THUMBS);
  if (sheet && sel.length) {
    const out = path.join(process.env.TEMP || os.tmpdir(), 'sf_sheet_' + String(q).replace(/[^a-z0-9]+/gi, '_') + '.png');
    cp.execFileSync('python', [path.join(__dirname, 'sf_sheet.py'), out].concat(sel.slice(0, 12)));
  }
}

function loadCredits() {
  return fs.existsSync(CREDITS_JSON) ? JSON.parse(fs.readFileSync(CREDITS_JSON, 'utf8')) : [];
}

async function get(uid, as, changed) {
  const m = await api('https://api.sketchfab.com/v3/models/' + uid);
  const slug = m.license && m.license.slug;
  if (!ALLOWED[slug]) {
    console.error('ОТКАЗ: лицензия модели «' + (m.license && (m.license.label || m.license.slug)) + '» не подходит (разрешены только CC0 и CC-BY): ' + m.viewerUrl);
    process.exit(2);
  }
  const d = await api('https://api.sketchfab.com/v3/models/' + uid + '/download');
  const dir = path.join(SRC, as);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(SRC, '.gdignore'), '');
  let file;
  if (d.glb && d.glb.url) {
    file = path.join(dir, as + '.glb');
    await download(d.glb.url, file);
  } else if (d.gltf && d.gltf.url) {
    const zip = path.join(dir, 'download.zip');
    await download(d.gltf.url, zip);
    cp.execFileSync('tar', ['-xf', zip, '-C', dir]);
    fs.unlinkSync(zip);
    file = path.join(dir, 'scene.gltf');
  } else throw new Error('нет glb/gltf в ответе download');
  const credits = loadCredits().filter((c) => c.as !== as);
  credits.push({
    as, uid, title: m.name, author: m.user && m.user.displayName, author_url: m.user && m.user.profileUrl, url: m.viewerUrl,
    license: ALLOWED[slug], license_slug: slug, license_url: m.license.url, faces: m.faceCount, date: new Date().toISOString().slice(0, 10),
    changed: typeof changed === 'string' ? changed : 'масштаб, упрощение сетки, слияние частей, текстуры уменьшены',
  });
  fs.writeFileSync(CREDITS_JSON, JSON.stringify(credits, null, 1));
  console.log('готово:', file, '|', m.name, '|', ALLOWED[slug], '| граней', m.faceCount);
  writeCredits();
}

function writeCredits() {
  const c = loadCredits().sort((a, b) => a.as.localeCompare(b.as));
  let s = '# Ассеты Sketchfab в «ГОЛДА 67»\n\nМодели скачаны с Sketchfab под лицензиями CC0 и CC Attribution (CC-BY) и изменены под игру (масштаб, упрощение, слияние сеток, текстуры). Авторство указано по условиям CC-BY. Таблица собирается `node tools/sketchfab-get.cjs --credits` из `godot/assets/golda67/CREDITS_SKETCHFAB.json`.\n\n| В игре | Оригинал | Автор | Лицензия | Что изменено |\n|---|---|---|---|---|\n';
  for (const x of c) s += '| `' + x.as + '` | [' + x.title + '](' + x.url + ') | [' + x.author + '](' + x.author_url + ') | ' + (x.license_url ? '[' + x.license + '](' + x.license_url + ')' : x.license) + ' | ' + x.changed + ' |\n';
  fs.mkdirSync(path.dirname(CREDITS_MD), { recursive: true });
  fs.writeFileSync(CREDITS_MD, s);
  console.log('записано', CREDITS_MD, '(' + c.length + ' моделей)');
}

(async () => {
  const o = args();
  if (o.search) await search(String(o.search), Number(o.count || 24), Number(o.maxfaces || 0), !!o.sheet);
  else if (o.get) { if (!o.as) throw new Error('--get требует --as <имя>'); await get(String(o.get), String(o.as), o.changed); }
  else if (o.credits) writeCredits();
  else console.log('см. шапку файла');
})().catch((e) => { console.error('ОШИБКА:', e.message); process.exit(1); });
