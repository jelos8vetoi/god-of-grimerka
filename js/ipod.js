(() => {
'use strict';
const T = THREE, ease = t => t * t * (3 - 2 * t);
class PhysicalIPod {
  constructor(player) {
    this.player = player; this.state = 'HIDDEN'; this.blend = 0; this.page = 'Now Playing'; this.selected = 0; this.press = 0;
    this.canvas = document.createElement('canvas'); this.canvas.width = 512; this.canvas.height = 512;
    this.texture = new T.CanvasTexture(this.canvas); this.texture.encoding = T.sRGBEncoding;
    this.group = new T.Group(); this.group.name = 'Physical iPod';
    const shape = new T.Shape(), w = .42, h = .72, r = .07;
    shape.moveTo(-w+r,-h); shape.lineTo(w-r,-h); shape.quadraticCurveTo(w,-h,w,-h+r); shape.lineTo(w,h-r); shape.quadraticCurveTo(w,h,w-r,h); shape.lineTo(-w+r,h); shape.quadraticCurveTo(-w,h,-w,h-r); shape.lineTo(-w,-h+r); shape.quadraticCurveTo(-w,-h,-w+r,-h);
    const body = new T.Mesh(new T.ExtrudeGeometry(shape,{depth:.09,bevelEnabled:true,bevelThickness:.025,bevelSize:.025,bevelSegments:3,steps:1}),new T.MeshStandardMaterial({color:0xb7bac0,metalness:.65,roughness:.34})); this.group.add(body);
    this.face = new T.Mesh(new T.PlaneGeometry(.77,1.32),new T.MeshBasicMaterial({map:this.texture})); this.face.position.set(0,0,.122); this.group.add(this.face);
    const wheelRim = new T.Mesh(new T.TorusGeometry(.168,.008,6,48),new T.MeshStandardMaterial({color:0xe4e3df,roughness:.6}));
    wheelRim.position.set(0,-.346,.135); this.group.add(wheelRim);
    const select = new T.Mesh(new T.CylinderGeometry(.054,.054,.012,32),new T.MeshStandardMaterial({color:0x9e9d99,roughness:.5}));
    select.rotation.x=Math.PI/2; select.position.set(0,-.346,.137); this.group.add(select);
    this.group.visible = false; this.ray = new T.Raycaster(); this.pointer = new T.Vector2(); this.bones = [];
    this.draw();
  }
  attach(model) {
    if (this.model === model) return; this.model = model; this.bones = [];
    let hand; model.traverse(b => { if (/^handslot\.?l$/i.test(b.name)) hand = b;
      if (b.isBone && ['upperarml','lowerarml','wristl','upperarmr','lowerarmr','head'].includes(b.name)) this.bones.push({bone:b,base:b.quaternion.clone()}); });
    if (!hand) hand = model.getObjectByName('handl');
    if (hand) { hand.add(this.group); this.group.scale.setScalar(.42); this.group.position.set(0,.12,0); }
  }
  restore() { for (const b of this.bones) b.bone.quaternion.copy(b.base); }
  toggle() { this.state = this.state === 'HIDDEN' || this.state === 'UNEQUIPPING' ? 'EQUIPPING' : 'UNEQUIPPING'; }
  close(fast = false) { if (this.state !== 'HIDDEN') this.state = 'UNEQUIPPING'; if (fast) { this.blend = 0; this.state = 'HIDDEN'; this.group.visible = false; } }
  get active() { return this.state !== 'HIDDEN'; }
  update(dt, camera, now) {
    for (const b of this.bones) b.base.copy(b.bone.quaternion);
    if (this.state === 'EQUIPPING') { this.blend = Math.min(1,this.blend+dt/.55); if (this.blend === 1) this.state = 'HOLDING'; }
    if (this.state === 'UNEQUIPPING') { this.blend = Math.max(0,this.blend-dt/.45); if (!this.blend) this.state = 'HIDDEN'; }
    this.group.visible = this.active; this.press = Math.max(0,this.press-dt);
    const amount = ease(this.blend), angles = {upperarml:.55,lowerarml:.85,wristl:.3,upperarmr:.1,lowerarmr:.35+this.press,head:.18};
    for (const b of this.bones) b.bone.rotateX(angles[b.bone.name]*amount);
    if (this.active && this.group.parent) {
      // The attachment stays on the hand. Only the wrist-held device faces the viewer.
      this.group.parent.updateWorldMatrix(true,false);
      const hand = this.group.getWorldPosition(new T.Vector3());
      const forward = new T.Vector3(1,0,0).applyQuaternion(this.model.parent.parent.quaternion);
      const cameraPosition = hand.clone().addScaledVector(forward, 55).add(new T.Vector3(0,18,0));
      camera.position.lerp(cameraPosition, amount);
      const target = hand.clone().add(new T.Vector3(0,8,0).add(new T.Vector3(0,0,18).applyQuaternion(this.model.parent.parent.quaternion)));
      const original = camera.quaternion.clone(); camera.lookAt(target); camera.quaternion.copy(original.slerp(camera.quaternion.clone(), amount)); camera.updateMatrixWorld();
      const parentRotation = this.group.parent.getWorldQuaternion(new T.Quaternion());
      this.group.quaternion.copy(parentRotation.invert().multiply(camera.quaternion));
      this.group.rotateZ(Math.sin(now*2)*.018);
    }
    const signature = [this.page,this.selected,this.player.index,this.player.audio.paused,Math.floor(this.player.audio.currentTime),Math.floor(this.player.audio.duration||0),this.player.tracks.length,this.player.volume].join('|');
    if (signature !== this.signature) { this.signature = signature; this.draw(); }
  }
  items() {
    if (this.page === 'Menu') return ['Music','Playlists','Now Playing','Settings'];
    if (this.page === 'Music') return [...this.player.tracks.map(t=>t.title),'Добавить свою музыку'];
    if (this.page === 'Playlists') return ['Все треки','Встроенная музыка','Моя музыка'];
    if (this.page === 'Settings') return ['Громкость','Удалить текущий трек'];
    if (this.page === 'Встроенная музыка' || this.page === 'Моя музыка') return this.filtered().map(t=>t.title);
    return [];
  }
  filtered() { return this.player.tracks.filter(t=>this.page === 'Моя музыка' ? t.local : !t.local); }
  action(action) {
    this.press = .18;
    if (action === 'menu') { this.page = 'Menu'; this.selected = 0; }
    if (action === 'play') this.player.toggle();
    if (action === 'next') this.player.next(1);
    if (action === 'prev') this.player.next(-1);
    if (action === 'select') {
      const item = this.items()[this.selected];
      if (this.page === 'Now Playing') this.page = 'Перемотка';
      else if (this.page === 'Music') { if (this.selected === this.player.tracks.length) this.player.input.click(); else { this.player.select(this.selected); this.page = 'Now Playing'; } }
      else if (this.page === 'Моя музыка' || this.page === 'Встроенная музыка') { this.player.select(this.player.tracks.indexOf(this.filtered()[this.selected])); this.page = 'Now Playing'; }
      else if (item === 'Все треки') this.page = 'Music';
      else if (item === 'Удалить текущий трек') this.player.remove(this.player.index);
      else if (item) this.page = item;
      else this.page = 'Now Playing';
      this.selected = 0;
    }
    this.draw();
  }
  scroll(delta) { this.press=.12;
    if (this.page === 'Громкость') { this.player.volume=Math.max(0,Math.min(1,this.player.volume+delta*.05)); this.player.save(); }
    else if (this.page === 'Перемотка' || this.page === 'Now Playing') this.player.seek(delta*5);
    else this.selected=Math.max(0,Math.min(this.items().length-1,this.selected+delta));
    this.draw();
  }
  hit(event,camera,canvas) {
    if (!this.active) return null;
    const rect=canvas.getBoundingClientRect(); this.pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);
    this.ray.setFromCamera(this.pointer,camera); return this.ray.intersectObject(this.face)[0];
  }
  click(event,camera,canvas) {
    const hit=this.hit(event,camera,canvas); if (!hit) return false;
    const x=hit.uv.x,y=1-hit.uv.y;
    if(y<.51) this.action('select');
    else if(Math.hypot((x-.5), (y-.76)*1.7)<.13) this.action('select');
    else if(y<.66) this.action('menu'); else if(y>.88) this.action('play'); else this.action(x<.5?'prev':'next');
    return true;
  }
  draw() {
    const x=this.canvas.getContext('2d'), p=this.player, a=p.audio, track=p.tracks[p.index];
    x.fillStyle='#bcbec1';x.fillRect(0,0,512,512); x.fillStyle='#16191b';x.fillRect(18,12,476,244);x.fillStyle='#e0e4dc';x.fillRect(26,20,460,228);
    x.fillStyle='#b6c1c7';x.fillRect(26,20,460,32);x.fillStyle='#20252a';x.font='bold 22px Arial';x.fillText(this.page,36,44);x.fillText(a.paused?'Ⅱ':'▶',445,44);
    const items=this.items();x.font='22px Arial';
    if(items.length) { const offset=Math.max(0,this.selected-4);items.slice(offset,offset+5).forEach((item,i)=>{ if(offset+i===this.selected){x.fillStyle='#5b8fbd';x.fillRect(28,57+i*36,456,34);}x.fillStyle='#17222b';x.fillText(item.slice(0,31),38,82+i*36);}); }
    else if(this.page==='Громкость') x.fillText(Math.round(p.volume*100)+' %',180,145);
    else { x.fillStyle='#536879';x.fillRect(40,69,110,110);x.fillStyle='#d7dce0';x.font='64px Arial';x.fillText('♪',65,150);x.fillStyle='#20252a';x.font='bold 23px Arial';x.fillText((track?.title||'Выбери музыку').slice(0,24),164,94);x.font='18px Arial';x.fillText(track?.artist||'',164,126);x.fillText(`${Math.max(0,p.index+1)} / ${p.tracks.length}`,164,158);
      const format=t=>Number.isFinite(t)?`${Math.floor(t/60)}:${String(Math.floor(t%60)).padStart(2,'0')}`:'0:00';x.fillText(format(a.currentTime),40,230);x.fillText(format(a.duration),410,230);x.fillStyle='#9fa8ab';x.fillRect(115,210,280,12);x.fillStyle='#548ebc';x.fillRect(115,210,280*(a.currentTime/(a.duration||1)),12); }
    x.fillStyle='#e4e3df';x.beginPath();x.arc(256,390,111,0,Math.PI*2);x.fill();x.fillStyle='#9e9d99';x.beginPath();x.arc(256,390,36,0,Math.PI*2);x.fill();x.fillStyle='#636363';x.font='bold 18px Arial';x.textAlign='center';x.fillText('MENU',256,310);x.fillText('◀◀',172,396);x.fillText('▶▶',340,396);x.fillText('▶Ⅱ',256,480);x.textAlign='left';this.texture.needsUpdate=true;
  }
}
window.PhysicalIPod=PhysicalIPod;
})();
