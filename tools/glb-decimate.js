// Упрощение сетки .glb (в том числе со скелетом) кластеризацией вершин — без сторонних библиотек.
//   node tools/glb-decimate.js вход.glb выход.glb [целевое_число_треугольников]
// Вершины в одной ячейке сетки сливаются: положение — среднее по ячейке (швы не расходятся), а UV, нормаль, кости
// и веса берутся от вершины того же участка текстуры (острова UV), что и треугольник, — текстура не рвётся по швам.
// Размер ячейки подбирается двоичным поиском под нужное число треугольников.
const fs = require('fs');
const [src, dst, targetArg] = process.argv.slice(2);
const TARGET = +targetArg || 12000;
const b = fs.readFileSync(src), jl = b.readUInt32LE(12), j = JSON.parse(b.toString('utf8', 20, 20 + jl));
const bin = b.slice(20 + jl + 8, 20 + jl + 8 + b.readUInt32LE(20 + jl));
const CT = { 5120: Int8Array, 5121: Uint8Array, 5122: Int16Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };
const NC = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
function read(ai) {
  const a = j.accessors[ai], v = j.bufferViews[a.bufferView], T = CT[a.componentType], n = NC[a.type], es = T.BYTES_PER_ELEMENT;
  const stride = v.byteStride || n * es, off = (v.byteOffset || 0) + (a.byteOffset || 0), out = new T(a.count * n);
  for (let i = 0; i < a.count; i++) for (let c = 0; c < n; c++) out[i * n + c] = bin['read' + ({ 1: T === Int8Array ? 'Int8' : 'UInt8', 2: T === Int16Array ? 'Int16LE' : 'UInt16LE', 4: T === Float32Array ? 'FloatLE' : 'UInt32LE' })[es]](off + i * stride + c * es);
  return { a, T, n, data: out };
}
const newViews = [], parts = []; let boff = 0;
const keepView = i => { const v = j.bufferViews[i], d = bin.slice(v.byteOffset || 0, (v.byteOffset || 0) + v.byteLength); return push(d, Object.assign({}, v)); };
function push(d, v) { const L = d.byteLength, pad = (4 - L % 4) % 4; v.buffer = 0; v.byteOffset = boff; v.byteLength = L; delete v.byteStride; newViews.push(v); parts.push(Buffer.from(d.buffer, d.byteOffset, L), Buffer.alloc(pad)); boff += L + pad; return newViews.length - 1; }
const replaced = {};   // старый индекс accessor → новые данные
let report = '';
for (const m of j.meshes) for (const p of m.primitives) {
  const pos = read(p.attributes.POSITION), idx = read(p.indices), attrs = {};
  for (const k in p.attributes) attrs[k] = read(p.attributes[k]);
  const uv = attrs.TEXCOORD_0, nV = pos.a.count, I = idx.data, tris0 = I.length / 3;
  if (tris0 <= TARGET) continue;
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; for (let i = 0; i < nV; i++) for (let c = 0; c < 3; c++) { mn[c] = Math.min(mn[c], pos.data[i * 3 + c]); mx[c] = Math.max(mx[c], pos.data[i * 3 + c]); }
  // участки текстуры (острова UV): склеиваем совпадающие вершины (позиция+UV) и ищем связные куски по треугольникам
  const par = new Int32Array(nV).map((_, i) => i), fnd = x => { while (par[x] !== x) x = par[x] = par[par[x]]; return x; }, uni = (a, c) => { a = fnd(a); c = fnd(c); if (a !== c) par[a] = c; };
  { const wm = new Map(); for (let i = 0; i < nV; i++) { const k = [0, 1, 2].map(q => Math.round(pos.data[i * 3 + q] * 1e5)).join(',') + (uv ? '|' + Math.round(uv.data[i * 2] * 1e5) + ',' + Math.round(uv.data[i * 2 + 1] * 1e5) : ''); const o = wm.get(k); if (o == null) wm.set(k, i); else uni(i, o); } }
  for (let t = 0; t < I.length; t += 3) { uni(I[t], I[t + 1]); uni(I[t], I[t + 2]); }
  const isl = new Int32Array(nV); for (let i = 0; i < nV; i++) isl[i] = fnd(i);
  const ext = Math.max(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]);
  const build = cell => {
    const key = new Int32Array(nV), map = new Map(); let nc = 0;
    for (let i = 0; i < nV; i++) {
      const kx = Math.floor((pos.data[i * 3] - mn[0]) / cell), ky = Math.floor((pos.data[i * 3 + 1] - mn[1]) / cell), kz = Math.floor((pos.data[i * 3 + 2] - mn[2]) / cell);
      const k = kx + ',' + ky + ',' + kz; let c = map.get(k); if (c == null) { c = nc++; map.set(k, c); } key[i] = c;
    }
    const tri = [], seen = new Set();
    for (let t = 0; t < I.length; t += 3) { const a = key[I[t]], bq = key[I[t + 1]], c = key[I[t + 2]]; if (a === bq || bq === c || a === c) continue; const s = [a, bq, c].sort((x, y) => x - y).join(','); if (seen.has(s)) continue; seen.add(s); tri.push(a, bq, c); }
    return { key, nc, tri };
  };
  let lo = ext / 2000, hi = ext / 8, best = null;
  for (let it = 0; it < 22; it++) { const mid = Math.sqrt(lo * hi), r = build(mid); if (r.tri.length / 3 > TARGET) lo = mid; else { hi = mid; best = r; } }
  if (!best) best = build(hi);
  // положение — среднее по кластеру (общее для всех островов, поэтому швы не расходятся);
  // UV/нормаль/кости — от ближайшей к центру вершины того же острова, что и треугольник
  const sum = new Float64Array(best.nc * 3), cnt = new Uint32Array(best.nc);
  for (let i = 0; i < nV; i++) { const c = best.key[i]; cnt[c]++; for (let q = 0; q < 3; q++) sum[c * 3 + q] += pos.data[i * 3 + q]; }
  const outMap = new Map(), order = [], ocl = [], dist2 = [];
  const vid = (c, i) => { const k = c + ':' + isl[i]; let o = outMap.get(k); let d = 0; for (let q = 0; q < 3; q++) { const m0 = sum[c * 3 + q] / cnt[c] - pos.data[i * 3 + q]; d += m0 * m0; }
    if (o == null) { o = order.length; outMap.set(k, o); order.push(i); ocl.push(c); dist2.push(d); } else if (d < dist2[o]) { order[o] = i; dist2[o] = d; } return o; };
  const tri = [], seenT = new Set();
  for (let t = 0; t < I.length; t += 3) { const ca = best.key[I[t]], cb = best.key[I[t + 1]], cc = best.key[I[t + 2]]; if (ca === cb || cb === cc || ca === cc) continue;
    const a = vid(ca, I[t]), bq = vid(cb, I[t + 1]), c = vid(cc, I[t + 2]); const sk = [a, bq, c].sort((x, y) => x - y).join(','); if (seenT.has(sk)) continue; seenT.add(sk); tri.push(a, bq, c); }
  const nn = order.length;
  for (const k in attrs) {
    const A = attrs[k], out = new A.T(nn * A.n);
    for (let i = 0; i < nn; i++) for (let q = 0; q < A.n; q++) out[i * A.n + q] = A.data[order[i] * A.n + q];
    if (k === 'POSITION') for (let i = 0; i < nn; i++) { const c = ocl[i]; for (let q = 0; q < 3; q++) out[i * 3 + q] = sum[c * 3 + q] / cnt[c]; }
    replaced[p.attributes[k]] = { a: A.a, data: out, n: A.n };
  }
  const ni = nn > 65535 ? new Uint32Array(tri.length) : new Uint16Array(tri.length); for (let t = 0; t < tri.length; t++) ni[t] = tri[t];
  replaced[p.indices] = { a: idx.a, data: ni, n: 1, ct: nn > 65535 ? 5125 : 5123 };
  best.tri = tri;
  report += `${m.name || 'mesh'}: ${tris0} → ${best.tri.length / 3} треугольников, ${nV} → ${nn} вершин\n`;
}
// пересобрать буферы: заменённые accessor'ы получают свои view, остальные view копируются
const viewMap = {};
j.accessors.forEach((a, i) => {
  if (replaced[i]) {
    const r = replaced[i]; a.bufferView = push(r.data, {}); a.byteOffset = 0; a.count = r.data.length / r.n; if (r.ct) a.componentType = r.ct;
    if (a.min && r.n <= 4 && a.type !== 'SCALAR') { const mn = new Array(r.n).fill(1e9), mx = new Array(r.n).fill(-1e9); for (let k = 0; k < r.data.length; k++) { const q = k % r.n; mn[q] = Math.min(mn[q], r.data[k]); mx[q] = Math.max(mx[q], r.data[k]); } a.min = mn; a.max = mx; }
    else if (a.type === 'SCALAR') { delete a.min; delete a.max; }
  } else if (a.bufferView != null) { if (viewMap[a.bufferView] == null) viewMap[a.bufferView] = keepView(a.bufferView); a.bufferView = viewMap[a.bufferView]; }
});
for (const im of j.images || []) if (im.bufferView != null) { if (viewMap[im.bufferView] == null) viewMap[im.bufferView] = keepView(im.bufferView); im.bufferView = viewMap[im.bufferView]; }
j.bufferViews = newViews; const nb = Buffer.concat(parts); j.buffers = [{ byteLength: nb.length }];
if (j.extensionsUsed) j.extensionsUsed = j.extensionsUsed.filter(e => e !== 'FB_ngon_encoding');
let js = Buffer.from(JSON.stringify(j)); js = Buffer.concat([js, Buffer.alloc((4 - js.length % 4) % 4, 0x20)]);
const h = Buffer.alloc(12); h.writeUInt32LE(0x46546C67, 0); h.writeUInt32LE(2, 4); h.writeUInt32LE(12 + 8 + js.length + 8 + nb.length, 8);
const h1 = Buffer.alloc(8); h1.writeUInt32LE(js.length, 0); h1.writeUInt32LE(0x4E4F534A, 4); const h2 = Buffer.alloc(8); h2.writeUInt32LE(nb.length, 0); h2.writeUInt32LE(0x004E4942, 4);
fs.writeFileSync(dst, Buffer.concat([h, h1, js, h2, nb]));
console.log(report + dst + ' ' + (b.length / 1048576).toFixed(1) + ' MB -> ' + ((28 + js.length + nb.length) / 1048576).toFixed(1) + ' MB');
