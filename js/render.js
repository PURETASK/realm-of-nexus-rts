// Canvas renderer
class Renderer {
  constructor(game, canvas, minimap) {
    this.g = game; this.canvas = canvas; this.ctx = canvas.getContext('2d');
    this.mm = minimap; this.mctx = minimap.getContext('2d');
    this.hudH = 190;
    this.terrainCanvas = document.createElement('canvas'); this.terrainCanvas.width = WORLD_W; this.terrainCanvas.height = WORLD_H;
    this.fogCanvas = document.createElement('canvas'); this.fogCanvas.width = MAP_W; this.fogCanvas.height = MAP_H;
    this.fogData = this.fogCanvas.getContext('2d').createImageData(MAP_W, MAP_H);
    this.mmTerrain = document.createElement('canvas'); this.mmTerrain.width = MAP_W; this.mmTerrain.height = MAP_H;
    this.prerenderTerrain();
    this.blink = 0;
  }

  get viewW() { return this.canvas.width; }
  get viewH() { return this.canvas.height - this.hudH; }

  prerenderTerrain() {
    const c = this.terrainCanvas.getContext('2d'), m = this.g.map;
    c.fillStyle = '#26311f'; c.fillRect(0, 0, WORLD_W, WORLD_H);
    // subtle ground variation
    for (let ty = 0; ty < MAP_H; ty++) for (let tx = 0; tx < MAP_W; tx++) {
      const v = (Math.sin(tx * 0.7) + Math.cos(ty * 0.9) + Math.sin((tx + ty) * 0.35)) * 4;
      c.fillStyle = `rgb(${38 + v},${52 + v},${32 + v})`;
      c.fillRect(tx * TILE, ty * TILE, TILE, TILE);
    }
    for (const d of m.decor) { c.fillStyle = d.t === 0 ? 'rgba(60,90,45,0.6)' : 'rgba(90,80,60,0.5)'; c.beginPath(); c.arc(d.x, d.y, d.r, 0, Math.PI * 2); c.fill(); }
    // rocks
    for (let ty = 0; ty < MAP_H; ty++) for (let tx = 0; tx < MAP_W; tx++) {
      if (!m.terrain[m.idx(tx, ty)]) continue;
      c.fillStyle = '#4a4d55'; c.fillRect(tx * TILE, ty * TILE, TILE, TILE);
      c.fillStyle = '#5c6068'; c.fillRect(tx * TILE + 3, ty * TILE + 3, TILE - 10, TILE - 12);
      c.fillStyle = '#33363c'; c.fillRect(tx * TILE, ty * TILE + TILE - 5, TILE, 5);
    }
    // minimap terrain
    const mc = this.mmTerrain.getContext('2d');
    for (let ty = 0; ty < MAP_H; ty++) for (let tx = 0; tx < MAP_W; tx++) { mc.fillStyle = m.terrain[m.idx(tx, ty)] ? '#55585f' : '#2b3a24'; mc.fillRect(tx, ty, 1, 1); }
  }

  worldToScreen(x, y) { return { x: x - this.g.camera.x, y: y - this.g.camera.y }; }
  screenToWorld(x, y) { return { x: x + this.g.camera.x, y: y + this.g.camera.y }; }

  clampCamera() {
    const cam = this.g.camera;
    cam.x = clamp(cam.x, 0, Math.max(0, WORLD_W - this.viewW));
    cam.y = clamp(cam.y, 0, Math.max(0, WORLD_H - this.viewH));
  }

  visible(e) { return this.g.canSee(this.g.human, e); }

  draw(input, dt) {
    const ctx = this.ctx, g = this.g, cam = g.camera;
    this.blink += dt;
    this.clampCamera();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.save();
    ctx.translate(-cam.x, -cam.y);
    const vx0 = cam.x, vy0 = cam.y, vx1 = cam.x + this.viewW, vy1 = cam.y + this.viewH;
    ctx.drawImage(this.terrainCanvas, vx0, vy0, vx1 - vx0, vy1 - vy0, vx0, vy0, vx1 - vx0, vy1 - vy0);
    this.drawLayers(vx0, vy0, vx1, vy1);
    this.drawNodes();
    this.drawWards();
    for (const c of g.corpses) this.drawCorpse(c);
    const ents = g.entities.filter(e => !e.dead && e.x > vx0 - 120 && e.x < vx1 + 120 && e.y > vy0 - 120 && e.y < vy1 + 120);
    for (const b of ents) if (b.kind === 'building' && !b.relocate) this.drawBuilding(b);
    for (const u of ents) if (u.kind === 'unit' && !u.flying) this.drawUnit(u);
    for (const p of g.projectiles) this.drawProjectile(p);
    for (const u of ents) if (u.kind === 'unit' && u.flying) this.drawUnit(u);
    for (const b of ents) if (b.kind === 'building' && b.relocate) this.drawBuilding(b);
    this.drawEffects();
    this.drawClouds();
    if (input) this.drawInputOverlay(input);
    this.drawFog(vx0, vy0, vx1, vy1);
    if (g.weather.storm) this.drawStorm(vx0, vy0, vx1, vy1);
    ctx.restore();
    this.drawMinimap();
  }

  drawLayers(vx0, vy0, vx1, vy1) {
    const ctx = this.ctx, m = this.g.map;
    const tx0 = Math.max(0, Math.floor(vx0 / TILE)), ty0 = Math.max(0, Math.floor(vy0 / TILE)), tx1 = Math.min(MAP_W - 1, Math.ceil(vx1 / TILE)), ty1 = Math.min(MAP_H - 1, Math.ceil(vy1 / TILE));
    const B = m.layers.blight, L = m.layers.light, G = m.layers.grove;
    for (let ty = ty0; ty <= ty1; ty++) for (let tx = tx0; tx <= tx1; tx++) {
      const i = m.idx(tx, ty), px = tx * TILE, py = ty * TILE;
      const c = B[i], l = L[i], g = G[i];
      if (g > 0.05) { ctx.fillStyle = `rgba(40,150,60,${g * 0.5})`; ctx.fillRect(px, py, TILE, TILE); if (g > 0.6) { ctx.fillStyle = `rgba(200,240,160,${(g - 0.6) * 0.5})`; ctx.fillRect(px + 6, py + 20, 5, 5); ctx.fillRect(px + 22, py + 7, 4, 4); } }
      if (c > 0.05) { ctx.fillStyle = `rgba(90,20,140,${c * 0.55})`; ctx.fillRect(px, py, TILE, TILE); if (c > 0.6) { ctx.fillStyle = `rgba(200,120,255,${(c - 0.6) * 0.25})`; ctx.fillRect(px + 8, py + 8, 6, 6); ctx.fillRect(px + 20, py + 18, 4, 4); } }
      if (l > 0.05) { ctx.fillStyle = `rgba(255,215,110,${l * 0.3})`; ctx.fillRect(px, py, TILE, TILE); }
    }
  }

  drawNodes() {
    const ctx = this.ctx;
    for (const n of this.g.map.nodes) {
      if (n.building) continue;
      const x = n.x, y = n.y, depleted = n.amount <= 0;
      if (n.type === 'primary') {
        ctx.fillStyle = depleted ? '#4d4f58' : '#5ad0e6';
        for (let i = 0; i < 5; i++) { const a = i * 1.3, r = 12 + (i % 2) * 6; ctx.beginPath(); ctx.moveTo(x + Math.cos(a) * 6, y + Math.sin(a) * 6); ctx.lineTo(x + Math.cos(a + 0.4) * r, y + Math.sin(a + 0.4) * r - 6); ctx.lineTo(x + Math.cos(a + 0.8) * 6, y + Math.sin(a + 0.8) * 6); ctx.fill(); }
        ctx.fillStyle = depleted ? '#3c3d44' : '#9ff0ff'; ctx.beginPath(); ctx.arc(x, y - 4, 7, 0, Math.PI * 2); ctx.fill();
        if (!depleted) { ctx.fillStyle = '#000'; ctx.fillRect(x - 18, y + 20, 36, 4); ctx.fillStyle = '#5ad0e6'; ctx.fillRect(x - 18, y + 20, 36 * n.amount / n.max, 4); }
      } else {
        ctx.fillStyle = '#245a3a'; ctx.beginPath(); ctx.arc(x, y, 20, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#48d67f'; ctx.beginPath(); ctx.arc(x, y, 12, 0, Math.PI * 2); ctx.fill();
        const p = (this.blink * 2) % 1; ctx.strokeStyle = `rgba(120,255,170,${1 - p})`; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, y, 12 + p * 16, 0, Math.PI * 2); ctx.stroke();
      }
    }
  }

  drawCorpse(c) {
    const ctx = this.ctx; ctx.fillStyle = `rgba(80,70,70,${Math.min(1, c.t / 5)})`;
    ctx.beginPath(); ctx.ellipse(c.x, c.y + 4, 10, 5, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = `rgba(200,190,180,${Math.min(1, c.t / 5) * 0.7})`; ctx.fillRect(c.x - 4, c.y - 1, 8, 3);
  }

  abbrev(name) { const w = name.replace(/[^A-Za-z ]/g, '').split(' ').filter(x => x && x !== 'of' && x !== 'the'); return w.map(x => x[0]).join('').slice(0, 3).toUpperCase(); }

  drawBuilding(b) {
    const ctx = this.ctx, g = this.g, vis = this.visible(b);
    if (!vis) return;
    if (b.def.invisible && b.owner !== g.human && !g.detected(g.human, b)) return;
    const px = b.tx * TILE, py = b.ty * TILE, w = b.w * TILE, h = b.h * TILE;
    let lift = 0;
    if (b.relocate) { lift = b.relocate.phase === 'lift' ? b.relocate.t / 2 * 30 : b.relocate.phase === 'land' ? (1 - b.relocate.t / 2) * 30 : 30; }
    const dx = b.relocate ? b.x - w / 2 : px, dy = (b.relocate ? b.y - h / 2 : py) - lift;
    const fc = b.faction.color, pc = b.player.color;
    if (b.relocate) { ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.beginPath(); ctx.ellipse(b.x, b.y + h / 2, w / 2, h / 4, 0, 0, Math.PI * 2); ctx.fill(); }
    const sel = g.selection.includes(b);
    const fills = { abyss: '#2a1a3a', tempest: '#1d2c3d', radiance: '#3f3014', verdance: '#1a3320', sanctuary: '#2c2f48' };
    ctx.fillStyle = b.flash > 0 ? '#e8e8f4' : (b.complete ? (fills[b.faction.id] || '#222') : '#222');
    ctx.fillRect(dx + 2, dy + 2, w - 4, h - 4);
    ctx.strokeStyle = sel ? '#fff' : pc; ctx.lineWidth = sel ? 3 : 2; ctx.strokeRect(dx + 2, dy + 2, w - 4, h - 4);
    // detail
    ctx.fillStyle = hexToRgba(fc, b.complete ? 0.55 : 0.25);
    if (b.def.isBase) { ctx.beginPath(); ctx.moveTo(dx + w / 2, dy + 8); ctx.lineTo(dx + w - 10, dy + h - 10); ctx.lineTo(dx + 10, dy + h - 10); ctx.fill(); }
    else if (b.def.tower) { ctx.beginPath(); ctx.arc(dx + w / 2, dy + h / 2, w * 0.3, 0, Math.PI * 2); ctx.fill(); }
    else if (b.def.wall) { ctx.fillStyle = b.def.blocksAir ? 'rgba(120,220,255,0.5)' : '#8a8478'; ctx.fillRect(dx + 4, dy + 4, w - 8, h - 8); }
    else { ctx.fillRect(dx + 8, dy + 8, w - 16, h - 16); }
    if (b.def.needsNode && b.node) { ctx.fillStyle = b.def.needsNode === 'primary' ? '#5ad0e6' : '#48d67f'; ctx.beginPath(); ctx.arc(dx + w / 2, dy + h / 2, 6, 0, Math.PI * 2); ctx.fill(); }
    if (b.def.converter && b.toggles.convert && b.complete) { ctx.fillStyle = `rgba(200,120,255,${0.5 + 0.5 * Math.sin(this.blink * 6)})`; ctx.beginPath(); ctx.arc(dx + w / 2, dy + h / 2, 8, 0, Math.PI * 2); ctx.fill(); }
    // label
    ctx.fillStyle = '#fff'; ctx.font = (b.w >= 3 ? 'bold 13px' : b.w === 2 ? 'bold 11px' : '9px') + ' sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(b.def.isBase ? ['I', 'II', 'III'][b.player.tier - 1] : this.abbrev(b.def.name), dx + w / 2, dy + h / 2 + (b.def.isBase ? 6 : 0));
    // progress / hp
    if (!b.complete) { ctx.fillStyle = '#000'; ctx.fillRect(dx, dy - 8, w, 5); ctx.fillStyle = '#ffd479'; ctx.fillRect(dx, dy - 8, w * b.progress, 5); }
    if (sel || b.hp < b.maxHp) { ctx.fillStyle = '#000'; ctx.fillRect(dx, dy - 3 - (b.complete ? 0 : 0), w, 4); ctx.fillStyle = b.hp / b.maxHp > 0.5 ? '#3fd66a' : b.hp / b.maxHp > 0.25 ? '#ffd479' : '#ff5a3c'; ctx.fillRect(dx, dy - 3, w * b.hp / b.maxHp, 4); }
    if (b.darkPact > 0) { ctx.strokeStyle = '#ff4b6e'; ctx.lineWidth = 2; ctx.strokeRect(dx - 2, dy - 2, w + 4, h + 4); }
    if (b.queue.length && b.owner === g.human) { const q = b.queue[0]; ctx.fillStyle = '#000'; ctx.fillRect(dx + 4, dy + h - 8, w - 8, 4); ctx.fillStyle = '#8fd3ff'; ctx.fillRect(dx + 4, dy + h - 8, (w - 8) * q.elapsed / q.time, 4); }
    if (sel && b.rally && b.owner === g.human) { ctx.strokeStyle = '#ffd479'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]); ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(b.rally.x, b.rally.y); ctx.stroke(); ctx.setLineDash([]); ctx.fillStyle = '#ffd479'; ctx.beginPath(); ctx.moveTo(b.rally.x, b.rally.y - 12); ctx.lineTo(b.rally.x + 10, b.rally.y - 8); ctx.lineTo(b.rally.x, b.rally.y - 4); ctx.fill(); ctx.fillRect(b.rally.x - 1, b.rally.y - 12, 2, 12); }
    if (sel && b.def.tower && b.def.tower.dmg > 0) { ctx.strokeStyle = 'rgba(255,255,255,0.25)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(b.x, b.y, b.towerRange(), 0, Math.PI * 2); ctx.stroke(); }
    if (sel && b.def.aura) { ctx.strokeStyle = 'rgba(255,255,255,0.25)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(b.x, b.y, b.def.aura.radius * TILE, 0, Math.PI * 2); ctx.stroke(); }
  }

  drawUnit(u) {
    const ctx = this.ctx, g = this.g;
    const isOwn = u.owner === g.human;
    if (!isOwn && !this.visible(u)) return;
    if (u.invisible && !isOwn && !g.detected(g.human, u)) return;
    if (u.hasBuff('banish')) return;
    const sel = g.selection.includes(u);
    const pc = u.player.color, fc = u.faction.color;
    const lift = u.flying ? 14 : 0;
    const x = u.x, y = u.y - lift, r = u.radius;
    ctx.globalAlpha = u.invisible ? 0.45 : 1;
    if (u.flying) { ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(u.x, u.y + 6, r, r * 0.5, 0, 0, Math.PI * 2); ctx.fill(); }
    if (sel) { ctx.strokeStyle = isOwn ? '#5fff8a' : '#ff6a6a'; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(u.x, u.y + (u.flying ? 6 : 2), r + 4, (r + 4) * 0.6, 0, 0, Math.PI * 2); ctx.stroke(); }
    ctx.fillStyle = u.flash > 0 ? '#ffffff' : pc; ctx.strokeStyle = u.flash > 0 ? '#ffffff' : fc; ctx.lineWidth = 2;
    const t = u.def.type;
    ctx.beginPath();
    if (u.isHero) { for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * 0.5 : r + 2; ctx.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); } ctx.closePath(); }
    else if (t === 'ranged') { ctx.moveTo(x + Math.cos(u.facing) * r, y + Math.sin(u.facing) * r); ctx.lineTo(x + Math.cos(u.facing + 2.4) * r, y + Math.sin(u.facing + 2.4) * r); ctx.lineTo(x + Math.cos(u.facing - 2.4) * r, y + Math.sin(u.facing - 2.4) * r); ctx.closePath(); }
    else if (t === 'caster') { ctx.moveTo(x, y - r); ctx.lineTo(x + r, y); ctx.lineTo(x, y + r); ctx.lineTo(x - r, y); ctx.closePath(); }
    else if (t === 'siege') { ctx.rect(x - r, y - r * 0.8, r * 2, r * 1.6); }
    else if (t === 'worker') { ctx.arc(x, y, r * 0.8, 0, Math.PI * 2); }
    else { ctx.arc(x, y, r, 0, Math.PI * 2); }
    ctx.fill(); ctx.stroke();
    if (u.flying) { ctx.strokeStyle = fc; ctx.lineWidth = 2; const w = Math.sin(this.blink * 12 + u.id) * 3; ctx.beginPath(); ctx.moveTo(x - r - 8, y - 4 + w); ctx.lineTo(x - r + 2, y); ctx.moveTo(x + r + 8, y - 4 + w); ctx.lineTo(x + r - 2, y); ctx.stroke(); }
    if (t === 'worker') { ctx.strokeStyle = '#ddd'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x + Math.cos(u.facing) * 4, y + Math.sin(u.facing) * 4); ctx.lineTo(x + Math.cos(u.facing) * (r + 6), y + Math.sin(u.facing) * (r + 6)); ctx.stroke(); if (u.gather.carrying > 0) { ctx.fillStyle = '#c9a0ff'; ctx.beginPath(); ctx.arc(x - 6, y - 8, 4, 0, Math.PI * 2); ctx.fill(); } }
    else if (!u.isHero && t !== 'siege') { ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(u.facing) * (r + 3), y + Math.sin(u.facing) * (r + 3)); ctx.stroke(); }
    if (u.isHero) { ctx.fillStyle = '#000'; ctx.font = 'bold 10px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(u.level, x, y + 1); }
    if (u.def.unique) { ctx.strokeStyle = '#ff4b6e'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, y, r + 5 + Math.sin(this.blink * 4) * 2, 0, Math.PI * 2); ctx.stroke(); }
    // status marks
    if (u.stunned) { ctx.fillStyle = '#ffd479'; ctx.font = '10px sans-serif'; ctx.fillText('✶', x, y - r - 10); }
    // hp bar
    if (sel || u.hp < u.maxHp || u.isHero) {
      const bw = Math.max(20, r * 2 + 4);
      ctx.fillStyle = '#000'; ctx.fillRect(x - bw / 2, y - r - 8, bw, 4);
      const f = u.hp / u.maxHp; ctx.fillStyle = f > 0.5 ? '#3fd66a' : f > 0.25 ? '#ffd479' : '#ff5a3c'; ctx.fillRect(x - bw / 2, y - r - 8, bw * f, 4);
      if (u.isHero && isOwn) { ctx.fillStyle = '#3a3a55'; ctx.fillRect(x - bw / 2, y - r - 4, bw, 2); ctx.fillStyle = '#c9a0ff'; ctx.fillRect(x - bw / 2, y - r - 4, bw * Math.min(1, u.xp / u.xpToLevel), 2); }
      if (u.maxShield) { ctx.fillStyle = '#123'; ctx.fillRect(x - bw / 2, y - r - 11, bw, 3); ctx.fillStyle = '#9fe0ff'; ctx.fillRect(x - bw / 2, y - r - 11, bw * Math.min(1, u.shield / u.stat('maxShield')), 3); }
    }
    ctx.globalAlpha = 1;
    if (sel && isOwn && u.def.range > 1.6) { ctx.strokeStyle = 'rgba(255,255,255,0.15)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(u.x, u.y, u.stat('range'), 0, Math.PI * 2); ctx.stroke(); }
  }

  drawProjectile(p) {
    const ctx = this.ctx;
    if (p.kind === 'shell') { ctx.fillStyle = '#e8e0d0'; ctx.beginPath(); ctx.arc(p.x, p.y - 10, 5, 0, Math.PI * 2); ctx.fill(); }
    else if (p.kind === 'bolt') { ctx.fillStyle = p.color; ctx.beginPath(); ctx.arc(p.x, p.y, 4, 0, Math.PI * 2); ctx.fill(); ctx.strokeStyle = hexToRgba(p.color, 0.5); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - (p.target.x - p.x) * 0.15, p.y - (p.target.y - p.y) * 0.15); ctx.stroke(); }
    else { ctx.strokeStyle = '#eee'; ctx.lineWidth = 2; const a = angleTo(p.x, p.y, p.target.x, p.target.y); ctx.beginPath(); ctx.moveTo(p.x - Math.cos(a) * 6, p.y - Math.sin(a) * 6); ctx.lineTo(p.x + Math.cos(a) * 6, p.y + Math.sin(a) * 6); ctx.stroke(); }
  }

  drawWards() {
    const ctx = this.ctx;
    for (const w of (this.g.wards || [])) {
      const colors = { corruption: '#8b3cff', veil: '#1a0830', curse: '#c040ff', zephyr: '#8fd3ff', cloud: '#7fa8c8', eye: '#ffffff', hurricane: '#9fc4ff' };
      const c = colors[w.kind] || '#fff';
      ctx.strokeStyle = hexToRgba(c, 0.6); ctx.lineWidth = 2; ctx.setLineDash([6, 6]); ctx.lineDashOffset = -this.blink * 30;
      ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = hexToRgba(c, w.kind === 'veil' ? 0.45 : 0.08); ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, Math.PI * 2); ctx.fill();
      if (w.kind === 'corruption') { ctx.fillStyle = '#8b3cff'; ctx.fillRect(w.x - 4, w.y - 18, 8, 22); ctx.beginPath(); ctx.arc(w.x, w.y - 20, 7, 0, Math.PI * 2); ctx.fill(); }
      if (w.kind === 'zephyr') { ctx.fillStyle = '#8fd3ff'; ctx.fillRect(w.x - 3, w.y - 20, 6, 24); }
      if (w.kind === 'hurricane' || w.kind === 'eye') { for (let i = 0; i < 3; i++) { ctx.strokeStyle = hexToRgba(c, 0.4); ctx.beginPath(); ctx.arc(w.x, w.y, w.r * (0.3 + i * 0.25), this.blink * (2 + i) % (Math.PI * 2), this.blink * (2 + i) % (Math.PI * 2) + 2); ctx.stroke(); } }
    }
  }

  drawClouds() {
    const ctx = this.ctx;
    for (const c of this.g.weather.cloud) {
      ctx.fillStyle = c.heavy ? 'rgba(30,40,70,0.45)' : 'rgba(80,100,130,0.35)';
      for (let i = 0; i < 6; i++) { const a = i * 1.05 + this.blink * 0.3, rr = c.r * 0.55; ctx.beginPath(); ctx.arc(c.x + Math.cos(a) * rr * 0.6, c.y - 20 + Math.sin(a) * rr * 0.4, rr * 0.7, 0, Math.PI * 2); ctx.fill(); }
      ctx.strokeStyle = 'rgba(180,200,255,0.5)'; ctx.lineWidth = 1;
      for (let i = 0; i < 25; i++) { const rx = c.x + (Math.sin(i * 12.9 + 1) * 0.5 + 0.5) * c.r * 2 - c.r, ry = c.y + ((Math.sin(i * 7.3) * 0.5 + 0.5) * c.r * 2 - c.r) + ((this.blink * 300 + i * 37) % 60); if (dist(rx, ry, c.x, c.y) > c.r) continue; ctx.beginPath(); ctx.moveTo(rx, ry); ctx.lineTo(rx - 2, ry + 8); ctx.stroke(); }
    }
  }

  drawStorm(vx0, vy0, vx1, vy1) {
    const ctx = this.ctx;
    ctx.fillStyle = 'rgba(10,20,50,0.35)'; ctx.fillRect(vx0, vy0, vx1 - vx0, vy1 - vy0);
    ctx.strokeStyle = 'rgba(200,220,255,0.35)'; ctx.lineWidth = 1;
    for (let i = 0; i < 120; i++) { const rx = vx0 + ((i * 97) % (vx1 - vx0)), ry = vy0 + ((i * 53 + this.blink * 500) % (vy1 - vy0)); ctx.beginPath(); ctx.moveTo(rx, ry); ctx.lineTo(rx - 3, ry + 12); ctx.stroke(); }
    if (Math.random() < 0.02) { ctx.fillStyle = 'rgba(255,255,255,0.15)'; ctx.fillRect(vx0, vy0, vx1 - vx0, vy1 - vy0); }
  }

  drawEffects() {
    const ctx = this.ctx;
    for (const e of this.g.effects) {
      const p = 1 - e.t / e.max;
      switch (e.type) {
        case 'ring': ctx.strokeStyle = hexToRgba(e.color, 1 - p); ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(e.x, e.y, e.r * (0.3 + 0.7 * p), 0, Math.PI * 2); ctx.stroke(); break;
        case 'burst': ctx.fillStyle = hexToRgba(e.color, (1 - p) * 0.5); ctx.beginPath(); ctx.arc(e.x, e.y, e.r * (0.4 + 0.6 * p), 0, Math.PI * 2); ctx.fill(); break;
        case 'lightning': {
          ctx.strokeStyle = e.color; ctx.lineWidth = 3 * (1 - p) + 1; ctx.beginPath(); ctx.moveTo(e.x1, e.y1);
          const segs = 8; for (let i = 1; i <= segs; i++) { const t = i / segs, jx = i < segs ? (Math.sin(i * 7.1 + e.x1) * 14) : 0, jy = i < segs ? (Math.cos(i * 5.3 + e.y1) * 14) : 0; ctx.lineTo(lerp(e.x1, e.x2, t) + jx, lerp(e.y1, e.y2, t) + jy); }
          ctx.stroke(); ctx.strokeStyle = 'rgba(255,255,255,0.4)'; ctx.lineWidth = 6 * (1 - p); ctx.stroke(); break;
        }
        case 'slash': ctx.strokeStyle = hexToRgba(e.color, 1 - p); ctx.lineWidth = e.big ? 4 : 2; ctx.beginPath(); ctx.arc(e.x, e.y, (e.big ? 22 : 12) * (0.5 + p), -0.8, 0.8); ctx.stroke(); break;
        case 'spark': ctx.fillStyle = hexToRgba(e.color, 1 - p); for (let i = 0; i < 5; i++) { const a = i * 1.26; ctx.fillRect(e.x + Math.cos(a) * 10 * p, e.y + Math.sin(a) * 10 * p, 3, 3); } break;
        case 'text': ctx.fillStyle = e.color; ctx.globalAlpha = 1 - p; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(e.text, e.x, e.y - p * 20); ctx.globalAlpha = 1; break;
        case 'death': ctx.fillStyle = hexToRgba(e.color, (1 - p) * 0.7); for (let i = 0; i < 6; i++) { const a = i * 1.05; ctx.beginPath(); ctx.arc(e.x + Math.cos(a) * 18 * p, e.y - (e.flying ? 14 : 0) + Math.sin(a) * 18 * p, 4 * (1 - p), 0, Math.PI * 2); ctx.fill(); } break;
      }
    }
  }

  drawInputOverlay(input) {
    const ctx = this.ctx, g = this.g;
    if (input.dragging && input.dragStart) {
      const a = input.dragStart, b = input.mouseWorld;
      ctx.strokeStyle = '#5fff8a'; ctx.lineWidth = 1; ctx.strokeRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
      ctx.fillStyle = 'rgba(95,255,138,0.1)'; ctx.fillRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }
    const pend = input.pending;
    if (pend && (pend.kind === 'build' || pend.kind === 'relocate')) {
      const def = pend.kind === 'build' ? g.players[g.human].faction.buildings[pend.defId] : g.baseOf(g.human).def;
      const tx = Math.floor(input.mouseWorld.x / TILE) - Math.floor(def.w / 2), ty = Math.floor(input.mouseWorld.y / TILE) - Math.floor(def.h / 2);
      let ok;
      if (pend.kind === 'build') ok = g.canPlace(g.human, pend.defId, tx, ty);
      else { const b = g.baseOf(g.human); g.map.setBlocked(b.tx, b.ty, b.w, b.h, false); ok = g.map.areaFree(tx, ty, def.w, def.h); g.map.setBlocked(b.tx, b.ty, b.w, b.h, true); }
      ctx.fillStyle = ok ? 'rgba(95,255,138,0.35)' : 'rgba(255,80,80,0.35)'; ctx.fillRect(tx * TILE, ty * TILE, def.w * TILE, def.h * TILE);
      ctx.strokeStyle = ok ? '#5fff8a' : '#ff5050'; ctx.strokeRect(tx * TILE, ty * TILE, def.w * TILE, def.h * TILE);
      if (def.tower) { ctx.strokeStyle = 'rgba(255,255,255,0.3)'; ctx.beginPath(); ctx.arc((tx + def.w / 2) * TILE, (ty + def.h / 2) * TILE, def.tower.range * TILE, 0, Math.PI * 2); ctx.stroke(); }
      if (def.aura) { ctx.strokeStyle = 'rgba(255,255,255,0.3)'; ctx.beginPath(); ctx.arc((tx + def.w / 2) * TILE, (ty + def.h / 2) * TILE, def.aura.radius * TILE, 0, Math.PI * 2); ctx.stroke(); }
      input.ghost = { tx, ty, ok };
    }
    if (pend && pend.kind === 'cast') {
      const ab = ABILITIES[pend.ability];
      const radii = { corruption_ward: 4, nightmare_veil: 4, curse_of_undeath: 6, zephyr_ward: 4, cloudburst: 3.5, hurricane_maelstrom: 6, call_of_the_armada: 2, nether_portal: 2.5, thunderstrike: 2, void_bolt: 3 };
      if (radii[pend.ability]) { ctx.strokeStyle = 'rgba(255,255,255,0.5)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(input.mouseWorld.x, input.mouseWorld.y, radii[pend.ability] * TILE, 0, Math.PI * 2); ctx.stroke(); }
      for (const u of g.selection) if (u.kind === 'unit' && ab.range) { ctx.strokeStyle = 'rgba(140,200,255,0.3)'; ctx.beginPath(); ctx.arc(u.x, u.y, ab.range * TILE, 0, Math.PI * 2); ctx.stroke(); }
    }
    if (pend && (pend.kind === 'attack' || pend.kind === 'move' || pend.kind === 'gather')) { ctx.strokeStyle = pend.kind === 'attack' ? '#ff5a3c' : '#5fff8a'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(input.mouseWorld.x, input.mouseWorld.y, 10, 0, Math.PI * 2); ctx.stroke(); }
    if (input.clickMarker && input.clickMarker.t > 0) { const m = input.clickMarker; ctx.strokeStyle = m.color; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(m.x, m.y, 6 + (0.5 - m.t) * 24, 0, Math.PI * 2); ctx.stroke(); }
  }

  drawFog(vx0, vy0, vx1, vy1) {
    const p = this.g.players[this.g.human], d = this.fogData.data, v = p.vision;
    for (let i = 0; i < v.length; i++) { const o = i * 4; d[o] = 0; d[o + 1] = 0; d[o + 2] = 8; d[o + 3] = v[i] === 2 ? 0 : v[i] === 1 ? 120 : 235; }
    this.fogCanvas.getContext('2d').putImageData(this.fogData, 0, 0);
    const ctx = this.ctx; ctx.imageSmoothingEnabled = true;
    ctx.drawImage(this.fogCanvas, 0, 0, MAP_W, MAP_H, 0, 0, WORLD_W, WORLD_H);
  }

  drawMinimap() {
    const c = this.mctx, g = this.g, W = this.mm.width, H = this.mm.height, sx = W / WORLD_W, sy = H / WORLD_H;
    c.imageSmoothingEnabled = false;
    c.drawImage(this.mmTerrain, 0, 0, W, H);
    // corruption
    const m = g.map;
    for (let ty = 0; ty < MAP_H; ty += 2) for (let tx = 0; tx < MAP_W; tx += 2) { const i = m.idx(tx, ty); const v = m.corruption[i], l = m.layers.light[i], gr = m.layers.grove[i]; if (v > 0.2) { c.fillStyle = `rgba(140,60,255,${v * 0.6})`; c.fillRect(tx * W / MAP_W, ty * H / MAP_H, 2 * W / MAP_W, 2 * H / MAP_H); } if (l > 0.2) { c.fillStyle = `rgba(255,220,120,${l * 0.5})`; c.fillRect(tx * W / MAP_W, ty * H / MAP_H, 2 * W / MAP_W, 2 * H / MAP_H); } if (gr > 0.2) { c.fillStyle = `rgba(60,200,90,${gr * 0.5})`; c.fillRect(tx * W / MAP_W, ty * H / MAP_H, 2 * W / MAP_W, 2 * H / MAP_H); } }
    for (const n of m.nodes) { c.fillStyle = n.type === 'primary' ? '#5ad0e6' : '#48d67f'; c.fillRect(n.x * sx - 1.5, n.y * sy - 1.5, 3, 3); }
    for (const e of g.entities) {
      if (e.dead) continue;
      if (e.owner !== g.human && !this.visible(e)) continue;
      if (e.invisible && e.owner !== g.human) continue;
      c.fillStyle = e.owner === g.human ? '#5fff8a' : '#ff5a3c';
      if (e.kind === 'building') c.fillRect(e.tx * W / MAP_W, e.ty * H / MAP_H, Math.max(2, e.w * W / MAP_W), Math.max(2, e.h * H / MAP_H));
      else { c.fillRect(e.x * sx - 1, e.y * sy - 1, e.isHero ? 3 : 2, e.isHero ? 3 : 2); }
    }
    // fog
    c.globalAlpha = 0.8; c.drawImage(this.fogCanvas, 0, 0, MAP_W, MAP_H, 0, 0, W, H); c.globalAlpha = 1;
    if (g.attackPing && g.attackPing.t > 0) { g.attackPing.t -= 0.016; c.strokeStyle = '#ff5a3c'; c.lineWidth = 2; c.beginPath(); c.arc(g.attackPing.x * sx, g.attackPing.y * sy, 4 + (Math.sin(this.blink * 10) + 1) * 3, 0, Math.PI * 2); c.stroke(); }
    c.strokeStyle = '#fff'; c.lineWidth = 1; c.strokeRect(g.camera.x * sx, g.camera.y * sy, this.viewW * sx, this.viewH * sy);
  }
}
