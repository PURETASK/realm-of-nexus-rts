// AI opponent: build order, economy, army, attacks, hero ability use
const AI_BUILD_ORDERS = {
  abyss: [
    { b: 'soul_well', node: 'primary' }, { b: 'grim_crypt' }, { b: 'occult_den' }, { b: 'soul_well', node: 'primary' }, { b: 'soul_obelisk' },
    { b: 'grim_crypt' }, { b: 'corruption_spire' }, { tier: 2 }, { b: 'corruption_crucible' }, { b: 'necromancer_spire' }, { b: 'flesh_forge' },
    { b: 'soul_obelisk' }, { b: 'reliquary' }, { b: 'soul_well', node: 'primary' }, { b: 'grim_crypt' }, { tier: 3 }, { b: 'void_gate' }, { b: 'cathedral_of_decay' }, { b: 'flesh_forge' },
  ],
  tempest: [
    { b: 'aetherforge', node: 'primary' }, { b: 'gale_barracks' }, { b: 'aetherforge', node: 'primary' }, { b: 'stormcall_tower' }, { b: 'aerie' },
    { b: 'stormcall_array', node: 'secondary' }, { b: 'aetherforge', node: 'primary' }, { b: 'thunderhead_tower' }, { b: 'gale_barracks' }, { tier: 2 },
    { b: 'tempest_forge' }, { b: 'stratosanct' }, { b: 'cyclone_totem' }, { b: 'aetherforge', node: 'primary' }, { b: 'aerie' }, { tier: 3 },
    { b: 'stormseer_conclave' }, { b: 'celestial_bastion' }, { b: 'maelstrom_altar' },
  ],
  radiance: [
    { b: 'sunstone_vault', node: 'primary' }, { b: 'solar_crucible' }, { b: 'radiant_shrine' }, { b: 'sunstone_vault', node: 'primary' }, { b: 'blazing_bastion' },
    { b: 'solar_crucible' }, { b: 'dawnwatch_beacon' }, { tier: 2 }, { b: 'heliarch_spire' }, { b: 'phoenix_roost' },
    { b: 'blazing_bastion' }, { b: 'sunstone_vault', node: 'primary' }, { b: 'solar_relay' }, { b: 'pyrestorm_battery' }, { tier: 3 }, { b: 'solar_crucible' }, { b: 'phoenix_roost' },
  ],
  verdance: [
    { b: 'groveheart_nexus', node: 'primary' }, { b: 'bloomforge' }, { b: 'verdant_sigil_hall' }, { b: 'groveheart_nexus', node: 'primary' }, { b: 'rootwarden_bastion' },
    { b: 'sapwood_granary' }, { b: 'bloomforge' }, { tier: 2 }, { b: 'cycle_sanctuary' }, { b: 'spirit_tree' }, { b: 'wild_den' },
    { b: 'rootwarden_bastion' }, { b: 'groveheart_nexus', node: 'primary' }, { b: 'sylvan_waystone' }, { tier: 3 }, { b: 'world_seed_altar' }, { b: 'spirit_tree' },
  ],
  sanctuary: [
    { b: 'sanctified_vault', node: 'primary' }, { b: 'beaconwright_hall' }, { b: 'sacrosanct_shrine' }, { b: 'sanctified_vault', node: 'primary' }, { b: 'radiant_tower' },
    { b: 'beaconwright_hall' }, { b: 'lightborne_relay' }, { tier: 2 }, { b: 'hall_of_luminaries' }, { b: 'concord_hall' }, { b: 'griffin_aerie' },
    { b: 'radiant_tower' }, { b: 'sanctified_vault', node: 'primary' }, { b: 'eternal_bell_spire' }, { b: 'siege_chapel' }, { tier: 3 }, { b: 'altar_of_tears' }, { b: 'hall_of_luminaries' },
  ],
};
const AI_RESEARCH = {
  abyss: ['dark_blessing', 'necrotic_armor', 'blight_plague', 'grave_march', 'vampiric_relics', 'death_fog'],
  tempest: ['stormsteel_weapons', 'static_shield', 'forecast', 'lightweight_alloy', 'overcharge', 'tribute_efficiency', 'storm_amplification'],
  radiance: ['blessed_steel', 'sunforged_plate', 'daybreak', 'phoenix_fire', 'radiant_wards', 'eternal_dawn'],
  verdance: ['sharpened_thorns', 'ironbark', 'wild_growth', 'symbiosis', 'deep_roots', 'everwood_blessing'],
  sanctuary: ['blessed_arms', 'aegis_plating', 'greater_wards', 'divine_favor', 'sanctified_walls', 'martyrdom'],
};
const AI_HERO_ORDER = { abyss: ['tyvaris', 'malazar', 'neratha'], tempest: ['rykan', 'alyssia', 'lyrian'], radiance: ['aurelian', 'solaris', 'seraphine'], verdance: ['kael', 'sylvara', 'elowen'], sanctuary: ['isolde', 'cassiel', 'adaline'] };
const AI_ECON_ABILITIES = ['trade_winds', 'blessed_tithe', 'bountiful_harvest', 'tithe_of_faith'];
const AI_HEAL_ABILITIES = ['healing_light', 'mend', 'mend_wounds'];

class AIController {
  constructor(game, owner) {
    this.g = game; this.owner = owner; this.p = game.players[owner]; this.f = this.p.faction;
    this.timer = 0; this.orderIdx = 0; this.mode = 'build'; this.attackGroup = []; this.attackStart = 0;
    this.nextAttackSupply = game.difficulty.attackSupply; this.lastDefend = 0; this.abilityTimer = 0;
    this.workerTarget = this.f.gathers ? 9 : 4;
  }

  update(dt) {
    if (this.p.defeated) return;
    this.abilityTimer -= dt;
    if (this.abilityTimer <= 0) { this.abilityTimer = 1.2; this.useAbilities(); }
    this.timer -= dt;
    if (this.timer > 0) return;
    this.timer = 1.0 * this.g.difficulty.buildDelay + 0.3;
    const g = this.g, base = g.baseOf(this.owner);
    if (!base) return;
    const armySupply = this.army().filter(u => !u.isWorker).reduce((n, u) => n + (u.def.supply || 0), 0);
    this.reserve = this.computeReserve(this.currentStep(), armySupply);
    this.manageWorkers(base);
    this.manageProduction(base);
    this.manageBuild(base);
    this.manageArmy(base);
  }

  workers() { return this.g.units(this.owner).filter(u => u.isWorker); }
  army() { return this.g.units(this.owner).filter(u => u.isCombat && !u.isHero || u.isHero); }

  currentStep() { return AI_BUILD_ORDERS[this.f.id][this.orderIdx] || null; }

  // Primary resource kept back for the current build-order step: a tier upgrade reserves its full cost once a
  // small army exists; a building reserves its cost once the army is a bit larger.
  computeReserve(step, armySupply) {
    if (!step || this.mode === 'defend') return 0;
    if (step.tier) return (armySupply >= 8 || this.g.time > 300) ? (this.f.tiers[step.tier - 1].cost.p || 0) : 0;
    if (armySupply < 12) return 0;
    return (this.f.buildings[step.b].cost.p || 0) * (this.g.time > 480 ? 0.5 : 1);
  }

  // Secondary resource the current step still needs
  stepSecondaryNeed() {
    const step = this.currentStep(); if (!step) return 0;
    const cost = step.tier ? this.f.tiers[step.tier - 1].cost : this.f.buildings[step.b].cost;
    return (cost && cost.s) || 0;
  }

  ownsBuilding(bid) { return this.g.buildings(this.owner).some(b => b.defId === bid); }

  // Tries to start a building. Returns 'built', 'wait' (money or worker) or 'nospot'.
  tryBuild(bid, base, ws, nodeType) {
    const def = this.f.buildings[bid];
    if (!this.p.canAfford(def.cost)) return 'wait';
    const w = this.freeWorker(ws); if (!w) return 'wait';
    if (!nodeType && def.needsNode) nodeType = def.needsNode;
    const spot = nodeType ? this.findNodeSpot(nodeType, base) : this.findSpot(def, base, def.tower || def.aura ? 'front' : 'back');
    if (!spot) return 'nospot';
    return this.g.orderBuild([w], bid, spot.tx, spot.ty) ? 'built' : 'wait';
  }

  manageWorkers(base) {
    const ws = this.workers();
    const step = this.currentStep();
    const want = (step && step.tier && this.reserve > 0) ? Math.floor(this.workerTarget * 0.6) : this.workerTarget;
    if (ws.length < want && base.queue.length === 0 && this.g.canQueue(base, { type: 'unit', id: this.f.worker }).ok) this.g.enqueue(base, { type: 'unit', id: this.f.worker });
    if (this.f.gathers) {
      for (const w of ws) if (w.order.type === 'idle') { const n = this.g.nearestNode(w, 'primary'); if (n) this.g.orderGather([w], n); }
    }
  }

  manageBuild(base) {
    const g = this.g, order = AI_BUILD_ORDERS[this.f.id];
    const ws = this.workers();
    // keep constructing existing incomplete buildings
    const incomplete = g.buildings(this.owner).filter(b => !b.complete);
    for (const b of incomplete) {
      if (!ws.some(w => w.buildTask === b)) { const w = this.freeWorker(ws); if (w) { g.clearOrder(w); w.order = { type: 'build', building: b }; w.buildTask = b; g.setPath(w, b.x, b.y); } }
    }
    if (incomplete.length >= 2) return;
    // pick next step
    let step = order[this.orderIdx];
    if (!step) {
      // late game: keep adding production / defenses
      const opts = Object.keys(this.f.buildings).filter(id => { const d = this.f.buildings[id]; return !d.isBase && !d.needsNode && !d.wall && !d.mine && d.tier <= this.p.tier && (d.trains || (d.tower && d.tower.dmg > 0)); });
      step = { b: choice(opts) };
      if (g.buildings(this.owner).length > 26) step = null;
    }
    if (!step) return;
    if (step.tier) {
      if (this.p.tier >= step.tier) { this.orderIdx++; return; }
      const c = g.canQueue(base, { type: 'tier' });
      if (c.ok) { if (base.queue.length < 2) { g.enqueue(base, { type: 'tier' }); this.orderIdx++; } }
      else if (c.why.startsWith('Requires')) {
        // prerequisite missing or under construction: build it, never skip the tier
        const req = this.f.tiers[this.p.tier].requires;
        if (req && !this.ownsBuilding(req)) this.tryBuild(req, base, ws, null);
      }
      return;
    }
    const def = this.f.buildings[step.b];
    if (def.tier > this.p.tier) { // wait for tier, but try tier queue
      const c = g.canQueue(base, { type: 'tier' });
      if (c.ok && base.queue.length < 2) g.enqueue(base, { type: 'tier' });
      else if (!c.ok && c.why.startsWith('Requires')) { const req = this.f.tiers[this.p.tier].requires; if (req && !this.ownsBuilding(req)) this.tryBuild(req, base, ws, null); }
      return;
    }
    const result = this.tryBuild(step.b, base, ws, step.node || null);
    if (result === 'built' || result === 'nospot') this.orderIdx++;
  }

  freeWorker(ws) {
    return ws.find(w => w.order.type === 'idle') || ws.find(w => w.order.type === 'gather' && w.gather.phase !== 'toDrop') || ws.find(w => w.order.type !== 'build');
  }

  findNodeSpot(type, base) {
    const bid = this.f.nodeBuilding[type]; if (!bid) return null;
    const nodes = this.g.map.nodes.filter(n => n.type === type && !n.building && n.amount > 0 && this.g.canPlace(this.owner, bid, n.tx, n.ty));
    nodes.sort((a, b) => dist2(a.x, a.y, base.x, base.y) - dist2(b.x, b.y, base.x, base.y));
    const n = nodes[0]; if (!n) return null;
    if (dist(n.x, n.y, base.x, base.y) > (type === 'secondary' ? 40 : 26) * TILE) return null;
    return { tx: n.tx, ty: n.ty };
  }

  findSpot(def, base, pref) {
    const g = this.g, enemyBase = g.baseOf(1 - this.owner);
    const dirx = enemyBase ? Math.sign(enemyBase.x - base.x) : -1, diry = enemyBase ? Math.sign(enemyBase.y - base.y) : -1;
    let best = null, bs = Infinity;
    for (let r = 3; r < 16; r++) {
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (Math.abs(dx) !== r && Math.abs(dy) !== r) continue;
        if (Math.random() < 0.5) continue;
        const tx = base.tx + dx, ty = base.ty + dy;
        // keep 1-tile gaps between buildings for pathing
        if (!g.canPlace(this.owner, def.name ? this.defIdOf(def) : def, tx, ty)) continue;
        if (!g.map.areaFree(tx - 1, ty - 1, def.w + 2, def.h + 2, true)) continue;
        let score = r;
        if (pref === 'front') score -= (dx * dirx + dy * diry) * 0.6; else score += (dx * dirx + dy * diry) * 0.3;
        if (score < bs) { bs = score; best = { tx, ty }; }
      }
      if (best && r > 5) return best;
    }
    return best;
  }
  defIdOf(def) { for (const k in this.f.buildings) if (this.f.buildings[k] === def) return k; return null; }

  manageProduction(base) {
    const g = this.g, p = this.p;
    // heroes
    const heroOrder = AI_HERO_ORDER[this.f.id];
    const reserve = this.reserve || 0, needS = this.stepSecondaryNeed();
    for (const h of heroOrder) {
      if (g.heroes(this.owner).some(x => x.defId === h)) continue;
      if (g.heroes(this.owner).length > 0 && p.res.p - (this.f.heroes[h].cost.p || 0) < reserve) break;
      if (base.queue.length === 0 && g.canQueue(base, { type: 'hero', id: h }).ok) { g.enqueue(base, { type: 'hero', id: h }); break; }
      break;
    }
    // research
    for (const b of g.buildings(this.owner)) {
      if (!b.complete || b.queue.length || !b.def.research) continue;
      for (const rid of AI_RESEARCH[this.f.id]) {
        if (!b.def.research.includes(rid)) continue;
        if (p.res.p - (this.f.research[rid].cost.p || 0) < reserve) continue;
        if (p.res.s - (this.f.research[rid].cost.s || 0) < needS) continue;
        if (g.canQueue(b, { type: 'research', id: rid }).ok && Math.random() < 0.5) { g.enqueue(b, { type: 'research', id: rid }); break; }
      }
    }
    // units
    const prod = g.buildings(this.owner).filter(b => b.complete && b.def.trains && !b.def.isBase && b.queue.length < 2);
    for (const b of prod) {
      const opts = b.def.trains.filter(id => { const d = this.f.units[id]; return d && d.tier <= p.tier && !d.unique; });
      if (!opts.length) continue;
      // weight toward stronger units when rich
      const pick = (p.res.p > 600 || Math.random() < 0.6) ? opts[opts.length - 1] : choice(opts);
      const d = this.f.units[pick];
      if (p.res.p - (d.cost.p || 0) < reserve && g.time > 90) continue;
      if ((d.cost.s || 0) > 0 && this.currentStep() && this.currentStep().tier && p.res.s - d.cost.s < needS) continue;
      if (g.canQueue(b, { type: 'unit', id: pick }).ok) g.enqueue(b, { type: 'unit', id: pick });
    }
    // Deathlord / catalyst usage
    if (p.res.c >= 1) {
      if (this.f.id === 'abyss') { const cath = g.buildings(this.owner).find(b => b.defId === 'cathedral_of_decay' && b.complete && !b.queue.length); if (cath && g.canQueue(cath, { type: 'unit', id: 'deathlord' }).ok) g.enqueue(cath, { type: 'unit', id: 'deathlord' }); }
      else if (this.f.id === 'tempest') { const altar = g.buildings(this.owner).find(b => b.defId === 'maelstrom_altar' && b.complete); if (altar && this.mode === 'attack' && !g.weather.storm) g.buildingCast(altar, 'eye_of_auranth'); }
      else { const altar = g.buildings(this.owner).find(b => b.complete && b.def.catalystGen && b.def.trains && !b.queue.length); if (altar) { const uid = altar.def.trains[0]; if (g.canQueue(altar, { type: 'unit', id: uid }).ok) g.enqueue(altar, { type: 'unit', id: uid }); } }
    }
    // global rally structures when attacking
    if (this.mode === 'attack') for (const b of g.buildings(this.owner)) if (b.complete && b.def.abilities) for (const id of b.def.abilities) if ((id === 'solar_surge' || id === 'toll_the_bell') && (b.cooldowns[id] || 0) <= 0) g.buildingCast(b, id);
    // Abyss crucible: keep converting only when souls are plentiful
    for (const b of g.buildings(this.owner)) if (b.def.converter) b.toggles.convert = p.res.p > 250 || (needS > p.res.s && p.res.p > 120);
    // Soul well sacrifice of excess skeletons when poor and many units
    if (this.f.id === 'abyss' && p.res.p < 80 && this.army().length > 20) { const w = g.buildings(this.owner).find(b => b.defId === 'soul_well' && b.complete && (b.cooldowns.sacrifice || 0) <= 0); if (w) g.buildingCast(w, 'sacrifice'); }
  }

  manageArmy(base) {
    const g = this.g, army = this.army().filter(u => !u.isWorker);
    const enemyBase = g.baseOf(1 - this.owner);
    const supply = army.reduce((n, u) => n + (u.def.supply || 0), 0) + g.heroes(this.owner).length * 3;
    // defend
    const threats = g.enemiesNear(this.owner, base.x, base.y, 14 * TILE, false);
    const myBuildingsUnderAttack = g.buildings(this.owner).filter(b => g.enemiesNear(this.owner, b.x, b.y, 8 * TILE).length);
    if ((threats.length || myBuildingsUnderAttack.length) && this.mode !== 'attack') {
      const tgt = threats[0] || g.enemiesNear(this.owner, myBuildingsUnderAttack[0].x, myBuildingsUnderAttack[0].y, 8 * TILE)[0];
      if (tgt && g.time - this.lastDefend > 3) { this.lastDefend = g.time; g.orderMove(army.filter(u => u.order.type !== 'attack'), tgt.x, tgt.y, true); }
      this.mode = 'defend';
      return;
    }
    if (this.mode === 'defend' && !threats.length) { this.mode = 'build'; g.orderMove(army, base.x + (enemyBase ? Math.sign(enemyBase.x - base.x) : 0) * 5 * TILE, base.y + (enemyBase ? Math.sign(enemyBase.y - base.y) : 0) * 5 * TILE, true); }
    if (this.mode === 'build') {
      // rally idle army near base front
      const idle = army.filter(u => u.order.type === 'idle' && dist(u.x, u.y, base.x, base.y) > 9 * TILE);
      if (idle.length) g.orderMove(idle, base.x + (enemyBase ? Math.sign(enemyBase.x - base.x) : 0) * 5 * TILE, base.y + (enemyBase ? Math.sign(enemyBase.y - base.y) : 0) * 5 * TILE, true);
      const threshold = g.time < 900 ? this.nextAttackSupply : Math.min(this.nextAttackSupply, 14);
      if (supply >= threshold && enemyBase && g.time >= g.difficulty.firstAttack) {
        this.mode = 'attack'; this.attackGroup = army.slice(); this.attackStart = g.time; this.attackSupply = supply;
        // target: nearest enemy building to our base (expansions first), else base
        const eb = g.buildings(1 - this.owner).filter(b => g.time > 600 || !b.def.isBase);
        eb.sort((a, b) => dist2(a.x, a.y, base.x, base.y) - dist2(b.x, b.y, base.x, base.y));
        const tgt = eb[0] || enemyBase;
        g.orderMove(army, tgt.x, tgt.y, true);
        this.attackTarget = tgt;
        this.nextAttackSupply += g.difficulty.attackGrowth;
      }
    } else if (this.mode === 'attack') {
      const alive = this.attackGroup.filter(u => !u.dead);
      const curSupply = alive.reduce((n, u) => n + (u.def.supply || 0), 0) + alive.filter(u => u.isHero).length * 3;
      if (curSupply < this.attackSupply * 0.35 || g.time - this.attackStart > 150) {
        this.mode = 'build'; g.orderMove(alive, base.x, base.y + 3 * TILE, true); return;
      }
      // retarget when target dies or units idle
      if (!this.attackTarget || this.attackTarget.dead) {
        const eb = g.buildings(1 - this.owner); if (!eb.length) return;
        eb.sort((a, b) => dist2(a.x, a.y, alive[0]?.x || base.x, alive[0]?.y || base.y) - dist2(b.x, b.y, alive[0]?.x || base.x, alive[0]?.y || base.y));
        this.attackTarget = eb[0]; g.orderMove(alive, eb[0].x, eb[0].y, true);
      } else {
        const idle = alive.filter(u => u.order.type === 'idle');
        if (idle.length) g.orderMove(idle, this.attackTarget.x, this.attackTarget.y, true);
      }
      // reinforce with new units
      for (const u of army) if (!this.attackGroup.includes(u) && u.order.type === 'idle') { this.attackGroup.push(u); if (this.attackTarget) g.orderMove([u], this.attackTarget.x, this.attackTarget.y, true); }
    }
  }

  useAbilities() {
    const g = this.g;
    for (const h of g.heroes(this.owner)) {
      const enemies = g.enemiesNear(this.owner, h.x, h.y, 7 * TILE, true);
      const eu = enemies.filter(e => e.kind === 'unit');
      for (const id of h.abilities) {
        const ab = ABILITIES[id]; if (!ab || ab.passive) continue;
        if (!g.canCast(h, id).ok) continue;
        // cluster target
        let best = null, bn = 0;
        for (const e of eu) { const n = g.enemiesNear(this.owner, e.x, e.y, 3 * TILE).length; if (n > bn) { bn = n; best = e; } }
        const inRange = best && h.distTo(best) <= (ab.range || 0) * TILE + 20;
        switch (ab.target) {
          case 'enemy': if (best && inRange && (!ab.ult || bn >= 3)) g.castAbility(h, id, best, best.x, best.y); break;
          case 'point': {
            if (id === 'nether_portal' || id === 'call_of_the_armada') { if (best && h.hp < h.maxHp * 0.35 && id === 'nether_portal') { const b = g.baseOf(this.owner); if (b) g.castAbility(h, id, null, h.x + (b.x - h.x) * 0.5, h.y + (b.y - h.y) * 0.5); } else if (id === 'call_of_the_armada' && best && bn >= 3) g.castAbility(h, id, null, best.x, best.y); break; }
            if (id === 'corruption_ward' || id === 'zephyr_ward') { if (eu.length >= 2) g.castAbility(h, id, null, h.x, h.y); break; }
            if (best && inRange && (!ab.ult || bn >= 4)) g.castAbility(h, id, null, best.x, best.y);
            break;
          }
          case 'none': {
            if (id === 'eye_of_clarity' || AI_ECON_ABILITIES.includes(id)) { if (g.time > 120) g.castAbility(h, id); break; }
            if (id === 'sacrificial_surge') { if (eu.length >= 4 && g.alliesNear(this.owner, h.x, h.y, 4 * TILE).length > 4) g.castAbility(h, id); break; }
            if (eu.length >= (ab.ult ? 4 : 2)) g.castAbility(h, id);
            break;
          }
          case 'ally': {
            if (id === 'dark_pact') { const b = g.buildings(this.owner).find(bb => bb.queue.length && dist(bb.x, bb.y, h.x, h.y) < 6 * TILE); if (b && h.hp > h.maxHp * 0.6) g.castAbility(h, id, b, b.x, b.y); }
            else if (AI_HEAL_ABILITIES.includes(id)) { let w = null, wr = 0.6; for (const a of g.alliesNear(this.owner, h.x, h.y, (ab.range || 6) * TILE)) if (a.kind === 'unit' && a.hp / a.maxHp < wr) { wr = a.hp / a.maxHp; w = a; } if (w) g.castAbility(h, id, w, w.x, w.y); }
            break;
          }
        }
      }
    }
  }
}
