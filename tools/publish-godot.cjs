// Обновить Godot-сборку на GitHub: собирает .exe и кладёт его в релиз «godot-build» того же репозитория,
// описание релиза берёт из godot/CHANGELOG.md. Ссылка на сборку всегда одна и та же.
//
// Порядок для любого из нас:
//   1. git pull, внести правки, проверить игру;
//   2. дописать сверху в godot/CHANGELOG.md раздел «## дата · что сделано» с пунктами;
//   3. git commit, git push;
//   4. node tools/publish-godot.cjs
//
// Нужно: Godot 4.7.2 в tools/godot (или путь в переменной GODOT), шаблоны экспорта 4.7.2,
// GitHub CLI с входом (gh auth login) и права на запись в репозиторий.
// Ключи:  --no-export  не пересобирать, залить уже лежащий dist/godot/GOD OF GRIMERKA.exe
//         --force      публиковать, даже если есть незакоммиченные или незапушенные правки в godot/
//         --dry        только показать, что будет сделано
//         --no-launcher не собирать и не заливать лаунчер
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const TAG = 'godot-build', ASSET = 'GOD-OF-GRIMERKA-Godot.exe', LAUNCHER = 'GOD-OF-GRIMERKA-Launcher.exe';
const root = path.join(__dirname, '..');
const godot = process.env.GODOT || path.join(root, 'tools', 'godot', 'Godot_v4.7.2-stable_win64_console.exe');
const exe = path.join(root, 'dist', 'godot', 'GOD OF GRIMERKA.exe');
const has = f => process.argv.includes(f);
const run = (cmd, args, opt = {}) => execFileSync(cmd, args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20, ...opt });
const fail = m => { console.error('ОШИБКА: ' + m); process.exit(1); };

// журнал изменений
const logPath = path.join(root, 'godot', 'CHANGELOG.md');
if (!fs.existsSync(logPath)) fail('нет godot/CHANGELOG.md');
const log = fs.readFileSync(logPath, 'utf8').replace(/\r\n/g, '\n');
const first = log.match(/^## (.+)$/m);
if (!first) fail('в godot/CHANGELOG.md нет ни одного раздела «## дата · что сделано»');
const body = log.slice(log.indexOf('\n## ') + 1);

// состояние репозитория
const sha = run('git', ['rev-parse', '--short', 'HEAD']).trim();
const dirty = run('git', ['status', '--porcelain', '--', 'godot']).trim();
try { run('git', ['fetch', '--quiet']); } catch (e) { console.warn('не удалось обновить сведения о сервере: ' + e.message.split('\n')[0]); }
const branch = run('git', ['status', '-sb']).split('\n')[0];
if (!has('--force')) {
  if (dirty) fail('в godot/ есть незакоммиченные правки — сборка не совпадёт с кодом на GitHub. Закоммить их или запусти с --force.\n' + dirty);
  if (/ahead|behind/.test(branch)) fail('ветка расходится с сервером (' + branch + '). Сделай git pull / git push или запусти с --force.');
}
const when = new Date().toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
const title = 'GOD OF GRIMERKA — Godot-сборка для Windows';
const notes = [
  '**Скачай `' + LAUNCHER + '` один раз** — он сам ставит игру, проверяет обновления при каждом запуске и докачивает новую сборку. Игра ставится в `%LOCALAPPDATA%\\GOD OF GRIMERKA Godot`.',
  '',
  'Без лаунчера: скачай `' + ASSET + '` и запусти — установка не нужна.',
  '',
  'Последнее обновление: **' + first[1] + '** · собрано ' + when + ' · коммит `' + sha + '`.',
  'Как обновить сборку самому — в `tools/publish-godot.cjs` и в README.',
  '',
  body.trim(), ''].join('\n');
console.log('релиз: ' + TAG + '\nкоммит: ' + sha + '\nпоследняя запись: ' + first[1]);
if (has('--dry')) { console.log('\n' + notes); process.exit(0); }

// сборка
if (!has('--no-export')) {
  if (!fs.existsSync(godot)) fail('не найден Godot: ' + godot + ' (положи в tools/godot или задай путь в переменной GODOT)');
  fs.mkdirSync(path.dirname(exe), { recursive: true });
  const before = fs.existsSync(exe) ? fs.statSync(exe).mtimeMs : 0;
  // музыка в git не лежит (её делает скрипт за десять секунд): если файлов нет — создаём, затем импортируем новое
  if (!fs.existsSync(path.join(root, 'godot', 'assets', 'music', 'loc_snow_base.wav'))) { console.log('генерирую музыку…'); run('node', [path.join(root, 'tools', 'godot-music.cjs')]); }
  fs.writeFileSync(path.join(root, 'godot', 'data', 'build.json'), JSON.stringify({ sha, time: when }));
  try { run(godot, ['--headless', '--path', 'godot', '--import']); } catch (e) {}
  console.log('собираю .exe…');
  let out = '';
  try { out = run(godot, ['--headless', '--path', 'godot', '--export-release', 'Windows', '../dist/godot/GOD OF GRIMERKA.exe'], { stdio: ['ignore', 'pipe', 'pipe'] }); }
  catch (e) { out = String(e.stdout || '') + String(e.stderr || ''); }
  if (/export for preset .* failed|Project export .* failed/i.test(out) || !fs.existsSync(exe) || fs.statSync(exe).mtimeMs <= before)
    fail('сборка не удалась (игра запущена и держит файл? нет шаблонов экспорта?).\n' + out.split('\n').filter(l => /ERROR/.test(l)).slice(0, 5).join('\n'));
}
if (!fs.existsSync(exe)) fail('нет файла ' + exe);
// лаунчер: маленький .exe на C# (компилятор .NET Framework есть в любой Windows), собирается каждый раз
const launcherExe = path.join(root, 'dist', LAUNCHER);
if (!has('--no-launcher')) {
  console.log('собираю лаунчер…');
  try { run('cmd.exe', ['/c', path.join(root, 'tools', 'launcher', 'build.cmd')]); } catch (e) { fail('лаунчер не собрался:\n' + String(e.stdout || '') + String(e.stderr || e.message)); }
}
const tmp = path.join(path.dirname(exe), ASSET), notesFile = path.join(path.dirname(exe), 'notes.md');
fs.copyFileSync(exe, tmp);
fs.writeFileSync(notesFile, notes);

// релиз
try {
  let exists = true;
  try { run('gh', ['release', 'view', TAG, '--json', 'tagName']); } catch (e) { exists = false; }
  if (!exists) {
    console.log('создаю релиз ' + TAG + '…');
    run('gh', ['release', 'create', TAG, '--title', title, '--notes-file', notesFile, '--latest=false']);
  }
  console.log('заливаю ' + ASSET + ' (' + Math.round(fs.statSync(tmp).size / 1048576) + ' МБ)…');
  run('gh', ['release', 'upload', TAG, tmp, '--clobber']);
  if (fs.existsSync(launcherExe)) { console.log('заливаю ' + LAUNCHER + '…'); run('gh', ['release', 'upload', TAG, launcherExe, '--clobber']); }
  run('gh', ['release', 'edit', TAG, '--title', title, '--notes-file', notesFile, '--latest=false']);
  console.log('готово: ' + run('gh', ['release', 'view', TAG, '--json', 'url', '--jq', '.url']).trim());
} catch (e) {
  fail('GitHub CLI: ' + String(e.stderr || e.message).split('\n').slice(0, 4).join('\n') + '\nПроверь gh auth status и права на запись в репозиторий.');
} finally {
  fs.rmSync(tmp, { force: true });
  fs.rmSync(notesFile, { force: true });
}
