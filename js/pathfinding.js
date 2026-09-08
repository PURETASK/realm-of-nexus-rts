// A* pathfinding on the tile grid with line-of-sight smoothing
class MinHeap {
  constructor() { this.a = []; }
  push(n) { const a = this.a; a.push(n); let i = a.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (a[p].f <= a[i].f) break; [a[p], a[i]] = [a[i], a[p]]; i = p; } }
  pop() { const a = this.a; const top = a[0]; const last = a.pop(); if (a.length) { a[0] = last; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let m = i; if (l < a.length && a[l].f < a[m].f) m = l; if (r < a.length && a[r].f < a[m].f) m = r; if (m === i) break; [a[m], a[i]] = [a[i], a[m]]; i = m; } } return top; }
  get size() { return this.a.length; }
}

const Pathfinder = {
  // returns array of world-space waypoints (excluding start), or [] if unreachable
  find(map, sx, sy, tx, ty, flying) {
    const stx = clamp(Math.floor(sx / TILE), 0, MAP_W - 1), sty = clamp(Math.floor(sy / TILE), 0, MAP_H - 1);
    let gtx = clamp(Math.floor(tx / TILE), 0, MAP_W - 1), gty = clamp(Math.floor(ty / TILE), 0, MAP_H - 1);
    if (map.isBlocked(gtx, gty, flying)) { const nf = map.nearestFree(gtx, gty, flying); gtx = nf.tx; gty = nf.ty; }
    if (flying && !map.airBlocked.some(v => v)) {
      return [{ x: gtx * TILE + TILE / 2, y: gty * TILE + TILE / 2 }];
    }
    if (stx === gtx && sty === gty) return [{ x: gtx * TILE + TILE / 2, y: gty * TILE + TILE / 2 }];
    // If start tile is blocked (e.g. unit pushed into building), begin from nearest free tile
    let s0x = stx, s0y = sty;
    if (map.isBlocked(stx, sty, flying)) { const nf = map.nearestFree(stx, sty, flying); s0x = nf.tx; s0y = nf.ty; }

    const W = MAP_W, N = MAP_W * MAP_H;
    const g = new Float32Array(N).fill(Infinity);
    const came = new Int32Array(N).fill(-1);
    const closed = new Uint8Array(N);
    const heap = new MinHeap();
    const start = s0y * W + s0x, goal = gty * W + gtx;
    g[start] = 0;
    const h = (i) => { const x = i % W, y = (i / W) | 0; const dx = Math.abs(x - gtx), dy = Math.abs(y - gty); return Math.max(dx, dy) + 0.414 * Math.min(dx, dy); };
    heap.push({ i: start, f: h(start) });
    let found = false, expansions = 0;
    const dirs = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, 1.414], [-1, 1, 1.414], [1, -1, 1.414], [-1, -1, 1.414]];
    while (heap.size) {
      const cur = heap.pop();
      const i = cur.i;
      if (closed[i]) continue;
      closed[i] = 1;
      if (i === goal) { found = true; break; }
      if (++expansions > 5000) break;
      const x = i % W, y = (i / W) | 0;
      for (const [dx, dy, c] of dirs) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= MAP_H) continue;
        if (map.isBlocked(nx, ny, flying)) continue;
        if (dx && dy && (map.isBlocked(x + dx, y, flying) || map.isBlocked(x, y + dy, flying))) continue; // no corner cutting
        const ni = ny * W + nx;
        if (closed[ni]) continue;
        const ng = g[i] + c;
        if (ng < g[ni]) { g[ni] = ng; came[ni] = i; heap.push({ i: ni, f: ng + h(ni) }); }
      }
    }
    let end = goal;
    if (!found) {
      // pick the closed node nearest to goal
      let best = -1, bd = Infinity;
      for (let i = 0; i < N; i++) if (closed[i]) { const d = h(i); if (d < bd) { bd = d; best = i; } }
      if (best < 0) return [];
      end = best;
    }
    const tiles = [];
    for (let i = end; i !== -1 && i !== start; i = came[i]) tiles.push(i);
    tiles.reverse();
    // Smooth: skip waypoints reachable by straight line
    const pts = tiles.map(i => ({ x: (i % W) * TILE + TILE / 2, y: ((i / W) | 0) * TILE + TILE / 2 }));
    const out = [];
    let cx = sx, cy = sy, k = 0;
    while (k < pts.length) {
      let j = pts.length - 1;
      while (j > k && !this.lineFree(map, cx, cy, pts[j].x, pts[j].y, flying)) j--;
      out.push(pts[j]); cx = pts[j].x; cy = pts[j].y; k = j + 1;
    }
    return out;
  },

  lineFree(map, x0, y0, x1, y1, flying) {
    const steps = Math.ceil(dist(x0, y0, x1, y1) / (TILE / 3));
    for (let i = 0; i <= steps; i++) {
      const t = i / steps, x = lerp(x0, x1, t), y = lerp(y0, y1, t);
      // check with small margin for unit radius
      for (const [ox, oy] of [[0, 0], [8, 8], [-8, -8], [8, -8], [-8, 8]]) {
        if (map.isBlocked(Math.floor((x + ox) / TILE), Math.floor((y + oy) / TILE), flying)) return false;
      }
    }
    return true;
  },
};
