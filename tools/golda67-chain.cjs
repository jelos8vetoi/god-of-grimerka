// Золотая цепь Миши Минасяна: звенья-торы по кривой, уложенной на грудь и шею модели, и медальон.
// Координаты — «единицы модели» (1 = рост, начало — центр основания, +Z — лицо), как в tools/rig-horror.py.
//   node chain.cjs <статичная модель Миши .glb> <выход.glb>
const fs=require('fs');
const [src,dst]=process.argv.slice(2);
const b=fs.readFileSync(src);const jl=b.readUInt32LE(12);const j=JSON.parse(b.slice(20,20+jl).toString());
const bin=b.slice(20+jl+8);const pr=j.meshes[0].primitives[0];const a=j.accessors[pr.attributes.POSITION];const bv=j.bufferViews[a.bufferView];
const off=(bv.byteOffset||0)+(a.byteOffset||0),st=bv.byteStride||12;
const lo=a.min,hi=a.max;const unit=Math.max(hi[0]-lo[0],hi[1]-lo[1],hi[2]-lo[2]);const cx=(lo[0]+hi[0])/2,cz=(lo[2]+hi[2])/2;
const V=[];for(let i=0;i<a.count;i++){const o=off+i*st;V.push([(bin.readFloatLE(o)-cx)/unit,(bin.readFloatLE(o+4)-lo[1])/unit,(bin.readFloatLE(o+8)-cz)/unit]);}
// поверхность: самая передняя / задняя точка сетки рядом с (x, y); голову (y > 0.655) не берём — цепь лежит на теле
const surf=(x,y,front)=>{let best=front?-9:9;for(const v of V){if(v[1]>0.655||Math.abs(v[0])>0.16)continue;const dx=v[0]-x,dy=v[1]-y;if(dx*dx+dy*dy<0.012*0.012){best=front?Math.max(best,v[2]):Math.min(best,v[2]);}}return Math.abs(best)>8?null:best;};
const R=0.019,r=0.0066,PAD=r*1.1;            // звено: большой и малый радиус тора
// кривая: петля вокруг шеи, спереди свисает на грудь
const pts=[];const N=240;
for(let i=0;i<N;i++){const t=i/N*Math.PI*2;const c=Math.cos(t),s=Math.sin(t);
  const f=(1+c)/2;                               // 1 — спереди внизу, 0 — сзади на шее
  const x=0.098*s*(0.72+0.28*(1-f*f));           // у груди петля уже
  const y=0.652-0.075*Math.pow(f,1.6);
  let zf=surf(x,Math.min(y,0.65),true),zb=surf(x,Math.min(y,0.65),false);
  if(zf===null)zf=0.06;if(zb===null)zb=-0.06;
  const k=Math.max(0,Math.min(1,(c+0.35)/0.7));const kk=k*k*(3-2*k);
  pts.push([x,y,(zb-PAD)*(1-kk)+(zf+PAD)*kk]);}
// сглаживание и равномерный шаг
for(let it=0;it<6;it++){const q=pts.map((p,i)=>{const A=pts[(i+N-1)%N],B=pts[(i+1)%N];return [p[0],(A[1]+2*p[1]+B[1])/4,(A[2]+2*p[2]+B[2])/4];});q.forEach((p,i)=>pts[i]=p);}
const len=[0];for(let i=1;i<=N;i++){const A=pts[i-1],B=pts[i%N];len.push(len[i-1]+Math.hypot(B[0]-A[0],B[1]-A[1],B[2]-A[2]));}
const total=len[N];const step=2*R-2*r*1.15;const count=Math.round(total/step);
const at=d=>{d=((d%total)+total)%total;let i=1;while(len[i]<d)i++;const A=pts[i-1],B=pts[i%N];const u=(d-len[i-1])/(len[i]-len[i-1]);return [A[0]+(B[0]-A[0])*u,A[1]+(B[1]-A[1])*u,A[2]+(B[2]-A[2])*u];};
const P=[],Nn=[],I=[];
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],nrm=a=>{const l=Math.hypot(...a)||1;return a.map(x=>x/l);};
function torus(c,t,n,RR,rr,sx){ // ось тора — n; вытянут вдоль t (овальное звено)
  const bN=nrm(cross(n,t));const base=P.length/3;const SEG=14,TUB=7;
  for(let i=0;i<SEG;i++){const u=i/SEG*Math.PI*2;const cu=Math.cos(u),su=Math.sin(u);
    const dir=[t[0]*cu*sx+bN[0]*su,t[1]*cu*sx+bN[1]*su,t[2]*cu*sx+bN[2]*su];const dn=nrm([t[0]*cu+bN[0]*su,t[1]*cu+bN[1]*su,t[2]*cu+bN[2]*su]);
    for(let k=0;k<TUB;k++){const v=k/TUB*Math.PI*2;const cv=Math.cos(v),sv=Math.sin(v);
      const nn=[dn[0]*cv+n[0]*sv,dn[1]*cv+n[1]*sv,dn[2]*cv+n[2]*sv];
      P.push(c[0]+dir[0]*RR+nn[0]*rr,c[1]+dir[1]*RR+nn[1]*rr,c[2]+dir[2]*RR+nn[2]*rr);Nn.push(...nn);}}
  for(let i=0;i<SEG;i++)for(let k=0;k<TUB;k++){const a0=base+i*TUB+k,a1=base+((i+1)%SEG)*TUB+k,a2=base+((i+1)%SEG)*TUB+(k+1)%TUB,a3=base+i*TUB+(k+1)%TUB;I.push(a0,a1,a2,a0,a2,a3);}
}
let low=null;
for(let i=0;i<count;i++){const d=i*total/count;const c=at(d);const t=nrm(sub(at(d+0.002),at(d-0.002)));
  // наружу от тела: спереди +Z, сзади −Z, по бокам — в сторону
  let outw=nrm([c[0]*0.6,0.0,c[2]>=0?1:-1]);let side=nrm(cross(t,outw));let n=(i%2===0)?nrm(cross(side,t)):side;   // соседние звенья повёрнуты на 90°
  torus(c,t,n,R,r,1.18);if(!low||c[1]<low[1])low=c;}
// медальон: толстый диск на кольце под нижним звеном
(function(){const c=[low[0],low[1]-R-0.03,low[2]+0.006];const RAD=0.036,TH=0.009,SEG=28;const base=P.length/3;
  for(const sz of [1,-1]){const b0=P.length/3;P.push(c[0],c[1],c[2]+sz*TH);Nn.push(0,0,sz);
    for(let i=0;i<SEG;i++){const u=i/SEG*Math.PI*2;P.push(c[0]+Math.cos(u)*RAD,c[1]+Math.sin(u)*RAD,c[2]+sz*TH*0.7);Nn.push(Math.cos(u)*0.3,Math.sin(u)*0.3,sz*0.95);}
    for(let i=0;i<SEG;i++){const p1=b0+1+i,p2=b0+1+(i+1)%SEG;if(sz>0)I.push(b0,p1,p2);else I.push(b0,p2,p1);}}
  const rim=P.length/3;for(let i=0;i<SEG;i++){const u=i/SEG*Math.PI*2;for(const sz of [1,-1]){P.push(c[0]+Math.cos(u)*RAD,c[1]+Math.sin(u)*RAD,c[2]+sz*TH*0.7);Nn.push(Math.cos(u),Math.sin(u),0);}}
  for(let i=0;i<SEG;i++){const a0=rim+i*2,a1=rim+i*2+1,b1=rim+((i+1)%SEG)*2,b2=rim+((i+1)%SEG)*2+1;I.push(a0,a1,b2,a0,b2,b1);}
  // выпуклый ромб в центре медальона
  const d0=P.length/3;const K=0.02;const q=[[0,K],[K,0],[0,-K],[-K,0]];P.push(c[0],c[1],c[2]+TH*1.9);Nn.push(0,0,1);for(const e of q){P.push(c[0]+e[0],c[1]+e[1],c[2]+TH);Nn.push(e[0]*30,e[1]*30,0.6);}
  for(let i=0;i<4;i++)I.push(d0,d0+1+(i+1)%4,d0+1+i);
  torus([c[0],c[1]+RAD+R*0.55,c[2]],[0,1,0],[1,0,0],R*0.8,r,1.0);
})();
console.log('звеньев',count,'длина',total.toFixed(3),'вершин',P.length/3,'тр-ков',I.length/3,'низ',low.map(x=>x.toFixed(3)).join(','));
const pb=Buffer.alloc(P.length*4),nb=Buffer.alloc(Nn.length*4),ib=Buffer.alloc(I.length*4);
P.forEach((v,i)=>pb.writeFloatLE(v,i*4));for(let i=0;i<Nn.length;i+=3){const l=Math.hypot(Nn[i],Nn[i+1],Nn[i+2])||1;for(let k=0;k<3;k++)nb.writeFloatLE(Nn[i+k]/l,(i+k)*4);}I.forEach((v,i)=>ib.writeUInt32LE(v,i*4));
const mn=[9,9,9],mx=[-9,-9,-9];for(let i=0;i<P.length;i+=3)for(let k=0;k<3;k++){mn[k]=Math.min(mn[k],P[i+k]);mx[k]=Math.max(mx[k],P[i+k]);}
const g={asset:{version:'2.0',generator:'GOD OF GRIMERKA golda67-chain'},scene:0,scenes:[{nodes:[0]}],nodes:[{name:'MishaChain',mesh:0}],
 meshes:[{name:'MishaChain',primitives:[{attributes:{POSITION:0,NORMAL:1},indices:2,material:0}]}],
 materials:[{name:'gold',pbrMetallicRoughness:{baseColorFactor:[1.0,0.78,0.2,1],metallicFactor:0.55,roughnessFactor:0.32},emissiveFactor:[0.16,0.11,0.02]}],
 buffers:[{byteLength:pb.length+nb.length+ib.length}],
 bufferViews:[{buffer:0,byteOffset:0,byteLength:pb.length,target:34962},{buffer:0,byteOffset:pb.length,byteLength:nb.length,target:34962},{buffer:0,byteOffset:pb.length+nb.length,byteLength:ib.length,target:34963}],
 accessors:[{bufferView:0,componentType:5126,count:P.length/3,type:'VEC3',min:mn,max:mx},{bufferView:1,componentType:5126,count:P.length/3,type:'VEC3'},{bufferView:2,componentType:5125,count:I.length,type:'SCALAR'}]};
let js=Buffer.from(JSON.stringify(g));js=Buffer.concat([js,Buffer.alloc((4-js.length%4)%4,0x20)]);const body=Buffer.concat([pb,nb,ib]);
const h=Buffer.alloc(12);h.write('glTF');h.writeUInt32LE(2,4);h.writeUInt32LE(12+8+js.length+8+body.length,8);
const c1=Buffer.alloc(8);c1.writeUInt32LE(js.length,0);c1.write('JSON',4);const c2=Buffer.alloc(8);c2.writeUInt32LE(body.length,0);c2.write('BIN\0',4);
fs.writeFileSync(dst,Buffer.concat([h,c1,js,c2,body]));
