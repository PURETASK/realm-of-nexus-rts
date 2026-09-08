// Mouse and keyboard input
class Input {
  constructor(game, renderer, canvas, minimap) {
    this.g = game; this.r = renderer; this.canvas = canvas; this.mm = minimap;
    this.mouse = { x: 0, y: 0 }; this.mouseWorld = { x: 0, y: 0 };
    this.dragStart = null; this.dragging = false; this.pending = null; this.ghost = null; this.ui = null;
    this.keys = {}; this.clickMarker = null; this.lastClick = 0; this.mmDrag = false;
    this.bind();
  }

  bind() {
    const c = this.canvas;
    c.addEventListener('contextmenu', e => e.preventDefault());
    c.addEventListener('mousedown', e => this.onDown(e));
    window.addEventListener('mouseup', e => this.onUp(e));
    window.addEventListener('mousemove', e => this.onMove(e));
    c.addEventListener('dblclick', e => this.onDbl(e));
    window.addEventListener('keydown', e => this.onKey(e));
    window.addEventListener('keyup', e => { this.keys[e.key] = false; });
    this.mm.addEventListener('mousedown', e => { this.mmDrag = e.button === 0; this.onMinimap(e); });
    this.mm.addEventListener('mousemove', e => { if (this.mmDrag) this.onMinimap(e); });
    this.mm.addEventListener('contextmenu', e => e.preventDefault());
  }

  updateMouseWorld(e) {
    const rect = this.canvas.getBoundingClientRect();
    this.mouse.x = e.clientX - rect.left; this.mouse.y = e.clientY - rect.top;
    const w = this.r.screenToWorld(this.mouse.x, this.mouse.y);
    this.mouseWorld.x = clamp(w.x, 0, WORLD_W); this.mouseWorld.y = clamp(w.y, 0, WORLD_H);
  }

  onMinimap(e) {
    const rect = this.mm.getBoundingClientRect();
    const wx = (e.clientX - rect.left) / rect.width * WORLD_W, wy = (e.clientY - rect.top) / rect.height * WORLD_H;
    if (e.button === 2 || (e.buttons & 2)) { this.issueContext(wx, wy, null); return; }
    if (this.pending && (this.pending.kind === 'attack' || this.pending.kind === 'move')) { this.issuePending(wx, wy, null); return; }
    this.g.camera.x = wx - this.r.viewW / 2; this.g.camera.y = wy - this.r.viewH / 2;
  }

  entityAt(x, y) {
    const g = this.g; let best = null, bd = Infinity;
    for (const e of g.entities) {
      if (e.dead) continue;
      if (e.owner !== g.human && !g.canSee(g.human, e)) continue;
      if (e.invisible && e.owner !== g.human && !g.detected(g.human, e)) continue;
      if (e.kind === 'building') { if (x >= e.tx * TILE && x < (e.tx + e.w) * TILE && y >= e.ty * TILE && y < (e.ty + e.h) * TILE) { const d = dist(x, y, e.x, e.y) + 100; if (d < bd) { bd = d; best = e; } } }
      else { const d = dist(x, y, e.x, e.y - (e.flying ? 14 : 0)); if (d < e.radius + 6 && d < bd) { bd = d; best = e; } }
    }
    return best;
  }
  nodeAt(x, y) { for (const n of this.g.map.nodes) if (dist(x, y, n.x, n.y) < TILE * 1.2) return n; return null; }

  onDown(e) {
    this.updateMouseWorld(e);
    if (this.mouse.y > this.r.viewH) return;
    if (e.button === 0) {
      if (this.pending) { this.issuePending(this.mouseWorld.x, this.mouseWorld.y, this.entityAt(this.mouseWorld.x, this.mouseWorld.y)); return; }
      this.dragStart = { x: this.mouseWorld.x, y: this.mouseWorld.y }; this.dragging = false;
    } else if (e.button === 2) {
      if (this.pending) { this.pending = null; if (this.ui) this.ui.buildMenu = false; return; }
      this.issueContext(this.mouseWorld.x, this.mouseWorld.y, this.entityAt(this.mouseWorld.x, this.mouseWorld.y));
    }
  }
  onMove(e) {
    this.updateMouseWorld(e);
    if (this.dragStart && dist(this.dragStart.x, this.dragStart.y, this.mouseWorld.x, this.mouseWorld.y) > 6) this.dragging = true;
  }
  onUp(e) {
    if (e.button === 0) this.mmDrag = false;
    if (e.button !== 0 || !this.dragStart) return;
    this.updateMouseWorld(e);
    const g = this.g;
    if (this.dragging) {
      const a = this.dragStart, b = this.mouseWorld;
      const x0 = Math.min(a.x, b.x), x1 = Math.max(a.x, b.x), y0 = Math.min(a.y, b.y), y1 = Math.max(a.y, b.y);
      let sel = g.units(g.human).filter(u => u.x >= x0 && u.x <= x1 && u.y >= y0 && u.y <= y1);
      if (sel.some(u => u.isCombat)) sel = sel.filter(u => u.isCombat);
      if (!sel.length) sel = g.buildings(g.human).filter(bb => bb.x >= x0 && bb.x <= x1 && bb.y >= y0 && bb.y <= y1).slice(0, 1);
      if (e.shiftKey) g.selection = [...new Set([...g.selection, ...sel])]; else g.selection = sel;
      if (g.selection.length) g.emit('select', 0, 0, g.human);
    } else {
      const ent = this.entityAt(this.mouseWorld.x, this.mouseWorld.y);
      if (ent) { if (e.shiftKey && ent.owner === g.human) { if (g.selection.includes(ent)) g.selection = g.selection.filter(x => x !== ent); else g.selection = [...g.selection, ent]; } else g.selection = [ent]; g.emit('select', 0, 0, g.human); }
      else if (!e.shiftKey) g.selection = [];
    }
    if (this.ui) this.ui.buildMenu = false;
    this.dragStart = null; this.dragging = false;
  }
  onDbl(e) {
    this.updateMouseWorld(e);
    const ent = this.entityAt(this.mouseWorld.x, this.mouseWorld.y);
    if (ent && ent.kind === 'unit' && ent.owner === this.g.human) {
      const r = this.r;
      this.g.selection = this.g.units(this.g.human).filter(u => u.defId === ent.defId && u.x > r.g.camera.x && u.x < r.g.camera.x + r.viewW && u.y > r.g.camera.y && u.y < r.g.camera.y + r.viewH);
    }
  }

  issuePending(x, y, ent) {
    const g = this.g, p = this.pending, sel = g.selection.filter(e => e.owner === g.human), units = sel.filter(e => e.kind === 'unit');
    switch (p.kind) {
      case 'move': g.orderMove(units, x, y); this.marker(x, y, '#5fff8a'); break;
      case 'attack': if (ent && ent.owner !== g.human && ent.owner >= 0) g.orderAttack(units, ent); else g.orderMove(units, x, y, true); this.marker(x, y, '#ff5a3c'); break;
      case 'gather': { const n = this.nodeAt(x, y); if (n && n.type === 'primary') g.orderGather(units, n); else g.msg('Target a resource node', 'warn'); break; }
      case 'build': { if (this.ghost) { const b = g.orderBuild(units, p.defId, this.ghost.tx, this.ghost.ty); if (b) { if (this.ui) this.ui.buildMenu = false; } else return; } break; }
      case 'relocate': { if (this.ghost) { if (!g.orderRelocate(p.building, this.ghost.tx, this.ghost.ty)) return; } break; }
      case 'rally': p.building.rally = { x, y }; break;
      case 'bcast': { const ab = ABILITIES[p.ability]; if (ab.target === 'ally' && (!ent || ent.owner !== g.human)) { g.msg('Select a friendly target', 'warn'); return; } if (ab.target === 'enemy' && (!ent || ent.owner === g.human || ent.owner < 0)) { g.msg('Select an enemy target', 'warn'); return; } if (!g.buildingCast(p.building, p.ability, ent, x, y)) return; this.marker(x, y, '#8fd3ff'); break; }
      case 'cast': {
        const ab = ABILITIES[p.ability], h = p.caster;
        if (!h || h.dead) break;
        if (ab.target === 'enemy') { if (!ent || ent.owner === g.human || ent.owner < 0) { g.msg('Select an enemy target', 'warn'); return; } g.orderCast(h, p.ability, ent, ent.x, ent.y); }
        else if (ab.target === 'ally') { if (!ent || ent.owner !== g.human) { g.msg('Select a friendly target', 'warn'); return; } g.orderCast(h, p.ability, ent, ent.x, ent.y); }
        else g.orderCast(h, p.ability, null, x, y);
        this.marker(x, y, '#8fd3ff');
        break;
      }
    }
    this.pending = null; this.ghost = null;
  }

  issueContext(x, y, ent) {
    const g = this.g, sel = g.selection.filter(e => e.owner === g.human);
    if (!sel.length) return;
    const units = sel.filter(e => e.kind === 'unit'), buildings = sel.filter(e => e.kind === 'building');
    if (units.length) {
      if (ent && ent.owner !== g.human && ent.owner >= 0) { g.orderAttack(units, ent); this.marker(x, y, '#ff5a3c'); return; }
      const n = this.nodeAt(x, y);
      if (n && n.type === 'primary' && units.some(u => u.isWorker && u.faction.gathers)) { g.orderGather(units.filter(u => u.isWorker), n); g.orderMove(units.filter(u => !u.isWorker), x, y); this.marker(x, y, '#c9a0ff'); return; }
      if (ent && ent.kind === 'building' && ent.owner === g.human && !ent.complete && units.some(u => u.isWorker)) { for (const w of units.filter(u => u.isWorker)) { g.clearOrder(w); w.order = { type: 'build', building: ent }; w.buildTask = ent; g.setPath(w, ent.x, ent.y); } return; }
      g.orderMove(units, x, y); this.marker(x, y, '#5fff8a');
    } else if (buildings.length === 1 && buildings[0].def.trains) { buildings[0].rally = { x, y }; this.marker(x, y, '#ffd479'); }
  }

  marker(x, y, color) { this.clickMarker = { x, y, color, t: 0.5 }; this.g.emit('ack', x, y, this.g.human); }

  onKey(e) {
    const g = this.g;
    if (e.target && e.target.tagName === 'SELECT') return;
    this.keys[e.key] = true;
    if (e.key === 'Escape') { if (this.pending) { this.pending = null; return; } if (this.ui && this.ui.buildMenu) { this.ui.buildMenu = false; return; } g.selection = []; return; }
    if (e.key === 'p' || e.key === 'P') { g.paused = !g.paused; document.getElementById('pausebox').style.display = g.paused ? 'block' : 'none'; return; }
    if ((e.key === 'm' || e.key === 'M') && window.sfx) { sfx.muted = !sfx.muted; g.msg('Sound ' + (sfx.muted ? 'off' : 'on')); return; }
    if (e.key === ' ') { e.preventDefault(); const b = g.baseOf(g.human); if (g.attackPing && g.attackPing.t > 0) { g.camera.x = g.attackPing.x - this.r.viewW / 2; g.camera.y = g.attackPing.y - this.r.viewH / 2; } else if (b) { g.camera.x = b.x - this.r.viewW / 2; g.camera.y = b.y - this.r.viewH / 2; } return; }
    if (/^[0-9]$/.test(e.key)) {
      if (e.ctrlKey) { g.groups[e.key] = g.selection.filter(x => x.owner === g.human); e.preventDefault(); }
      else if (g.groups[e.key] && g.groups[e.key].length) { g.selection = g.groups[e.key].filter(x => !x.dead); if (this.lastGroupKey === e.key && g.time - this.lastGroupTime < 0.4 && g.selection.length) { g.camera.x = g.selection[0].x - this.r.viewW / 2; g.camera.y = g.selection[0].y - this.r.viewH / 2; } this.lastGroupKey = e.key; this.lastGroupTime = g.time; }
      return;
    }
    if (e.key === 'F1') { e.preventDefault(); g.selection = g.units(g.human).filter(u => u.isCombat); return; }
    if (e.key === 'F2') { e.preventDefault(); const h = g.heroes(g.human); if (h.length) { g.selection = [h[0]]; g.camera.x = h[0].x - this.r.viewW / 2; g.camera.y = h[0].y - this.r.viewH / 2; } return; }
    if (e.key === 'Tab') { e.preventDefault(); const idle = g.units(g.human).filter(u => u.isWorker && u.order.type === 'idle'); if (idle.length) { g.selection = [idle[0]]; g.camera.x = idle[0].x - this.r.viewW / 2; g.camera.y = idle[0].y - this.r.viewH / 2; } return; }
    if (e.ctrlKey || e.altKey || e.metaKey) return;
    if (this.ui && this.ui.handleKey(e.key)) { e.preventDefault(); }
  }

  updateCamera(dt) {
    const cam = this.g.camera, sp = 700 * dt;
    if (this.keys.ArrowLeft) cam.x -= sp; if (this.keys.ArrowRight) cam.x += sp;
    if (this.keys.ArrowUp) cam.y -= sp; if (this.keys.ArrowDown) cam.y += sp;
    const m = this.mouse, W = this.canvas.width, H = this.r.viewH, edge = 14;
    if (document.hasFocus() && m.x >= 0 && m.y >= 0 && m.x <= W && m.y <= this.canvas.height) {
      if (m.x < edge) cam.x -= sp; if (m.x > W - edge) cam.x += sp;
      if (m.y < edge && m.y > 34) cam.y -= sp; if (m.y > H - edge && m.y < H + 4) cam.y += sp;
    }
    if (this.clickMarker) this.clickMarker.t -= dt;
  }
}
