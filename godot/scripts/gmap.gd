class_name GMap
extends RefCounted
## Tile map: terrain, resource nodes, terrain layers (blight / light / grove), pathfinding grids

var w = Cfg.MAP_W
var h = Cfg.MAP_H
var n = Cfg.MAP_W * Cfg.MAP_H
var terrain = PackedByteArray()
var blocked = PackedByteArray()
var air_blocked = PackedByteArray()
var layers = {}
var layer_src = {}
var nodes = []
var starts = [{"tx": 7, "ty": 49}, {"tx": 70, "ty": 8}]
var decor = []
var astar_ground = AStarGrid2D.new()
var astar_air = AStarGrid2D.new()
var any_air_blocked = false
var active = {}          # layer name -> {tile index: true} for tiles with any value or pending source
var layer_acc = 0.0      # seconds accumulated since the last layer step
var accept_sources = true
const LAYER_STEP = 0.1
var _next_id = 1

func _init(seed_value: int) -> void:
	terrain.resize(n); blocked.resize(n); air_blocked.resize(n)
	for name in Cfg.LAYERS:
		var a = PackedFloat32Array(); a.resize(n); a.fill(0.0)
		var s = PackedFloat32Array(); s.resize(n); s.fill(0.0)
		layers[name] = a; layer_src[name] = s; active[name] = {}
	for attempt in range(30):
		if generate(seed_value + attempt * 7919):
			break
	_setup_astar(astar_ground)
	_setup_astar(astar_air)
	for i in range(n):
		if terrain[i] == 1:
			astar_ground.set_point_solid(Vector2i(i % w, i / w), true)

func _setup_astar(a: AStarGrid2D) -> void:
	a.region = Rect2i(0, 0, w, h)
	a.cell_size = Vector2(Cfg.TILE, Cfg.TILE)
	a.offset = Vector2(Cfg.TILE / 2.0, Cfg.TILE / 2.0)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.jumping_enabled = true
	a.update()

func idx(tx: int, ty: int) -> int:
	return ty * w + tx

func in_bounds(tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < w and ty < h

func generate(seed_value: int) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	terrain.fill(0); blocked.fill(0); air_blocked.fill(0)
	for name in Cfg.LAYERS:
		var z: PackedFloat32Array = layers[name]; z.fill(0.0); layers[name] = z
	nodes = []; decor = []
	for x in range(w):
		terrain[idx(x, 0)] = 1; terrain[idx(x, h - 1)] = 1
	for y in range(h):
		terrain[idx(0, y)] = 1; terrain[idx(w - 1, y)] = 1
	for b in range(70):
		var x = rng.randi_range(0, w - 1)
		var y = rng.randi_range(0, h - 1)
		var seg_len = 3 + rng.randi_range(0, 8)
		for i in range(seg_len):
			if in_bounds(x, y) and not _clear(x, y):
				terrain[idx(x, y)] = 1
				if rng.randf() < 0.5 and in_bounds(x + 1, y) and not _clear(x + 1, y): terrain[idx(x + 1, y)] = 1
				if rng.randf() < 0.4 and in_bounds(x, y + 1) and not _clear(x, y + 1): terrain[idx(x, y + 1)] = 1
			var d = rng.randi_range(0, 3)
			x += [1, -1, 0, 0][d]; y += [0, 0, 1, -1][d]
	for i in range(260):
		decor.append({"x": rng.randf() * Cfg.WORLD_W, "y": rng.randf() * Cfg.WORLD_H, "t": 0 if rng.randf() < 0.7 else 1, "r": 2.0 + rng.randf() * 4.0})
	for i in range(n):
		blocked[i] = terrain[i]
	if not connected(starts[0]["tx"] - 1, starts[0]["ty"] - 1, starts[1]["tx"] - 1, starts[1]["ty"] - 1):
		return false
	for s in starts:
		var placed = 0; var tries = 0
		while placed < 3 and tries < 400:
			tries += 1
			var a = rng.randf() * TAU; var r = 6.0 + rng.randf() * 4.0
			var tx = roundi(s["tx"] + 1 + cos(a) * r); var ty = roundi(s["ty"] + 1 + sin(a) * r)
			if not in_bounds(tx, ty) or not in_bounds(tx + 1, ty + 1): continue
			if absi(tx - s["tx"]) < 4 and absi(ty - s["ty"]) < 4: continue
			if _place_node("primary", tx, ty, 1500.0): placed += 1
		placed = 0; tries = 0
		while placed < 1 and tries < 400:
			tries += 1
			var a = rng.randf() * TAU; var r = 7.0 + rng.randf() * 4.0
			var tx = roundi(s["tx"] + 1 + cos(a) * r); var ty = roundi(s["ty"] + 1 + sin(a) * r)
			if not in_bounds(tx, ty) or not in_bounds(tx + 1, ty + 1): continue
			if absi(tx - s["tx"]) < 4 and absi(ty - s["ty"]) < 4: continue
			if _place_node("secondary", tx, ty, 1e9): placed += 1
		if placed < 1: return false
	var mid = 0; var tries2 = 0
	while mid < 8 and tries2 < 3000:
		tries2 += 1
		var tx = 3 + rng.randi_range(0, w - 7); var ty = 3 + rng.randi_range(0, h - 7)
		var near_start = false
		for s in starts:
			if Cfg.dist(tx, ty, s["tx"], s["ty"]) < 18: near_start = true
		if near_start: continue
		if _place_node("primary" if mid < 5 else "secondary", tx, ty, 2500.0): mid += 1
	var prim = 0
	for nd in nodes:
		if nd["type"] == "primary": prim += 1
	return prim >= 9

func _clear(tx: int, ty: int) -> bool:
	for s in starts:
		if Cfg.dist(tx, ty, s["tx"] + 1, s["ty"] + 1) < 13: return true
	return false

func _place_node(type: String, tx: int, ty: int, amount: float) -> bool:
	if not area_free(tx, ty, 2, 2, false): return false
	for nd in nodes:
		if Cfg.dist(nd["tx"], nd["ty"], tx, ty) < 4: return false
	nodes.append({"id": _next_id, "type": type, "tx": tx, "ty": ty, "w": 2, "h": 2, "x": (tx + 1) * Cfg.TILE, "y": (ty + 1) * Cfg.TILE, "amount": amount, "max": amount, "building": null})
	_next_id += 1
	return true

func connected(ax: int, ay: int, bx: int, by: int) -> bool:
	var seen = PackedByteArray(); seen.resize(n)
	var q = [Vector2i(ax, ay)]; seen[idx(ax, ay)] = 1
	var head = 0
	while head < q.size():
		var p: Vector2i = q[head]; head += 1
		if p.x == bx and p.y == by: return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx = p.x + d.x; var ny = p.y + d.y
			if not in_bounds(nx, ny): continue
			var i = idx(nx, ny)
			if seen[i] == 1 or terrain[i] == 1: continue
			seen[i] = 1; q.append(Vector2i(nx, ny))
	return false

func area_free(tx: int, ty: int, aw: int, ah: int, ignore_nodes: bool) -> bool:
	for y in range(ty, ty + ah):
		for x in range(tx, tx + aw):
			if not in_bounds(x, y): return false
			if blocked[idx(x, y)] == 1: return false
	if not ignore_nodes:
		for nd in nodes:
			if tx < nd["tx"] + nd["w"] and tx + aw > nd["tx"] and ty < nd["ty"] + nd["h"] and ty + ah > nd["ty"]: return false
	return true

func node_under(tx: int, ty: int, aw: int, ah: int) -> Variant:
	for nd in nodes:
		if nd["tx"] == tx and nd["ty"] == ty and nd["w"] == aw and nd["h"] == ah: return nd
	return null

func set_blocked(tx: int, ty: int, aw: int, ah: int, val: bool, air: bool) -> void:
	for y in range(ty, ty + ah):
		for x in range(tx, tx + aw):
			if not in_bounds(x, y): continue
			var i = idx(x, y)
			blocked[i] = 1 if val else terrain[i]
			astar_ground.set_point_solid(Vector2i(x, y), blocked[i] == 1)
			if air:
				air_blocked[i] = 1 if val else 0
				astar_air.set_point_solid(Vector2i(x, y), val)
	if air:
		any_air_blocked = false
		for i in range(n):
			if air_blocked[i] == 1: any_air_blocked = true; break

func is_blocked(tx: int, ty: int, flying: bool) -> bool:
	if not in_bounds(tx, ty): return true
	var i = idx(tx, ty)
	return air_blocked[i] == 1 if flying else blocked[i] == 1

func corruption_at_world(x: float, y: float) -> float:
	return layer_at_world("blight", x, y)

func layer_at_world(name: String, x: float, y: float) -> float:
	var tx = int(x / Cfg.TILE); var ty = int(y / Cfg.TILE)
	if not in_bounds(tx, ty): return 0.0
	return layers[name][idx(tx, ty)]

## Called once per game tick before buildings/units run; sources are only accepted on ticks where the layers step
func begin_tick(dt: float) -> void:
	layer_acc += dt
	accept_sources = layer_acc >= LAYER_STEP

func add_layer_source(name: String, x: float, y: float, radius: float, strength: float) -> void:
	if not accept_sources: return
	var src: PackedFloat32Array = layer_src[name]; var act: Dictionary = active[name]
	var cx = int(x / Cfg.TILE); var cy = int(y / Cfg.TILE); var r = ceili(radius)
	for ty in range(cy - r, cy + r + 1):
		for tx in range(cx - r, cx + r + 1):
			if not in_bounds(tx, ty): continue
			var d = Cfg.dist(tx + 0.5, ty + 0.5, x / Cfg.TILE, y / Cfg.TILE)
			if d > radius: continue
			var i = idx(tx, ty)
			var s = strength * (1.0 - d / (radius + 1.0))
			if s > src[i]: src[i] = s; act[i] = true
	layer_src[name] = src

## Steps the terrain layers every LAYER_STEP seconds, touching only tiles that are active
func update_layers(_dt: float) -> void:
	if not accept_sources: return
	var step = layer_acc; layer_acc = 0.0; accept_sources = false
	var light: PackedFloat32Array = layers["light"]
	for name in Cfg.LAYERS:
		var c: PackedFloat32Array = layers[name]
		var s: PackedFloat32Array = layer_src[name]
		var act: Dictionary = active[name]
		for i in act.keys():
			if s[i] > 0.0:
				c[i] = minf(1.0, c[i] + Cfg.CORRUPTION_GROW * s[i] * step); s[i] = 0.0
			elif c[i] > 0.0:
				var mul = 8.0 if (name == "blight" and light[i] > 0.3) else 1.0
				c[i] = maxf(0.0, c[i] - Cfg.CORRUPTION_DECAY * step * mul)
			else: act.erase(i)
		layers[name] = c
		layer_src[name] = s

func nearest_free(tx: int, ty: int, flying: bool) -> Vector2i:
	if not is_blocked(tx, ty, flying): return Vector2i(tx, ty)
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r: continue
				if not is_blocked(tx + dx, ty + dy, flying): return Vector2i(tx + dx, ty + dy)
	return Vector2i(tx, ty)

## Returns an Array of Vector2 waypoints (world coords, excluding start)
func find_path(sx: float, sy: float, tx: float, ty: float, flying: bool) -> Array:
	var stx = clampi(int(sx / Cfg.TILE), 0, w - 1); var sty = clampi(int(sy / Cfg.TILE), 0, h - 1)
	var gtx = clampi(int(tx / Cfg.TILE), 0, w - 1); var gty = clampi(int(ty / Cfg.TILE), 0, h - 1)
	if is_blocked(gtx, gty, flying):
		var nf = nearest_free(gtx, gty, flying); gtx = nf.x; gty = nf.y
	var goal = Vector2(gtx * Cfg.TILE + Cfg.TILE / 2.0, gty * Cfg.TILE + Cfg.TILE / 2.0)
	if flying and not any_air_blocked:
		return [goal]
	if is_blocked(stx, sty, flying):
		var nf2 = nearest_free(stx, sty, flying); stx = nf2.x; sty = nf2.y
	if stx == gtx and sty == gty:
		return [goal]
	var a = astar_air if flying else astar_ground
	var pts = a.get_point_path(Vector2i(stx, sty), Vector2i(gtx, gty))
	if pts.size() == 0:
		return [goal]
	var out = []
	for i in range(1, pts.size()):
		out.append(pts[i])
	if out.is_empty():
		out.append(goal)
	return out
