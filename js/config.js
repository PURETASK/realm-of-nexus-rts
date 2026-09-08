// Global configuration constants for Realm of Nexus RTS
const TILE = 32;
const MAP_W = 80;
const MAP_H = 60;
const WORLD_W = MAP_W * TILE;
const WORLD_H = MAP_H * TILE;

const MAX_SUPPLY = 150;
const CORPSE_LIFETIME = 20;      // seconds a corpse remains
const VISION_REFRESH = 0.2;      // seconds between fog recomputes
const CORRUPTION_DECAY = 0.004;  // per second, when no source nearby
const CORRUPTION_GROW = 0.12;    // per second inside source radius

const PLAYER_COLORS = ['#3fa9f5', '#ff5a3c'];

const DIFFICULTY = {
  easy:   { name: 'Easy',   incomeMul: 0.8, attackSupply: 30, attackGrowth: 4, buildDelay: 2.0, firstAttack: 420 },
  normal: { name: 'Normal', incomeMul: 1.0, attackSupply: 24, attackGrowth: 5, buildDelay: 1.0, firstAttack: 270 },
  hard:   { name: 'Hard',   incomeMul: 1.35, attackSupply: 18, attackGrowth: 6, buildDelay: 0.5, firstAttack: 150 },
};
