// Abilities for Radiance, Verdance and Sanctuary (provisional designs)
function healUnit(g, a, amount) { if (!a || a.dead) return; a.hp = Math.min(a.maxHp, a.hp + amount); if (a.maxShield) a.shield = Math.min(a.stat('maxShield'), a.shield + amount * 0.5); }
function teleportGroup(g, c, allies, x, y) {
  let i = 0;
  for (const a of allies) {
    const ang = i * 2.4, r = Math.sqrt(i) * 22; i++;
    let nx = x + Math.cos(ang) * r, ny = y + Math.sin(ang) * r;
    if (!a.flying) { const nf = g.map.nearestFree(Math.floor(nx / TILE), Math.floor(ny / TILE), false); nx = nf.tx * TILE + TILE / 2; ny = nf.ty * TILE + TILE / 2; }
    a.x = nx; a.y = ny; a.path = []; if (a.order.type === 'move' || a.order.type === 'attackmove') g.clearOrder(a);
  }
}
function reviveCorpses(g, c, x, y, r, max, hpFrac) {
  let n = 0;
  for (const co of g.corpses) {
    if (co.dead || co.owner !== c.owner || dist(co.x, co.y, x, y) > r) continue;
    const def = unitDef(c.faction, co.defId); if (!def || def.unique) continue;
    if (c.player.supplyUsed + (def.supply || 0) > c.player.supplyCap) break;
    co.dead = true; const u = g.spawnUnit(c.owner, co.defId, co.x, co.y); u.hp = u.maxHp * hpFrac;
    g.addEffect({ type: 'ring', x: co.x, y: co.y, r: 24, color: '#fff2b0', t: 0.8 });
    if (++n >= max) break;
  }
  if (!n && c.owner === g.human) g.msg('No fallen allies nearby to raise', 'warn');
  return n;
}

Object.assign(EXTRA_WARDS, {
  sanctify(g, w, allies, enemies, dt) { g.map.addLayerSource('light', w.x, w.y, w.r / TILE, 3); for (const a of allies) if (a.kind === 'unit') { a.addBuff('sanctified', 0.3, { dmgTakenMul: 0.85 }); healUnit(g, a, 3 * dt); } for (const e of enemies) if (e.kind === 'unit') e.addBuff('sanctify_weak', 0.3, { dmgMul: 0.85 }); },
  sunfire(g, w, allies, enemies, dt) { for (const e of enemies) { g.damage(e, 40 * dt * (w.mul || 1), w.source || null, 'magic', true); if (e.kind === 'unit') e.addBuff('blind', 0.3, { dmgMul: 0.6 }); } for (const a of allies) if (a.kind === 'unit') healUnit(g, a, 12 * dt); },
  grove(g, w, allies, enemies, dt) { g.map.addLayerSource('grove', w.x, w.y, w.r / TILE, 3); for (const a of allies) if (a.kind === 'unit') healUnit(g, a, 4 * dt); for (const e of enemies) if (e.kind === 'unit' && !e.flying) e.addBuff('vines', 0.3, { speedMul: 0.7 }); },
  vines(g, w, allies, enemies, dt) { for (const e of enemies) if (e.kind === 'unit' && !e.flying) { e.addBuff('entangled', 0.3, { speedMul: 0.15 }); g.damage(e, 5 * dt, w.source || null, 'physical', true); } },
  bloom(g, w, allies, enemies, dt) { for (const a of allies) if (a.kind === 'unit') { healUnit(g, a, 25 * dt); a.addBuff('bloom', 0.3, { regen: 3 }); } },
  heaven(g, w, allies, enemies, dt) { w.tick = (w.tick || 0) + dt; if (w.tick > 0.5) { w.tick = 0; const eu = enemies.filter(e => e.kind === 'unit' || e.kind === 'building'); if (eu.length) { const e = choice(eu); g.addEffect({ type: 'lightning', x1: e.x + rand(-30, 30), y1: e.y - 220, x2: e.x, y2: e.y, color: '#fff7d0', t: 0.3 }); g.damage(e, 60 * (w.mul || 1), w.source || null, 'magic'); } } },
});

Object.assign(ABILITIES, {
  // ================= RADIANCE =================
  sun_smite: { name: 'Sun Smite', key: 'Q', target: 'enemy', range: 1.5, cooldown: 8, desc: 'Blazing strike: 100 damage plus 40 splash in 2 tiles. Heals Aurelian for 30.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'burst', x: t.x, y: t.y, r: 2 * TILE, color: '#ffd55a', t: 0.4 }); for (const e of g.enemiesNear(c.owner, t.x, t.y, 2 * TILE, true)) g.damage(e, (e === t ? 100 : 40) * m, c, 'magic'); healUnit(g, c, 30); } },
  rally_of_dawn: { name: 'Rally of Dawn', key: 'W', target: 'none', cooldown: 30, desc: 'Allies within 6 tiles gain +2 armor and +20% damage for 12s.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 6 * TILE, color: '#ffd55a', t: 1 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('rally_dawn', 12, { armorAdd: 2, dmgMul: 1.2 }); } },
  blinding_flare: { name: 'Blinding Flare', key: 'E', target: 'point', range: 7, cooldown: 25, desc: 'Flash of sunlight in 4 tiles: enemies deal 50% less damage for 5s and are revealed.',
    cast(g, c, t, x, y) { g.addEffect({ type: 'burst', x, y, r: 4 * TILE, color: '#ffffff', t: 0.5 }); for (const e of g.enemiesNear(c.owner, x, y, 4 * TILE)) { e.addBuff('blind', 5, { dmgMul: 0.5 }); e.removeBuff('invisible'); } c.player.reveal.push({ x, y, r: 5 * TILE, t: 5 }); } },
  judgment_of_the_sun: { name: 'Judgment of the Sun', key: 'R', ult: true, target: 'point', range: 9, cooldown: 90, desc: 'ULTIMATE: a pillar of sunfire in 4 tiles for 5s. Enemies burn for 40/s and are blinded; allies inside are healed 12/s.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 5, r: 4 * TILE, kind: 'sunfire', source: c, mul: abilityDmgMul(g, c) }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#ffd55a', t: 1 }); } },

  healing_light: { name: 'Healing Light', key: 'Q', target: 'ally', range: 6, cooldown: 10, desc: 'Heal a friendly unit for 150 (structures 100).',
    cast(g, c, t) { if (t.kind === 'unit') healUnit(g, t, 150 * (1 + (c.level - 1) * 0.1)); else t.hp = Math.min(t.maxHp, t.hp + 100); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#fff2b0', t: 0.3 }); } },
  sanctified_ground: { name: 'Sanctified Ground', key: 'W', target: 'point', range: 6, cooldown: 30, desc: 'Bless 4 tiles for 20s: spreads sunlight, allies take 15% less damage and heal 3/s, enemies deal 15% less.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 20, r: 4 * TILE, kind: 'sanctify' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#ffd55a', t: 1 }); } },
  blessed_tithe: { name: 'Blessed Tithe', key: 'E', target: 'none', cooldown: 60, desc: 'For 20s income is increased 40% and production is 30% faster.',
    cast(g, c) { g.addPlayerBuff(c.player, 'prosperity', 20); g.addEffect({ type: 'text', x: c.x, y: c.y - 20, text: 'BLESSED TITHE', color: '#ffd55a', t: 1.5 }); } },
  resurrection: { name: 'Resurrection', key: 'R', ult: true, target: 'point', range: 7, cooldown: 120, desc: 'ULTIMATE: up to 5 fallen allies within 5 tiles return to life at half health.',
    cast(g, c, t, x, y) { reviveCorpses(g, c, x, y, 5 * TILE, 5, 0.5); g.addEffect({ type: 'ring', x, y, r: 5 * TILE, color: '#fff2b0', t: 1.2 }); } },

  solar_lance: { name: 'Solar Lance', key: 'Q', target: 'enemy', range: 7, cooldown: 7, desc: 'Lance of light: 120 damage, pierces to 2 enemies behind the target for 60.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#fff7a0', t: 0.3 }); g.damage(t, 120 * m, c, 'magic'); let n = 0; for (const e of g.enemiesNear(c.owner, t.x, t.y, 2.5 * TILE)) { if (e === t || n >= 2) continue; n++; g.damage(e, 60 * m, c, 'magic'); } } },
  dawnstrike: { name: 'Dawnstrike', key: 'W', target: 'point', range: 8, cooldown: 14, desc: 'Burst of dawn in 3 tiles: 70 damage and enemies are blinded for 3s.',
    cast(g, c, t, x, y) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'burst', x, y, r: 3 * TILE, color: '#ffe680', t: 0.5 }); for (const e of g.enemiesNear(c.owner, x, y, 3 * TILE, true)) { g.damage(e, 70 * m, c, 'magic'); if (e.kind === 'unit') e.addBuff('blind', 3, { dmgMul: 0.6 }); } } },
  light_step: { name: 'Light Step', key: 'E', target: 'point', range: 10, cooldown: 35, desc: 'Solaris and allies within 3 tiles step through light to the target point.',
    cast(g, c, t, x, y) { const al = g.alliesNear(c.owner, c.x, c.y, 3 * TILE).filter(a => a.kind === 'unit'); g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 3 * TILE, color: '#fff7a0', t: 0.8 }); teleportGroup(g, c, al, x, y); g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#fff7a0', t: 0.8 }); } },
  supernova: { name: 'Supernova', key: 'R', ult: true, target: 'none', cooldown: 110, desc: 'ULTIMATE: the sun bursts from Solaris: 220 damage to every enemy within 7 tiles; allies are healed for 100.',
    cast(g, c) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'burst', x: c.x, y: c.y, r: 7 * TILE, color: '#ffffff', t: 0.8 }); for (const e of g.enemiesNear(c.owner, c.x, c.y, 7 * TILE, true)) g.damage(e, 220 * m, c, 'magic'); for (const a of g.alliesNear(c.owner, c.x, c.y, 7 * TILE)) if (a.kind === 'unit') healUnit(g, a, 100); } },

  solar_surge: { name: 'Solar Surge', key: 'S', target: 'none', cooldown: 90, building: true, desc: 'Map-wide: for 15s all Radiance units gain +20% damage and towers +50%.',
    cast(g, b) { for (const u of g.units(b.owner)) u.addBuff('solar_surge', 15, { dmgMul: 1.2 }); g.addPlayerBuff(b.player, 'solar_surge', 15); g.msg('Solar Surge! The relay floods the realm with light.', b.owner === g.human ? 'good' : 'warn'); } },

  // ================= VERDANCE =================
  briar_charge: { name: 'Briar Charge', key: 'Q', target: 'enemy', range: 6, cooldown: 9, desc: 'Charge the target: Kael dashes in, deals 110 damage and roots it for 2s.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); teleportGroup(g, c, [c], t.x + 20, t.y); g.addEffect({ type: 'slash', x: t.x, y: t.y, color: '#7ee08a', t: 0.3, big: true }); g.damage(t, 110 * m, c, 'physical'); if (t.kind === 'unit') t.addBuff('rooted', 2, { speedMul: 0 }); } },
  bark_skin: { name: 'Bark Skin', key: 'W', target: 'none', cooldown: 30, desc: 'Allies within 6 tiles gain +3 armor and +2 hp/s for 12s.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 6 * TILE, color: '#7ee08a', t: 1 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('bark_skin', 12, { armorAdd: 3, regen: 2 }); } },
  thorn_burst: { name: 'Thorn Burst', key: 'E', target: 'point', range: 6, cooldown: 20, desc: 'Vines erupt in 3 tiles for 6s: ground enemies are entangled (85% slower) and lacerated 5/s.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 6, r: 3 * TILE, kind: 'vines', source: c }); g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#4caf50', t: 1 }); } },
  wrath_of_the_wild: { name: 'Wrath of the Wild', key: 'R', ult: true, target: 'point', range: 8, cooldown: 120, desc: 'ULTIMATE: 4 Dire Stags answer the call at the target for 60s.',
    cast(g, c, t, x, y) { for (let i = 0; i < 4; i++) { const u = g.spawnUnit(c.owner, 'dire_stag', x + rand(-30, 30), y + rand(-30, 30)); u.lifetime = 60; } g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#7ee08a', t: 1 }); g.updateSupply(c.owner); } },

  mend: { name: 'Mend', key: 'Q', target: 'ally', range: 6, cooldown: 10, desc: 'Heal a friendly unit for 150 (structures 100).',
    cast(g, c, t) { if (t.kind === 'unit') healUnit(g, t, 150 * (1 + (c.level - 1) * 0.1)); else t.hp = Math.min(t.maxHp, t.hp + 100); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#8fffa0', t: 0.3 }); } },
  seed_the_land: { name: 'Seed the Land', key: 'W', target: 'point', range: 6, cooldown: 25, desc: 'Grow the grove in 4 tiles for 30s: allies heal 4/s, ground enemies are slowed by vines.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 30, r: 4 * TILE, kind: 'grove' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#7ee08a', t: 1 }); } },
  bountiful_harvest: { name: 'Bountiful Harvest', key: 'E', target: 'none', cooldown: 60, desc: 'For 20s income is increased 40% and production is 30% faster.',
    cast(g, c) { g.addPlayerBuff(c.player, 'prosperity', 20); g.addEffect({ type: 'text', x: c.x, y: c.y - 20, text: 'BOUNTIFUL HARVEST', color: '#7ee08a', t: 1.5 }); } },
  bloom_of_life: { name: 'Bloom of Life', key: 'R', ult: true, target: 'none', cooldown: 100, desc: 'ULTIMATE: for 8s every ally within 8 tiles heals 25/s and regenerates +3.',
    cast(g, c) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, follow: c, x: c.x, y: c.y, t: 8, r: 8 * TILE, kind: 'bloom' }); g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 8 * TILE, color: '#c8ffd0', t: 1.2 }); } },

  spirit_bolt: { name: 'Spirit Bolt', key: 'Q', target: 'enemy', range: 7, cooldown: 7, desc: 'Bolt of spirit-fire: 90 damage, leaping to 2 more enemies for 50.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#a8ffb0', t: 0.3 }); g.damage(t, 90 * m, c, 'magic'); g.chainLightning(c, t, 50 * m, 2, 'spell'); } },
  entangle: { name: 'Entangle', key: 'W', target: 'point', range: 8, cooldown: 24, desc: 'Vines seize 4 tiles for 8s: ground enemies are held (85% slower) and lacerated 5/s.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 8, r: 4 * TILE, kind: 'vines', source: c }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#4caf50', t: 1 }); } },
  spirit_walk: { name: 'Spirit Walk', key: 'E', target: 'point', range: 10, cooldown: 35, desc: 'Sylvara and allies within 3 tiles pass through the spirit world to the target point.',
    cast(g, c, t, x, y) { const al = g.alliesNear(c.owner, c.x, c.y, 3 * TILE).filter(a => a.kind === 'unit'); g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 3 * TILE, color: '#a8ffb0', t: 0.8 }); teleportGroup(g, c, al, x, y); g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#a8ffb0', t: 0.8 }); } },
  everwood_awakening: { name: 'Everwood Awakening', key: 'R', ult: true, target: 'none', cooldown: 120, desc: 'ULTIMATE: 6 Spirits of the Everwood awaken around Sylvara for 45s.',
    cast(g, c) { for (let i = 0; i < 6; i++) { const u = g.spawnUnit(c.owner, 'everwood_spirit', c.x + rand(-40, 40), c.y + rand(-40, 40)); u.lifetime = 45; } g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 3 * TILE, color: '#a8ffb0', t: 1 }); g.updateSupply(c.owner); } },

  waystep: { name: 'Waystep', key: 'W', target: 'ally', range: 0, cooldown: 25, building: true, desc: 'Send allied units within 3 tiles of this Waystone to another of your Sylvan Waystones (click it).',
    cast(g, b, t) { if (!t || t.kind !== 'building' || t.defId !== 'sylvan_waystone' || t === b || !t.complete) { if (b.owner === g.human) g.msg('Target another completed Sylvan Waystone', 'warn'); b.cooldowns.waystep = 0; return; } const al = g.alliesNear(b.owner, b.x, b.y, 3 * TILE).filter(a => a.kind === 'unit'); if (!al.length) { b.cooldowns.waystep = 0; return; } g.addEffect({ type: 'ring', x: b.x, y: b.y, r: 3 * TILE, color: '#9fffe0', t: 0.8 }); teleportGroup(g, b, al, t.x, t.y + 1.5 * TILE); g.addEffect({ type: 'ring', x: t.x, y: t.y, r: 3 * TILE, color: '#9fffe0', t: 0.8 }); } },

  // ================= SANCTUARY =================
  holy_strike: { name: 'Holy Strike', key: 'Q', target: 'enemy', range: 1.5, cooldown: 8, desc: 'Consecrated blow: 3x damage (double against undead). Restores 40 ward.',
    cast(g, c, t) { const dmg = c.stat('dmg') * 3 * abilityDmgMul(g, c) * (t.def && t.def.undead ? 2 : 1); g.addEffect({ type: 'slash', x: t.x, y: t.y, color: '#fff7d0', t: 0.3, big: true }); g.damage(t, dmg, c, 'magic'); c.shield = Math.min(c.stat('maxShield'), c.shield + 40); } },
  shield_wall: { name: 'Shield Wall', key: 'W', target: 'none', cooldown: 30, desc: 'Allies within 6 tiles gain 80 ward and take 20% less damage for 12s.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 6 * TILE, color: '#9fe0ff', t: 1 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') { a.addBuff('shield_wall', 12, { dmgTakenMul: 0.8 }); a.shield = Math.min(a.stat('maxShield') + 80, a.shield + 80); } } },
  banner_of_order: { name: 'Banner of Order', key: 'E', target: 'none', cooldown: 30, desc: 'For 12s: nearby allies +20% damage; nearby enemies attack 25% slower.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 6 * TILE, color: '#fff7d0', t: 1 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('banner_order', 12, { dmgMul: 1.2 }); for (const e of g.enemiesNear(c.owner, c.x, c.y, 6 * TILE)) e.addBuff('order_awe', 12, { atkSpeedMul: 0.75 }); } },
  divine_intervention: { name: 'Divine Intervention', key: 'R', ult: true, target: 'none', cooldown: 120, desc: 'ULTIMATE: allies within 7 tiles become invulnerable for 4s.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 7 * TILE, color: '#ffffff', t: 1.2 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 7 * TILE)) if (a.kind === 'unit') a.addBuff('intervention', 4, { dmgTakenMul: 0 }); } },

  mend_wounds: { name: 'Mend Wounds', key: 'Q', target: 'ally', range: 6, cooldown: 10, desc: 'Heal a friendly unit for 160 and restore its ward (structures 100).',
    cast(g, c, t) { if (t.kind === 'unit') { healUnit(g, t, 160 * (1 + (c.level - 1) * 0.1)); t.shield = t.stat('maxShield'); } else t.hp = Math.min(t.maxHp, t.hp + 100); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#fff7d0', t: 0.3 }); } },
  consecrate: { name: 'Consecrate', key: 'W', target: 'point', range: 6, cooldown: 30, desc: 'Holy ground in 4 tiles for 20s: allies take 15% less damage and heal 3/s, enemies deal 15% less, blight burns away.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 20, r: 4 * TILE, kind: 'sanctify' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#fff7d0', t: 1 }); } },
  tithe_of_faith: { name: 'Tithe of Faith', key: 'E', target: 'none', cooldown: 60, desc: 'For 20s income is increased 40% and production is 30% faster.',
    cast(g, c) { g.addPlayerBuff(c.player, 'prosperity', 20); g.addEffect({ type: 'text', x: c.x, y: c.y - 20, text: 'TITHE OF FAITH', color: '#fff7d0', t: 1.5 }); } },
  mass_resurrection: { name: 'Mass Resurrection', key: 'R', ult: true, target: 'point', range: 7, cooldown: 120, desc: 'ULTIMATE: up to 5 fallen allies within 5 tiles return to life at half health.',
    cast(g, c, t, x, y) { reviveCorpses(g, c, x, y, 5 * TILE, 5, 0.5); g.addEffect({ type: 'ring', x, y, r: 5 * TILE, color: '#fff7d0', t: 1.2 }); } },

  smite: { name: 'Smite', key: 'Q', target: 'enemy', range: 7, cooldown: 7, desc: 'Column of holy light: 110 damage, +50% against undead.',
    cast(g, c, t) { const m = abilityDmgMul(g, c) * (t.def && t.def.undead ? 1.5 : 1); g.addEffect({ type: 'lightning', x1: t.x, y1: t.y - 200, x2: t.x, y2: t.y, color: '#fff7d0', t: 0.3 }); g.damage(t, 110 * m, c, 'magic'); } },
  banish_corruption: { name: 'Banish Corruption', key: 'W', target: 'point', range: 8, cooldown: 25, desc: 'Purge 4 tiles: blight is scoured, enemy buffs are dispelled, undead take 80 damage, and the ground is consecrated for 10s.',
    cast(g, c, t, x, y) { const m = g.map, cx = Math.floor(x / TILE), cy = Math.floor(y / TILE); for (let ty = cy - 4; ty <= cy + 4; ty++) for (let tx = cx - 4; tx <= cx + 4; tx++) if (m.inBounds(tx, ty) && dist(tx, ty, cx, cy) <= 4) m.layers.blight[m.idx(tx, ty)] = 0; for (const e of g.enemiesNear(c.owner, x, y, 4 * TILE)) { e.buffs = e.buffs.filter(b => b.mods.dot || b.mods.stun || b.mods.silence); if (e.def && e.def.undead) g.damage(e, 80 * abilityDmgMul(g, c), c, 'magic'); } g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 10, r: 4 * TILE, kind: 'sanctify' }); g.addEffect({ type: 'burst', x, y, r: 4 * TILE, color: '#ffffff', t: 0.6 }); } },
  celestial_step: { name: 'Celestial Step', key: 'E', target: 'point', range: 10, cooldown: 35, desc: 'Cassiel and allies within 3 tiles step through heaven to the target point.',
    cast(g, c, t, x, y) { const al = g.alliesNear(c.owner, c.x, c.y, 3 * TILE).filter(a => a.kind === 'unit'); g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 3 * TILE, color: '#fff7d0', t: 0.8 }); teleportGroup(g, c, al, x, y); g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#fff7d0', t: 0.8 }); } },
  wrath_of_heaven: { name: 'Wrath of Heaven', key: 'R', ult: true, target: 'point', range: 9, cooldown: 100, desc: 'ULTIMATE: for 5s, beams of judgment strike enemies within 5 tiles twice per second for 60 each.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 5, r: 5 * TILE, kind: 'heaven', source: c, mul: abilityDmgMul(g, c) }); g.addEffect({ type: 'ring', x, y, r: 5 * TILE, color: '#fff7d0', t: 1 }); } },

  toll_the_bell: { name: 'Toll the Bell', key: 'T', target: 'none', cooldown: 90, building: true, desc: 'Map-wide: for 15s every Sanctuary unit gains +20% damage and +15% speed.',
    cast(g, b) { for (const u of g.units(b.owner)) u.addBuff('bell_toll', 15, { dmgMul: 1.2, speedMul: 1.15 }); g.msg('The Eternal Bell tolls! The faithful rally.', b.owner === g.human ? 'good' : 'warn'); } },
});

// Unit auras for the new factions (called from Game.applyUnitAura)
const EXTRA_UNIT_AURAS = {
  dawn_aura(g, u, a, dt) { for (const e of g.enemiesNear(u.owner, u.x, u.y, a.radius * TILE)) g.damage(e, 5 * 0.3, u, 'magic', true); for (const al of g.alliesNear(u.owner, u.x, u.y, a.radius * TILE)) if (al.kind === 'unit') healUnit(g, al, 5 * 0.3); },
  heart_aura(g, u, a, dt) { for (const e of g.enemiesNear(u.owner, u.x, u.y, a.radius * TILE)) if (e.kind === 'unit' && !e.flying) e.addBuff('rooted_heart', 0.4, { speedMul: 0.5 }); for (const al of g.alliesNear(u.owner, u.x, u.y, a.radius * TILE)) if (al.kind === 'unit') healUnit(g, al, 6 * 0.3); },
  archangel_aura(g, u, a, dt) { for (const al of g.alliesNear(u.owner, u.x, u.y, a.radius * TILE)) if (al.kind === 'unit' && al.maxShield) al.shield = Math.min(al.stat('maxShield'), al.shield + 8 * 0.3); for (const e of g.enemiesNear(u.owner, u.x, u.y, a.radius * TILE)) if (e.def && e.def.undead) g.damage(e, 8 * 0.3, u, 'magic', true); },
};
