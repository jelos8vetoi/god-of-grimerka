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
//         --build-only собрать архив и установщик локально, без публикации
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const TAG = 'godot-build', ASSET = 'GOD-OF-GRIMERKA-Godot.exe', LAUNCHER = 'GOD-OF-GRIMERKA-Launcher.exe', SETUP = 'GOD-OF-GRIMERKA-Setup.exe';
const root = path.join(__dirname, '..');
const godot = process.env.GODOT || path.join(root, 'tools', 'godot', 'Godot_v4.7.2-stable_win64_console.exe');
const exe = path.join(root, 'dist', 'godot', 'GOD OF GRIMERKA.exe');
const ARCHIVE = 'GOD-OF-GRIMERKA-Windows-x64.zip';
const archive = path.join(root, 'dist', ARCHIVE);
const runtime = [
  path.basename(exe),
  'discord_partner_sdk.dll',
  'discord_social_sdk.windows.template_release.x86_64.dll',
  'Discord-SDK-LICENSE.txt',
  'Discord-SDK-Notices.txt',
];
const has = f => process.argv.includes(f);
const run = (cmd, args, opt = {}) => execFileSync(cmd, args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20, ...opt });
const fail = m => { console.error('ОШИБКА: ' + m); process.exit(1); };

// журнал изменений
const logPath = path.join(root, 'godot', 'CHANGELOG.md');
if (!fs.existsSync(logPath)) fail('нет godot/CHANGELOG.md');
const log = fs.readFileSync(logPath, 'utf8').replace(/\r\n/g, '\n');
const first = log.match(/^## (.+)$/m);
if (!first) fail('в godot/CHANGELOG.md нет ни одного раздела «## дата · что сделано»');
// GitHub принимает описание релиза не длиннее 125 000 символов: берём свежие разделы целиком, пока влезают,
// остальное — ссылкой на полный журнал (иначе последний шаг сборки падал, и в описании оставался старый коммит)
const BODY_MAX = 100000;
let body = '';
for (const part of log.slice(log.indexOf('\n## ') + 1).split(/\n(?=## )/)) {
  if (body.length + part.length + 1 > BODY_MAX) {
    body += '\n…\n\nПолный журнал изменений — `godot/CHANGELOG.md` в репозитории.\n';
    break;
  }
  body += (body ? '\n' : '') + part;
}

// состояние репозитория
const sha = run('git', ['rev-parse', '--short', 'HEAD']).trim();
const dirty = run('git', ['status', '--porcelain', '--', 'godot']).trim();
try { run('git', ['fetch', '--quiet']); } catch (e) { console.warn('не удалось обновить сведения о сервере: ' + e.message.split('\n')[0]); }
const branch = run('git', ['status', '-sb']).split('\n')[0];
if (!has('--force')) {
  if (dirty && !has('--build-only')) fail('в godot/ есть незакоммиченные правки — сборка не совпадёт с кодом на GitHub. Закоммить их или запусти с --force.\n' + dirty);
  if (/ahead|behind/.test(branch) && !has('--build-only')) fail('ветка расходится с сервером (' + branch + '). Сделай git pull / git push или запусти с --force.');
}
const when = new Date().toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
const title = 'GOD OF GRIMERKA — Godot-сборка для Windows';
const notes = [
  '**Скачай `' + SETUP + '`** — установщик в стиле игры: сам ставит игру и лаунчер в выбранную папку, делает ярлыки, а удалить можно из «Приложений» Windows. Сохранения при обновлении и удалении остаются.',
  '',
  'Или без установки: скачай `' + LAUNCHER + '` один раз — он сам ставит игру, проверяет обновления при каждом запуске и докачивает новую сборку. Игра ставится в `%LOCALAPPDATA%\\GOD OF GRIMERKA Godot`.',
  '',
  'Без лаунчера: скачай `' + ARCHIVE + '`, распакуй все файлы в одну папку и запусти `GOD OF GRIMERKA.exe`.',
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
  try { run(godot, ['--headless', '--path', 'godot', '--import']); }
  catch (e) { fail('импорт Godot не удался: ' + String(e.stderr || e.message).split('\n').slice(-12).join('\n')); }
  console.log('собираю .exe…');
  let out = '';
  try { out = run(godot, ['--headless', '--path', 'godot', '--export-release', 'Windows', '../dist/godot/GOD OF GRIMERKA.exe'], { stdio: ['ignore', 'pipe', 'pipe'] }); }
  catch (e) { out = String(e.stdout || '') + String(e.stderr || ''); }
  if (/export for preset .* failed|Project export .* failed/i.test(out) || !fs.existsSync(exe) || fs.statSync(exe).mtimeMs <= before)
    fail('сборка не удалась (игра запущена и держит файл? нет шаблонов экспорта?).\n' + out.split('\n').filter(l => /ERROR/.test(l)).slice(0, 5).join('\n'));
}
if (!fs.existsSync(exe)) fail('нет файла ' + exe);

const sdk = path.join(root, 'godot', 'addons', 'discord_social_sdk');
const exportDir = path.dirname(exe);
fs.copyFileSync(path.join(sdk, 'LICENSE'), path.join(exportDir, 'Discord-SDK-LICENSE.txt'));
fs.copyFileSync(path.join(sdk, 'License-Notices.txt'), path.join(exportDir, 'Discord-SDK-Notices.txt'));
for (const name of runtime) {
  const file = path.join(exportDir, name);
  if (!fs.existsSync(file) || !fs.statSync(file).size) fail('в экспорте отсутствует ' + name);
}
console.log('упаковываю Windows x64…');
const windowsTar = path.join(process.env.SystemRoot || 'C:/Windows', 'System32', 'tar.exe');
try {
  run(windowsTar, ['-a', '-cf', path.relative(root, archive), '-C', path.relative(root, exportDir), ...runtime]);
}
catch (e) { fail('не удалось собрать архив: ' + String(e.stderr || e.message)); }
if (fs.statSync(archive).size >= 2 ** 31 || fs.statSync(exe).size >= 2 ** 31)
  fail('файл превышает лимит GitHub Release (2 ГиБ)');

// лаунчер: маленький .exe на C# (компилятор .NET Framework есть в любой Windows), собирается каждый раз
const launcherExe = path.join(root, 'dist', LAUNCHER);
if (!has('--no-launcher')) {
  console.log('собираю лаунчер…');
  try { run('cmd.exe', ['/c', path.join(root, 'tools', 'launcher', 'build.cmd')]); } catch (e) { fail('лаунчер не собрался:\n' + String(e.stdout || '') + String(e.stderr || e.message)); }
}
const setupExe = path.join(root, 'dist', SETUP);
if (!has('--no-launcher')) {
  console.log('собираю установщик…');
  try { run('cmd.exe', ['/c', path.join(root, 'tools', 'setup', 'build.cmd')]); } catch (e) { fail('установщик не собрался:\n' + String(e.stdout || '') + String(e.stderr || e.message)); }
}
if (has('--build-only')) {
  console.log('готово: ' + archive);
  process.exit(0);
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
    run('gh', ['release', 'create', TAG, '--title', title, '--notes-file', notesFile, '--latest']);
  }
  console.log('заливаю ' + ARCHIVE + '…');
  run('gh', ['release', 'upload', TAG, archive, '--clobber']);
  console.log('заливаю ' + ASSET + ' (' + Math.round(fs.statSync(tmp).size / 1048576) + ' МБ)…');
  run('gh', ['release', 'upload', TAG, tmp, '--clobber']);
  if (fs.existsSync(setupExe)) { console.log('заливаю ' + SETUP + '…'); run('gh', ['release', 'upload', TAG, setupExe, '--clobber']); }
  if (fs.existsSync(launcherExe)) { console.log('заливаю ' + LAUNCHER + '…'); run('gh', ['release', 'upload', TAG, launcherExe, '--clobber']); }
  run('gh', ['release', 'edit', TAG, '--title', title, '--notes-file', notesFile, '--latest']);
  console.log('готово: ' + run('gh', ['release', 'view', TAG, '--json', 'url', '--jq', '.url']).trim());
} catch (e) {
  fail('GitHub CLI: ' + String(e.stderr || e.message).split('\n').slice(0, 4).join('\n') + '\nПроверь gh auth status и права на запись в репозиторий.');
} finally {
  fs.rmSync(tmp, { force: true });
  fs.rmSync(notesFile, { force: true });
}
