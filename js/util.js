// Utility helpers
let __uid = 1;
function uid() { return __uid++; }

function dist(ax, ay, bx, by) { const dx = ax - bx, dy = ay - by; return Math.sqrt(dx * dx + dy * dy); }
function dist2(ax, ay, bx, by) { const dx = ax - bx, dy = ay - by; return dx * dx + dy * dy; }
function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
function lerp(a, b, t) { return a + (b - a) * t; }
function rand(a, b) { return a + Math.random() * (b - a); }
function randInt(a, b) { return Math.floor(rand(a, b + 1)); }
function choice(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function angleTo(ax, ay, bx, by) { return Math.atan2(by - ay, bx - ax); }

function mulberry32(seed) {
  return function () {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function fmtTime(s) {
  s = Math.floor(s);
  const m = Math.floor(s / 60);
  return m + ':' + String(s % 60).padStart(2, '0');
}

function costStr(cost, faction) {
  if (!cost) return 'Free';
  const parts = [];
  const r = faction.resources;
  if (cost.p) parts.push(cost.p + ' ' + r.primary.short);
  if (cost.s) parts.push(cost.s + ' ' + r.secondary.short);
  if (cost.c) parts.push(cost.c + ' ' + r.catalyst.short);
  return parts.join(', ') || 'Free';
}

// Distance from a point to a rectangle (world px)
function distToRect(px, py, rx, ry, rw, rh) {
  const cx = clamp(px, rx, rx + rw), cy = clamp(py, ry, ry + rh);
  return dist(px, py, cx, cy);
}

function hexToRgba(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}
