// Фон и звуки «5 НОЧЕЙ С ПАХАНОМ» из настоящих записей (CC0): godot/assets/audio/fn/amb (петли) и .../sfx (разовые).
//   node tools/godot-fn-ambience.cjs --src <папка с исходниками> [--ffmpeg <ffmpeg.exe>] [--only <имя>]
// Рецепт — tools/fn-ambience.json (по записи на каждый выходной файл: исходник, отрезок, фильтры, цель громкости).
// Исходники в репозиторий не входят (оригиналы лежат у автора сборки); откуда каждый взят — в
// godot/docs/FIVE_NIGHTS_AUDIO_SOURCES.md, этот файл скрипт каждый раз пересоздаёт из рецепта.
// Петли: отрезок S длиной L+X, тело S[X..L+X] плавно (qsin) переходит в голову S[0..X] → длина L, конец стыкуется с
//   началом; тональные фильтры стоят ДО сборки петли; громкость — одно усиление до цели в LUFS (потолок −6 dBTP).
// Разовые: отрезок, фильтры, эхо (far/room/wall), вход 5 мс, выход в тишину, нормализация по пику (dBFS).
// После сборки: Godot --headless --path godot --import.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const OUT_AMB = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'amb');
const OUT_SFX = path.join(ROOT, 'godot', 'assets', 'audio', 'fn', 'sfx');
const DOC = path.join(ROOT, 'godot', 'docs', 'FIVE_NIGHTS_AUDIO_SOURCES.md');
const MANIFEST = path.join(__dirname, 'fn-ambience.json');
const REVERB = {
  far: { f: 'aecho=0.8:0.75:110|230|390:0.5|0.35|0.22', tail: 1.2, fade: 0.8 },
  room: { f: 'aecho=0.8:0.6:60|130:0.35|0.2', tail: 0.5, fade: 0.35 },
  wall: { f: 'aecho=0.8:0.5:35|70:0.3|0.15', tail: 0.3, fade: 0.2 },
};

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : ''; };
const SRC = opt('src');
const FFMPEG = opt('ffmpeg') || process.env.FFMPEG || 'ffmpeg';
const ONLY = opt('only');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'fn-amb-'));

function ff(a, quiet = true) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-nostats', '-y', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  if (r.status !== 0) throw new Error('ffmpeg: ' + (r.stderr || '').split('\n').slice(-6).join('\n'));
  return r.stderr;
}

function loudness(file) {
  const t = ff(['-i', file, '-af', 'ebur128=peak=true', '-f', 'null', '-']);
  const s = t.slice(t.lastIndexOf('Summary:'));
  return { lufs: Number(s.match(/I:\s+(-?[\d.]+) LUFS/)[1]), tp: Number(s.match(/Peak:\s+(-?[\d.]+) dBFS/)[1]) };
}

function maxVolume(file) {
  const t = ff(['-i', file, '-af', 'volumedetect', '-f', 'null', '-']);
  return Number(t.match(/max_volume:\s+(-?[\d.]+) dB/)[1]);
}

function encodeArgs(e, ch) {
  const fmt = e.out.endsWith('.wav') ? 'wav' : 'ogg';
  if (fmt === 'wav') return ['-c:a', 'pcm_s16le', '-ac', String(ch), '-ar', '44100'];
  return ['-c:a', 'libvorbis', '-q:a', String(ch === 2 ? 5 : e.kind === 'loop' ? 4 : 5), '-ac', String(ch), '-ar', '44100'];
}

function buildLoop(e, src) {
  const [L, X] = e.loop;
  const pre = e.segment ? ['-ss', String(e.segment[0]), '-t', String(e.segment[1] - e.segment[0])] : [];
  const mix = e.stereo_haas_ms
    ? `[0:a]${e.filters},asplit=2[l0][r0];[r0]adelay=${e.stereo_haas_ms},lowpass=f=${e.haas_lowpass}[r1];[l0][r1]join=inputs=2:channel_layout=stereo,aresample=44100[s]`
    : `[0:a]${e.filters},aresample=44100[s]`;
  const fc = `${mix};[s]atrim=0:${L + X},asetpts=PTS-STARTPTS,asplit=2[a][b];[a]atrim=start=${X}:end=${L + X},asetpts=PTS-STARTPTS[body];[b]atrim=0:${X},asetpts=PTS-STARTPTS[head];[body][head]acrossfade=d=${X}:c1=qsin:c2=qsin[o]`;
  const tmp = path.join(TMP, e.out + '.wav');
  ff([...pre, '-i', path.join(SRC, e.src), '-filter_complex', fc, '-map', '[o]', '-c:a', 'pcm_f32le', tmp]);
  const m = loudness(tmp);
  let gain = e.target_lufs - m.lufs;
  let note = '';
  if (m.tp + gain > -6) { gain = -6 - m.tp; note = `gain limited by true peak (-6 dBTP): ${gain.toFixed(2)} dB`; }
  const dest = path.join(OUT_AMB, e.out);
  ff(['-i', tmp, '-af', `volume=${gain.toFixed(3)}dB`, ...encodeArgs(e, e.channels), dest]);
  return `${e.out}: ${m.lufs.toFixed(1)} LUFS -> gain ${gain.toFixed(2)} dB${note ? ' (' + note + ')' : ''}`;
}

function buildShot(e, src) {
  const rv = e.reverb ? REVERB[e.reverb] : null;
  const tail = rv ? rv.tail : 0;
  const len = e.len !== undefined ? e.len : e.segment[1] + tail;
  const fi = e.fade_in !== undefined ? e.fade_in : 0.005;
  const fo = e.fade_out !== undefined ? e.fade_out : rv ? rv.fade : 0.05;
  const chain = ['aformat=channel_layouts=mono'];
  if (e.pre) chain.push(e.pre);
  if (e.filters) chain.push(e.filters);
  if (rv) chain.push(`apad=pad_dur=${tail + 4}`, rv.f);
  chain.push('aresample=44100', `atrim=0:${len}`, 'asetpts=PTS-STARTPTS', `afade=t=in:d=${fi}`, `afade=t=out:st=${(len - fo).toFixed(3)}:d=${fo}`);
  if (e.tail_silence) chain.push(`apad=pad_dur=${e.tail_silence}`, `atrim=0:${(len + e.tail_silence).toFixed(3)}`);
  const tmp = path.join(TMP, e.out + '.wav');
  ff(['-ss', String(e.segment[0]), '-t', String(e.segment[1]), '-i', path.join(SRC, e.src), '-af', chain.join(','), '-c:a', 'pcm_f32le', tmp]);
  const mv = maxVolume(tmp);
  const gain = e.peak_db - mv;
  const dest = path.join(OUT_SFX, e.out);
  ff(['-i', tmp, '-af', `volume=${gain.toFixed(3)}dB`, ...encodeArgs(e, 1), dest]);
  return `${e.out}: len ${len.toFixed(2)} s, max ${mv.toFixed(1)} dB -> gain ${gain.toFixed(2)} dB`;
}

function writeDoc(items, notBuilt) {
  const rows = items.filter((e) => !e.skip);
  let d = '# «5 НОЧЕЙ С ПАХАНОМ» — источники фона и звуков\n\n';
  d += 'Этот файл создаёт `tools/godot-fn-ambience.cjs` из рецепта `tools/fn-ambience.json`: он всегда совпадает с тем, что собрано.\n';
  d += 'Все записи — CC0 (общественное достояние): на странице каждой записи указана лицензия CC0, авторство не обязательно. Страницы открыты 2026-11-22.\n';
  d += 'Дополнительные звуки: Joseph SARDIN — BigSoundBank.com; LEGIT Audio, Longor, Cough-E и другие авторы OpenGameArt — см. таблицу.\n';
  d += 'Файлы BigSoundBank — это OGG или FLAC, которые отдаёт сама страница звука (OGG — тот же файл, что в её плеере); учётная запись не использовалась. Файлы OpenGameArt — оригиналы со страниц.\n';
  d += 'Исходные файлы в репозиторий не входят (лежат у автора сборки, скачаны со страниц ниже); в `godot/assets/audio/fn/amb` и `.../sfx` лежат только обработанные результаты.\n';
  d += 'Сборка: `node tools/godot-fn-ambience.cjs --src <папка исходников> [--ffmpeg <ffmpeg.exe>] [--only <имя>]`, затем `Godot --headless --path godot --import`.\n\n';
  d += '| файл | вид | исходник | автор | страница | лицензия | где звучит | обработка |\n|---|---|---|---|---|---|---|---|\n';
  for (const e of rows) {
    const seg = e.segment ? (e.kind === 'loop' ? `${e.segment[0]}–${e.segment[1]} с` : `с ${e.segment[0]} с, ${e.segment[1]} с`) : 'целиком';
    const proc = e.kind === 'loop'
      ? `${seg}; ${e.filters}${e.stereo_haas_ms ? `; стерео: правый канал +${e.stereo_haas_ms} мс, lowpass ${e.haas_lowpass}` : ''}; петля L=${e.loop[0]} с, X=${e.loop[1]} с; цель ${e.target_lufs} LUFS; ${e.channels === 2 ? 'стерео' : 'моно'}`
      : `${seg}; ${[e.pre, e.filters].filter(Boolean).join(', ') || '—'}${e.reverb ? `; эхо ${e.reverb}` : ''}; пик ${e.peak_db} dBFS`;
    d += `| ${e.kind === 'loop' ? 'amb/' : 'sfx/'}${e.out} | ${e.kind === 'loop' ? 'петля' : 'разовый'} | ${e.title} (${e.src_name}) | ${e.author} | ${e.url} | ${e.licence} | ${e.use} | ${proc} |\n`;
  }
  const skipped = items.filter((e) => e.skip).map((e) => `- \`${e.out}\` — ${e.skip}`).concat(notBuilt.map((x) => '- ' + x));
  if (skipped.length) {
    d += '\nНе вошло:\n\n' + skipped.join('\n') + '\n';
  }
  fs.writeFileSync(DOC, d);
}

(function main() {
  if (!SRC) { console.log('нужен --src <папка исходников>'); process.exit(1); }
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  const items = manifest.items;
  fs.mkdirSync(OUT_AMB, { recursive: true });
  fs.mkdirSync(OUT_SFX, { recursive: true });
  let built = 0;
  for (const e of items) {
    if (e.skip) { console.log(`пропуск ${e.out}: ${e.skip}`); continue; }
    if (ONLY && !e.out.startsWith(ONLY)) continue;
    console.log(e.kind === 'loop' ? buildLoop(e) : buildShot(e));
    built++;
  }
  writeDoc(items, manifest.not_built || []);
  console.log(`собрано файлов: ${built}; документ: ${path.relative(ROOT, DOC)}`);
  fs.rmSync(TMP, { recursive: true, force: true });
})();
