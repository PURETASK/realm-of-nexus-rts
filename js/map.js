// Tile map: terrain, resource nodes, corruption (blight) layer
class GameMap {
  constructor(seed) {
    this.w = MAP_W; this.h = MAP_H;
    this.n = this.w * this.h;
    this.terrain = new Uint8Array(this.n);     // 0 ground, 1 rock
    this.blocked = new Uint8Array(this.n);     // ground blocking (rock or building)
    this.airBlocked = new Uint8Array(this.n);  // air blocking (tempest barriers)
    this.corruption = new Float32Array(this.n);
    this.corruptSrc = new Float32Array(this.n); // per-frame source strength accumulator
    this.layers = { blight: this.corruption, light: new Float32Array(this.n), grove: new Float32Array(this.n) };
    this.layerSrc = { blight: this.corruptSrc, light: new Float32Array(this.n), grove: new Float32Array(this.n) };
    this.nodes = [];
    this.starts = [{ tx: 7, ty: 49 }, { tx: 70, ty: 8 }];
    this.decor = [];
    let s = seed;
    for (let attempt = 0; attempt < 30; attempt++) {
      if (this.generate(s + attempt * 7919)) break;
    }
  }

  idx(tx, ty) { return ty * this.w + tx; }
  inBounds(tx, ty) { return tx >= 0 && ty >= 0 && tx < this.w && ty < this.h; }

  generate(seed) {
    const rng = mulberry32(seed);
    this.terrain.fill(0); this.blocked.fill(0); this.airBlocked.fill(0); this.corruption.fill(0);
    if (this.layers) { this.layers.light.fill(0); this.layers.grove.fill(0); }
    this.nodes = []; this.decor = [];
    const clear = (tx, ty) => this.starts.some(s => dist(tx, ty, s.tx + 1, s.ty + 1) < 13);
    // Border rocks
    for (let x = 0; x < this.w; x++) { this.terrain[this.idx(x, 0)] = 1; this.terrain[this.idx(x, this.h - 1)] = 1; }
    for (let y = 0; y < this.h; y++) { this.terrain[this.idx(0, y)] = 1; this.terrain[this.idx(this.w - 1, y)] = 1; }
    // Rock blobs
    const blobs = 70;
    for (let b = 0; b < blobs; b++) {
      let x = Math.floor(rng() * this.w), y = Math.floor(rng() * this.h);
      const len = 3 + Math.floor(rng() * 9);
      for (let i = 0; i < len; i++) {
        if (this.inBounds(x, y) && !clear(x, y)) {
          this.terrain[this.idx(x, y)] = 1;
          if (rng() < 0.5 && this.inBounds(x + 1, y) && !clear(x + 1, y)) this.terrain[this.idx(x + 1, y)] = 1;
          if (rng() < 0.4 && this.inBounds(x, y + 1) && !clear(x, y + 1)) this.terrain[this.idx(x, y + 1)] = 1;
        }
        const d = Math.floor(rng() * 4);
        x += [1, -1, 0, 0][d]; y += [0, 0, 1, -1][d];
      }
    }
    // Decor (visual only)
    for (let i = 0; i < 260; i++) this.decor.push({ x: rng() * WORLD_W, y: rng() * WORLD_H, t: rng() < 0.7 ? 0 : 1, r: 2 + rng() * 4 });
    for (let i = 0; i < this.n; i++) this.blocked[i] = this.terrain[i];

    // Connectivity check between starts
    if (!this.connected(this.starts[0].tx - 1, this.starts[0].ty - 1, this.starts[1].tx - 1, this.starts[1].ty - 1)) return false;

    // Resource nodes
    const placeNode = (type, tx, ty, amount) => {
      if (!this.areaFree(tx, ty, 2, 2)) return false;
      for (const n of this.nodes) if (dist(n.tx, n.ty, tx, ty) < 4) return false;
      this.nodes.push({ id: uid(), type, tx, ty, w: 2, h: 2, x: (tx + 1) * TILE, y: (ty + 1) * TILE, amount, max: amount, building: null });
      return true;
    };
    for (const s of this.starts) {
      let placed = 0, tries = 0;
      while (placed < 3 && tries++ < 400) {
        const a = rng() * Math.PI * 2, r = 6 + rng() * 4;
        const tx = Math.round(s.tx + 1 + Math.cos(a) * r), ty = Math.round(s.ty + 1 + Math.sin(a) * r);
        if (!this.inBounds(tx, ty) || !this.inBounds(tx + 1, ty + 1)) continue;
        if (Math.abs(tx - s.tx) < 4 && Math.abs(ty - s.ty) < 4) continue;
        if (placeNode('primary', tx, ty, 1500)) placed++;
      }
      placed = 0; tries = 0;
      while (placed < 1 && tries++ < 400) {
        const a = rng() * Math.PI * 2, r = 7 + rng() * 4;
        const tx = Math.round(s.tx + 1 + Math.cos(a) * r), ty = Math.round(s.ty + 1 + Math.sin(a) * r);
        if (!this.inBounds(tx, ty) || !this.inBounds(tx + 1, ty + 1)) continue;
        if (Math.abs(tx - s.tx) < 4 && Math.abs(ty - s.ty) < 4) continue;
        if (placeNode('secondary', tx, ty, 1e9)) placed++;
      }
      if (placed < 1) return false;
    }
    let mid = 0, tries = 0;
    while (mid < 8 && tries++ < 3000) {
      const tx = 3 + Math.floor(rng() * (this.w - 6)), ty = 3 + Math.floor(rng() * (this.h - 6));
      if (this.starts.some(s => dist(tx, ty, s.tx, s.ty) < 18)) continue;
      if (placeNode(mid < 5 ? 'primary' : 'secondary', tx, ty, 2500)) mid++;
    }
    return this.nodes.filter(n => n.type === 'primary').length >= 9;
  }

  connected(ax, ay, bx, by) {
    const seen = new Uint8Array(this.n);
    const q = [[ax, ay]]; seen[this.idx(ax, ay)] = 1;
    while (q.length) {
      const [x, y] = q.shift();
      if (x === bx && y === by) return true;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, ny = y + dy;
        if (!this.inBounds(nx, ny)) continue;
        const i = this.idx(nx, ny);
        if (seen[i] || this.terrain[i]) continue;
        seen[i] = 1; q.push([nx, ny]);
      }
    }
    return false;
  }

  areaFree(tx, ty, w, h, ignoreNodes) {
    for (let y = ty; y < ty + h; y++) for (let x = tx; x < tx + w; x++) {
      if (!this.inBounds(x, y)) return false;
      if (this.blocked[this.idx(x, y)]) return false;
    }
    if (!ignoreNodes) {
      for (const n of this.nodes) {
        if (tx < n.tx + n.w && tx + w > n.tx && ty < n.ty + n.h && ty + h > n.ty) return false;
      }
    }
    return true;
  }

  nodeUnder(tx, ty, w, h) {
    for (const n of this.nodes) {
      if (n.tx === tx && n.ty === ty && n.w === w && n.h === h) return n;
    }
    return null;
  }

  setBlocked(tx, ty, w, h, val, air) {
    for (let y = ty; y < ty + h; y++) for (let x = tx; x < tx + w; x++) {
      if (!this.inBounds(x, y)) continue;
      const i = this.idx(x, y);
      this.blocked[i] = val ? 1 : this.terrain[i];
      if (air) this.airBlocked[i] = val ? 1 : 0;
    }
  }

  isBlocked(tx, ty, flying) {
    if (!this.inBounds(tx, ty)) return true;
    const i = this.idx(tx, ty);
    return flying ? this.airBlocked[i] === 1 : this.blocked[i] === 1;
  }

  corruptionAtWorld(x, y) {
    const tx = Math.floor(x / TILE), ty = Math.floor(y / TILE);
    if (!this.inBounds(tx, ty)) return 0;
    return this.corruption[this.idx(tx, ty)];
  }

  layerAtWorld(name, x, y) {
    const tx = Math.floor(x / TILE), ty = Math.floor(y / TILE);
    if (!this.inBounds(tx, ty)) return 0;
    return this.layers[name][this.idx(tx, ty)];
  }

  addCorruptionSource(x, y, radius, strength) { this.addLayerSource('blight', x, y, radius, strength); }

  // Mark a terrain-layer source for this frame (world coords, radius in tiles)
  addLayerSource(name, x, y, radius, strength) {
    const srcArr = this.layerSrc[name];
    const cx = Math.floor(x / TILE), cy = Math.floor(y / TILE), r = Math.ceil(radius);
    for (let ty = cy - r; ty <= cy + r; ty++) for (let tx = cx - r; tx <= cx + r; tx++) {
      if (!this.inBounds(tx, ty)) continue;
      const d = dist(tx + 0.5, ty + 0.5, x / TILE, y / TILE);
      if (d > radius) continue;
      const i = this.idx(tx, ty);
      const s = strength * (1 - d / (radius + 1));
      if (s > srcArr[i]) srcArr[i] = s;
    }
  }

  updateCorruption(dt) { this.updateLayers(dt); }

  updateLayers(dt) {
    const light = this.layers.light;
    for (const name of LAYERS) {
      const c = this.layers[name], s = this.layerSrc[name];
      for (let i = 0; i < this.n; i++) {
        if (s[i] > 0) { c[i] = Math.min(1, c[i] + CORRUPTION_GROW * s[i] * dt); s[i] = 0; }
        else if (c[i] > 0) c[i] = Math.max(0, c[i] - CORRUPTION_DECAY * dt * (name === 'blight' && light[i] > 0.3 ? 8 : 1));
      }
    }
  }

  // Find nearest non-blocked tile to (tx,ty)
  nearestFree(tx, ty, flying) {
    if (!this.isBlocked(tx, ty, flying)) return { tx, ty };
    for (let r = 1; r < 12; r++) {
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (Math.abs(dx) !== r && Math.abs(dy) !== r) continue;
        if (!this.isBlocked(tx + dx, ty + dy, flying)) return { tx: tx + dx, ty: ty + dy };
      }
    }
    return { tx, ty };
  }
}
