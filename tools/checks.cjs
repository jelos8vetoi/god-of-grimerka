#!/usr/bin/env node
// Быстрый прогон проверок Godot: параллельно и в ускоренном времени.
//
//   node tools/checks.cjs [имена или группы…] [--jobs=N] [--real] [--out=<папка>] [--list]
//
//   node tools/checks.cjs                    — все проверки
//   node tools/checks.cjs combat             — бой и стили (после правок боя — обязательно все)
//   node tools/checks.cjs modes              — меню, гонки, мини-игры, вёрстка
//   node tools/checks.cjs race microloans    — выборочно (имя = ключ без «check»: race, microloans, five-nights…)
//
// Что ускоряет:
//   * игровое время отвязано от настоящего: --fixed-fps 60 --disable-vsync, проверка видит обычные кадры по 1/60 с,
//     но кадр рисуется так быстро, как может видеокарта (обычно в 4–10 раз быстрее настоящего времени). Ожидания
//     в проверках идут по игровым часам (GameClock.ms()), поэтому смысл «подождать 3 секунды» не меняется;
//   * проверки идут параллельно (--jobs, по умолчанию 6). Раньше параллельно было нельзя: ожидания шли по настоящим
//     часам и «плыли» от нагрузки. Теперь у каждой проверки свой кадр и своё время — нагрузка на итог не влияет;
//   * у каждой проверки своя папка данных (переменная APPDATA → %TEMP%\grimerka-checks\<имя>): проверки не делят
//     сохранения друг с другом и не трогают настоящие сохранения игрока; кэш шейдеров там же сохраняется между
//     прогонами.
// В настоящем времени (fast: false) остаются: звук (пики шин — живое аудио), сеть (таймауты и задержки — настоящие),
// iPod (поток звука «без замираний»). Ключ --real гонит всё в настоящем времени и по одной — как раньше.
//
// Итог: таблица (проверка, результат, пунктов ok, время, ускорение), логи — <папка>/<имя>.log, снимки — <папка>/<имя>/.
// Код выхода 1, если хоть одна проверка не прошла. Godot завершается с кодом 0 даже при ошибках скрипта, поэтому
// результат читается из лога: строка «<ИМЯ> ok» / итог без ошибок, и ни одной «SCRIPT ERROR» или «ОШИБКА».

const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const G = process.env.GODOT_BIN || [
  path.join(ROOT, 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'),
  path.join(ROOT, '../GOD OF CLOUD/tools/godot/Godot_v4.7.2-stable_win64_console.exe'),
].find((p) => fs.existsSync(p));

// name — имя для командной строки; key — ключ проверки (-- --<key>=<папка>); res — размер окна; fps — частота
// ускоренного кадра (у боевого ядра 30 — под него подобраны тайминги); fast — можно ли ускорять; ok — признак успеха;
// extra — свои ключи; t — таймаут, с (настоящих); script — запуск скрипта без игры
const C = [
  // ---- бой и анимации
  { name: 'combat', key: 'combatcheck', fps: 30, ok: /COMBAT итог: ошибок 0/, groups: ['combat'] },
  { name: 'flow', key: 'flowcheck', ok: /FLOWCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'tag', key: 'tagcheck', ok: /TAGCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'exec', key: 'execcheck', ok: /EXECCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'hype', key: 'hypecheck', ok: /HYPECHECK ok\s*$/m, groups: ['combat'] },
  { name: 'base', key: 'basecheck', ok: /BASECHECK ok\s*$/m, groups: ['combat'] },
  { name: 'bottle', key: 'bottlecheck', ok: /BOTTLECHECK ok\s*$/m, groups: ['combat'] },
  { name: 'tyaga', key: 'tyagacheck', ok: /TYAGACHECK ok\s*$/m, groups: ['combat'] },
  { name: 'madk', key: 'madkcheck', ok: /MADKCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'duo', key: 'duocheck', ok: /DUOCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'hud', key: 'hudcheck', ok: /HUDCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'lock', key: 'lockcheck', ok: /LOCKCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'movement', key: 'movementcheck', ok: /MOVEMENTCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'damage', key: 'damagecheck', ok: /DAMAGECHECK ok\s*$/m, groups: ['combat'] },
  { name: 'ai', key: 'aicheck', ok: /AICHECK ok\s*$/m, groups: ['combat'] },
  { name: 'vfx', key: 'vfxcheck', ok: /VFXCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'tutorial', key: 'tutorialcheck', ok: /TUTORIALCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'anim', key: 'animcheck', extra: ['--noshots'], ok: /ANIMCHECK ok\s*$/m, groups: ['combat'] },
  { name: 'animaudit', script: 'res://scripts/animaudit.gd', ok: /AUDIT/, groups: ['combat'] },
  // ---- меню, режимы, мини-игры
  { name: 'mode', key: 'modecheck', ok: /MODECHECK ok\s*$/m, groups: ['modes'] },
  { name: 'training', key: 'trainingcheck', ok: /TRAININGCHECK ok\s*$/m, groups: ['modes'] },
  { name: 'golda67', key: 'golda67check', ok: /GOLDA67CHECK ok\s*$/m, groups: ['modes', 'golda67'] },
  { name: 'podzemka', key: 'golda67check', extra: ['--g67-pz'], ok: /GOLDA67CHECK oks*$/m, groups: ['golda67'], t: 900 },
  { name: 'survival', key: 'playtest-survival', ok: /SURVIVALPLAY ok\s*$/m, groups: ['modes', 'survival'], t: 1500 },
  // Endless Survival и Balance Lab: плейтест клавишами (выше), тесты логики без окна, стенд баланса.
  // root — тесту нужна своя папка данных игрока (пишет настоящее сохранение кампании в неё); uargs — ключи после «--»
  ...['director', 'encounters', 'defeat', 'hud', 'telemetry', 'upgrades'].map((n) => (
    { name: 'sv-' + n, script: `res://tests/survival_${n}_test.gd`, ok: /\b0 failures\s*$/m, groups: ['modes', 'survival'] })),
  { name: 'balance-int', script: 'res://tests/balance_integration_test.gd', root: true, ok: /integration: 0 failures\s*$/m, groups: ['modes', 'survival', 'balance'] },
  { name: 'balance-panel', script: 'res://tests/balance_integration_test.gd', root: true, uargs: ['--balance-lab'], ok: /export: 0 failures\s*$/m, groups: ['modes', 'survival', 'balance'] },
  { name: 'balance-lab', key: 'balance-lab-check', headless: true, ok: /Balance Lab: \d+ samples, \d+ scenario/, groups: ['survival', 'balance'], t: 900 },
  { name: 'trans', key: 'transcheck', ok: /TRANS итог: ошибок 0/, groups: ['modes'] },
  { name: 'death', key: 'deathcheck', ok: /DEATH итог: ошибок 0/, groups: ['modes'] },
  { name: 'race', key: 'racecheck', ok: /RACECHECK ok\s*$/m, groups: ['modes', 'race'] },
  { name: 'weather', key: 'weathercheck', ok: /WEATHERCHECK ok\s*$/m, groups: ['modes', 'race'] },
  { name: 'microloans', key: 'microloanscheck', ok: /MICROLOANSCHECK ok\s*$/m, groups: ['modes', 'ml'] },
  { name: 'abuse', script: 'res://scripts/microloans/ml_abuse_run.gd', ok: /ABUSE итог: ошибок 0/, groups: ['modes', 'ml'] },
  { name: 'five-nights', key: 'fivenightscheck', fast: false, ok: /FIVENIGHTSCHECK ok\s*$/m, groups: ['modes', 'fn'] },
  { name: 'ui', key: 'uicheck', res: '1600x900', ok: /UICHECK ok\s*$/m, groups: ['modes', 'ui'], t: 1500 },
  { name: 'uiqa', key: 'uiqa', ok: /UIQA итог: ошибок 0/, groups: ['modes', 'ui'] },
  // ---- в настоящем времени
  { name: 'sound', key: 'soundcheck', fast: false, ok: /SOUNDCHECK ok\s*$/m, groups: ['modes', 'real'] },
  { name: 'net', key: 'race-netcheck', fast: false, ok: /NETCHECK ok\s*$/m, groups: ['race', 'real'], t: 1500 },
  { name: 'ipod', key: 'ipodcheck', fast: false, ok: /IPOD итог: ошибок 0/, groups: ['real'] },
];

const args = process.argv.slice(2);
const opt = Object.fromEntries(args.filter((a) => a.startsWith('--')).map((a) => { const [k, v] = a.slice(2).split('='); return [k, v ?? true]; }));
const want = args.filter((a) => !a.startsWith('--'));
if (opt.list) {
  for (const c of C) console.log(`${c.name.padEnd(12)} ${(c.groups || []).join(', ').padEnd(16)} ${c.fast === false ? 'настоящее время' : 'ускоренно'}`);
  process.exit(0);
}
if (!G) { console.error('Нет Godot: положи бинарник в tools/godot/ или задай GODOT_BIN'); process.exit(2); }
const real = !!opt.real;
const jobs = real ? 1 : Math.max(1, parseInt(opt.jobs || '6', 10));
const pick = want.length === 0 || want.includes('all') ? C : C.filter((c) => want.includes(c.name) || (c.groups || []).some((g) => want.includes(g)));
if (pick.length === 0) { console.error('Ничего не выбрано. Список: node tools/checks.cjs --list'); process.exit(2); }
const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const OUT = path.resolve(opt.out || path.join(os.tmpdir(), 'grimerka-checks', 'run-' + stamp));
fs.mkdirSync(OUT, { recursive: true });
const DATA = path.join(os.tmpdir(), 'grimerka-checks', 'appdata');
// Данные игрока (сохранения, настройки экрана, звука, iPod) копируются в папку проверки перед каждым запуском:
// проверки рассчитаны на «как у игрока» (есть сохранение, свои громкости) и работают с копией, а оригинал не трогают.
// Кэши шейдеров (vulkan, shader_cache) копируются один раз и дальше остаются свои — прогрев не повторяется.
const USER = process.env.APPDATA ? path.join(process.env.APPDATA, 'Godot', 'app_userdata', 'GOD OF GRIMERKA') : '';
function seed(appdata) {
  const dst = path.join(appdata, 'Godot', 'app_userdata', 'GOD OF GRIMERKA');
  fs.mkdirSync(dst, { recursive: true });
  if (!USER || !fs.existsSync(USER)) return;
  for (const f of fs.readdirSync(USER)) {
    const from = path.join(USER, f);
    const to = path.join(dst, f);
    const dir = fs.statSync(from).isDirectory();
    if (f === 'logs' || /\.png$|_verts\.txt$/.test(f)) continue;
    if ((f === 'vulkan' || f === 'shader_cache') && fs.existsSync(to)) continue;
    fs.rmSync(to, { recursive: true, force: true });
    fs.cpSync(from, to, { recursive: dir });
  }
}

function run(c) {
  return new Promise((resolve) => {
    const fast = !real && c.fast !== false;
    const fps = c.fps || 60;
    const shots = path.join(OUT, c.name);
    fs.mkdirSync(shots, { recursive: true });
    let a;
    if (c.script) {
      a = ['--headless', '--path', 'godot', '--script', c.script];
      if (c.uargs) a.push('--', ...c.uargs);
    } else if (c.headless) {
      // стенд баланса: без окна, шаг строго 1/60 с — так его замеры повторяются
      a = ['--headless', '--disable-render-loop', '--fixed-fps', '60', '--path', 'godot', '--', `--${c.key}=${shots}`];
    } else {
      a = ['--path', 'godot', '--resolution', c.res || '1280x720'];
      if (fast) a.push('--fixed-fps', String(fps), '--disable-vsync');
      else if (c.fps) a.push('--fixed-fps', String(fps));
      a.push('--', `--${c.key}=${shots}`, ...(c.extra || []));
      if (fast) a.push(`--clock=${fps}`);
    }
    const appdata = path.join(DATA, c.name);
    seed(appdata);
    const log = fs.createWriteStream(path.join(OUT, c.name + '.log'));
    const t0 = Date.now();
    const env = { ...process.env, APPDATA: appdata };
    if (c.root) env.GRIMERKA_LAB_TEST_ROOT = appdata.split(path.sep).join('/');
    const p = spawn(G, a, { cwd: ROOT, env });
    let text = '';
    const eat = (d) => { text += d; log.write(d); };
    p.stdout.on('data', eat);
    p.stderr.on('data', eat);
    const limit = (c.t || 1200) * 1000;
    const timer = setTimeout(() => { text += '\nCHECKS: таймаут\n'; p.kill(); }, limit);
    p.on('close', () => {
      clearTimeout(timer);
      log.end();
      const sec = (Date.now() - t0) / 1000;
      const errs = (text.match(/SCRIPT ERROR/g) || []).length;
      const fails = text.split('\n').filter((l) => /ОШИБКА/.test(l) && !/ошибок 0/.test(l));
      const oks = (text.match(/ ok[:\s]/g) || []).length;
      const gm = text.match(/GAMECLOCK игра ([\d.]+) с/);
      const game = gm ? parseFloat(gm[1]) : null;
      const pass = c.ok.test(text) && errs === 0 && fails.length === 0 && !/CHECKS: таймаут/.test(text);
      resolve({ c, pass, sec, game, errs, fails, oks, fast });
    });
  });
}

(async () => {
  console.log(`Проверок: ${pick.length}, параллельно: ${jobs}, ${real ? 'настоящее время' : 'ускоренно'} · логи и снимки: ${OUT}`);
  const t0 = Date.now();
  // долгие — первыми (длительности с прошлых прогонов — times.json рядом с папками данных): так хвост из одной
  // длинной проверки не тянется в конце, пока остальные потоки простаивают
  const TIMES = path.join(os.tmpdir(), 'grimerka-checks', 'times.json');
  let times = {};
  try { times = JSON.parse(fs.readFileSync(TIMES, 'utf8')); } catch (e) { /* первый прогон */ }
  const queue = [...pick].sort((x, y) => (times[y.name] || 120) - (times[x.name] || 120));
  const res = [];
  await Promise.all(Array.from({ length: Math.min(jobs, queue.length) }, async () => {
    while (queue.length) {
      const c = queue.shift();
      const r = await run(c);
      res.push(r);
      const sp = r.game ? `  ×${(r.game / r.sec).toFixed(1)}` : '';
      console.log(`${r.pass ? 'ok    ' : 'ОШИБКА'} ${c.name.padEnd(12)} ${r.sec.toFixed(0).padStart(4)} с${sp}${r.pass ? '' : `  (ошибок скрипта ${r.errs}${r.fails.length ? ', ' + r.fails[0].trim().slice(0, 140) : ''})`}`);
    }
  }));
  const wall = (Date.now() - t0) / 1000;
  for (const r of res) times[r.c.name] = Math.round(r.sec);
  try { fs.writeFileSync(TIMES, JSON.stringify(times, null, 1)); } catch (e) { /* не страшно */ }
  const sum = res.reduce((s, r) => s + (r.game || r.sec), 0);
  res.sort((x, y) => x.c.name.localeCompare(y.c.name));
  const lines = ['проверка      итог     пунктов  время, с  игровое, с', ...res.map((r) => `${r.c.name.padEnd(13)} ${(r.pass ? 'ok' : 'ОШИБКА').padEnd(8)} ${String(r.oks).padStart(7)} ${r.sec.toFixed(0).padStart(9)} ${(r.game ? r.game.toFixed(0) : '—').padStart(11)}`)];
  const bad = res.filter((r) => !r.pass);
  lines.push('', `Всего: ${res.length}, не прошли: ${bad.length}. Настоящего времени: ${(wall / 60).toFixed(1)} мин (по одной в настоящем времени было бы ≈ ${(sum / 60).toFixed(0)} мин).`);
  fs.writeFileSync(path.join(OUT, 'summary.txt'), lines.join('\n') + '\n');
  console.log('\n' + lines.join('\n'));
  if (bad.length) console.log('Не прошли: ' + bad.map((r) => `${r.c.name} (${path.join(OUT, r.c.name + '.log')})`).join(', '));
  process.exit(bad.length ? 1 : 0);
})();
