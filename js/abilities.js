// Ability registry: heroes and buildings. target: 'none' | 'point' | 'unit' | 'ally' | 'enemy'
function abilityDmgMul(game, caster) {
  let m = 1;
  m *= caster.player.eff('abilityDmg', 'mul');
  if (caster.kind === 'unit' && caster.isHero) m *= 1 + (caster.level - 1) * 0.08;
  return m;
}
function stormDur(game, caster, base) { return base * caster.player.eff('stormDur', 'mul'); }
const EXTRA_WARDS = {};

const ABILITIES = {
  // ================= ABYSS =================
  soulcleaver: { name: 'Soulcleaver Blade', key: 'Q', target: 'enemy', range: 1.5, cooldown: 8, desc: 'Heavy strike (3x damage). If the target dies, its soul heals Tyvaris and nearby undead.',
    cast(g, c, t) { const dmg = c.stat('dmg') * 3 * abilityDmgMul(g, c); g.addEffect({ type: 'slash', x: t.x, y: t.y, color: '#c9a0ff', t: 0.3, big: true }); g.damage(t, dmg, c, 'physical'); if (t.dead) { c.hp = Math.min(c.maxHp, c.hp + 80); for (const a of g.alliesNear(c.owner, c.x, c.y, 5 * TILE)) if (a.kind === 'unit') a.hp = Math.min(a.maxHp, a.hp + 30); } } },
  dread_banner: { name: 'Dread Banner', key: 'W', target: 'none', cooldown: 30, desc: 'For 12s: nearby allies +25% damage and take 20% less; nearby enemies attack 25% slower.',
    cast(g, c) { const d = 12; g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 6 * TILE, color: '#8b3cff', t: 1 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('dread_banner', d, { dmgMul: 1.25, dmgTakenMul: 0.8 }); for (const e of g.enemiesNear(c.owner, c.x, c.y, 6 * TILE)) e.addBuff('dread', d, { atkSpeedMul: 0.75 }); } },
  sacrificial_surge: { name: 'Sacrificial Surge', key: 'E', target: 'none', cooldown: 25, desc: 'Execute the nearest lesser ally: +40 souls and 8s of +40% speed and +30% damage for nearby allies.',
    cast(g, c) { const cands = g.alliesNear(c.owner, c.x, c.y, 4 * TILE).filter(a => a.kind === 'unit' && !a.isHero && !a.isWorker); if (!cands.length) { if (c.owner === g.human) g.msg('No lesser unit to sacrifice nearby', 'warn'); c.cooldowns.sacrificial_surge = 0; return; } cands.sort((a, b) => (a.def.supply || 0) - (b.def.supply || 0)); const v = cands[0]; g.kill(v, c, true); c.player.res.p += 40; for (const a of g.alliesNear(c.owner, c.x, c.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('surge', 8, { speedMul: 1.4, dmgMul: 1.3 }); g.addEffect({ type: 'burst', x: v.x, y: v.y, r: 40, color: '#ff4b6e', t: 0.5 }); } },
  pale_king: { name: 'Aura of the Pale King', key: 'R', passive: true, desc: 'Passive: Tyvaris spreads blight as he walks. Nearby allies +10% damage. Undead that die near him rise once more as skeletons.' },

  harvest_soul: { name: 'Harvest Soul', key: 'Q', target: 'enemy', range: 6, cooldown: 12, desc: 'Curse a target: 60 damage over 6s. Grants +30 souls immediately and +40 more if it dies cursed.',
    cast(g, c, t) { const b = t.addBuff('harvest', 6, { dot: 10 * abilityDmgMul(g, c) }); b.source = c; c.player.res.p += 30; t.addBuff('curse_undeath', 6, {}).owner = c.owner; g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#c9a0ff', t: 0.4 }); } },
  corruption_ward: { name: 'Corruption Ward', key: 'W', target: 'point', range: 6, cooldown: 20, desc: 'Plant a totem for 30s: rapidly spreads blight, heals undead +4/s, reveals stealth and slows enemies within 4 tiles.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 30, r: 4 * TILE, kind: 'corruption' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#8b3cff', t: 1 }); } },
  dark_pact: { name: 'Dark Pact', key: 'E', target: 'ally', range: 6, cooldown: 40, desc: 'Sacrifice 25% of Neratha\'s health: target structure produces 2.5x faster for 20s.',
    cast(g, c, t) { if (t.kind !== 'building') { c.cooldowns.dark_pact = 0; return; } c.hp = Math.max(1, c.hp - c.maxHp * 0.25); t.darkPact = 20; g.addEffect({ type: 'ring', x: t.x, y: t.y, r: 40, color: '#ff4b6e', t: 1 }); } },
  undying_devotion: { name: 'Undying Devotion', key: 'R', passive: true, desc: 'Passive: allies near Neratha survive a killing blow once every 90s, remaining at 15% health.' },

  void_bolt: { name: 'Void Bolt', key: 'Q', target: 'enemy', range: 7, cooldown: 7, desc: 'Bolt of Void energy: 90 damage, then splits to 3 nearby enemies for 40 and silences them 3s.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#8b3cff', t: 0.3 }); g.damage(t, 90 * m, c, 'magic'); let n = 0; for (const e of g.enemiesNear(c.owner, t.x, t.y, 3 * TILE)) { if (e === t || n >= 3) continue; n++; g.addEffect({ type: 'lightning', x1: t.x, y1: t.y, x2: e.x, y2: e.y, color: '#8b3cff', t: 0.3 }); g.damage(e, 40 * m, c, 'magic'); if (e.kind === 'unit') e.addBuff('silence', 3, { silence: true }); } } },
  nightmare_veil: { name: 'Nightmare Veil', key: 'W', target: 'point', range: 8, cooldown: 30, desc: 'Shroud an area for 10s: enemies inside are slowed 30% and deal 25% less; allied undead inside become invisible while not attacking.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 10, r: 4 * TILE, kind: 'veil' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#2a1050', t: 1 }); } },
  nether_portal: { name: 'Nether Portal', key: 'E', target: 'point', range: 10, cooldown: 35, desc: 'Teleport Malazar and allies within 3 tiles to the target point. Enemies at the destination are banished for 2s.',
    cast(g, c, t, x, y) { const al = g.alliesNear(c.owner, c.x, c.y, 3 * TILE).filter(a => a.kind === 'unit'); g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 3 * TILE, color: '#8b3cff', t: 0.8 }); for (const e of g.enemiesNear(c.owner, x, y, 2.5 * TILE)) e.addBuff('banish', 2, { stun: true, invisible: true, dmgTakenMul: 0 }); let i = 0; for (const a of al) { const ang = i * 2.4, r = Math.sqrt(i) * 22; i++; let nx = x + Math.cos(ang) * r, ny = y + Math.sin(ang) * r; if (!a.flying) { const nf = g.map.nearestFree(Math.floor(nx / TILE), Math.floor(ny / TILE), false); nx = nf.tx * TILE + TILE / 2; ny = nf.ty * TILE + TILE / 2; } a.x = nx; a.y = ny; a.path = []; if (a.order.type === 'move' || a.order.type === 'attackmove') g.clearOrder(a); } g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#8b3cff', t: 0.8 }); } },
  curse_of_undeath: { name: 'Curse of Undeath', key: 'R', ult: true, target: 'point', range: 9, cooldown: 90, desc: 'ULTIMATE: curse a wide area for 12s. Enemies that die there rise as skeletons under your control.',
    cast(g, c, t, x, y) { for (const e of g.enemiesNear(c.owner, x, y, 6 * TILE)) e.addBuff('curse_undeath', 12, {}).owner = c.owner; g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: 12, r: 6 * TILE, kind: 'curse' }); g.addEffect({ type: 'ring', x, y, r: 6 * TILE, color: '#8b3cff', t: 1.2 }); } },

  sacrifice: { name: 'Sacrifice', key: 'S', target: 'none', cooldown: 10, building: true, desc: 'Sacrifice the nearest lesser allied unit at this well for +60 Soul Essence.',
    cast(g, b) { const cands = g.alliesNear(b.owner, b.x, b.y, 4 * TILE).filter(a => a.kind === 'unit' && !a.isHero); if (!cands.length) { if (b.owner === g.human) g.msg('No unit near the well to sacrifice', 'warn'); b.cooldowns.sacrifice = 0; return; } cands.sort((a, c) => (a.def.supply || 0) - (c.def.supply || 0) || (a.isWorker ? 1 : -1)); const v = cands[0]; g.kill(v, b, true); b.player.res.p += 60; g.addEffect({ type: 'burst', x: v.x, y: v.y, r: 30, color: '#ff4b6e', t: 0.5 }); } },
  toggle_convert: { name: 'Toggle Conversion', key: 'T', target: 'none', cooldown: 0, building: true, desc: 'Start / stop condensing Soul Essence into Voidstone.',
    cast(g, b) { b.toggles.convert = !b.toggles.convert; } },

  // ================= TEMPEST =================
  thunderstrike: { name: 'Thunderstrike', key: 'Q', target: 'enemy', range: 4, cooldown: 8, desc: 'Lightning smite: 110 damage plus 50 splash in 2 tiles. Mechanical targets are stunned 2s.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'lightning', x1: t.x, y1: t.y - 200, x2: t.x, y2: t.y, color: '#ffffff', t: 0.3 }); g.addEffect({ type: 'burst', x: t.x, y: t.y, r: 2 * TILE, color: '#bfe8ff', t: 0.4 }); for (const e of g.enemiesNear(c.owner, t.x, t.y, 2 * TILE, true)) { g.damage(e, (e === t ? 110 : 50) * m, c, 'magic'); if (e.kind === 'unit' && e.def.mechanical) e.addBuff('stun', 2, { stun: true }); } } },
  wind_rally: { name: 'Wind Rally', key: 'W', target: 'none', cooldown: 25, desc: 'Allies within 7 tiles gain +45% speed and +15% attack speed for 8s.',
    cast(g, c) { g.addEffect({ type: 'ring', x: c.x, y: c.y, r: 7 * TILE, color: '#8fd3ff', t: 0.8 }); for (const a of g.alliesNear(c.owner, c.x, c.y, 7 * TILE)) if (a.kind === 'unit') a.addBuff('wind_rally', stormDur(g, c, 8), { speedMul: 1.45, atkSpeedMul: 1.15 }); } },
  skyfury: { name: 'Skyfury Aura', key: 'E', passive: true, desc: 'Passive: allied fliers near Rykan gain +2 armor and +15% damage. His strikes chain lightning to 2 nearby foes.' },
  eye_of_the_storm: { name: 'Eye of the Storm', key: 'R', ult: true, target: 'none', cooldown: 90, desc: 'ULTIMATE: a storm follows Rykan for 12s. Nearby allies take 40% less damage and deal +25%; enemies inside are slowed and struck by lightning.',
    cast(g, c) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, follow: c, x: c.x, y: c.y, t: stormDur(g, c, 12), r: 5 * TILE, kind: 'eye', tick: 0 }); } },

  trade_winds: { name: 'Trade Winds', key: 'Q', target: 'none', cooldown: 60, desc: 'For 20s all tribute income and production speed are increased by 50%.',
    cast(g, c) { g.addPlayerBuff(c.player, 'trade_winds', 20); g.addEffect({ type: 'text', x: c.x, y: c.y - 20, text: 'TRADE WINDS', color: '#8fd3ff', t: 1.5 }); } },
  zephyr_ward: { name: 'Zephyr Ward', key: 'W', target: 'point', range: 6, cooldown: 30, desc: 'Wind barrier for 15s: allies inside take 60% less ranged damage; reveals invisible units; repairs structures.',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: stormDur(g, c, 15), r: 4 * TILE, kind: 'zephyr' }); g.addEffect({ type: 'ring', x, y, r: 4 * TILE, color: '#8fd3ff', t: 1 }); } },
  aerial_logistik: { name: 'Aerial Logistik', key: 'E', passive: true, desc: 'Passive: +10% tribute income while Lyrian lives. He slowly repairs the base when nearby.' },
  call_of_the_armada: { name: 'Call of the Armada', key: 'R', ult: true, target: 'point', range: 8, cooldown: 120, desc: 'ULTIMATE: the fleet answers. 2 Thunderhawks and 4 Shocktroopers arrive at the target for 60s.',
    cast(g, c, t, x, y) { for (let i = 0; i < 2; i++) { const u = g.spawnUnit(c.owner, 'thunderhawk', x + rand(-30, 30), y + rand(-30, 30)); u.lifetime = 60; } for (let i = 0; i < 4; i++) { const u = g.spawnUnit(c.owner, 'armada_trooper', x + rand(-30, 30), y + rand(-30, 30)); u.lifetime = 60; } g.addEffect({ type: 'ring', x, y, r: 3 * TILE, color: '#8fd3ff', t: 1 }); g.updateSupply(c.owner); } },

  chain_lightning: { name: 'Chain Lightning', key: 'Q', target: 'enemy', range: 7, cooldown: 7, desc: 'Bolt that leaps to up to 6 enemies: 80 damage, decreasing 20% per jump. Stuns mechanical units.',
    cast(g, c, t) { const m = abilityDmgMul(g, c); g.addEffect({ type: 'lightning', x1: c.x, y1: c.y, x2: t.x, y2: t.y, color: '#ffffff', t: 0.3 }); g.damage(t, 80 * m, c, 'magic'); g.chainLightning(c, t, 64 * m, 5, 'spell'); } },
  cloudburst: { name: 'Cloudburst', key: 'W', target: 'point', range: 8, cooldown: 25, desc: 'Storm cloud for 10s: enemies inside slowed 30% and take 6/s; allies healed 4/s. Re-energizes a depleted stormglass node beneath it (+400).',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: stormDur(g, c, 10), r: 3.5 * TILE, kind: 'cloud' }); g.weather.cloud.push({ x, y, r: 3.5 * TILE, t: stormDur(g, c, 10) }); for (const n of g.map.nodes) if (n.type === 'primary' && dist(n.x, n.y, x, y) < 3.5 * TILE) { n.amount = Math.min(n.max, n.amount + 400); g.addEffect({ type: 'text', x: n.x, y: n.y - 10, text: '+400 ore', color: '#8fd3ff', t: 1.2 }); } } },
  eye_of_clarity: { name: 'Eye of Clarity', key: 'E', target: 'none', cooldown: 60, desc: 'Reveal the entire map for 8s and expose invisible units.',
    cast(g, c) { c.player.reveal.push({ x: WORLD_W / 2, y: WORLD_H / 2, r: WORLD_W, t: 8 }); g.clarity = { owner: c.owner, t: 8 }; g.visionTimer = 0; g.addEffect({ type: 'text', x: c.x, y: c.y - 20, text: 'EYE OF CLARITY', color: '#8fd3ff', t: 1.5 }); } },
  hurricane_maelstrom: { name: 'Hurricane Maelstrom', key: 'R', ult: true, target: 'point', range: 10, cooldown: 120, desc: 'ULTIMATE: a hurricane rages for 10s in a 6-tile radius. Ground units inside barely move, fliers are battered, projectiles are useless, lightning strikes everywhere. Hits friend and foe (allies less).',
    cast(g, c, t, x, y) { g.wards = g.wards || []; g.wards.push({ owner: c.owner, x, y, t: stormDur(g, c, 10), r: 6 * TILE, kind: 'hurricane', tick: 0 }); g.weather.cloud.push({ x, y, r: 6 * TILE, t: stormDur(g, c, 10), heavy: true }); } },

  relocate: { name: 'Relocate Base', key: 'X', target: 'point', cooldown: 60, building: true, desc: 'Lift off and float the Stormspire to a new position (2.2 tiles/s). Production halts while airborne.' },
  eye_of_auranth: { name: 'Eye of Auranth', key: 'E', target: 'none', cooldown: 30, building: true, cost: { c: 1 }, desc: 'Spend a Tempest Pearl: a map-wide storm for 30s. Tempest units are faster and stronger; enemies are slowed, blinded and struck by lightning.',
    cast(g, b) { g.weather.storm = { until: stormDur(g, b, 30), owner: b.owner, tick: 0 }; g.msg('THE EYE OF AURANTH OPENS — a storm engulfs the realm!', b.owner === g.human ? 'good' : 'warn'); } },
};

// Ward (area effect) processing — called from game loop
Game.prototype.updateWards = function (dt) {
  this.wards = this.wards || [];
  for (const w of this.wards) {
    w.t -= dt;
    if (w.follow) { if (w.follow.dead) { w.t = 0; continue; } w.x = w.follow.x; w.y = w.follow.y; }
    w.tick = (w.tick || 0) + dt;
    const allies = this.alliesNear(w.owner, w.x, w.y, w.r, true), enemies = this.enemiesNear(w.owner, w.x, w.y, w.r, true);
    switch (w.kind) {
      case 'corruption':
        this.map.addCorruptionSource(w.x, w.y, w.r / TILE, 3);
        for (const a of allies) if (a.kind === 'unit' && a.def.undead) a.hp = Math.min(a.maxHp, a.hp + 4 * dt);
        for (const e of enemies) if (e.kind === 'unit') e.addBuff('ward_slow', 0.3, { speedMul: 0.8 });
        break;
      case 'veil':
        for (const e of enemies) if (e.kind === 'unit') e.addBuff('veil', 0.3, { speedMul: 0.7, dmgMul: 0.75 });
        for (const a of allies) if (a.kind === 'unit' && a.def.undead && a.attackTimer <= 0 && a.order.type !== 'attack') a.addBuff('invisible', 0.4, { invisible: true });
        break;
      case 'curse':
        for (const e of enemies) if (e.kind === 'unit') e.addBuff('curse_undeath', 0.5, {}).owner = w.owner;
        break;
      case 'zephyr':
        for (const a of allies) { if (a.kind === 'unit') a.addBuff('zephyr', 0.3, { rangedTakenMul: 0.4 }); else if (a.hp < a.maxHp) a.hp = Math.min(a.maxHp, a.hp + 8 * dt); }
        break;
      case 'cloud':
        for (const e of enemies) if (e.kind === 'unit') { e.addBuff('cloud', 0.3, { speedMul: 0.7 }); this.damage(e, 6 * dt, null, 'magic', true); }
        for (const a of allies) if (a.kind === 'unit') a.hp = Math.min(a.maxHp, a.hp + 4 * dt);
        break;
      case 'eye':
        for (const a of allies) if (a.kind === 'unit') a.addBuff('eye_storm', 0.3, { dmgTakenMul: 0.6, dmgMul: 1.25 });
        for (const e of enemies) if (e.kind === 'unit') e.addBuff('eye_slow', 0.3, { speedMul: 0.6 });
        if (w.tick > 0.8 && enemies.length) { w.tick = 0; const e = choice(enemies); this.addEffect({ type: 'lightning', x1: e.x, y1: e.y - 180, x2: e.x, y2: e.y, color: '#fff', t: 0.25 }); this.damage(e, 35, w.follow, 'magic'); }
        break;
      case 'hurricane':
        for (const e of enemies) if (e.kind === 'unit') { e.addBuff('hurricane', 0.3, e.flying ? { speedMul: 0.5, dmgMul: 0.6 } : { speedMul: 0.15, dmgMul: 0.5 }); this.damage(e, (e.flying ? 12 : 8) * dt, null, 'magic', true); }
        for (const a of allies) if (a.kind === 'unit' && a.kind === 'unit' && !(a.isHero && a.defId === 'alyssia')) { a.addBuff('hurricane', 0.3, { speedMul: a.flying ? 0.8 : 0.5 }); this.damage(a, 3 * dt, null, 'magic', true); }
        if (w.tick > 0.5) { w.tick = 0; const all = enemies.filter(e => e.kind === 'unit'); if (all.length) { const e = choice(all); this.addEffect({ type: 'lightning', x1: e.x + rand(-40, 40), y1: e.y - 200, x2: e.x, y2: e.y, color: '#fff', t: 0.25 }); this.damage(e, 30, null, 'magic'); } }
        break;
      default: if (EXTRA_WARDS[w.kind]) EXTRA_WARDS[w.kind](this, w, allies, enemies, dt);
    }
  }
  this.wards = this.wards.filter(w => w.t > 0);
  // global storm lightning
  if (this.weather.storm) {
    const s = this.weather.storm; s.tick += dt;
    if (s.tick > 0.7) { s.tick = 0; const en = this.units().filter(u => u.owner !== s.owner); if (en.length) { const e = choice(en); this.addEffect({ type: 'lightning', x1: e.x + rand(-60, 60), y1: e.y - 220, x2: e.x, y2: e.y, color: '#fff', t: 0.25 }); this.damage(e, 18, null, 'magic'); } }
  }
  if (this.clarity) { this.clarity.t -= dt; if (this.clarity.t <= 0) this.clarity = null; }
};
