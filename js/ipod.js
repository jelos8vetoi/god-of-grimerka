(() => {
'use strict';
class IPodHUD {
  constructor(player) {
    this.player = player;
    this.element = document.getElementById('ipod');
    this.canvas = document.getElementById('ipod-display');
    this.depthPanel = document.getElementById('ipod-depth');
    this.depthInput = document.getElementById('ipod-reverb');
    this.depthValue = document.getElementById('ipod-reverb-value');
    this.depthInput.addEventListener('input', () => this.setDepth(Number(this.depthInput.value)));
    this.active = false;
    this.page = 'Now Playing';
    this.selected = 0;
    this.element.addEventListener('click', event => {
      const button = event.target.closest('button[data-action]');
      if (button) this.action(button.dataset.action);
    });
    this.canvas.addEventListener('click', event => {
      const bounds = this.canvas.getBoundingClientRect();
      const y = (event.clientY - bounds.top) / bounds.height * 302;
      const items = this.items();
      const row = Math.floor((y - 57) / 36);
      if (items.length && row >= 0 && row < 5) {
        const index = Math.max(0, this.selected - 4) + row;
        if (index >= items.length) return;
        this.selected = index;
      }
      this.action('select');
    });
    this.element.addEventListener('wheel', event => {
      event.preventDefault();
      if (event.deltaY) this.scroll(Math.sign(event.deltaY));
    }, { passive: false });
    this.draw();
  }
  open() {
    this.active = true;
    this.element.inert = false;
    this.element.classList.remove('instant');
    this.element.classList.add('open');
    this.update();
  }
  close(fast = false) {
    if (!this.active && !fast) return;
    this.active = false;
    this.element.inert = true;
    this.element.classList.toggle('instant', fast);
    this.element.classList.remove('open');
  }
  get fullyOpen() {
    return this.active && !this.element.getAnimations().some(animation => animation.transitionProperty === 'transform');
  }
  update() {
    if (!this.active) return;
    const { audio, index, tracks, volume } = this.player;
    const signature = [this.page, this.selected, index, audio.paused, Math.floor(audio.currentTime), Math.floor(audio.duration || 0), tracks.length, volume].join('|');
    if (signature !== this.signature) { this.signature = signature; this.draw(); }
  }
  items() {
    if (this.page === 'Menu') return ['Music','Playlists','Now Playing','Settings'];
    if (this.page === 'Music') return [...this.player.tracks.map(t=>t.title),'Добавить свою музыку'];
    if (this.page === 'Playlists') return ['Все треки','Встроенная музыка','Моя музыка'];
    if (this.page === 'Settings') return ['Звук','Удалить текущий трек'];
    if (this.page === 'Звук') return ['Reverb Depth','Громкость'];
    if (this.page === 'Встроенная музыка' || this.page === 'Моя музыка') return this.filtered().map(t=>t.title);
    return [];
  }
  filtered() { return this.player.tracks.filter(t=>this.page === 'Моя музыка' ? t.local : !t.local); }
  action(action) {
    if (action === 'menu') {
      const back = { 'Reverb Depth': 'Звук', 'Громкость': 'Звук', 'Звук': 'Settings' };
      this.page = back[this.page] || 'Menu';
      this.selected = 0;
    }
    if (action === 'play') this.player.toggle();
    if (action === 'next') this.player.next(1);
    if (action === 'prev') this.player.next(-1);
    if (action === 'select') {
      const item = this.items()[this.selected];
      if (this.page === 'Reverb Depth') this.depthInput.focus();
      else if (this.page === 'Now Playing') this.page = 'Перемотка';
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
  scroll(delta) {
    if (this.page === 'Reverb Depth') this.setDepth(Math.round(this.player.reverbDepth * 100) + delta * 5);
    else if (this.page === 'Громкость') { this.player.volume=Math.max(0,Math.min(1,this.player.volume+delta*.05)); this.player.save(); }
    else if (this.page === 'Перемотка' || this.page === 'Now Playing') this.player.seek(delta*5);
    else this.selected=Math.max(0,Math.min(this.items().length-1,this.selected+delta));
    this.draw();
  }
  setDepth(percent) {
    this.player.setReverbDepth(percent / 100);
    this.depthInput.value = Math.round(this.player.reverbDepth * 100);
    this.depthValue.value = this.depthInput.value + '%';
  }
  draw() {
    this.depthPanel.hidden = this.page !== 'Reverb Depth';
    this.depthInput.value = Math.round(this.player.reverbDepth * 100);
    this.depthValue.value = this.depthInput.value + '%';
    const x=this.canvas.getContext('2d'), p=this.player, a=p.audio, track=p.tracks[p.index];
    x.fillStyle='#e0e4dc';x.fillRect(0,0,512,302);
    x.fillStyle='#b6c1c7';x.fillRect(26,20,460,32);x.fillStyle='#20252a';x.font='bold 28px Arial';x.fillText(this.page,36,44);x.fillText(a.paused?'Ⅱ':'▶',445,44);
    const items=this.items();x.font='27px Arial';
    if(this.page === 'Reverb Depth') return;
    if(items.length) { const offset=Math.max(0,this.selected-4);items.slice(offset,offset+5).forEach((item,i)=>{ if(offset+i===this.selected){x.fillStyle='#5b8fbd';x.fillRect(28,57+i*36,456,34);}x.fillStyle='#17222b';x.fillText(item.slice(0,31),38,82+i*36);}); }
    else if(this.page==='Громкость') x.fillText(Math.round(p.volume*100)+' %',180,145);
    else { x.fillStyle='#536879';x.fillRect(40,69,110,110);x.fillStyle='#d7dce0';x.font='64px Arial';x.fillText('♪',65,150);x.fillStyle='#20252a';x.font='bold 29px Arial';x.fillText((track?.title||'Выбери музыку').slice(0,24),164,94);x.font='24px Arial';x.fillText(track?.artist||'',164,126);x.fillText(`${Math.max(0,p.index+1)} / ${p.tracks.length}`,164,158);
      const format=t=>Number.isFinite(t)?`${Math.floor(t/60)}:${String(Math.floor(t%60)).padStart(2,'0')}`:'0:00';x.fillText(format(a.currentTime),40,270);x.fillText(format(a.duration),410,270);x.fillStyle='#9fa8ab';x.fillRect(115,249,280,12);x.fillStyle='#548ebc';x.fillRect(115,249,280*(a.currentTime/(a.duration||1)),12); }
  }
}
window.IPodHUD = IPodHUD;
})();
