// Entities: units, heroes, buildings, corpses
const LAYERS = ['blight', 'light', 'grove'];

class Entity {
  constructor(game, owner, x, y) {
    this.id = uid(); this.game = game; this.owner = owner; this.x = x; this.y = y;
    this.hp = 1; this.maxHp = 1; this.dead = false; this.kind = 'entity';
  }
  get player() { return this.game.players[this.owner]; }
  get faction() { return this.player ? this.player.faction : null; }
  get alive() { return !this.dead; }
}

class Unit extends Entity {
  constructor(game, owner, defId, x, y) {
    super(game, owner, x, y);
    this.kind = 'unit';
    this.defId = defId;
    this.def = unitDef(this.faction, defId);
    this.isHero = this.def.type === 'hero';
    this.flying = !!this.def.flying;
    this.radius = this.isHero ? 14 : (this.def.type === 'siege' || this.def.supply >= 5 ? 14 : this.def.supply >= 3 ? 12 : 10);
    this.maxHp = this.def.hp; this.hp = this.maxHp;
    this.maxShield = this.def.shield || 0; this.shield = this.maxShield; this.shieldDelay = 0;
    this.buffs = []; this.cooldowns = {};
    this.order = { type: 'idle' };
    this.path = []; this.target = null; this.attackTimer = 0; this.facing = 0;
    this.level = 1; this.xp = 0;
    this.lifetime = 0; // >0 = temporary summon
    this.gather = { carrying: 0, node: null, phase: 'toNode', timer: 0 };
    this.buildTask = null;
    this.abilities = this.def.abilities || [];
    this.auraTimer = 0; this.regenAcc = 0; this.stuck = 0; this.holdPos = false;
    this.deathOnce = false; this.reborn = false;
    this.vx = 0; this.vy = 0;
  }

  get name() { return this.def.name; }
  get tileX() { return Math.floor(this.x / TILE); }
  get tileY() { return Math.floor(this.y / TILE); }
  get isWorker() { return this.def.type === 'worker'; }
  get isCombat() { return !this.isWorker; }

  hasBuff(id) { return this.buffs.some(b => b.id === id); }
  getBuff(id) { return this.buffs.find(b => b.id === id); }
  addBuff(id, dur, mods) {
    const ex = this.getBuff(id);
    if (ex) { ex.t = Math.max(ex.t, dur); ex.mods = mods || ex.mods; return ex; }
    const b = { id, t: dur, mods: mods || {} }; this.buffs.push(b); return b;
  }
  removeBuff(id) { this.buffs = this.buffs.filter(b => b.id !== id); }
  buffMul(key) { let m = 1; for (const b of this.buffs) if (b.mods[key] != null) m *= b.mods[key]; return m; }
  buffAdd(key) { let m = 0; for (const b of this.buffs) if (b.mods[key] != null) m += b.mods[key]; return m; }
  buffFlag(key) { return this.buffs.some(b => b.mods[key]); }

  layer(name) { return this.game.map.layerAtWorld(name, this.x, this.y); }
  get onBlight() { return this.layer('blight') > 0.3; }
  get onOwnLayer() { const a = this.faction.affinity; return !!a && this.layer(a) > 0.3; }
  get onHostileLayer() { const a = this.faction.affinity; return LAYERS.some(l => l !== a && this.layer(l) > 0.3); }
  get stunned() { return this.buffFlag('stun'); }
  get invisible() { return this.buffFlag('invisible'); }

  stat(name) {
    const p = this.player, f = this.faction, w = this.game.weather;
    const lvl = this.isHero ? this.level - 1 : 0;
    const own = this.onOwnLayer, hostile = this.onHostileLayer;
    switch (name) {
      case 'dmg': {
        let d = this.def.dmg + lvl * 3 + p.eff('dmg', 'add', this);
        let m = this.buffMul('dmgMul');
        if (own) m *= 1.1;
        if (hostile) m *= 0.9;
        if (this.onBlight && f.id !== 'abyss' && this.game.abyssTier() >= 3) m *= 0.85;
        if (f.id === 'tempest' && w.storm) m *= 1.1;
        if (f.id !== 'tempest' && w.storm && !this.flying) m *= 0.9;
        return d * m;
      }
      case 'armor': return this.def.armor + (this.isHero ? Math.floor(lvl * 0.5) : 0) + this.buffAdd('armorAdd') + p.eff('armor', 'add', this);
      case 'speed': {
        let s = this.def.speed * TILE * this.buffMul('speedMul');
        if (own) s *= p.eff('affinitySpeed', 'mul', this) * (f.affinity === 'grove' ? 1.15 : 1.05);
        if (!this.flying && f.affinity !== 'grove' && this.layer('grove') > 0.3) s *= 0.85;
        if (this.onBlight && f.id !== 'abyss') s *= 0.9;
        if (this.flying) s *= p.eff('flyingSpeed', 'mul', this);
        if (w.storm) { if (f.id === 'tempest') s *= (p.tier >= 3 ? 1.3 : 1.15); else s *= 0.75; }
        return s;
      }
      case 'cd': return this.def.cd / this.buffMul('atkSpeedMul');
      case 'range': return this.def.range * TILE;
      case 'sight': return this.def.sight * TILE * (this.game.weather.storm && f.id !== 'tempest' ? 0.8 : 1);
      case 'dmgTaken': {
        let m = this.buffMul('dmgTakenMul');
        if (f.id === 'tempest' && w.storm && p.tier >= 3) m *= 0.8;
        return m;
      }
      case 'lifesteal': return (this.def.lifesteal || 0) + this.buffAdd('lifesteal') + p.eff('lifesteal', 'add', this);
      case 'regen': {
        let rg = this.buffAdd('regen') + p.eff('regen', 'add', this);
        if (this.isHero) rg += 1;
        if (own) rg += 1.5;
        return rg;
      }
      case 'maxShield': return this.maxShield * p.eff('shieldMul', 'mul', this);
      case 'heal': return (this.def.heal || 0) * p.eff('healMul', 'mul', this);
    }
    return 0;
  }

  get xpToLevel() { return 80 * this.level; }
  gainXp(v) {
    if (!this.isHero || this.level >= 10) return;
    this.xp += v;
    while (this.xp >= this.xpToLevel && this.level < 10) {
      this.xp -= this.xpToLevel; this.level++;
      this.maxHp = this.def.hp + (this.level - 1) * 35; this.hp = Math.min(this.maxHp, this.hp + 60);
      this.game.addEffect({ type: 'text', x: this.x, y: this.y - 20, text: 'LEVEL ' + this.level, color: '#ffd479', t: 1.5 });
      if (this.owner === this.game.human) this.game.msg(`${this.name} reached level ${this.level}`, 'good');
    }
  }

  canAttack(target) {
    if (!target || target.dead) return false;
    if (target.kind === 'unit' && target.flying && !this.def.air) return false;
    if (this.def.dmg <= 0) return false;
    return true;
  }

  distTo(e) {
    if (e.kind === 'building') return distToRect(this.x, this.y, e.tx * TILE, e.ty * TILE, e.w * TILE, e.h * TILE) - this.radius;
    return dist(this.x, this.y, e.x, e.y) - this.radius - (e.radius || 0);
  }
  inRange(e) { return this.distTo(e) <= this.stat('range') + 4; }
}

class Building extends Entity {
  constructor(game, owner, defId, tx, ty, complete) {
    super(game, owner, 0, 0);
    this.kind = 'building';
    this.defId = defId;
    this.def = this.faction.buildings[defId];
    this.tx = tx; this.ty = ty; this.w = this.def.w; this.h = this.def.h;
    this.x = (tx + this.w / 2) * TILE; this.y = (ty + this.h / 2) * TILE;
    this.maxHp = this.def.hp; this.hp = complete ? this.maxHp : Math.max(1, this.maxHp * 0.1);
    this.progress = complete ? 1 : 0;
    this.buildTime = this.def.time || 1;
    this.queue = []; this.rally = null; this.cooldowns = {}; this.attackTimer = 0;
    this.toggles = { convert: true };
    this.spawnTimer = 0; this.catalystTimer = 0;
    this.relocate = null; // {phase:'lift'|'fly'|'land', tx, ty, t}
    this.node = null;
    this.builders = 0;
    this.radius = Math.max(this.w, this.h) * TILE / 2;
  }
  get name() { return this.def.isBase ? this.faction.tiers[this.player.tier - 1].name : this.def.name; }
  get complete() { return this.progress >= 1; }
  get invisible() { return !!this.def.invisible; }
  stat(name) {
    if (name === 'armor') return this.def.armor + this.player.eff('structArmor', 'add');
    if (name === 'sight') return (this.def.sight || 6) * TILE;
    return 0;
  }
  towerDmg() {
    let d = this.def.tower.dmg;
    if (this.def.isBase && this.faction.id === 'tempest') d = [8, 12, 30][this.player.tier - 1];
    d *= this.player.eff('towerDmg', 'mul');
    if (this.game.playerBuff(this.player, 'solar_surge')) d *= 1.5;
    if (this.faction.id === 'tempest' && this.game.weather.storm) d *= 1.25;
    if (this.faction.affinity && this.game.map.layerAtWorld(this.faction.affinity, this.x, this.y) > 0.3 && this.def.tower.layerBonus) d *= this.def.tower.layerBonus;
    return d;
  }
  towerRange() {
    let r = this.def.tower.range;
    if (this.def.tower.blightRange && this.game.map.corruptionAtWorld(this.x, this.y) > 0.3) r += this.def.tower.blightRange;
    return r * TILE;
  }
  distTo(e) {
    if (e.kind === 'building') return dist(this.x, this.y, e.x, e.y) - this.radius - e.radius;
    return distToRect(e.x, e.y, this.tx * TILE, this.ty * TILE, this.w * TILE, this.h * TILE) - (e.radius || 0);
  }
}

class Corpse {
  constructor(game, owner, defId, x, y, flying) {
    this.id = uid(); this.kind = 'corpse'; this.game = game; this.owner = owner; this.defId = defId;
    this.x = x; this.y = y; this.t = CORPSE_LIFETIME; this.dead = false; this.flying = flying; this.radius = 8;
  }
}
