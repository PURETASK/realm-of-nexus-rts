// Core game state and simulation
class Player {
  constructor(index, factionId, isAI, color) {
    this.index = index; this.faction = FACTIONS[factionId]; this.isAI = isAI; this.color = color;
    this.res = Object.assign({}, this.faction.startRes);
    this.tier = 1; this.research = new Set(); this.supplyUsed = 0; this.supplyCap = 0;
    this.heroCooldowns = {}; this.vision = new Uint8Array(MAP_W * MAP_H); // 0 unseen, 1 explored, 2 visible
    this.reveal = []; // {x,y,r,t}
    this.incomeMul = 1; this.defeated = false; this.kills = 0; this.losses = 0;
    this.stats = { p: 0, s: 0 };
  }
  eff(key, mode, unit) {
    let v = mode === 'mul' ? 1 : 0;
    for (const id of this.research) {
      const e = this.faction.research[id] && this.faction.research[id].effect;
      if (!e || e[key] == null) continue;
      if (unit) { if (e.minTier && unit.def.tier < e.minTier) continue; if (e.undeadOnly && !unit.def.undead) continue; if (e.onAffinity && !unit.onOwnLayer) continue; }
      if (mode === 'mul') v *= e[key]; else v += e[key];
    }
    return v;
  }
  canAfford(cost) { if (!cost) return true; return (this.res.p >= (cost.p || 0)) && (this.res.s >= (cost.s || 0)) && (this.res.c >= (cost.c || 0)); }
  pay(cost) { if (!cost) return; this.res.p -= cost.p || 0; this.res.s -= cost.s || 0; this.res.c -= cost.c || 0; }
  refund(cost) { if (!cost) return; this.res.p += cost.p || 0; this.res.s += cost.s || 0; this.res.c += cost.c || 0; }
}

class Game {
  constructor(opts) {
    this.opts = opts;
    this.map = new GameMap(opts.seed || Math.floor(Math.random() * 1e9));
    this.players = [new Player(0, opts.playerFaction, false, PLAYER_COLORS[0]), new Player(1, opts.aiFaction, true, PLAYER_COLORS[1])];
    this.human = 0;
    this.entities = []; this.corpses = []; this.effects = []; this.projectiles = [];
    this.time = 0; this.paused = false; this.over = false; this.winner = -1;
    this.weather = { storm: null, cloud: [] };
    this.visionTimer = 0; this.messages = []; this.events = [];
    this.selection = []; this.groups = {};
    this.difficulty = DIFFICULTY[opts.difficulty || 'normal'];
    this.players[1].incomeMul = this.difficulty.incomeMul;
    this.setup();
    this.ai = new AIController(this, 1);
  }

  setup() {
    for (let i = 0; i < 2; i++) {
      const p = this.players[i], s = this.map.starts[i];
      const base = this.placeBuilding(i, p.faction.base, s.tx, s.ty, true);
      const wx = base.x, wy = base.y + 2.5 * TILE;
      const nWorkers = p.faction.id === 'tempest' ? 3 : 5;
      for (let k = 0; k < nWorkers; k++) {
        const w = this.spawnUnit(i, p.faction.worker, wx + (k - nWorkers / 2) * 26, wy + 10);
        if (p.faction.gathers) { const n = this.nearestNode(w, 'primary'); if (n) this.orderGather([w], n); }
      }
      if (p.faction.affinity) this.map.addLayerSource(p.faction.affinity, base.x, base.y, 5, 3);
    }
    for (let k = 0; k < 40; k++) this.map.updateLayers(1); // pre-seed terrain around bases
    this.respawns = [];
    this.updateSupply(0); this.updateSupply(1);
    this.camera = { x: this.map.starts[0].tx * TILE - 300, y: this.map.starts[0].ty * TILE - 250 };
    const f = this.players[0].faction;
    this.msg(`You command the ${f.name}. ${f.tips[0]}`, 'good');
    this.tipIndex = 1;
  }

  // ---------- helpers ----------
  abyssTier() { const p = this.players.find(p => p.faction.id === 'abyss'); return p ? p.tier : 0; }
  msg(text, cls) { this.messages.push({ text, cls: cls || '', t: 9 }); if (this.messages.length > 6) this.messages.shift(); }
  addEffect(e) { e.t = e.t || 0.5; e.max = e.t; this.effects.push(e); }

  units(owner) { return this.entities.filter(e => e.kind === 'unit' && !e.dead && (owner == null || e.owner === owner)); }
  buildings(owner) { return this.entities.filter(e => e.kind === 'building' && !e.dead && (owner == null || e.owner === owner)); }
  baseOf(owner) { return this.entities.find(e => e.kind === 'building' && !e.dead && e.owner === owner && e.def.isBase); }
  heroes(owner) { return this.entities.filter(e => e.kind === 'unit' && !e.dead && e.owner === owner && e.isHero); }

  nearby(x, y, r, filter) {
    const r2 = r * r, out = [];
    for (const e of this.entities) {
      if (e.dead) continue;
      if (filter && !filter(e)) continue;
      const d = e.kind === 'building' ? distToRect(x, y, e.tx * TILE, e.ty * TILE, e.w * TILE, e.h * TILE) : dist(x, y, e.x, e.y);
      if (d <= r) out.push(e);
    }
    return out;
  }
  enemiesNear(owner, x, y, r, includeBuildings) {
    return this.nearby(x, y, r, e => e.owner !== owner && e.owner >= 0 && (includeBuildings || e.kind === 'unit') && !(e.kind === 'building' && e.def.invisible && !this.canSee(owner, e)));
  }
  alliesNear(owner, x, y, r, includeBuildings) { return this.nearby(x, y, r, e => e.owner === owner && (includeBuildings || e.kind === 'unit')); }

  canSee(viewer, e) {
    if (viewer === e.owner) return true;
    const p = this.players[viewer];
    if (p.isAI) return !(e.invisible) || this.detected(viewer, e);
    const tx = Math.floor(e.x / TILE), ty = Math.floor(e.y / TILE);
    if (!this.map.inBounds(tx, ty)) return false;
    if (p.vision[this.map.idx(tx, ty)] !== 2) return e.kind === 'building' && p.vision[this.map.idx(tx, ty)] === 1 && !e.invisible;
    if (e.invisible) return this.detected(viewer, e);
    return true;
  }
  detected(viewer, e) {
    const vf = this.players[viewer].faction;
    if (vf.affinity === 'light' && this.map.layerAtWorld('light', e.x, e.y) > 0.3) return true;
    for (const d of this.entities) {
      if (d.dead || d.owner !== viewer) continue;
      if (d.kind === 'building' && d.def.detector && d.complete && dist(d.x, d.y, e.x, e.y) < d.stat('sight')) return true;
      if (d.kind === 'unit' && d.hasBuff('detector_aura') && dist(d.x, d.y, e.x, e.y) < 6 * TILE) return true;
    }
    for (const w of this.entities) if (!w.dead && w.kind === 'building' && w.owner === viewer && w.def.aura && w.def.aura.id === 'zephyr' && dist(w.x, w.y, e.x, e.y) < 5 * TILE) return true;
    return false;
  }

  // ---------- spawning ----------
  spawnUnit(owner, defId, x, y, opts) {
    const u = new Unit(this, owner, defId, x, y);
    if (opts) Object.assign(u, opts);
    // nudge off blocked tiles
    if (!u.flying && this.map.isBlocked(u.tileX, u.tileY, false)) { const nf = this.map.nearestFree(u.tileX, u.tileY, false); u.x = nf.tx * TILE + TILE / 2; u.y = nf.ty * TILE + TILE / 2; }
    this.entities.push(u);
    this.updateSupply(owner);
    return u;
  }

  placeBuilding(owner, defId, tx, ty, complete) {
    const b = new Building(this, owner, defId, tx, ty, complete);
    this.map.setBlocked(tx, ty, b.w, b.h, true, b.def.blocksAir);
    const node = this.map.nodeUnder(tx, ty, b.w, b.h);
    if (node) { node.building = b; b.node = node; }
    this.entities.push(b);
    if (complete) this.updateSupply(owner);
    return b;
  }

  canPlace(owner, defId, tx, ty) {
    const p = this.players[owner], def = p.faction.buildings[defId];
    if (!def) return false;
    if (def.needsNode) {
      const node = this.map.nodeUnder(tx, ty, def.w, def.h);
      if (!node || node.type !== def.needsNode || node.building) return false;
      for (let y = ty; y < ty + def.h; y++) for (let x = tx; x < tx + def.w; x++) if (this.map.isBlocked(x, y, false)) return false;
      return true;
    }
    if (!this.map.areaFree(tx, ty, def.w, def.h)) return false;
    // don't trap units: buildings can't be placed directly on top of other units' tiles (they get pushed anyway)
    return true;
  }

  updateSupply(owner) {
    const p = this.players[owner];
    let used = 0;
    for (const e of this.entities) if (!e.dead && e.owner === owner && e.kind === 'unit') used += e.def.supply || 0;
    let cap = p.faction.tiers[p.tier - 1].supply;
    for (const e of this.entities) if (!e.dead && e.owner === owner && e.kind === 'building' && e.complete && e.def.supply) cap += e.def.supply;
    p.supplyUsed = used; p.supplyCap = Math.min(MAX_SUPPLY, cap);
  }

  // ---------- production ----------
  canQueue(b, item) {
    const p = b.player, f = p.faction;
    if (!b.complete || b.relocate) return { ok: false, why: 'Building not ready' };
    if (item.type === 'unit' || item.type === 'hero') {
      const def = unitDef(f, item.id);
      if (item.type === 'unit' && def.tier > p.tier) return { ok: false, why: 'Requires Tier ' + def.tier };
      if (item.type === 'hero') {
        const count = this.heroes(b.owner).length + this.buildings(b.owner).reduce((n, bb) => n + bb.queue.filter(q => q.type === 'hero').length, 0);
        if (count >= p.tier) return { ok: false, why: 'Tier ' + p.tier + ' allows ' + p.tier + ' hero' + (p.tier > 1 ? 'es' : '') };
        if (this.heroes(b.owner).some(h => h.defId === item.id) || this.buildings(b.owner).some(bb => bb.queue.some(q => q.id === item.id))) return { ok: false, why: 'Already summoned' };
        if ((p.heroCooldowns[item.id] || 0) > 0) return { ok: false, why: 'Returns in ' + Math.ceil(p.heroCooldowns[item.id]) + 's' };
      }
      if (def.unique && (this.units(b.owner).some(u => u.defId === item.id) || b.queue.some(q => q.id === item.id))) return { ok: false, why: 'Only one may exist' };
      if ((def.supply || 0) > 0 && p.supplyUsed + def.supply > p.supplyCap) return { ok: false, why: 'Not enough supply' };
      if (!p.canAfford(def.cost)) return { ok: false, why: 'Not enough resources' };
      return { ok: true, cost: def.cost, time: def.time };
    }
    if (item.type === 'research') {
      const r = f.research[item.id];
      if (p.research.has(item.id)) return { ok: false, why: 'Already researched' };
      if (this.buildings(b.owner).some(bb => bb.queue.some(q => q.type === 'research' && q.id === item.id))) return { ok: false, why: 'In progress' };
      if (r.tier > p.tier) return { ok: false, why: 'Requires Tier ' + r.tier };
      if (!p.canAfford(r.cost)) return { ok: false, why: 'Not enough resources' };
      return { ok: true, cost: r.cost, time: r.time };
    }
    if (item.type === 'tier') {
      if (p.tier >= 3) return { ok: false, why: 'Max tier' };
      const t = f.tiers[p.tier];
      if (b.queue.some(q => q.type === 'tier')) return { ok: false, why: 'In progress' };
      if (!this.buildings(b.owner).some(bb => bb.defId === t.requires && bb.complete)) return { ok: false, why: 'Requires ' + f.buildings[t.requires].name };
      if (!p.canAfford(t.cost)) return { ok: false, why: 'Not enough resources' };
      return { ok: true, cost: t.cost, time: t.time };
    }
    return { ok: false, why: '?' };
  }

  enqueue(b, item) {
    const c = this.canQueue(b, item);
    if (!c.ok) { if (b.owner === this.human) this.msg(c.why, 'warn'); return false; }
    if (b.queue.length >= 6) return false;
    b.player.pay(c.cost);
    b.queue.push({ type: item.type, id: item.id, time: c.time, elapsed: 0, cost: c.cost });
    return true;
  }
  dequeue(b, i) {
    const q = b.queue[i]; if (!q) return;
    b.player.refund(q.cost); b.queue.splice(i, 1);
  }

  // sound / feel events for the presentation layer: {type, x, y, owner, ...}
  emit(type, x, y, owner, extra) { if (this.events.length > 200) return; this.events.push(Object.assign({ type, x, y, owner }, extra || {})); }

  finishQueueItem(b, q) {
    const p = b.player, f = p.faction;
    if (q.type === 'unit' || q.type === 'hero') {
      const sp = this.spawnPoint(b);
      const u = this.spawnUnit(b.owner, q.id, sp.x, sp.y);
      this.emit('ready', b.x, b.y, b.owner, { what: q.type });
      if (b.rally) this.orderMove([u], b.rally.x, b.rally.y);
      else if (u.isWorker && f.gathers) { const n = this.nearestNode(u, 'primary'); if (n) this.orderGather([u], n); }
      if (q.type === 'hero' && b.owner === this.human) this.msg(`${u.name} has answered the call.`, 'good');
      if (q.type === 'hero' && this.opts.playerFaction && this.tipIndex < f.tips.length && b.owner === this.human) { this.msg(f.tips[this.tipIndex++]); }
    } else if (q.type === 'research') {
      p.research.add(q.id); this.emit('ready', b.x, b.y, b.owner, { what: 'research' });
      if (b.owner === this.human) this.msg(`Research complete: ${f.research[q.id].name}`, 'good');
    } else if (q.type === 'tier') {
      p.tier++;
      const t = f.tiers[p.tier - 1];
      b.maxHp = t.hp; b.hp = Math.min(b.maxHp, b.hp + 600);
      this.updateSupply(b.owner); this.emit('tier', b.x, b.y, b.owner);
      this.msg(`${p.isAI ? 'The enemy' : 'You'} ascended to ${t.name}!`, p.isAI ? 'warn' : 'good');
      if (b.owner === this.human && this.tipIndex < f.tips.length) this.msg(f.tips[this.tipIndex++]);
    }
  }

  spawnPoint(b) {
    // free tile around building perimeter closest to rally or below
    const cands = [];
    for (let y = b.ty - 1; y <= b.ty + b.h; y++) for (let x = b.tx - 1; x <= b.tx + b.w; x++) {
      if (y >= b.ty && y < b.ty + b.h && x >= b.tx && x < b.tx + b.w) continue;
      if (!this.map.isBlocked(x, y, false)) cands.push({ x: x * TILE + TILE / 2, y: y * TILE + TILE / 2 });
    }
    if (!cands.length) return { x: b.x, y: b.y + (b.h / 2 + 1) * TILE };
    const ref = b.rally || { x: b.x, y: b.y + 999 };
    cands.sort((a, c) => dist2(a.x, a.y, ref.x, ref.y) - dist2(c.x, c.y, ref.x, ref.y));
    return cands[0];
  }

  nearestNode(u, type) {
    let best = null, bd = Infinity;
    for (const n of this.map.nodes) {
      if (n.type !== type || n.amount <= 0) continue;
      if (type === 'primary' && n.building && n.building.owner !== u.owner) continue;
      const d = dist2(u.x, u.y, n.x, n.y);
      if (d < bd) { bd = d; best = n; }
    }
    return best;
  }
  nearestDropoff(u) {
    let best = null, bd = Infinity;
    for (const b of this.entities) {
      if (b.dead || b.kind !== 'building' || b.owner !== u.owner || !b.def.dropoff || !b.complete) continue;
      const d = dist2(u.x, u.y, b.x, b.y);
      if (d < bd) { bd = d; best = b; }
    }
    return best;
  }

  // ---------- orders ----------
  clearOrder(u) { u.order = { type: 'idle' }; u.path = []; u.target = null; u.buildTask = null; u.holdPos = false; }
  setPath(u, x, y) {
    if (this.pathCalls >= 14) { u.pendingPath = { x, y }; u.path = []; u.pathTarget = { x, y }; return; }
    this.pathCalls++;
    u.pendingPath = null;
    u.path = Pathfinder.find(this.map, u.x, u.y, x, y, u.flying);
    u.pathTarget = { x, y };
  }
  orderMove(units, x, y, attackMove) {
    const n = units.length; let i = 0;
    for (const u of units) {
      if (u.kind !== 'unit' || u.dead) continue;
      let ox = 0, oy = 0;
      if (n > 1) { const ring = Math.floor(Math.sqrt(i)), ang = i * 2.399; ox = Math.cos(ang) * ring * 26; oy = Math.sin(ang) * ring * 26; }
      i++;
      this.clearOrder(u);
      u.order = { type: attackMove ? 'attackmove' : 'move', x: x + ox, y: y + oy };
      this.setPath(u, x + ox, y + oy);
    }
  }
  orderAttack(units, target) {
    for (const u of units) {
      if (u.kind !== 'unit' || u.dead) continue;
      if (!u.canAttack(target)) { this.orderMove([u], target.x, target.y, true); continue; }
      this.clearOrder(u);
      u.order = { type: 'attack', target };
      u.target = target;
    }
  }
  orderStop(units) { for (const u of units) if (u.kind === 'unit') this.clearOrder(u); }
  orderHold(units) { for (const u of units) if (u.kind === 'unit') { this.clearOrder(u); u.holdPos = true; u.order = { type: 'hold' }; } }
  orderGather(units, node) {
    for (const u of units) {
      if (u.kind !== 'unit' || !u.isWorker || !u.faction.gathers) continue;
      this.clearOrder(u);
      u.order = { type: 'gather' };
      u.gather.node = node; u.gather.phase = u.gather.carrying > 0 ? 'toDrop' : 'toNode';
      this.setPath(u, node.x, node.y);
    }
  }
  orderBuild(units, defId, tx, ty) {
    const workers = units.filter(u => u.kind === 'unit' && u.isWorker && !u.dead);
    if (!workers.length) return false;
    const p = workers[0].player, def = p.faction.buildings[defId];
    if (!this.canPlace(workers[0].owner, defId, tx, ty)) { if (p.index === this.human) this.msg('Cannot build there', 'warn'); return false; }
    if (def.tier > p.tier) { if (p.index === this.human) this.msg('Requires Tier ' + def.tier, 'warn'); return false; }
    if (!p.canAfford(def.cost)) { if (p.index === this.human) this.msg('Not enough resources', 'warn'); return false; }
    p.pay(def.cost);
    // push units off the footprint
    const b = this.placeBuilding(workers[0].owner, defId, tx, ty, false);
    for (const u of this.units()) {
      if (u.flying) continue;
      if (u.tileX >= tx && u.tileX < tx + def.w && u.tileY >= ty && u.tileY < ty + def.h) {
        const nf = this.map.nearestFree(u.tileX, u.tileY, false); u.x = nf.tx * TILE + TILE / 2; u.y = nf.ty * TILE + TILE / 2;
      }
    }
    for (const u of workers) {
      this.clearOrder(u);
      u.order = { type: 'build', building: b };
      u.buildTask = b;
      this.setPath(u, b.x, b.y);
    }
    return b;
  }
  orderRelocate(b, tx, ty) {
    if (!b.def.abilities || !b.def.abilities.includes('relocate') || b.relocate) return false;
    if ((b.cooldowns.relocate || 0) > 0) { if (b.owner === this.human) this.msg('Relocate on cooldown', 'warn'); return false; }
    if (!this.map.areaFree(tx, ty, b.w, b.h)) {
      // allow current footprint overlap check: temporarily unblock
      this.map.setBlocked(b.tx, b.ty, b.w, b.h, false);
      const ok = this.map.areaFree(tx, ty, b.w, b.h);
      this.map.setBlocked(b.tx, b.ty, b.w, b.h, true);
      if (!ok) { if (b.owner === this.human) this.msg('Cannot land there', 'warn'); return false; }
    }
    b.relocate = { phase: 'lift', tx, ty, t: 0, fromX: b.x, fromY: b.y, toX: (tx + b.w / 2) * TILE, toY: (ty + b.h / 2) * TILE };
    b.queue.forEach(q => b.player.refund(q.cost)); b.queue = [];
    this.map.setBlocked(b.tx, b.ty, b.w, b.h, false);
    this.addEffect({ type: 'ring', x: b.x, y: b.y, r: 60, color: '#8fd3ff', t: 1 });
    return true;
  }

  // ---------- main update ----------
  update(dt) {
    if (this.paused || this.over) return;
    this.time += dt;
    this.pathCalls = 0;
    // weather
    if (this.weather.storm && (this.weather.storm.until -= dt) <= 0) { this.weather.storm = null; this.msg('The storm passes.'); }
    this.weather.cloud = this.weather.cloud.filter(c => (c.t -= dt) > 0);

    // income & buildings
    for (const b of this.entities) if (b.kind === 'building' && !b.dead) this.updateBuilding(b, dt);
    // units
    for (const u of this.entities) if (u.kind === 'unit' && !u.dead) this.updateUnit(u, dt);
    this.separateUnits();
    // combat systems
    this.updateProjectiles(dt);
    this.updateCorpses(dt);
    this.updateMines();
    // terrain layers
    this.map.updateLayers(dt);
    // rebirths
    for (const r of this.respawns) { r.t -= dt; if (r.t <= 0) { const u = this.spawnUnit(r.owner, r.defId, r.x, r.y); u.reborn = true; u.hp = u.maxHp * 0.5; this.addEffect({ type: 'burst', x: r.x, y: r.y, r: 40, color: '#ffb347', t: 0.8 }); } }
    this.respawns = this.respawns.filter(r => r.t > 0);
    // effects
    for (const e of this.effects) e.t -= dt;
    this.effects = this.effects.filter(e => e.t > 0);
    for (const m of this.messages) m.t -= dt;
    this.messages = this.messages.filter(m => m.t > 0);
    // players
    for (const p of this.players) {
      for (const k in p.heroCooldowns) if (p.heroCooldowns[k] > 0) p.heroCooldowns[k] -= dt;
      p.reveal = p.reveal.filter(r => (r.t -= dt) > 0);
    }
    // cleanup
    if (this.entities.some(e => e.dead)) {
      this.entities = this.entities.filter(e => !e.dead);
      this.selection = this.selection.filter(e => !e.dead);
      for (const k in this.groups) this.groups[k] = this.groups[k].filter(e => !e.dead);
    }
    // vision
    this.visionTimer -= dt;
    if (this.visionTimer <= 0) { this.visionTimer = VISION_REFRESH; this.computeVision(this.human); }
    // AI
    this.ai.update(dt);
    // victory
    for (const p of this.players) {
      if (!p.defeated && this.buildings(p.index).length === 0) { p.defeated = true; }
    }
    if (this.players.some(p => p.defeated)) { this.over = true; this.winner = this.players.find(p => !p.defeated)?.index ?? -1; }
  }

  updateBuilding(b, dt) {
    const p = b.player, f = p.faction;
    for (const k in b.cooldowns) if (b.cooldowns[k] > 0) b.cooldowns[k] -= dt;
    // construction
    if (!b.complete) {
      if (b.builders > 0 || b.def.grows) {
        const rate = b.builders > 0 ? Math.min(b.builders, 3) * (b.builders > 1 ? 0.7 : 1) : 0.45;
        b.progress = Math.min(1, b.progress + dt / b.buildTime * rate);
        b.hp = Math.min(b.maxHp, b.hp + b.maxHp * 0.9 * dt / b.buildTime);
        if (b.complete) { b.hp = b.maxHp; this.updateSupply(b.owner); this.emit('build_done', b.x, b.y, b.owner); if (b.owner === this.human) this.msg(`${b.name} complete.`); }
      }
      b.builders = 0;
      return;
    }
    // relocation
    if (b.relocate) { this.updateRelocate(b, dt); return; }
    // income
    if (b.def.income || b.def.isBase) {
      let inc = b.def.income ? Object.assign({}, b.def.income) : {};
      if (b.def.isBase && f.tiers[p.tier - 1].income) inc.p = (inc.p || 0) + f.tiers[p.tier - 1].income;
      let mul = p.incomeMul * p.eff('income', 'mul');
      if (this.heroes(b.owner).some(h => h.defId === 'lyrian')) mul *= 1.1;
      if (p.hasBuff && false) {}
      if (this.playerBuff(p, 'trade_winds')) mul *= 1.5;
      if (this.playerBuff(p, 'prosperity')) mul *= 1.4;
      if (inc.p) {
        let amt = inc.p * mul * dt;
        if (b.node) { if (b.node.amount <= 0) amt = 0; else { amt = Math.min(amt, b.node.amount); b.node.amount -= amt; } }
        p.res.p += amt; p.stats.p += amt;
      }
      if (inc.s) { let amt = inc.s * mul * dt; if (this.weather.storm && b.node) amt *= 2; p.res.s += amt; p.stats.s += amt; }
    }
    // converter
    if (b.def.converter && b.toggles.convert) {
      const c = b.def.converter, take = Math.min(p.res[c.from], c.rate * dt);
      if (take > 0) { p.res[c.from] -= take; p.res[c.to] += take * c.ratio; }
    }
    // catalyst generation
    if (b.def.catalystGen && p.res.c < 1) {
      b.catalystTimer += dt;
      if (b.catalystTimer >= b.def.catalystGen.every) { b.catalystTimer = 0; p.res.c += 1; this.msg(`${p.isAI ? 'Enemy' : 'A'} ${f.resources.catalyst.name} has formed.`, p.isAI ? 'warn' : 'good'); }
    }
    if (b.def.isBase && f.id === 'abyss' && p.tier >= 3 && p.res.c < 1) {
      b.catalystTimer += dt;
      if (b.catalystTimer >= 150) { b.catalystTimer = 0; p.res.c += 1; this.msg(`${p.isAI ? 'Enemy' : 'An'} Oblivion Shard has crystallized.`, p.isAI ? 'warn' : 'good'); }
    }
    // spawner
    if (b.def.spawner) {
      b.spawnTimer += dt;
      if (b.spawnTimer >= b.def.spawner.every && p.supplyUsed < p.supplyCap) { b.spawnTimer = 0; const sp = this.spawnPoint(b); this.spawnUnit(b.owner, b.def.spawner.unit, sp.x, sp.y); }
    }
    // terrain layer sources
    if (b.def.isBase && f.affinity) this.map.addLayerSource(f.affinity, b.x, b.y, f.tiers[p.tier - 1].terrain || 5, 2 * p.eff('layerGrow', 'mul'));
    else if (b.def.corrupt) this.map.addLayerSource('blight', b.x, b.y, b.def.corrupt, 1.5 * p.eff('layerGrow', 'mul'));
    else if (b.def.light) this.map.addLayerSource('light', b.x, b.y, b.def.light, 1.5 * p.eff('layerGrow', 'mul'));
    else if (b.def.grow) this.map.addLayerSource('grove', b.x, b.y, b.def.grow, 1.5 * p.eff('layerGrow', 'mul'));
    // queue
    if (b.queue.length) {
      const q = b.queue[0];
      let speed = 1;
      if (b.hasBuff && b.hasBuff('dark_pact')) speed = 2.5;
      if (b.darkPact > 0) { b.darkPact -= dt; speed = 2.5; }
      if (this.playerBuff(p, 'trade_winds')) speed *= 1.5;
      if (this.playerBuff(p, 'prosperity')) speed *= 1.3;
      q.elapsed += dt * speed;
      if (q.elapsed >= q.time) {
        b.queue.shift();
        this.finishQueueItem(b, q);
      }
    }
    // tower
    if (b.def.tower && b.def.tower.dmg > 0 || (b.def.isBase && f.id === 'tempest')) this.updateTower(b, dt);
    // auras
    if (b.def.aura) this.applyBuildingAura(b, dt);
    // bone wall regen handled on deaths
  }

  playerBuff(p, id) { return (p.buffs && p.buffs[id] > 0); }
  addPlayerBuff(p, id, dur) { p.buffs = p.buffs || {}; p.buffs[id] = Math.max(p.buffs[id] || 0, dur); }

  updateRelocate(b, dt) {
    const r = b.relocate;
    r.t += dt;
    if (r.phase === 'lift') { if (r.t > 2) { r.phase = 'fly'; r.t = 0; } return; }
    if (r.phase === 'fly') {
      const sp = 2.2 * TILE * dt, d = dist(b.x, b.y, r.toX, r.toY);
      if (d <= sp) { b.x = r.toX; b.y = r.toY; r.phase = 'land'; r.t = 0; }
      else { b.x += (r.toX - b.x) / d * sp; b.y += (r.toY - b.y) / d * sp; }
      return;
    }
    if (r.phase === 'land' && r.t > 2) {
      // ensure area free, else find nearest
      let tx = r.tx, ty = r.ty;
      if (!this.map.areaFree(tx, ty, b.w, b.h)) {
        outer: for (let rad = 1; rad < 10; rad++) for (let dy = -rad; dy <= rad; dy++) for (let dx = -rad; dx <= rad; dx++) {
          if (this.map.areaFree(tx + dx, ty + dy, b.w, b.h)) { tx += dx; ty += dy; break outer; }
        }
      }
      b.tx = tx; b.ty = ty; b.x = (tx + b.w / 2) * TILE; b.y = (ty + b.h / 2) * TILE;
      this.map.setBlocked(tx, ty, b.w, b.h, true, b.def.blocksAir);
      for (const u of this.units()) if (!u.flying && u.tileX >= tx && u.tileX < tx + b.w && u.tileY >= ty && u.tileY < ty + b.h) { const nf = this.map.nearestFree(u.tileX, u.tileY, false); u.x = nf.tx * TILE + TILE / 2; u.y = nf.ty * TILE + TILE / 2; }
      b.relocate = null; b.cooldowns.relocate = 60;
      this.addEffect({ type: 'ring', x: b.x, y: b.y, r: 70, color: '#8fd3ff', t: 1 });
      if (b.owner === this.human) this.msg('Stormspire has landed.');
    }
  }

  applyBuildingAura(b, dt) {
    const a = b.def.aura, r = a.radius * TILE;
    if (a.id === 'cyclone') {
      for (const u of this.alliesNear(b.owner, b.x, b.y, r)) u.addBuff('cyclone', 0.3, { rangedTakenMul: 0.5 });
      for (const u of this.enemiesNear(b.owner, b.x, b.y, r)) if (!u.flying) u.addBuff('cyclone_slow', 0.3, { speedMul: 0.65 });
    } else if (a.id === 'blight_miasma') {
      for (const u of this.enemiesNear(b.owner, b.x, b.y, r)) { u.addBuff('miasma', 0.3, { speedMul: 0.75, armorAdd: -1 }); this.damage(u, 1.5 * dt, b, 'magic', true); }
    } else if (a.id === 'healing') {
      for (const u of this.alliesNear(b.owner, b.x, b.y, r)) { if (u.hp < u.maxHp) u.hp = Math.min(u.maxHp, u.hp + (a.rate || 3) * dt); if (u.maxShield) u.shield = Math.min(u.stat('maxShield'), u.shield + 4 * dt); }
    } else if (a.id === 'consecrated') {
      for (const u of this.alliesNear(b.owner, b.x, b.y, r)) u.addBuff('consecrated', 0.3, { dmgTakenMul: 0.85 });
      for (const u of this.enemiesNear(b.owner, b.x, b.y, r)) if (u.def.undead) u.addBuff('holy_ground', 0.3, { dmgMul: 0.8 });
    } else if (a.id === 'thorns') {
      for (const u of this.enemiesNear(b.owner, b.x, b.y, r)) if (!u.flying) { u.addBuff('entangled', 0.3, { speedMul: 0.5 }); this.damage(u, 2 * dt, b, 'physical', true); }
    } else if (a.id === 'bell') {
      for (const u of this.alliesNear(b.owner, b.x, b.y, r)) u.addBuff('bell', 0.3, { atkSpeedMul: 1.1 });
    }
  }

  // ---------- units ----------
  updateUnit(u, dt) {
    // buffs / cooldowns
    for (const b of u.buffs) { b.t -= dt; if (b.mods.dot) this.damage(u, b.mods.dot * dt, b.source || null, 'magic', true); }
    u.buffs = u.buffs.filter(b => b.t > 0);
    for (const k in u.cooldowns) if (u.cooldowns[k] > 0) u.cooldowns[k] -= dt;
    if (u.attackTimer > 0) u.attackTimer -= dt;
    if (u.lifetime > 0) { u.lifetime -= dt; if (u.lifetime <= 0) { this.kill(u, null, true); return; } }
    // regen
    const rg = u.stat('regen'); if (rg > 0 && u.hp < u.maxHp) u.hp = Math.min(u.maxHp, u.hp + rg * dt);
    if (u.maxShield) { u.shieldDelay -= dt; const ms = u.stat('maxShield'); if (u.shieldDelay <= 0 && u.shield < ms) u.shield = Math.min(ms, u.shield + ms * 0.10 * dt); }
    if (u.def.heal && u.attackTimer <= 0) this.tryHeal(u);
    // heroes passive/auras
    if (u.isHero) this.updateHeroPassives(u, dt);
    if (u.def.aura) this.applyUnitAura(u, dt);
    if (u.def.raiseDead && u.attackTimer <= 0) this.tryRaiseDead(u);
    if (u.stunned) return;
    // orders
    switch (u.order.type) {
      case 'idle': case 'hold': this.idleBehaviour(u, dt); break;
      case 'move': this.followPath(u, dt, () => this.clearOrder(u)); break;
      case 'attackmove': this.attackMoveBehaviour(u, dt); break;
      case 'attack': this.attackBehaviour(u, dt); break;
      case 'gather': this.gatherBehaviour(u, dt); break;
      case 'build': this.buildBehaviour(u, dt); break;
      case 'cast': this.castBehaviour(u, dt); break;
    }
  }

  acquireTarget(u, range) {
    let best = null, bd = Infinity;
    const cands = this.enemiesNear(u.owner, u.x, u.y, range, true);
    for (const e of cands) {
      if (!u.canAttack(e)) continue;
      if (e.kind === 'building' && !this.canSee(u.owner, e)) continue;
      if (e.kind === 'unit' && e.invisible && !this.detected(u.owner, e)) continue;
      let d = u.distTo(e);
      if (e.kind === 'building') d += 200; // prefer units
      if (e.kind === 'building' && e.def.wall) d += 300;
      if (e.kind === 'unit' && e.isWorker) d += 60;
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  idleBehaviour(u, dt) {
    if (u.isWorker && u.faction.gathers && u.gather.carrying > 0) { u.order = { type: 'gather' }; u.gather.phase = 'toDrop'; return; }
    if (u.def.dmg <= 0) return;
    const t = this.acquireTarget(u, Math.max(u.stat('sight'), u.stat('range')) * (u.isWorker ? 0.5 : 1));
    if (t && !u.isWorker) { u.target = t; u.order = { type: 'attack', target: t, returnTo: u.holdPos ? null : { x: u.x, y: u.y }, hold: u.holdPos }; }
    else if (t && u.isWorker && u.distTo(t) < u.stat('range') + 10) { this.tryAttack(u, t, dt); }
  }

  attackMoveBehaviour(u, dt) {
    if (!u.target || u.target.dead) {
      const t = this.acquireTarget(u, Math.max(u.stat('sight'), u.stat('range')));
      if (t) { u.target = t; }
    }
    if (u.target && !u.target.dead) { this.engage(u, u.target, dt); return; }
    this.followPath(u, dt, () => this.clearOrder(u));
  }

  attackBehaviour(u, dt) {
    const t = u.order.target;
    if (!t || t.dead || (t.kind === 'unit' && t.invisible && !this.detected(u.owner, t))) {
      if (u.order.returnTo && !u.order.hold) { const r = u.order.returnTo; this.clearOrder(u); u.order = { type: 'attackmove', x: r.x, y: r.y }; this.setPath(u, r.x, r.y); }
      else { const hold = u.order.hold; this.clearOrder(u); if (hold) { u.holdPos = true; u.order = { type: 'hold' }; } }
      return;
    }
    if (u.order.hold && !u.inRange(t)) { const t2 = this.acquireTarget(u, u.stat('range')); if (t2) { u.order.target = t2; u.target = t2; } else { this.clearOrder(u); u.holdPos = true; u.order = { type: 'hold' }; } return; }
    // leash: return if too far
    if (u.order.returnTo && dist(u.x, u.y, u.order.returnTo.x, u.order.returnTo.y) > 12 * TILE) { const r = u.order.returnTo; this.clearOrder(u); u.order = { type: 'move', x: r.x, y: r.y }; this.setPath(u, r.x, r.y); return; }
    this.engage(u, t, dt);
  }

  engage(u, t, dt) {
    if (u.inRange(t)) {
      u.path = [];
      if (u.def.minRange && u.distTo(t) < u.def.minRange * TILE) { // kite back
        const a = angleTo(t.x, t.y, u.x, u.y); this.moveToward(u, u.x + Math.cos(a) * 60, u.y + Math.sin(a) * 60, dt); return;
      }
      this.tryAttack(u, t, dt);
    } else {
      // repath periodically toward moving target
      u.repath = (u.repath || 0) - dt;
      if (u.repath <= 0 && (!u.pathTarget || dist(u.pathTarget.x, u.pathTarget.y, t.x, t.y) > TILE * 1.5 || !u.path.length)) { this.setPath(u, t.x, t.y); u.repath = 0.5 + Math.random() * 0.4; }
      this.followPath(u, dt, () => {});
    }
  }

  followPath(u, dt, onDone) {
    if (u.pendingPath) { if (this.pathCalls < 14) { const p = u.pendingPath; this.setPath(u, p.x, p.y); } if (!u.path.length) return; }
    if (!u.path.length) { onDone(); return; }
    const wp = u.path[0];
    const d = dist(u.x, u.y, wp.x, wp.y);
    const step = u.stat('speed') * dt;
    if (d <= Math.max(step, 6)) { u.x = wp.x; u.y = wp.y; u.path.shift(); if (!u.path.length) onDone(); return; }
    // check blocked ahead (new building)
    if (!u.flying) {
      const nx = u.x + (wp.x - u.x) / d * Math.min(step + 10, d), ny = u.y + (wp.y - u.y) / d * Math.min(step + 10, d);
      if (this.map.isBlocked(Math.floor(nx / TILE), Math.floor(ny / TILE), false)) {
        u.stuck += dt;
        if (u.stuck > 0.3) { u.stuck = 0; const last = u.path[u.path.length - 1]; this.setPath(u, last.x, last.y); if (!u.path.length) { onDone(); } }
        return;
      }
    }
    u.stuck = 0;
    this.moveToward(u, wp.x, wp.y, dt);
  }

  moveToward(u, x, y, dt) {
    const d = dist(u.x, u.y, x, y); if (d < 0.01) return;
    const step = Math.min(d, u.stat('speed') * dt);
    const nx = u.x + (x - u.x) / d * step, ny = u.y + (y - u.y) / d * step;
    if (u.flying || !this.map.isBlocked(Math.floor(nx / TILE), Math.floor(ny / TILE), false)) { u.x = nx; u.y = ny; }
    u.facing = angleTo(u.x, u.y, x, y);
    if (u.def.spreads && u.faction.affinity) this.map.addLayerSource(u.faction.affinity, u.x, u.y, 2.5, 2);
  }

  separateUnits() {
    const us = this.units();
    const cell = 48, grid = new Map();
    for (const u of us) { const k = ((u.x / cell) | 0) + ',' + ((u.y / cell) | 0); (grid.get(k) || grid.set(k, []).get(k)).push(u); }
    for (const u of us) {
      const cx = (u.x / cell) | 0, cy = (u.y / cell) | 0;
      for (let gy = cy - 1; gy <= cy + 1; gy++) for (let gx = cx - 1; gx <= cx + 1; gx++) {
        const list = grid.get(gx + ',' + gy); if (!list) continue;
        for (const v of list) {
          if (v === u || v.flying !== u.flying || v.id < u.id) continue;
          const d = dist(u.x, u.y, v.x, v.y), min = u.radius + v.radius;
          if (d < min && d > 0.01) {
            const push = (min - d) / 2 * 0.6, nx = (u.x - v.x) / d, ny = (u.y - v.y) / d;
            const um = u.holdPos ? 0 : 1, vm = v.holdPos ? 0 : 1;
            u.x += nx * push * um; u.y += ny * push * um; v.x -= nx * push * vm; v.y -= ny * push * vm;
          } else if (d <= 0.01) { u.x += rand(-2, 2); u.y += rand(-2, 2); }
        }
      }
      u.x = clamp(u.x, TILE, WORLD_W - TILE); u.y = clamp(u.y, TILE, WORLD_H - TILE);
      if (!u.flying && this.map.isBlocked(u.tileX, u.tileY, false)) { const nf = this.map.nearestFree(u.tileX, u.tileY, false); u.x += (nf.tx * TILE + TILE / 2 - u.x) * 0.3; u.y += (nf.ty * TILE + TILE / 2 - u.y) * 0.3; }
    }
  }

  gatherBehaviour(u, dt) {
    const g = u.gather;
    if (g.phase === 'toNode') {
      if (!g.node || g.node.amount <= 0) { g.node = this.nearestNode(u, 'primary'); if (!g.node) { this.clearOrder(u); return; } this.setPath(u, g.node.x, g.node.y); }
      if (dist(u.x, u.y, g.node.x, g.node.y) < TILE * 1.6) { g.phase = 'gathering'; g.timer = 3.0; u.path = []; }
      else this.followPath(u, dt, () => { if (dist(u.x, u.y, g.node.x, g.node.y) > TILE * 1.6) this.setPath(u, g.node.x, g.node.y); });
    } else if (g.phase === 'gathering') {
      g.timer -= dt;
      if (g.timer <= 0) {
        const take = Math.min(5, g.node.amount); g.node.amount -= take; g.carrying = take;
        g.phase = 'toDrop';
        const d = this.nearestDropoff(u); if (d) this.setPath(u, d.x, d.y); else { this.clearOrder(u); return; }
      }
    } else if (g.phase === 'toDrop') {
      const d = this.nearestDropoff(u);
      if (!d) { this.clearOrder(u); return; }
      if (u.distTo(d) < TILE * 0.9) {
        u.player.res.p += g.carrying * u.player.incomeMul; u.player.stats.p += g.carrying; g.carrying = 0; g.phase = 'toNode';
        if (!g.node || g.node.amount <= 0) g.node = this.nearestNode(u, 'primary');
        if (!g.node) { this.clearOrder(u); return; }
        this.setPath(u, g.node.x, g.node.y);
      } else this.followPath(u, dt, () => this.setPath(u, d.x, d.y));
    }
  }

  buildBehaviour(u, dt) {
    const b = u.buildTask;
    if (!b || b.dead || b.complete) { this.clearOrder(u); if (b && b.complete && u.faction.gathers) { const n = this.nearestNode(u, 'primary'); if (n) this.orderGather([u], n); } return; }
    if (u.distTo(b) < TILE * 0.8) { b.builders++; u.path = []; }
    else this.followPath(u, dt, () => { if (u.distTo(b) >= TILE * 0.8) this.setPath(u, b.x, b.y); });
  }

  castBehaviour(u, dt) {
    const o = u.order;
    const ab = ABILITIES[o.ability];
    const tx = o.target ? o.target.x : o.x, ty = o.target ? o.target.y : o.y;
    if (o.target && o.target.dead) { this.clearOrder(u); return; }
    const range = (ab.range || 0) * TILE;
    const d = o.target ? u.distTo(o.target) : dist(u.x, u.y, tx, ty);
    if (d <= range + 2) {
      u.path = [];
      this.castAbility(u, o.ability, o.target, tx, ty);
      this.clearOrder(u);
    } else {
      if (!u.pathTarget || dist(u.pathTarget.x, u.pathTarget.y, tx, ty) > TILE || !u.path.length) this.setPath(u, tx, ty);
      this.followPath(u, dt, () => {});
    }
  }

  // ---------- abilities ----------
  canCast(u, id) {
    const ab = ABILITIES[id]; if (!ab) return { ok: false, why: '?' };
    if (ab.passive) return { ok: false, why: 'Passive' };
    if (ab.ult && u.level < 5) return { ok: false, why: 'Requires hero level 5' };
    if ((u.cooldowns[id] || 0) > 0) return { ok: false, why: 'Cooldown ' + Math.ceil(u.cooldowns[id]) + 's' };
    if (u.buffFlag && u.buffFlag('silence')) return { ok: false, why: 'Silenced' };
    if (ab.cost && !u.player.canAfford(ab.cost)) return { ok: false, why: 'Not enough resources' };
    return { ok: true };
  }
  orderCast(u, id, target, x, y) {
    const c = this.canCast(u, id);
    if (!c.ok) { if (u.owner === this.human) this.msg(c.why, 'warn'); return false; }
    const ab = ABILITIES[id];
    if (ab.target === 'none') { this.castAbility(u, id, null, u.x, u.y); return true; }
    this.clearOrder(u);
    u.order = { type: 'cast', ability: id, target, x, y };
    return true;
  }
  castAbility(caster, id, target, x, y) {
    const ab = ABILITIES[id];
    const c = this.canCast(caster, id); if (!c.ok) return false;
    if (ab.cost) caster.player.pay(ab.cost);
    caster.cooldowns[id] = ab.cooldown || 0;
    ab.cast(this, caster, target, x, y);
    this.emit('cast', caster.x, caster.y, caster.owner, { ult: !!ab.ult });
    if (caster.kind === 'unit') caster.attackTimer = Math.max(caster.attackTimer, 0.4);
    return true;
  }
  buildingCast(b, id, target, x, y) {
    const ab = ABILITIES[id];
    if ((b.cooldowns[id] || 0) > 0) { if (b.owner === this.human) this.msg('Cooldown', 'warn'); return false; }
    if (ab.cost && !b.player.canAfford(ab.cost)) { if (b.owner === this.human) this.msg('Not enough resources', 'warn'); return false; }
    if (ab.cost) b.player.pay(ab.cost);
    b.cooldowns[id] = ab.cooldown || 0;
    ab.cast(this, b, target, x, y);
    this.emit('cast', b.x, b.y, b.owner, { ult: !!ab.ult });
    return true;
  }

  // ---------- vision ----------
  computeVision(owner) {
    const p = this.players[owner], v = p.vision;
    for (let i = 0; i < v.length; i++) if (v[i] === 2) v[i] = 1;
    const mark = (x, y, r) => {
      const cx = Math.floor(x / TILE), cy = Math.floor(y / TILE), rt = Math.ceil(r / TILE), r2 = rt * rt;
      for (let ty = cy - rt; ty <= cy + rt; ty++) for (let tx = cx - rt; tx <= cx + rt; tx++) {
        if (!this.map.inBounds(tx, ty)) continue;
        const dx = tx - cx, dy = ty - cy; if (dx * dx + dy * dy > r2) continue;
        v[this.map.idx(tx, ty)] = 2;
      }
    };
    for (const e of this.entities) {
      if (e.dead || e.owner !== owner) continue;
      mark(e.x, e.y, e.kind === 'unit' ? e.stat('sight') : (e.complete ? e.stat('sight') : 4 * TILE));
    }
    for (const r of p.reveal) mark(r.x, r.y, r.r);
  }
}
