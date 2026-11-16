// Границы речи в vo*.wav (порог -40 дБ) → строка SPEECH для compose-godot.html. node speech.cjs <папка>
const fs=require('fs'),path=require('path');const dir=process.argv[2];const out={};
for(const f of fs.readdirSync(dir).filter(f=>/^vo\d+\.wav$/.test(f)).sort((a,b)=>parseInt(a.slice(2))-parseInt(b.slice(2)))){
 const b=fs.readFileSync(path.join(dir,f));let o=12,fmt,data;while(o<b.length){const id=b.toString('ascii',o,o+4),sz=b.readUInt32LE(o+4);if(id==='fmt ')fmt={ch:b.readUInt16LE(o+10),sr:b.readUInt32LE(o+12),bits:b.readUInt16LE(o+22)};if(id==='data'){data=b.slice(o+8,o+8+Math.min(sz,b.length-o-8));break;}o+=8+sz+(sz&1);}
 const n=data.length/2/fmt.ch,win=Math.round(fmt.sr*.02);let first=-1,last=-1,peak=0;
 for(let i=0;i<n;i+=win){let s=0;for(let j=i;j<Math.min(n,i+win);j++){const v=data.readInt16LE(j*2*fmt.ch)/32768;s+=v*v;peak=Math.max(peak,Math.abs(v));}const db=10*Math.log10(s/win+1e-12);if(db>-40){if(first<0)first=i;last=i+win;}}
 const k=f.slice(0,-4);out[k]=[+(first/fmt.sr).toFixed(2),+(last/fmt.sr).toFixed(2)];console.log(k,fmt.sr,fmt.ch,'dur',(n/fmt.sr).toFixed(2),'speech',out[k],'peak',peak.toFixed(2));}
console.log(JSON.stringify(out));
