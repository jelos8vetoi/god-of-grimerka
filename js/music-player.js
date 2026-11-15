(() => {
'use strict';
class MusicPlayer {
  constructor(notify) {
    this.notify = notify; this.audio = new Audio(); this.audio.preload = 'metadata';
    this.tracks = []; this.index = -1; this.volume = .7; this.urls = new Map();
    this.audio.addEventListener('ended', () => this.next(1));
    this.audio.addEventListener('error', () => this.notify('Не удалось прочитать аудиофайл'));
    this.input = document.createElement('input'); this.input.type = 'file'; this.input.multiple = true;
    this.input.accept = 'audio/*,.mp3,.wav,.ogg,.m4a'; this.input.hidden = true; document.body.append(this.input);
    this.input.onchange = async () => { await this.importFiles(this.input.files); this.input.value = ''; };
    this.ready = this.load();
    addEventListener('pagehide', () => { this.save(); for (const url of this.urls.values()) URL.revokeObjectURL(url); });
    this.audio.addEventListener('pause', () => this.save());
  }
  async load() {
    try { this.tracks = (window.GRIMERKA_TRACKS || []).map(track => ({ ...track })); }
    catch { this.notify('Встроенная библиотека недоступна. Можно добавить свои файлы.'); }
    try {
      this.db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('grimerka-music', 1);
        request.onupgradeneeded = () => request.result.createObjectStore('tracks', { keyPath: 'id' });
        request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
      });
      const records = await new Promise((resolve, reject) => { const r = this.db.transaction('tracks').objectStore('tracks').getAll(); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
      for (const record of records) this.addBlob(record);
    } catch { this.notify('Хранилище музыки недоступно. Импорт будет действовать до закрытия игры.'); }
    try {
      const saved = JSON.parse(localStorage.getItem('grimerka-player') || '{}');
      this.volume = Math.max(0, Math.min(1, saved.volume ?? .7));
      const index = this.tracks.findIndex(t => t.id === saved.id);
      if (index >= 0) { this.select(index, false); this.audio.addEventListener('loadedmetadata', () => { this.audio.currentTime = Math.min(saved.time || 0, this.audio.duration || 0); }, { once: true }); }
    } catch {}
  }
  connect(context, master) {
    if (this.context || !context) return;
    this.context = context; this.source = context.createMediaElementSource(this.audio);
    this.low = context.createBiquadFilter(); this.low.type = 'lowpass'; this.low.frequency.value = 22000;
    this.high = context.createBiquadFilter(); this.high.type = 'highpass'; this.high.frequency.value = 10;
    this.dry = context.createGain(); this.wet = context.createGain(); this.wet.gain.value = 0;
    this.gain = context.createGain(); this.gain.gain.value = this.volume;
    const reverb = context.createConvolver(), length = Math.ceil(context.sampleRate * 1.1);
    const impulse = context.createBuffer(2, length, context.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const data = impulse.getChannelData(ch); for (let i = 0; i < length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / length) ** 3; }
    reverb.buffer = impulse; this.source.connect(this.high).connect(this.low);
    this.low.connect(this.dry).connect(this.gain); this.low.connect(reverb).connect(this.wet).connect(this.gain); this.gain.connect(master);
  }
  update(open, muted, priority) {
    if (!this.context) return;
    const state = `${open}|${muted}|${priority}|${this.volume}`;
    if (state === this.lastState) return; this.lastState = state;
    const t = this.context.currentTime;
    this.low.frequency.setTargetAtTime(open ? 5200 : 22000, t, .15);
    this.high.frequency.setTargetAtTime(open ? 160 : 10, t, .15);
    this.wet.gain.setTargetAtTime(open ? .25 : 0, t, .15);
    this.dry.gain.setTargetAtTime(open ? .75 : 1, t, .15);
    this.gain.gain.setTargetAtTime(muted ? 0 : this.volume * priority, t, .15);
  }
  save() { try { localStorage.setItem('grimerka-player', JSON.stringify({ id: this.tracks[this.index]?.id, time: this.audio.currentTime, volume: this.volume })); } catch {} }
  async play() { try { await this.context?.resume(); await this.audio.play(); } catch { this.notify('Нажми Play ещё раз, чтобы разрешить воспроизведение'); } }
  select(index, play = true) { if (!this.tracks[index]) return; this.index = index; this.audio.src = this.tracks[index].src; if (play) this.play(); this.save(); }
  toggle() { if (this.index < 0) this.select(0); else if (this.audio.paused) this.play(); else this.audio.pause(); }
  next(delta) { if (this.tracks.length) this.select((this.index + delta + this.tracks.length) % this.tracks.length); }
  seek(delta) { if (Number.isFinite(this.audio.duration)) this.audio.currentTime = Math.max(0, Math.min(this.audio.duration, this.audio.currentTime + delta)); }
  addBlob(record) { const src = URL.createObjectURL(record.file); this.urls.set(record.id, src); this.tracks.push({ ...record, src, local: true }); }
  async importFiles(files) {
    for (const file of files) {
      if (!/\.(mp3|wav|ogg|m4a|aac|flac|webm)$/i.test(file.name)) { this.notify('Неподдерживаемый файл: ' + file.name); continue; }
      const record = { id: crypto.randomUUID(), title: file.name.replace(/\.[^.]+$/, ''), artist: '', file };
      if (this.db) try { await new Promise((resolve, reject) => { const tx = this.db.transaction('tracks', 'readwrite'); tx.objectStore('tracks').put(record); tx.oncomplete = resolve; tx.onerror = tx.onabort = () => reject(tx.error); }); }
      catch { this.notify('Не удалось сохранить файл. Он доступен только в этом сеансе.'); }
      this.addBlob(record);
    }
  }
  async remove(index) {
    const track = this.tracks[index]; if (!track?.local) return;
    try { if (this.db) await new Promise((resolve, reject) => { const tx = this.db.transaction('tracks', 'readwrite'); tx.objectStore('tracks').delete(track.id); tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); }); }
    catch { this.notify('Не удалось удалить трек из хранилища'); return; }
    if (index === this.index) { this.audio.pause(); this.audio.removeAttribute('src'); this.audio.load(); this.index = -1; }
    else if (index < this.index) this.index--;
    URL.revokeObjectURL(this.urls.get(track.id)); this.urls.delete(track.id); this.tracks.splice(index, 1); this.save();
  }
}
window.GrimerkaMusicPlayer = MusicPlayer;
})();
