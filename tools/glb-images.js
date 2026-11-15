// Работа с текстурами внутри .glb без сторонних библиотек.
//   node tools/glb-images.js extract модель.glb папка           — вытащить картинки как img0.jpg, img1.png, ...
//   node tools/glb-images.js replace модель.glb выход.glb 0=файл.jpg 1=файл.jpg ...  — подменить картинки (jpg/png)
//   Дополнительно для replace: rename=старое:новое,... — переименовать анимации (по началу имени).
// Уменьшать картинки можно чем угодно (например, в браузере через canvas) — скрипт только перепаковывает.
const fs = require('fs'), path = require('path');
const [cmd, src, a2, ...rest] = process.argv.slice(2);
const b = fs.readFileSync(src), jl = b.readUInt32LE(12), j = JSON.parse(b.toString('utf8', 20, 20 + jl)), bin = b.slice(20 + jl + 8, 20 + jl + 8 + b.readUInt32LE(20 + jl));
const view = i => { const v = j.bufferViews[i]; return bin.slice(v.byteOffset || 0, (v.byteOffset || 0) + v.byteLength); };
if (cmd === 'extract') {
  fs.mkdirSync(a2, { recursive: true });
  (j.images || []).forEach((im, i) => { const f = path.join(a2, 'img' + i + (/png/.test(im.mimeType) ? '.png' : '.jpg')); fs.writeFileSync(f, view(im.bufferView)); console.log(f, im.mimeType, view(im.bufferView).length); });
} else if (cmd === 'replace') {
  const rep = {}, ren = [];
  for (const r of rest) { const m = /^(\d+)=(.+)$/.exec(r); if (m) rep[m[1]] = fs.readFileSync(m[2]); else if (r.startsWith('rename=')) r.slice(7).split(',').forEach(p => ren.push(p.split(':'))); }
  for (const a of j.animations || []) { const hit = ren.find(([o]) => a.name.startsWith(o)); if (hit) a.name = hit[1]; }
  const parts = []; let off = 0; const nv = [];
  j.bufferViews.forEach((v, i) => {
    const im = (j.images || []).findIndex(q => q.bufferView === i);
    let d = view(i); if (im >= 0 && rep[im]) { d = rep[im]; j.images[im].mimeType = d[0] === 0x89 ? 'image/png' : 'image/jpeg'; }
    const pad = (4 - d.length % 4) % 4; const o = Object.assign({}, v, { byteOffset: off, byteLength: d.length }); nv.push(o); parts.push(d, Buffer.alloc(pad)); off += d.length + pad;
  });
  j.bufferViews = nv; const nb = Buffer.concat(parts); j.buffers = [{ byteLength: nb.length }];
  let js = Buffer.from(JSON.stringify(j)); js = Buffer.concat([js, Buffer.alloc((4 - js.length % 4) % 4, 0x20)]);
  const h = Buffer.alloc(12); h.writeUInt32LE(0x46546C67, 0); h.writeUInt32LE(2, 4); h.writeUInt32LE(12 + 8 + js.length + 8 + nb.length, 8);
  const h1 = Buffer.alloc(8); h1.writeUInt32LE(js.length, 0); h1.writeUInt32LE(0x4E4F534A, 4); const h2 = Buffer.alloc(8); h2.writeUInt32LE(nb.length, 0); h2.writeUInt32LE(0x004E4942, 4);
  fs.writeFileSync(a2, Buffer.concat([h, h1, js, h2, nb]));
  console.log(a2, (b.length / 1048576).toFixed(1) + ' MB ->', ((28 + js.length + nb.length) / 1048576).toFixed(1) + ' MB', 'анимации:', (j.animations || []).map(a => a.name).join(', '));
} else console.log('usage: extract|replace (см. начало файла)');
