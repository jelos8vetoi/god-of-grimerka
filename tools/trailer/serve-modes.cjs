// Локальный сервер для compose-modes.html (трейлер режимов) и compose-mini.html (трейлер мини-игр). Ничего не шлёт наружу, слушает только 127.0.0.1.
//   node tools/trailer/serve-modes.cjs <папка кадров trailermodes> <куда сохранить mp4> [порт]
// /frames/* — кадры и sfx_*.wav из --trailermodes, /voice/* — godot/assets/voice, /music/* — godot/assets/music,
// остальное — tools/trailer; PUT /__save?name=… — записать готовое видео в папку вывода.
const http = require('http'), fs = require('fs'), path = require('path');
const [frames, outDir, port = '8737'] = process.argv.slice(2);
const root = path.join(__dirname, '..', '..');
const MAP = { '/frames/': frames, '/voice/': path.join(root, 'godot', 'assets', 'voice'), '/music/': path.join(root, 'godot', 'assets', 'music') };
const TYPES = { '.html': 'text/html; charset=utf-8', '.jpg': 'image/jpeg', '.png': 'image/png', '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.ttf': 'font/ttf', '.js': 'text/javascript' };
fs.mkdirSync(outDir, { recursive: true });
http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  if (req.method === 'PUT' && u.pathname === '/__save') {
    const name = path.basename(u.searchParams.get('name') || 'trailer.mp4');
    const chunks = []; req.on('data', c => chunks.push(c));
    req.on('end', () => { const b = Buffer.concat(chunks); fs.writeFileSync(path.join(outDir, name), b); res.end('saved ' + b.length); console.log('saved', name, b.length); });
    return;
  }
  let file = null;
  for (const p in MAP) if (u.pathname.startsWith(p)) file = path.join(MAP[p], decodeURIComponent(u.pathname.slice(p.length)));
  if (!file) file = u.pathname === '/RussoOne-Regular.ttf' ? path.join(root, 'godot', 'assets', 'fonts', 'RussoOne-Regular.ttf') : path.join(__dirname, decodeURIComponent(u.pathname));
  fs.readFile(file, (err, b) => {
    if (err) { res.statusCode = 404; res.end('нет'); return; }
    res.setHeader('Content-Type', TYPES[path.extname(file)] || 'application/octet-stream');
    res.end(b);
  });
}).listen(+port, '127.0.0.1', () => console.log('trailer server http://127.0.0.1:' + port + '/compose-modes.html'));
