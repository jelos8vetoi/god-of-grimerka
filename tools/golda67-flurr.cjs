#!/usr/bin/env node
// Реплики dj flürr для «ГОЛДА 67»: из авторского текста владельца (godot/docs/golda67/DJ_FLURR_SPEC.md) — в данные игры
// (godot/scripts/golda67/g67_flurr_data.gd). Текст не набирается руками и не правится: каждая реплика берётся из
// документа как есть (снимаются только внешние кавычки-ёлочки). После правки документа — запустить заново:
//   node tools/golda67-flurr.cjs
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const cr = String.fromCharCode(13);
const src = fs.readFileSync(path.join(root, 'godot/docs/golda67/DJ_FLURR_SPEC.md'), 'utf8').split(cr).join('').split('\n');
// «Текст». → Текст.   «Текст» → Текст   (точка после закрывающей ёлочки остаётся точкой в конце)
const unq = (s) => { s = s.trim(); if (!s.startsWith('«')) return s; const k = s.lastIndexOf('»'); return k < 0 ? s.slice(1) : s.slice(1, k) + s.slice(k + 1); };
const isHead = (l) => { const m = /^(\d+)\. (.+)$/.exec(l); return m && +m[1] >= 2 && +m[1] <= 12 && /ЗНАКОМСТВО|ВСТРЕЧА КРОТА/.test(m[2]); };
const states = [];
let cur = null, who = '';
const i13 = src.findIndex((l) => l.startsWith('13. '));
const i14 = src.findIndex((l) => l.startsWith('14. '));
src.slice(0, i13).forEach((l) => {
  if (isHead(l)) { cur = []; states.push(cur); who = ''; return; }
  if (!cur) return;
  const t = l.trim();
  if (/^DJ FL.{1,2}RR:$/.test(t)) { who = 'DJ'; return; }
  if (t === 'Пахан:') { who = 'V'; return; }
  if (who && t.startsWith('«')) { cur.push(who + '|' + unq(t)); who = ''; }
});
if (states.length !== 11) throw new Error('состояний ' + states.length + ', нужно 11');
const wait = [], done = [];
let mode = '';
src.slice(i13, i14).forEach((l) => {
  const t = l.replace(/^\* /, '').trim();
  if (t.startsWith('Пока следующая встреча')) mode = 'w';
  else if (t.startsWith('После обнаружения всех')) mode = 'd';
  else if (t.startsWith('«')) (mode === 'd' ? done : wait).push('DJ|' + unq(t));
});
if (wait.length !== 7 || done.length !== 4) throw new Error('коротких ' + wait.length + ' и ' + done.length);
const q = (s) => JSON.stringify(s);
let out = `## Реплики dj flürr. ФАЙЛ СОБРАН СКРИПТОМ tools/golda67-flurr.cjs из godot/docs/golda67/DJ_FLURR_SPEC.md —
## авторский текст владельца, руками не править (правится документ, затем скрипт запускается заново).
## STATES[N] — большой диалог состояния N, где N — сколько встреч КРОТА завершено (0…10).
## WAIT — короткие фразы, пока следующая встреча не найдена; DONE — после всех десяти.
class_name G67Flurr
extends RefCounted

const STATES := [
`;
states.forEach((st) => { out += '\t[\n' + st.map((x) => '\t\t' + q(x) + ',').join('\n') + '\n\t],\n'; });
out += ']\n\nconst WAIT := [\n' + wait.map((x) => '\t' + q(x) + ',').join('\n') + '\n]\n\nconst DONE := [\n' + done.map((x) => '\t' + q(x) + ',').join('\n') + '\n]\n';
fs.writeFileSync(path.join(root, 'godot/scripts/golda67/g67_flurr_data.gd'), out);
console.log('состояний', states.length, 'реплик', states.reduce((a, s) => a + s.length, 0), 'коротких', wait.length + done.length);
