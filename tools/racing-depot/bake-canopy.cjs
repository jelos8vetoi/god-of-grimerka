// Bake the two orthogonal, three-layer foliage projections of the original
// CC0 tree. Each slice retains real branch/leaf silhouettes and internal parallax.
const fs = require('node:fs');
const path = require('node:path');
const [source, dest] = process.argv.slice(2);
const doc = JSON.parse(fs.readFileSync(path.join(source, 'tree_small_02.gltf')));
const binary = fs.readFileSync(path.join(source, 'tree_small_02/tree_small_02.bin'));
function accessor(index) {
  const a = doc.accessors[index], view = doc.bufferViews[a.bufferView];
  const type = {5126: Float32Array, 5125: Uint32Array, 5123: Uint16Array}[a.componentType];
  const width = {VEC3: 3, VEC2: 2, SCALAR: 1}[a.type];
  if (view.byteStride) throw Error('Expected packed glTF attributes');
  return new type(binary.buffer, binary.byteOffset + (view.byteOffset||0) + (a.byteOffset||0), a.count*width);
}
const side = 512, width = side*2, height = side*3;
const rgba = Buffer.alloc(width*height*4);
const depth = new Float32Array(width*height).fill(-Infinity);
const bounds = [[-1.7,1.9],[1.4,4.64],[-1.6,3.2]];
const alpha = fs.readFileSync(path.join(source, 'alpha.raw'));
const mesh = doc.meshes[0].primitives;
for (const part of [0,1]) {
  const texture = fs.readFileSync(path.join(source, part ? 'leaves.raw':'branch.raw'));
  const p=mesh[part], pos=accessor(p.attributes.POSITION), uv=accessor(p.attributes.TEXCOORD_0);
  const norm=accessor(p.attributes.NORMAL), indices=accessor(p.indices);
  for (let axis=0; axis<2; axis++) {
    const horizontal=axis?2:0, inward=axis?0:2;
    const coords=Array.from({length:3},()=>new Float32Array(pos.length/3));
    for(let i=0;i<pos.length/3;i++) {
      coords[0][i]=side*(pos[3*i+horizontal]-bounds[horizontal][0])/(bounds[horizontal][1]-bounds[horizontal][0]);
      coords[1][i]=side*(bounds[1][1]-pos[3*i+1])/(bounds[1][1]-bounds[1][0]);
      coords[2][i]=(pos[3*i+inward]-bounds[inward][0])/(bounds[inward][1]-bounds[inward][0]);
    }
    for(let k=0;k<indices.length;k+=3) {
      const a=indices[k],b=indices[k+1],c=indices[k+2];
      const [x,y,z]=coords, dx1=x[b]-x[a],dy1=y[b]-y[a],dx2=x[c]-x[a],dy2=y[c]-y[a];
      const det=dx1*dy2-dx2*dy1;
      if (Math.abs(det)<0.0001) continue;
      const shade=.80+.20*Math.abs(norm[a*3+1]);
      for(let j=Math.max(0,Math.floor(Math.min(y[a],y[b],y[c])));j<=Math.min(side-1,Math.ceil(Math.max(y[a],y[b],y[c])));j++)
        for(let i=Math.max(0,Math.floor(Math.min(x[a],x[b],x[c])));i<=Math.min(side-1,Math.ceil(Math.max(x[a],x[b],x[c])));i++) {
          const xx=i+.5-x[a], yy=j+.5-y[a];
          const u=(xx*dy2-yy*dx2)/det,v=(yy*dx1-xx*dy1)/det,w=1-u-v;
          if(u<0||v<0||w<0) continue;
          const d=w*z[a]+u*z[b]+v*z[c], slice=Math.max(0,Math.min(2,Math.floor(d*3)));
          const pixel=(slice*side+j)*width+axis*side+i;
          if(d<=depth[pixel]) continue;
          const tx=Math.floor(256*(w*uv[2*a]+u*uv[2*b]+v*uv[2*c]))&255;
          const ty=Math.floor(256*(w*uv[2*a+1]+u*uv[2*b+1]+v*uv[2*c+1]))&255;
          const texel=ty*256+tx;
          if(part && alpha[texel]<105) continue;
          depth[pixel]=d;
          for(let ch=0;ch<3;ch++) rgba[pixel*4+ch]=texture[texel*3+ch]*shade;
          rgba[pixel*4+3]=255;
        }
    }
  }
}
fs.writeFileSync(path.join(source,'canopy.rgba'),rgba);
const obj=['o Canopy'];let n=0;
for(let axis=0;axis<2;axis++) for(let slice=0;slice<3;slice++){
  const h=axis?2:0,d=axis?0:2;
  for(const [u,v] of [[0,0],[1,0],[1,1],[0,1]]){
    const p=[0,bounds[1][v],0];
    p[h]=bounds[h][u]; p[d]=bounds[d][0]+(slice+.5)/3*(bounds[d][1]-bounds[d][0]);
    obj.push('v '+p.join(' '),'vt '+((axis+u)/2)+' '+(1-(slice+1-v)/3));
  }
  obj.push('vn 0 1 0','f '+[1,2,3,4].map(i=>(n*4+i)+'/'+(n*4+i)+'/'+(n+1)).join(' ')); n++;
}
fs.writeFileSync(path.join(dest,'canopy.obj'),obj.join('\n')+'\n');
