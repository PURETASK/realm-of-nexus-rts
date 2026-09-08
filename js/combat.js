// Combat: attacks, damage, death, corpses, towers, projectiles, passives
Object.assign(Game.prototype, {
  tryAttack(u, t, dt) {
    u.facing = angleTo(u.x, u.y, t.x, t.y);
    if (u.attackTimer > 0) return;
    u.attackTimer = u.stat('cd');
    const dmg = u.stat('dmg');
    const type = u.def.magic ? 'magic' : 'physical';
    if (u.def.range > 1.6) {
      const kind = u.def.type === 'siege' ? 'shell' : (u.def.magic ? 'bolt' : 'arrow');
      this.projectiles.push({ x: u.x, y: u.y, target: t, speed: 9 * TILE, dmg, source: u, type, splash: u.def.splash, color: u.faction.color, kind });
      this.emit('shoot', u.x, u.y, u.owner, { kind });
    } else {
      this.hit(u, t, dmg, type, u.def.splash);
      this.addEffect({ type: 'slash', x: t.x, y: t.y, color: u.faction.color, t: 0.15 });
    }
  },

  hit(source, t, dmg, type, splash) {
    if (splash) {
      for (const e of this.nearby(t.x, t.y, splash * TILE, e => e.owner !== source.owner && e.owner >= 0 && (e.kind === 'unit' || e.kind === 'building'))) {
        if (e.kind === 'unit' && e.flying && !source.def.air && e !== t) continue;
        this.damage(e, e === t ? dmg : dmg * 0.6, source, type);
      }
      this.addEffect({ type: 'burst', x: t.x, y: t.y, r: splash * TILE, color: source.faction.color, t: 0.35 });
    } else this.damage(t, dmg, source, type);
    // on-hit specials
    if (source.kind === 'unit') {
      if (source.def.shock && t.kind === 'unit') this.damage(t, source.def.shock, source, 'true');
      if (source.def.chain && t.kind === 'unit') this.chainLightning(source, t, dmg * 0.5, source.def.chain, 'attack');
      if (source.def.range <= 1.6 && source.player.eff('meleeDot', 'add') > 0 && t.kind === 'unit') { const b = t.addBuff('plague', 6, { dot: 3 }); b.source = source; }
      const ls = source.stat('lifesteal');
      if (ls > 0) source.hp = Math.min(source.maxHp, source.hp + dmg * ls);
    }
  },

  chainLightning(source, from, dmg, count, tag) {
    let cur = from, hitSet = new Set([from.id]);
    for (let i = 0; i < count; i++) {
      const cands = this.enemiesNear(source.owner, cur.x, cur.y, 4 * TILE).filter(e => !hitSet.has(e.id) && (source.def ? (source.def.air !== false || !e.flying) : true));
      if (!cands.length) break;
      cands.sort((a, b) => dist2(a.x, a.y, cur.x, cur.y) - dist2(b.x, b.y, cur.x, cur.y));
      const nxt = cands[0];
      this.addEffect({ type: 'lightning', x1: cur.x, y1: cur.y, x2: nxt.x, y2: nxt.y, color: '#bfe8ff', t: 0.25 });
      this.damage(nxt, dmg, source, 'magic');
      if (nxt.kind === 'unit' && (nxt.def.mechanical)) nxt.addBuff('stun', 1, { stun: true });
      hitSet.add(nxt.id); cur = nxt; dmg *= 0.8;
    }
  },

  damage(t, amount, source, type, silent) {
    if (!t || t.dead || amount <= 0) return 0;
    let dmg = amount;
    if (type !== 'true') {
      let armor = t.stat ? t.stat('armor') : 0;
      if (type === 'magic') armor *= 0.5;
      dmg = Math.max(amount * 0.15, amount - armor);
    }
    if (source && source.def && source.def.vsUndead && t.def && t.def.undead) dmg *= source.def.vsUndead;
    if (t.kind === 'unit') {
      dmg *= t.stat('dmgTaken');
      if (source && source.kind === 'unit' && source.def.range > 1.6) dmg *= t.buffMul('rangedTakenMul');
      if (source && source.kind === 'building') dmg *= t.buffMul('rangedTakenMul');
      // Tempest Barrier aura from T2+ base
      if (t.faction.id === 'tempest' && t.player.tier >= 2 && source && ((source.kind === 'unit' && source.def.range > 1.6) || source.kind === 'building')) {
        const base = this.baseOf(t.owner); if (base && !base.relocate && dist(base.x, base.y, t.x, t.y) < 8 * TILE) dmg *= 0.75;
      }
      if (t.buffFlag('invisible') && !silent) t.removeBuff('invisible');
      if (source && source.kind === 'unit' && source.def.vsBuilding && t.kind === 'building') {}
    } else if (t.kind === 'building') {
      if (source && source.kind === 'unit' && source.def.vsBuilding) dmg *= source.def.vsBuilding;
      if (t.hasShield > 0) dmg *= 0.5;
    }
    // Undying Devotion: chance to negate fatal blow
    if (t.kind === 'unit' && t.hp - dmg <= 0 && t.hasBuff('undying') && (t.cooldowns.undying || 0) <= 0) {
      t.cooldowns.undying = 90; t.hp = Math.max(1, t.maxHp * 0.15);
      this.addEffect({ type: 'text', x: t.x, y: t.y - 16, text: 'UNDYING', color: '#c9a0ff', t: 1 });
      return 0;
    }
    if (t.kind === 'unit' && t.shield > 0 && type !== 'true') { const ab = Math.min(t.shield, dmg); t.shield -= ab; dmg -= ab; t.shieldDelay = 5; }
    t.hp -= dmg;
    if (!silent) { t.flash = 0.12; this.emit('hit', t.x, t.y, t.owner, { dmg }); }
    if (!silent && t.kind === 'unit' && t.isHero && dmg > 5) this.addEffect({ type: 'text', x: t.x + rand(-8, 8), y: t.y - 18, text: Math.round(dmg), color: '#ff8', t: 0.6 });
    // retaliation: idle units fight back
    if (t.kind === 'unit' && source && !source.dead && (t.order.type === 'idle' || t.order.type === 'hold' || (t.order.type === 'gather' && t.def.dmg > 0 && false)) && t.canAttack(source) && t.def.dmg > 0 && !t.isWorker) {
      t.order = { type: 'attack', target: source, returnTo: t.holdPos ? null : { x: t.x, y: t.y }, hold: t.holdPos }; t.target = source;
    }
    if (t.kind === 'unit' && t.isWorker && source && t.faction.gathers && t.order.type === 'gather' && dist(t.x, t.y, source.x, source.y) < 3 * TILE) {
      // flee toward base
      const b = this.baseOf(t.owner); if (b) { t.order = { type: 'move', x: b.x, y: b.y + 2 * TILE }; this.setPath(t, b.x, b.y + 2 * TILE); }
    }
    if (t.hp <= 0) this.kill(t, source);
    // notify human on attack
    if (t.owner === this.human && source && source.owner !== this.human && (this.lastAttackMsg || 0) < this.time - 12) {
      this.lastAttackMsg = this.time; this.msg(`${t.name} is under attack!`, 'warn'); this.attackPing = { x: t.x, y: t.y, t: 4 }; this.emit('warn', t.x, t.y, this.human);
    }
    return dmg;
  },

  kill(t, source, expire) {
    if (t.dead) return;
    t.dead = true;
    if (!expire || t.kind === 'building') this.emit('death', t.x, t.y, t.owner, { building: t.kind === 'building', big: t.kind === 'unit' && (t.isHero || (t.def.supply || 0) >= 3) });
    const killerP = source ? this.players[source.owner] : null;
    if (t.kind === 'unit') {
      if (killerP && killerP !== t.player) { killerP.kills++; t.player.losses++; }
      this.updateSupply(t.owner);
      // XP to nearby heroes of killer
      if (killerP && killerP !== t.player) {
        const xp = 8 + (t.def.supply || 0) * 8 + (t.isHero ? 60 : 0);
        for (const h of this.heroes(killerP.index)) if (dist(h.x, h.y, t.x, t.y) < 10 * TILE) h.gainXp(xp);
      }
      // Pale King: undead near Tyvaris rise once
      if (!expire && t.def.undead && !t.deathOnce && !t.isHero) {
        const ty = this.heroes(t.owner).find(h => h.defId === 'tyvaris' && dist(h.x, h.y, t.x, t.y) < 6 * TILE);
        if (ty) { const nu = this.spawnUnit(t.owner, 'skeleton_warrior', t.x, t.y); nu.deathOnce = true; nu.lifetime = 45; this.addEffect({ type: 'ring', x: t.x, y: t.y, r: 20, color: '#c9a0ff', t: 0.6 }); }
      }
      // Souls for Abyss players with presence nearby
      for (const p of this.players) {
        if (p.faction.id !== 'abyss') continue;
        const near = this.entities.some(e => !e.dead && e.owner === p.index && dist(e.x, e.y, t.x, t.y) < 8 * TILE);
        if (near) {
          let souls = 4 + (t.def.supply || 0) * 5 + (t.isHero ? 40 : 0);
          if (t.owner === p.index) souls *= 0.5;
          if (p.tier >= 2) souls *= 1.25;
          souls *= p.incomeMul;
          p.res.p += souls; p.stats.p += souls;
          if (p.index === this.human) this.addEffect({ type: 'text', x: t.x, y: t.y - 10, text: '+' + Math.round(souls) + ' souls', color: '#c9a0ff', t: 0.9 });
        }
      }
      // Curse of Undeath: enemies dying under curse rise for the caster
      if (t.hasBuff('curse_undeath') && !expire) {
        const b = t.getBuff('curse_undeath');
        if (b.owner != null && b.owner !== t.owner) { const nu = this.spawnUnit(b.owner, 'skeleton_warrior', t.x, t.y); nu.lifetime = 60; nu.deathOnce = true; this.addEffect({ type: 'ring', x: t.x, y: t.y, r: 22, color: '#8b3cff', t: 0.6 }); }
      }
      // Bone walls regen nearby
      for (const b of this.buildings()) if (b.def.wall && b.faction.id === 'abyss' && dist(b.x, b.y, t.x, t.y) < 2.5 * TILE) b.hp = Math.min(b.maxHp, b.hp + 60);
      // Soul Obelisk leech-on-kill is passive via hit()
      if (!expire && !t.isHero) this.corpses.push(new Corpse(this, t.owner, t.defId, t.x, t.y, t.flying));
      if (!expire && t.def.rebirth && !t.reborn) { this.respawns.push({ owner: t.owner, defId: t.defId, x: t.x, y: t.y, t: 4 }); this.addEffect({ type: 'ring', x: t.x, y: t.y, r: 30, color: '#ffb347', t: 1 }); }
      if (t.isHero) {
        t.player.heroCooldowns[t.defId] = 60;
        this.msg(`${t.name} has fallen. ${t.owner === this.human ? 'They may be resummoned in 60s.' : ''}`, t.owner === this.human ? 'warn' : 'good');
      }
      this.addEffect({ type: 'death', x: t.x, y: t.y, color: t.faction.color, t: 0.6, flying: t.flying });
    } else if (t.kind === 'building') {
      this.map.setBlocked(t.tx, t.ty, t.w, t.h, false, t.def.blocksAir);
      if (t.node) t.node.building = null;
      for (const q of t.queue) t.player.refund(q.cost);
      this.updateSupply(t.owner);
      this.addEffect({ type: 'burst', x: t.x, y: t.y, r: t.w * TILE * 0.7, color: '#ff9b6a', t: 0.8 });
      if (t.def.isBase) this.msg(`${t.owner === this.human ? 'Your' : 'The enemy'} ${t.name} has been destroyed!`, t.owner === this.human ? 'warn' : 'good');
      else if (t.owner === this.human) this.msg(`${t.name} destroyed!`, 'warn');
    }
  },

  updateProjectiles(dt) {
    for (const p of this.projectiles) {
      if (!p.target || p.target.dead) { p.done = true; continue; }
      const d = dist(p.x, p.y, p.target.x, p.target.y), step = p.speed * dt;
      if (d <= step) { p.done = true; this.hit(p.source, p.target, p.dmg, p.type, p.splash); if (p.kind === 'bolt') this.addEffect({ type: 'spark', x: p.target.x, y: p.target.y, color: p.color, t: 0.2 }); }
      else { p.x += (p.target.x - p.x) / d * step; p.y += (p.target.y - p.y) / d * step; }
    }
    this.projectiles = this.projectiles.filter(p => !p.done);
  },

  updateCorpses(dt) {
    for (const c of this.corpses) c.t -= dt;
    this.corpses = this.corpses.filter(c => c.t > 0 && !c.dead);
  },

  updateMines() {
    for (const m of this.buildings()) {
      if (!m.def.mine || !m.complete) continue;
      const en = this.enemiesNear(m.owner, m.x, m.y, 1.5 * TILE).filter(e => !e.flying);
      if (en.length) {
        for (const e of this.enemiesNear(m.owner, m.x, m.y, 3.5 * TILE)) { const b = e.addBuff('plague', 10, { dot: 3, dmgMul: 0.7 }); b.source = m; }
        this.addEffect({ type: 'burst', x: m.x, y: m.y, r: 3.5 * TILE, color: '#7fe07f', t: 0.8 });
        this.kill(m, null);
      }
    }
  },

  updateTower(b, dt) {
    if (b.attackTimer > 0) { b.attackTimer -= dt; return; }
    const tw = b.def.tower, range = b.towerRange();
    const cands = this.enemiesNear(b.owner, b.x, b.y, range).filter(e => (tw.air || !e.flying) && (!e.invisible || this.detected(b.owner, e)));
    if (!cands.length) return;
    cands.sort((a, c) => { const pa = (tw.prefAir && a.flying ? -1000 : 0) + b.distTo(a), pc = (tw.prefAir && c.flying ? -1000 : 0) + b.distTo(c); return pa - pc; });
    const t = cands[0];
    b.attackTimer = tw.cd;
    const dmg = b.towerDmg();
    if (b.faction.id === 'tempest') {
      this.addEffect({ type: 'lightning', x1: b.x, y1: b.y - 20, x2: t.x, y2: t.y, color: '#bfe8ff', t: 0.25 });
      this.damage(t, dmg, b, 'magic');
      if (tw.chain) this.chainLightning(b, t, dmg * 0.6, tw.chain, 'tower');
    } else {
      this.projectiles.push({ x: b.x, y: b.y - 16, target: t, speed: tw.splash ? 7 * TILE : 10 * TILE, dmg, source: b, type: 'magic', color: b.faction.affinity === 'light' ? '#ffe680' : b.faction.affinity === 'grove' ? '#8fffa0' : '#c9a0ff', kind: tw.splash ? 'shell' : 'bolt', splash: tw.splash });
      if (tw.leech) {
        for (const a of this.alliesNear(b.owner, b.x, b.y, 4 * TILE)) if (a.kind === 'unit' && a.def.undead) a.hp = Math.min(a.maxHp, a.hp + dmg * tw.leech * 0.3);
      }
    }
  },

  tryHeal(u) {
    const range = Math.max(u.stat('range'), 4 * TILE);
    let best = null, br = 0.95;
    for (const a of this.alliesNear(u.owner, u.x, u.y, range)) { if (a.kind !== 'unit' || a === u) continue; const r = a.hp / a.maxHp; if (r < br) { br = r; best = a; } }
    if (!best) return;
    u.attackTimer = u.stat('cd') * 1.5;
    best.hp = Math.min(best.maxHp, best.hp + u.stat('heal'));
    this.addEffect({ type: 'lightning', x1: u.x, y1: u.y, x2: best.x, y2: best.y, color: u.faction.affinity === 'grove' ? '#8fffa0' : '#fff2b0', t: 0.25 });
  },

  tryRaiseDead(u) {
    if ((u.cooldowns.raise || 0) > 0) return;
    const c = this.corpses.find(c => !c.dead && !c.flying && dist(c.x, c.y, u.x, u.y) < 5 * TILE);
    if (!c) return;
    if (u.player.supplyUsed + 1 > u.player.supplyCap) return;
    c.dead = true; u.cooldowns.raise = 4;
    const nu = this.spawnUnit(u.owner, 'skeleton_warrior', c.x, c.y); nu.lifetime = 50; nu.deathOnce = true;
    this.addEffect({ type: 'ring', x: c.x, y: c.y, r: 18, color: '#8b3cff', t: 0.5 });
    if (u.order.type === 'attackmove' || u.order.type === 'attack') { const t = u.target; if (t && !t.dead) this.orderAttack([nu], t); else this.orderMove([nu], u.x, u.y, true); }
  },

  updateHeroPassives(h, dt) {
    h.auraTimer -= dt; if (h.auraTimer > 0) return; h.auraTimer = 0.25;
    switch (h.defId) {
      case 'tyvaris': for (const a of this.alliesNear(h.owner, h.x, h.y, 6 * TILE)) if (a.kind === 'unit' && a !== h) a.addBuff('pale_king', 0.4, { dmgMul: 1.1 }); break;
      case 'neratha': for (const a of this.alliesNear(h.owner, h.x, h.y, 6 * TILE)) if (a.kind === 'unit') a.addBuff('undying', 0.4, {}); break;
      case 'rykan': for (const a of this.alliesNear(h.owner, h.x, h.y, 6 * TILE)) if (a.kind === 'unit' && a.flying && a !== h) a.addBuff('skyfury', 0.4, { armorAdd: 2, dmgMul: 1.15 }); break;
      case 'lyrian': { const base = this.baseOf(h.owner); if (base && dist(base.x, base.y, h.x, h.y) < 6 * TILE && base.hp < base.maxHp) base.hp = Math.min(base.maxHp, base.hp + 5 * 0.25); break; }
      case 'malazar': break;
      case 'alyssia': break;
    }
    // Skyfury chain on Rykan handled via def.chain? give Rykan chain 2
    if (h.defId === 'rykan' && !h.def.chain) h.def.chain = 2;
  },

  applyUnitAura(u, dt) {
    const a = u.def.aura;
    if (typeof EXTRA_UNIT_AURAS !== 'undefined' && EXTRA_UNIT_AURAS[a.id]) {
      u.auraTimer -= dt; if (u.auraTimer > 0) return; u.auraTimer = 0.3;
      EXTRA_UNIT_AURAS[a.id](this, u, a, dt);
      if (u.def.spreads && u.faction.affinity) this.map.addLayerSource(u.faction.affinity, u.x, u.y, 4, 2);
      return;
    }
    if (a.id === 'death_aura') {
      u.auraTimer -= dt; if (u.auraTimer > 0) return; u.auraTimer = 0.3;
      for (const e of this.enemiesNear(u.owner, u.x, u.y, a.radius * TILE)) { this.damage(e, 4 * 0.3, u, 'magic', true); e.addBuff('death_aura', 0.4, { dmgMul: 0.85 }); }
      this.map.addCorruptionSource(u.x, u.y, 4, 2);
    }
  },
});
