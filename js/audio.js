// Procedural sound effects for the web build (mirrors godot/scripts/sfx.gd).
// Every sound is synthesized into an AudioBuffer at startup; no audio files needed.
class Sfx {
  constructor() {
    this.ctx = null; this.buffers = {}; this.lastPlay = {}; this.muted = false; this.volume = 0.8;
    this.rate = 22050; this.rng = 1234567;
    this.view = { x: 0, y: 0, w: 1600, h: 800 };
  }
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain(); this.master.gain.value = this.volume; this.master.connect(this.ctx.destination);
    this.buildLibrary();
  }
  rand() { this.rng = (this.rng * 1664525 + 1013904223) >>> 0; return this.rng / 4294967296 * 2 - 1; }
  synth(dur, f0, f1, decay, noise, wave = 'sine', gain = 0.8) {
    const n = Math.floor(dur * this.rate), out = new Float32Array(n);
    let phase = 0, lp = 0; const dt = 1 / this.rate;
    for (let i = 0; i < n; i++) {
      const k = i / n, f = f0 + (f1 - f0) * k;
      phase += f * dt * Math.PI * 2;
      const ph = phase % (Math.PI * 2);
      let v = wave === 'square' ? (ph < Math.PI ? 1 : -1) : wave === 'saw' ? ph / Math.PI - 1 : wave === 'tri' ? Math.abs(ph / Math.PI - 1) * 2 - 1 : Math.sin(phase);
      if (noise > 0) { lp += (this.rand() - lp) * 0.35; v = v * (1 - noise) + lp * noise * 1.6; }
      const env = Math.exp(-decay * i * dt) * Math.min(1, i / (0.004 * this.rate));
      out[i] = v * env * gain;
    }
    return out;
  }
  mix(a, b, offset = 0) {
    const off = Math.floor(offset * this.rate), n = Math.max(a.length, b.length + off), out = new Float32Array(n);
    for (let i = 0; i < a.length; i++) out[i] += a[i];
    for (let i = 0; i < b.length; i++) out[i + off] += b[i];
    return out;
  }
  buildLibrary() {
    const S = (...a) => this.synth(...a), M = (...a) => this.mix(...a);
    const L = {
      hit: S(0.09, 180, 90, 40, 0.7, 'tri', 0.7),
      hit_heavy: M(S(0.2, 120, 50, 18, 0.6, 'tri', 0.9), S(0.12, 60, 40, 25, 0, 'sine', 0.6)),
      shoot_arrow: S(0.12, 900, 300, 30, 0.9, 'sine', 0.35),
      shoot_bolt: S(0.16, 300, 1200, 18, 0.15, 'saw', 0.35),
      shoot_shell: S(0.3, 90, 40, 12, 0.8, 'tri', 0.8),
      death: M(S(0.35, 420, 110, 9, 0.3, 'saw', 0.5), S(0.2, 200, 60, 20, 0.8, 'tri', 0.5), 0.03),
      death_big: M(S(0.7, 160, 40, 5, 0.4, 'saw', 0.7), S(0.5, 50, 30, 6, 0.9, 'tri', 0.8)),
      death_building: M(S(0.9, 70, 30, 4, 0.9, 'tri', 0.9), S(0.6, 40, 25, 5, 0, 'sine', 0.7), 0.1),
      ready: M(S(0.18, 660, 660, 12, 0, 'sine', 0.4), S(0.3, 990, 990, 9, 0, 'sine', 0.4), 0.12),
      tier: M(M(S(0.25, 523, 523, 8, 0, 'sine', 0.4), S(0.25, 659, 659, 8, 0, 'sine', 0.4), 0.15), S(0.5, 784, 784, 5, 0, 'sine', 0.45), 0.3),
      cast: S(0.3, 250, 1400, 9, 0.1, 'sine', 0.45),
      ult: M(S(0.6, 80, 600, 5, 0.2, 'saw', 0.5), S(0.8, 40, 30, 4, 0.7, 'tri', 0.7), 0.1),
      select: S(0.06, 800, 1100, 45, 0, 'square', 0.18),
      ack: M(S(0.05, 700, 700, 50, 0, 'square', 0.16), S(0.06, 1000, 1000, 45, 0, 'square', 0.16), 0.06),
      error: S(0.18, 140, 120, 15, 0, 'square', 0.25),
      warn: M(S(0.15, 880, 880, 10, 0, 'square', 0.22), S(0.2, 660, 660, 8, 0, 'square', 0.22), 0.16),
      build_done: M(S(0.1, 300, 300, 20, 0.6, 'tri', 0.4), S(0.25, 520, 520, 10, 0, 'sine', 0.35), 0.08),
      gather: S(0.05, 1400, 900, 60, 0.5, 'tri', 0.15),
    };
    for (const k in L) { const b = this.ctx.createBuffer(1, L[k].length, this.rate); b.copyToChannel(L[k], 0); this.buffers[k] = b; }
  }
  setVolume(v) { this.volume = v; if (this.master) this.master.gain.value = v; }
  // x < 0 plays non-positionally
  play(name, x = -1, y = 0, db = 0, minGap = 0.05, pitchVar = 0.08) {
    if (this.muted || !this.ctx || !this.buffers[name]) return;
    const now = this.ctx.currentTime;
    if (now - (this.lastPlay[name] ?? -1) < minGap) return;
    this.lastPlay[name] = now;
    let gain = Math.pow(10, db / 20), pan = 0;
    if (x >= 0) {
      const cx = this.view.x + this.view.w / 2, cy = this.view.y + this.view.h / 2;
      const d = Math.hypot(x - cx, y - cy);
      if (d > 1500) return;
      gain *= Math.max(0.08, 1 - d / 1500);
      pan = Math.max(-1, Math.min(1, (x - cx) / (this.view.w * 0.8)));
    }
    const src = this.ctx.createBufferSource(); src.buffer = this.buffers[name];
    src.playbackRate.value = 1 + (this.rand() * pitchVar);
    const g = this.ctx.createGain(); g.gain.value = gain;
    let node = g;
    if (this.ctx.createStereoPanner) { const p = this.ctx.createStereoPanner(); p.pan.value = pan; g.connect(p); node = p; }
    node.connect(this.master); src.connect(g); src.start();
  }
  // Translate a simulation event into sound; returns screen-shake amplitude
  handle(ev, human) {
    const mine = ev.owner === human;
    switch (ev.type) {
      case 'hit': if (ev.dmg >= 45) { this.play('hit_heavy', ev.x, ev.y, -2, 0.08); return 2.5; } this.play('hit', ev.x, ev.y, -8, 0.045); return 0;
      case 'shoot': this.play('shoot_' + (ev.kind || 'arrow'), ev.x, ev.y, -6, 0.06, 0.15); return 0;
      case 'death':
        if (ev.building) { this.play('death_building', ev.x, ev.y, 2, 0.1); return 9; }
        if (ev.big) { this.play('death_big', ev.x, ev.y, 0, 0.1); return 5; }
        this.play('death', ev.x, ev.y, -4, 0.06, 0.2); return 0;
      case 'ready': if (mine) this.play('ready', -1, 0, -4, 0.2); return 0;
      case 'tier': if (mine) this.play('tier', -1, 0, 0, 0.5); return 0;
      case 'build_done': if (mine) this.play('build_done', -1, 0, -4, 0.2); return 0;
      case 'cast': if (ev.ult) { this.play('ult', ev.x, ev.y, 2, 0.3); return 6; } this.play('cast', ev.x, ev.y, -3, 0.1, 0.2); return 0;
      case 'select': this.play('select', -1, 0, -6, 0.05, 0.02); return 0;
      case 'ack': this.play('ack', -1, 0, -6, 0.08, 0.05); return 0;
      case 'error': this.play('error', -1, 0, -4, 0.15); return 0;
      case 'warn': this.play('warn', -1, 0, -2, 1.0); return 0;
      case 'gather': this.play('gather', ev.x, ev.y, -10, 0.2, 0.3); return 0;
    }
    return 0;
  }
}
