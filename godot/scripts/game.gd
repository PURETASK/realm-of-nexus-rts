class_name Game
extends RefCounted
## Core simulation (mirrors js/game.js + js/combat.js + ward processing)

var opts: Dictionary = {}
var map: GMap
var players = []
var human = 0
var entities = []
var corpses = []
var effects = []
var projectiles = []
var time = 0.0
var paused = false
var over = false
var ended = false
var winner = -1
var weather = {"storm": null, "cloud": []}
var vision_timer = 0.0
var messages = []
var selection = []
var groups = {}
var difficulty: Dictionary = {}
var ai = null
var wards = []
var respawns = []
var clarity = null
var tip_index = 1
var last_attack_msg = -100.0
var attack_ping = null
var path_calls = 0
var camera = Vector2.ZERO
var _id = 1

func next_id() -> int:
	_id += 1
	return _id

func _init(o: Dictionary) -> void:
	opts = o
	GData.load_all()
	map = GMap.new(int(o.get("seed", randi() % 1000000000)))
	players = [GPlayer.new(0, o["playerFaction"], false, Cfg.PLAYER_COLORS[0]), GPlayer.new(1, o["aiFaction"], true, Cfg.PLAYER_COLORS[1])]
	difficulty = GData.difficulty[o.get("difficulty", "normal")]
	players[1].income_mul = float(difficulty["incomeMul"])
	setup()
	ai = AIController.new(self, 1)

func setup() -> void:
	for i in range(2):
		var p: GPlayer = players[i]
		var s: Dictionary = map.starts[i]
		var base = place_building(i, p.faction["base"], s["tx"], s["ty"], true)
		var wx = base.x; var wy = base.y + 2.5 * Cfg.TILE
		var n_workers = 3 if p.faction_id == "tempest" else 5
		for k in range(n_workers):
			var wk = spawn_unit(i, p.faction["worker"], wx + (k - n_workers / 2.0) * 26.0, wy + 10.0)
			if p.faction.get("gathers", false):
				var nd = nearest_node(wk, "primary")
				if nd != null: order_gather([wk], nd)
		var aff = p.faction.get("affinity", null)
		if aff != null: map.add_layer_source(aff, base.x, base.y, 5.0, 3.0)
	for k in range(40): map.update_layers(1.0)
	update_supply(0); update_supply(1)
	camera = Vector2(map.starts[0]["tx"] * Cfg.TILE - 300, map.starts[0]["ty"] * Cfg.TILE - 250)
	var f: Dictionary = players[0].faction
	msg("You command the " + f["name"] + ". " + f["tips"][0], "good")

# ---------- helpers ----------
func abyss_tier() -> int:
	for p in players:
		if p.faction_id == "abyss": return p.tier
	return 0

func msg(text: String, cls := "") -> void:
	messages.append({"text": text, "cls": cls, "t": 9.0})
	if messages.size() > 6: messages.pop_front()

func add_effect(e: Dictionary) -> void:
	if not e.has("t"): e["t"] = 0.5
	e["max"] = e["t"]
	effects.append(e)

func units(owner := -1) -> Array:
	return entities.filter(func(e): return e.kind == "unit" and not e.dead and (owner < 0 or e.owner == owner))

func buildings(owner := -1) -> Array:
	return entities.filter(func(e): return e.kind == "building" and not e.dead and (owner < 0 or e.owner == owner))

func base_of(owner: int) -> Variant:
	for e in entities:
		if e.kind == "building" and not e.dead and e.owner == owner and e.def.get("isBase", false): return e
	return null

func heroes(owner: int) -> Array:
	return entities.filter(func(e): return e.kind == "unit" and not e.dead and e.owner == owner and e.is_hero)

func nearby(x: float, y: float, r: float, filter: Callable) -> Array:
	var _t = Time.get_ticks_usec() if profiling else 0
	var out = _nearby_impl(x, y, r, filter)
	_pt("  (nearby)", _t)
	return out

func _nearby_impl(x: float, y: float, r: float, filter: Callable) -> Array:
	var out = []
	var has_filter = filter.is_valid()
	var gx0 = floori((x - r) / GRID_CELL) - 1; var gx1 = floori((x + r) / GRID_CELL) + 1
	var gy0 = floori((y - r) / GRID_CELL) - 1; var gy1 = floori((y + r) / GRID_CELL) + 1
	var seen = {}
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			var cell = _grid.get(Vector2i(gx, gy))
			if cell == null: continue
			for e in cell:
				if e.dead: continue
				var d: float
				if e.kind == "building":
					if seen.has(e): continue
					seen[e] = true
					d = Cfg.dist_to_rect(x, y, e.tx * Cfg.TILE, e.ty * Cfg.TILE, e.w * Cfg.TILE, e.h * Cfg.TILE)
				else: d = Cfg.dist(x, y, e.x, e.y)
				if d > r: continue
				if has_filter and not filter.call(e): continue
				out.append(e)
	return out

func _grid_add(e) -> void:
	if e.kind == "building":
		var x0 = floori(e.tx * Cfg.TILE / GRID_CELL); var y0 = floori(e.ty * Cfg.TILE / GRID_CELL)
		var x1 = floori((e.tx + e.w) * Cfg.TILE / GRID_CELL); var y1 = floori((e.ty + e.h) * Cfg.TILE / GRID_CELL)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var k = Vector2i(gx, gy)
				if _grid.has(k): _grid[k].append(e)
				else: _grid[k] = [e]
	else:
		var k = Vector2i(floori(e.x / GRID_CELL), floori(e.y / GRID_CELL))
		if _grid.has(k): _grid[k].append(e)
		else: _grid[k] = [e]

func emit(type: String, x: float, y: float, owner: int, extra := {}) -> void:
	if events.size() > 200: return
	var ev = {"type": type, "x": x, "y": y, "owner": owner}
	for k in extra: ev[k] = extra[k]
	events.append(ev)

func _log_produced(owner: int, kind: String, id: String) -> void:
	var d: Dictionary = produced[owner][kind]
	d[id] = d.get(id, 0) + 1

func _build_grid() -> void:
	_grid.clear()
	for e in entities:
		if not e.dead: _grid_add(e)

func enemies_near(owner: int, x: float, y: float, r: float, include_buildings := false) -> Array:
	return nearby(x, y, r, func(e): return e.owner != owner and e.owner >= 0 and (include_buildings or e.kind == "unit") and not (e.kind == "building" and e.def.get("invisible", false) and not can_see(owner, e)))

func allies_near(owner: int, x: float, y: float, r: float, include_buildings := false) -> Array:
	return nearby(x, y, r, func(e): return e.owner == owner and (include_buildings or e.kind == "unit"))

func can_see(viewer: int, e) -> bool:
	if viewer == e.owner: return true
	var p: GPlayer = players[viewer]
	if p.is_ai: return (not e.invisible()) or detected(viewer, e)
	var tx = int(e.x / Cfg.TILE); var ty = int(e.y / Cfg.TILE)
	if not map.in_bounds(tx, ty): return false
	var v = p.vision[map.idx(tx, ty)]
	if v != 2: return e.kind == "building" and v == 1 and not e.invisible()
	if e.invisible(): return detected(viewer, e)
	return true

func detected(viewer: int, e) -> bool:
	var vf: Dictionary = players[viewer].faction
	if vf.get("affinity", null) == "light" and map.layer_at_world("light", e.x, e.y) > 0.3: return true
	for d in entities:
		if d.dead or d.owner != viewer: continue
		if d.kind == "building" and d.def.get("detector", false) and d.complete() and Cfg.dist(d.x, d.y, e.x, e.y) < d.stat("sight"): return true
	for wd in wards:
		if wd["owner"] == viewer and (wd["kind"] == "zephyr" or wd["kind"] == "corruption") and Cfg.dist(wd["x"], wd["y"], e.x, e.y) < wd["r"]: return true
	return false

# ---------- spawning ----------
func spawn_unit(owner: int, def_id: String, x: float, y: float) -> Unit:
	var u = Unit.new(self, owner, def_id, x, y)
	if not u.flying and map.is_blocked(u.tile_x(), u.tile_y(), false):
		var nf = map.nearest_free(u.tile_x(), u.tile_y(), false)
		u.x = nf.x * Cfg.TILE + Cfg.TILE / 2.0; u.y = nf.y * Cfg.TILE + Cfg.TILE / 2.0
	entities.append(u); _grid_add(u)
	_log_produced(owner, "units", def_id)
	u.scan_timer = randf() * 0.2
	update_supply(owner)
	return u

func place_building(owner: int, def_id: String, tx: int, ty: int, complete: bool) -> Building:
	var b = Building.new(self, owner, def_id, tx, ty, complete)
	map.set_blocked(tx, ty, b.w, b.h, true, b.def.get("blocksAir", false))
	var nd = map.node_under(tx, ty, b.w, b.h)
	if nd != null:
		nd["building"] = b; b.node = nd
	entities.append(b); _grid_add(b)
	_log_produced(owner, "buildings", def_id)
	if complete: update_supply(owner)
	return b

func can_place(owner: int, def_id: String, tx: int, ty: int) -> bool:
	var p: GPlayer = players[owner]
	if not p.faction["buildings"].has(def_id): return false
	var d: Dictionary = p.faction["buildings"][def_id]
	var bw = int(d.get("w", 1)); var bh = int(d.get("h", 1))
	if d.has("needsNode"):
		var nd = map.node_under(tx, ty, bw, bh)
		if nd == null or nd["type"] != d["needsNode"] or nd["building"] != null: return false
		for y in range(ty, ty + bh):
			for x in range(tx, tx + bw):
				if map.is_blocked(x, y, false): return false
		return true
	return map.area_free(tx, ty, bw, bh, false)

func update_supply(owner: int) -> void:
	var p: GPlayer = players[owner]
	var used = 0
	var cap = int(p.faction["tiers"][p.tier - 1].get("supply", 30))
	for e in entities:
		if e.dead or e.owner != owner: continue
		if e.kind == "unit": used += int(e.def.get("supply", 0))
		elif e.complete() and e.def.get("supply", 0) > 0: cap += int(e.def["supply"])
	p.supply_used = used; p.supply_cap = mini(Cfg.MAX_SUPPLY, cap)

# ---------- production ----------
func can_queue(b: Building, item: Dictionary) -> Dictionary:
	var p = b.player(); var f = b.faction()
	if not b.complete() or b.relocate != null: return {"ok": false, "why": "Building not ready"}
	var t: String = item["type"]
	if t == "unit" or t == "hero":
		var d = GData.unit_def(f, item["id"])
		if d.is_empty(): return {"ok": false, "why": "Unknown unit"}
		if t == "unit" and d.get("tier", 1) > p.tier: return {"ok": false, "why": "Requires Tier " + str(int(d["tier"]))}
		if t == "hero":
			var count = heroes(b.owner).size()
			for bb in buildings(b.owner):
				for q in bb.queue:
					if q["type"] == "hero": count += 1
			if count >= p.tier: return {"ok": false, "why": "Tier %d allows %d hero%s" % [p.tier, p.tier, "es" if p.tier > 1 else ""]}
			for hh in heroes(b.owner):
				if hh.def_id == item["id"]: return {"ok": false, "why": "Already summoned"}
			for bb in buildings(b.owner):
				for q in bb.queue:
					if q["id"] == item["id"]: return {"ok": false, "why": "Already summoned"}
			if p.hero_cooldowns.get(item["id"], 0.0) > 0.0: return {"ok": false, "why": "Returns in " + str(ceili(p.hero_cooldowns[item["id"]])) + "s"}
		if d.get("unique", false):
			for uu in units(b.owner):
				if uu.def_id == item["id"]: return {"ok": false, "why": "Only one may exist"}
			for q in b.queue:
				if q["id"] == item["id"]: return {"ok": false, "why": "Only one may exist"}
		if d.get("supply", 0) > 0 and p.supply_used + int(d["supply"]) > p.supply_cap: return {"ok": false, "why": "Not enough supply"}
		if not p.can_afford(d.get("cost", {})): return {"ok": false, "why": "Not enough resources"}
		return {"ok": true, "cost": d.get("cost", {}), "time": float(d.get("time", 10))}
	if t == "research":
		var r: Dictionary = f["research"][item["id"]]
		if p.has_research(item["id"]): return {"ok": false, "why": "Already researched"}
		for bb in buildings(b.owner):
			for q in bb.queue:
				if q["type"] == "research" and q["id"] == item["id"]: return {"ok": false, "why": "In progress"}
		if r.get("tier", 1) > p.tier: return {"ok": false, "why": "Requires Tier " + str(int(r["tier"]))}
		if not p.can_afford(r.get("cost", {})): return {"ok": false, "why": "Not enough resources"}
		return {"ok": true, "cost": r.get("cost", {}), "time": float(r.get("time", 30))}
	if t == "tier":
		if p.tier >= 3: return {"ok": false, "why": "Max tier"}
		var tdef: Dictionary = f["tiers"][p.tier]
		for q in b.queue:
			if q["type"] == "tier": return {"ok": false, "why": "In progress"}
		var has_req = false
		for bb in buildings(b.owner):
			if bb.def_id == tdef.get("requires", "") and bb.complete(): has_req = true
		if not has_req: return {"ok": false, "why": "Requires " + f["buildings"][tdef["requires"]]["name"]}
		if not p.can_afford(tdef.get("cost", {})): return {"ok": false, "why": "Not enough resources"}
		return {"ok": true, "cost": tdef.get("cost", {}), "time": float(tdef.get("time", 60))}
	return {"ok": false, "why": "?"}

func enqueue(b: Building, item: Dictionary) -> bool:
	var c = can_queue(b, item)
	if not c["ok"]:
		if b.owner == human: msg(c["why"], "warn")
		return false
	if b.queue.size() >= 6: return false
	b.player().pay(c["cost"])
	b.queue.append({"type": item["type"], "id": item.get("id", ""), "time": c["time"], "elapsed": 0.0, "cost": c["cost"]})
	return true

func dequeue(b: Building, i: int) -> void:
	if i < 0 or i >= b.queue.size(): return
	b.player().refund(b.queue[i]["cost"]); b.queue.remove_at(i)

func finish_queue_item(b: Building, q: Dictionary) -> void:
	var p = b.player(); var f = b.faction()
	if q["type"] == "unit" or q["type"] == "hero":
		var sp = spawn_point(b)
		var u = spawn_unit(b.owner, q["id"], sp.x, sp.y)
		emit("ready", b.x, b.y, b.owner, {"what": q["type"]})
		if b.rally != null: order_move([u], b.rally.x, b.rally.y, false)
		elif u.is_worker() and f.get("gathers", false):
			var nd = nearest_node(u, "primary")
			if nd != null: order_gather([u], nd)
		if q["type"] == "hero" and b.owner == human:
			msg(u.name() + " has answered the call.", "good")
			if tip_index < f["tips"].size(): msg(f["tips"][tip_index]); tip_index += 1
	elif q["type"] == "research":
		p.research[q["id"]] = true; _log_produced(b.owner, "research", q["id"]); emit("ready", b.x, b.y, b.owner, {"what": "research"})
		if b.owner == human: msg("Research complete: " + f["research"][q["id"]]["name"], "good")
	elif q["type"] == "tier":
		p.tier += 1
		var tdef: Dictionary = f["tiers"][p.tier - 1]
		b.max_hp = float(tdef["hp"]); b.hp = minf(b.max_hp, b.hp + 600.0)
		update_supply(b.owner); emit("tier", b.x, b.y, b.owner)
		msg(("The enemy" if p.is_ai else "You") + " ascended to " + tdef["name"] + "!", "warn" if p.is_ai else "good")
		if b.owner == human and tip_index < f["tips"].size(): msg(f["tips"][tip_index]); tip_index += 1

func spawn_point(b: Building) -> Vector2:
	var cands = []
	for y in range(b.ty - 1, b.ty + b.h + 1):
		for x in range(b.tx - 1, b.tx + b.w + 1):
			if y >= b.ty and y < b.ty + b.h and x >= b.tx and x < b.tx + b.w: continue
			if not map.is_blocked(x, y, false): cands.append(Vector2(x * Cfg.TILE + Cfg.TILE / 2.0, y * Cfg.TILE + Cfg.TILE / 2.0))
	if cands.is_empty(): return Vector2(b.x, b.y + (b.h / 2.0 + 1) * Cfg.TILE)
	var ref: Vector2 = b.rally if b.rally != null else Vector2(b.x, b.y + 999.0)
	cands.sort_custom(func(a, c): return a.distance_squared_to(ref) < c.distance_squared_to(ref))
	return cands[0]

func nearest_node(u, type: String):
	var best = null; var bd = INF
	for nd in map.nodes:
		if nd["type"] != type or nd["amount"] <= 0: continue
		if type == "primary" and nd["building"] != null and nd["building"].owner != u.owner: continue
		var d = Cfg.dist(u.x, u.y, nd["x"], nd["y"])
		if d < bd: bd = d; best = nd
	return best

func nearest_dropoff(u):
	var best = null; var bd = INF
	for b in entities:
		if b.dead or b.kind != "building" or b.owner != u.owner or not b.def.get("dropoff", false) or not b.complete(): continue
		var d = Cfg.dist(u.x, u.y, b.x, b.y)
		if d < bd: bd = d; best = b
	return best

# ---------- orders ----------
func clear_order(u: Unit) -> void:
	u.order = {"type": "idle"}; u.path = []; u.target = null; u.build_task = null; u.hold_pos = false; u.pending_path = null

func set_path(u: Unit, x: float, y: float) -> void:
	if path_calls >= 14:
		u.pending_path = Vector2(x, y); u.path = []; u.path_target = Vector2(x, y); return
	path_calls += 1
	u.pending_path = null
	u.path = map.find_path(u.x, u.y, x, y, u.flying)
	u.path_target = Vector2(x, y)

func order_move(us: Array, x: float, y: float, attack_move: bool) -> void:
	var n = us.size(); var i = 0
	for u in us:
		if u.kind != "unit" or u.dead: continue
		var ox = 0.0; var oy = 0.0
		if n > 1:
			var ring = floorf(sqrt(i)); var ang = i * 2.399
			ox = cos(ang) * ring * 26.0; oy = sin(ang) * ring * 26.0
		i += 1
		clear_order(u)
		u.order = {"type": "attackmove" if attack_move else "move", "x": x + ox, "y": y + oy}
		set_path(u, x + ox, y + oy)

func order_attack(us: Array, t) -> void:
	for u in us:
		if u.kind != "unit" or u.dead: continue
		if not u.can_attack(t):
			order_move([u], t.x, t.y, true); continue
		clear_order(u)
		u.order = {"type": "attack", "target": t}
		u.target = t

func order_stop(us: Array) -> void:
	for u in us:
		if u.kind == "unit": clear_order(u)

func order_hold(us: Array) -> void:
	for u in us:
		if u.kind == "unit":
			clear_order(u); u.hold_pos = true; u.order = {"type": "hold"}

func order_gather(us: Array, nd: Dictionary) -> void:
	for u in us:
		if u.kind != "unit" or not u.is_worker() or not u.faction().get("gathers", false): continue
		clear_order(u)
		u.order = {"type": "gather"}
		u.gather["node"] = nd; u.gather["phase"] = "toDrop" if u.gather["carrying"] > 0 else "toNode"
		set_path(u, nd["x"], nd["y"])

func order_build(us: Array, def_id: String, tx: int, ty: int) -> Variant:
	var workers = us.filter(func(u): return u.kind == "unit" and u.is_worker() and not u.dead)
	if workers.is_empty(): return null
	var p: GPlayer = workers[0].player(); var d: Dictionary = p.faction["buildings"][def_id]
	if not can_place(workers[0].owner, def_id, tx, ty):
		if p.index == human: msg("Cannot build there", "warn")
		return null
	if d.get("tier", 1) > p.tier:
		if p.index == human: msg("Requires Tier " + str(int(d["tier"])), "warn")
		return null
	if not p.can_afford(d.get("cost", {})):
		if p.index == human: msg("Not enough resources", "warn")
		return null
	p.pay(d.get("cost", {}))
	var b = place_building(workers[0].owner, def_id, tx, ty, false)
	for u in units():
		if u.flying: continue
		if u.tile_x() >= tx and u.tile_x() < tx + b.w and u.tile_y() >= ty and u.tile_y() < ty + b.h:
			var nf = map.nearest_free(u.tile_x(), u.tile_y(), false)
			u.x = nf.x * Cfg.TILE + Cfg.TILE / 2.0; u.y = nf.y * Cfg.TILE + Cfg.TILE / 2.0
	for u in workers:
		clear_order(u)
		u.order = {"type": "build", "building": b}
		u.build_task = b
		set_path(u, b.x, b.y)
	return b

func order_relocate(b: Building, tx: int, ty: int) -> bool:
	if not b.def.get("abilities", []).has("relocate") or b.relocate != null: return false
	if b.cooldowns.get("relocate", 0.0) > 0.0:
		if b.owner == human: msg("Relocate on cooldown", "warn")
		return false
	map.set_blocked(b.tx, b.ty, b.w, b.h, false, false)
	var ok = map.area_free(tx, ty, b.w, b.h, false)
	map.set_blocked(b.tx, b.ty, b.w, b.h, true, false)
	if not ok:
		if b.owner == human: msg("Cannot land there", "warn")
		return false
	b.relocate = {"phase": "lift", "tx": tx, "ty": ty, "t": 0.0, "toX": (tx + b.w / 2.0) * Cfg.TILE, "toY": (ty + b.h / 2.0) * Cfg.TILE}
	for q in b.queue: b.player().refund(q["cost"])
	b.queue = []
	map.set_blocked(b.tx, b.ty, b.w, b.h, false, false)
	add_effect({"type": "ring", "x": b.x, "y": b.y, "r": 60.0, "color": "#8fd3ff", "t": 1.0})
	return true

# ---------- main update ----------
var profiling = false
var prof = {}
var frame = 0
var events = []      # sound / feel events for the presentation layer: {type, x, y, owner, ...}
var produced = [{"units": {}, "buildings": {}, "research": {}}, {"units": {}, "buildings": {}, "research": {}}]  # per-owner production log (balance tooling)
var _grid = {}          # spatial hash: Vector2i cell -> Array of live entities, rebuilt every tick
const GRID_CELL = 128.0
func _pt(name: String, t0: int) -> int:
	if not profiling: return 0
	var now = Time.get_ticks_usec()
	prof[name] = prof.get(name, 0) + (now - t0)
	return now

func update(dt: float) -> void:
	if paused or over: return
	time += dt
	path_calls = 0
	var _t = Time.get_ticks_usec() if profiling else 0
	frame += 1
	map.begin_tick(dt)
	_build_grid()
	for p in players: p.lyrian = false
	for e in entities:
		if e.kind == "unit" and not e.dead and e.def_id == "lyrian": players[e.owner].lyrian = true
	if weather["storm"] != null:
		weather["storm"]["until"] -= dt
		if weather["storm"]["until"] <= 0.0:
			weather["storm"] = null; msg("The storm passes.")
	var clouds = []
	for c in weather["cloud"]:
		c["t"] -= dt
		if c["t"] > 0.0: clouds.append(c)
	weather["cloud"] = clouds
	_t = _pt("weather", _t)
	for b in entities.duplicate():
		if b.kind == "building" and not b.dead: update_building(b, dt)
	_t = _pt("buildings", _t)
	for u in entities.duplicate():
		if u.kind == "unit" and not u.dead: update_unit(u, dt)
	_t = _pt("units", _t)
	separate_units()
	_t = _pt("separate", _t)
	update_projectiles(dt)
	update_corpses(dt)
	update_mines()
	_t = _pt("proj_corpse_mines", _t)
	map.update_layers(dt)
	_t = _pt("layers", _t)
	var keep = []
	for r in respawns:
		r["t"] -= dt
		if r["t"] <= 0.0:
			var u = spawn_unit(r["owner"], r["defId"], r["x"], r["y"]); u.reborn = true; u.hp = u.max_hp * 0.5
			add_effect({"type": "burst", "x": r["x"], "y": r["y"], "r": 40.0, "color": "#ffb347", "t": 0.8})
		else: keep.append(r)
	respawns = keep
	for e in effects: e["t"] -= dt
	effects = effects.filter(func(e): return e["t"] > 0.0)
	for m in messages: m["t"] -= dt
	messages = messages.filter(func(m): return m["t"] > 0.0)
	for p in players:
		for k in p.hero_cooldowns.keys():
			if p.hero_cooldowns[k] > 0.0: p.hero_cooldowns[k] -= dt
		var rv = []
		for r in p.reveal:
			r["t"] -= dt
			if r["t"] > 0.0: rv.append(r)
		p.reveal = rv
		for k in p.buffs.keys(): p.buffs[k] -= dt
	_t = _pt("timers", _t)
	var any_dead = false
	for e in entities:
		if e.dead: any_dead = true; break
	if any_dead:
		entities = entities.filter(func(e): return not e.dead)
		selection = selection.filter(func(e): return not e.dead)
		for k in groups.keys(): groups[k] = groups[k].filter(func(e): return not e.dead)
	_t = _pt("dead_filter", _t)
	vision_timer -= dt
	if vision_timer <= 0.0:
		vision_timer = Cfg.VISION_REFRESH; compute_vision(human)
	_t = _pt("vision", _t)
	update_wards(dt)
	_t = _pt("wards", _t)
	if ai != null: ai.update(dt)
	_t = _pt("ai", _t)
	for p in players:
		if p.defeated: continue
		var alive = false
		for e in entities:
			if e.kind == "building" and not e.dead and e.owner == p.index: alive = true; break
		if not alive: p.defeated = true
	_t = _pt("defeat_check", _t)
	for p in players:
		if p.defeated:
			over = true
			for q in players:
				if not q.defeated: winner = q.index
			break

func player_buff(p: GPlayer, id: String) -> bool:
	return p.buffs.get(id, 0.0) > 0.0

func add_player_buff(p: GPlayer, id: String, dur: float) -> void:
	p.buffs[id] = maxf(p.buffs.get(id, 0.0), dur)

func update_building(b: Building, dt: float) -> void:
	var p = b.player(); var f = b.faction(); var fid = b.faction_id()
	for k in b.cooldowns.keys():
		if b.cooldowns[k] > 0.0: b.cooldowns[k] -= dt
	if b.dark_pact > 0.0: b.dark_pact -= dt
	if b.flash > 0.0: b.flash -= dt
	if not b.complete():
		if b.builders > 0 or b.def.get("grows", false):
			var rate = (mini(b.builders, 3) * (0.7 if b.builders > 1 else 1.0)) if b.builders > 0 else 0.45
			b.progress = minf(1.0, b.progress + dt / b.build_time * rate)
			b.hp = minf(b.max_hp, b.hp + b.max_hp * 0.9 * dt / b.build_time)
			if b.complete():
				b.hp = b.max_hp; update_supply(b.owner); emit("build_done", b.x, b.y, b.owner)
				if b.owner == human: msg(b.name() + " complete.")
		b.builders = 0
		return
	if b.relocate != null:
		update_relocate(b, dt); return
	var tdef: Dictionary = f["tiers"][p.tier - 1]
	if b.def.has("income") or b.def.get("isBase", false):
		var inc: Dictionary = b.def.get("income", {}).duplicate()
		if b.def.get("isBase", false) and tdef.has("income"): inc["p"] = float(inc.get("p", 0)) + float(tdef["income"])
		var mul = p.income_mul * p.eff("income", "mul")
		if p.lyrian: mul *= 1.1
		if player_buff(p, "trade_winds"): mul *= 1.5
		if player_buff(p, "prosperity"): mul *= 1.4
		if inc.get("p", 0) > 0:
			var amt = float(inc["p"]) * mul * dt
			if b.node != null:
				if b.node["amount"] <= 0: amt = 0.0
				else:
					amt = minf(amt, b.node["amount"]); b.node["amount"] -= amt
			p.res["p"] += amt; p.stats["p"] += amt
		if inc.get("s", 0) > 0:
			var amt2 = float(inc["s"]) * mul * dt
			if weather["storm"] != null and b.node != null: amt2 *= 2.0
			p.res["s"] += amt2; p.stats["s"] += amt2
	if b.def.has("converter") and b.toggles["convert"]:
		var c: Dictionary = b.def["converter"]
		var take = minf(p.res[c["from"]], float(c["rate"]) * dt)
		if take > 0.0:
			p.res[c["from"]] -= take; p.res[c["to"]] += take * float(c["ratio"])
	if b.def.has("catalystGen") and p.res["c"] < 1.0:
		b.catalyst_timer += dt
		if b.catalyst_timer >= float(b.def["catalystGen"]["every"]):
			b.catalyst_timer = 0.0; p.res["c"] += 1.0
			msg(("Enemy " if p.is_ai else "A ") + f["resources"]["catalyst"]["name"] + " has formed.", "warn" if p.is_ai else "good")
	if b.def.get("isBase", false) and fid == "abyss" and p.tier >= 3 and p.res["c"] < 1.0:
		b.catalyst_timer += dt
		if b.catalyst_timer >= 150.0:
			b.catalyst_timer = 0.0; p.res["c"] += 1.0
			msg(("Enemy" if p.is_ai else "An") + " Oblivion Shard has crystallized.", "warn" if p.is_ai else "good")
	if b.def.has("spawner"):
		b.spawn_timer += dt
		if b.spawn_timer >= float(b.def["spawner"]["every"]) and p.supply_used < p.supply_cap:
			b.spawn_timer = 0.0; var sp = spawn_point(b); spawn_unit(b.owner, b.def["spawner"]["unit"], sp.x, sp.y)
	var aff = f.get("affinity", null)
	var lg = p.eff("layerGrow", "mul")
	if b.def.get("isBase", false) and aff != null: map.add_layer_source(aff, b.x, b.y, float(tdef.get("terrain", 5)), 2.0 * lg)
	elif b.def.has("corrupt"): map.add_layer_source("blight", b.x, b.y, float(b.def["corrupt"]), 1.5 * lg)
	elif b.def.has("light"): map.add_layer_source("light", b.x, b.y, float(b.def["light"]), 1.5 * lg)
	elif b.def.has("grow"): map.add_layer_source("grove", b.x, b.y, float(b.def["grow"]), 1.5 * lg)
	if not b.queue.is_empty():
		var q: Dictionary = b.queue[0]
		var speed = 1.0
		if b.dark_pact > 0.0: speed = 2.5
		if player_buff(p, "trade_winds"): speed *= 1.5
		if player_buff(p, "prosperity"): speed *= 1.3
		q["elapsed"] += dt * speed
		if q["elapsed"] >= q["time"]:
			b.queue.pop_front()
			finish_queue_item(b, q)
	if (b.def.has("tower") and b.def["tower"].get("dmg", 0) > 0) or (b.def.get("isBase", false) and fid == "tempest"):
		update_tower(b, dt)
	if b.def.has("aura"): apply_building_aura(b, dt)

func update_relocate(b: Building, dt: float) -> void:
	var r: Dictionary = b.relocate
	r["t"] += dt
	if r["phase"] == "lift":
		if r["t"] > 2.0: r["phase"] = "fly"; r["t"] = 0.0
		return
	if r["phase"] == "fly":
		var sp = 2.2 * Cfg.TILE * dt; var d = Cfg.dist(b.x, b.y, r["toX"], r["toY"])
		if d <= sp:
			b.x = r["toX"]; b.y = r["toY"]; r["phase"] = "land"; r["t"] = 0.0
		else:
			b.x += (r["toX"] - b.x) / d * sp; b.y += (r["toY"] - b.y) / d * sp
		return
	if r["phase"] == "land" and r["t"] > 2.0:
		var tx: int = r["tx"]; var ty: int = r["ty"]
		if not map.area_free(tx, ty, b.w, b.h, false):
			var found = false
			for rad in range(1, 10):
				if found: break
				for dy in range(-rad, rad + 1):
					if found: break
					for dx in range(-rad, rad + 1):
						if map.area_free(tx + dx, ty + dy, b.w, b.h, false):
							tx += dx; ty += dy; found = true; break
		b.tx = tx; b.ty = ty; b.x = (tx + b.w / 2.0) * Cfg.TILE; b.y = (ty + b.h / 2.0) * Cfg.TILE
		map.set_blocked(tx, ty, b.w, b.h, true, b.def.get("blocksAir", false))
		for u in units():
			if not u.flying and u.tile_x() >= tx and u.tile_x() < tx + b.w and u.tile_y() >= ty and u.tile_y() < ty + b.h:
				var nf = map.nearest_free(u.tile_x(), u.tile_y(), false)
				u.x = nf.x * Cfg.TILE + Cfg.TILE / 2.0; u.y = nf.y * Cfg.TILE + Cfg.TILE / 2.0
		b.relocate = null; b.cooldowns["relocate"] = 60.0
		add_effect({"type": "ring", "x": b.x, "y": b.y, "r": 70.0, "color": "#8fd3ff", "t": 1.0})
		if b.owner == human: msg("Stormspire has landed.")

func apply_building_aura(b: Building, dt: float) -> void:
	var a: Dictionary = b.def["aura"]; var r = float(a["radius"]) * Cfg.TILE
	match a["id"]:
		"cyclone":
			for u in allies_near(b.owner, b.x, b.y, r): u.add_buff("cyclone", 0.3, {"rangedTakenMul": 0.5})
			for u in enemies_near(b.owner, b.x, b.y, r):
				if not u.flying: u.add_buff("cyclone_slow", 0.3, {"speedMul": 0.65})
		"blight_miasma":
			for u in enemies_near(b.owner, b.x, b.y, r):
				u.add_buff("miasma", 0.3, {"speedMul": 0.75, "armorAdd": -1}); damage(u, 1.5 * dt, b, "magic", true)
		"healing":
			for u in allies_near(b.owner, b.x, b.y, r):
				if u.hp < u.max_hp: u.hp = minf(u.max_hp, u.hp + float(a.get("rate", 3)) * dt)
				if u.max_shield > 0: u.shield = minf(u.stat("maxShield"), u.shield + 4.0 * dt)
		"consecrated":
			for u in allies_near(b.owner, b.x, b.y, r): u.add_buff("consecrated", 0.3, {"dmgTakenMul": 0.85})
			for u in enemies_near(b.owner, b.x, b.y, r):
				if u.def.get("undead", false): u.add_buff("holy_ground", 0.3, {"dmgMul": 0.8})
		"thorns":
			for u in enemies_near(b.owner, b.x, b.y, r):
				if not u.flying:
					u.add_buff("entangled", 0.3, {"speedMul": 0.5}); damage(u, 2.0 * dt, b, "physical", true)
		"bell":
			for u in allies_near(b.owner, b.x, b.y, r): u.add_buff("bell", 0.3, {"atkSpeedMul": 1.1})

# ---------- units ----------
func update_unit(u: Unit, dt: float) -> void:
	var _t = Time.get_ticks_usec() if profiling else 0
	var expired = false
	for b in u.buffs:
		b["t"] -= dt
		if b["t"] <= 0.0: expired = true
		if b["mods"].has("dot"): damage(u, float(b["mods"]["dot"]) * dt, b.get("source", null), "magic", true)
	if expired: u.buffs = u.buffs.filter(func(b): return b["t"] > 0.0)
	for k in u.cooldowns:
		if u.cooldowns[k] > 0.0: u.cooldowns[k] -= dt
	if u.attack_timer > 0.0: u.attack_timer -= dt
	if u.flash > 0.0: u.flash -= dt
	if u.lifetime > 0.0:
		u.lifetime -= dt
		if u.lifetime <= 0.0:
			kill(u, null, true); return
	if u.hp < u.max_hp:
		var rg = u.stat("regen")
		if rg > 0.0: u.hp = minf(u.max_hp, u.hp + rg * dt)
	if u.max_shield > 0.0:
		u.shield_delay -= dt
		if u.shield_delay <= 0.0:
			var ms = u.stat("maxShield")
			if u.shield < ms: u.shield = minf(ms, u.shield + ms * 0.10 * dt)
	if u.def.get("heal", 0) > 0 and u.attack_timer <= 0.0: try_heal(u)
	if u.is_hero: update_hero_passives(u, dt)
	if u.def.has("aura"): apply_unit_aura(u, dt)
	if u.def.get("raiseDead", false) and u.attack_timer <= 0.0: try_raise_dead(u)
	_t = _pt("u_pre", _t)
	if u.stunned(): return
	var _ot: String = u.order["type"]
	match _ot:
		"idle", "hold": idle_behaviour(u, dt)
		"move": follow_path(u, dt, func(): clear_order(u))
		"attackmove": attack_move_behaviour(u, dt)
		"attack": attack_behaviour(u, dt)
		"gather": gather_behaviour(u, dt)
		"build": build_behaviour(u, dt)
		"cast": cast_behaviour(u, dt)
	_t = _pt("u_" + _ot, _t)

func acquire_target(u: Unit, range_px: float):
	var best = null; var bd = INF
	for e in enemies_near(u.owner, u.x, u.y, range_px, true):
		if not u.can_attack(e): continue
		if e.kind == "building" and not can_see(u.owner, e): continue
		if e.kind == "unit" and e.invisible() and not detected(u.owner, e): continue
		var d = u.dist_to(e)
		if e.kind == "building": d += 200.0
		if e.kind == "building" and e.def.get("wall", false): d += 300.0
		if e.kind == "unit" and e.is_worker(): d += 60.0
		if d < bd: bd = d; best = e
	return best

func idle_behaviour(u: Unit, dt: float) -> void:
	if u.is_worker() and u.faction().get("gathers", false) and u.gather["carrying"] > 0:
		u.order = {"type": "gather"}; u.gather["phase"] = "toDrop"; return
	if float(u.def.get("dmg", 0)) <= 0.0: return
	u.scan_timer -= dt
	if u.scan_timer > 0.0: return
	u.scan_timer = 0.15 + randf() * 0.1
	var t = acquire_target(u, maxf(u.stat("sight"), u.stat("range")) * (0.5 if u.is_worker() else 1.0))
	if t != null and not u.is_worker():
		u.target = t
		u.order = {"type": "attack", "target": t, "returnTo": (null if u.hold_pos else Vector2(u.x, u.y)), "hold": u.hold_pos}
	elif t != null and u.is_worker() and u.dist_to(t) < u.stat("range") + 10.0:
		try_attack(u, t, dt)

func attack_move_behaviour(u: Unit, dt: float) -> void:
	if u.target == null or u.target.dead:
		u.scan_timer -= dt
		if u.scan_timer <= 0.0:
			u.scan_timer = 0.15 + randf() * 0.1
			var t = acquire_target(u, maxf(u.stat("sight"), u.stat("range")))
			if t != null: u.target = t
	if u.target != null and not u.target.dead:
		engage(u, u.target, dt); return
	follow_path(u, dt, func(): clear_order(u))

func attack_behaviour(u: Unit, dt: float) -> void:
	var t = u.order.get("target", null)
	if t == null or t.dead or (t.kind == "unit" and t.invisible() and not detected(u.owner, t)):
		var rt = u.order.get("returnTo", null)
		if rt != null and not u.order.get("hold", false):
			clear_order(u); u.order = {"type": "attackmove", "x": rt.x, "y": rt.y}; set_path(u, rt.x, rt.y)
		else:
			var hold: bool = u.order.get("hold", false)
			clear_order(u)
			if hold: u.hold_pos = true; u.order = {"type": "hold"}
		return
	if u.order.get("hold", false) and not u.in_range(t):
		var t2 = acquire_target(u, u.stat("range"))
		if t2 != null: u.order["target"] = t2; u.target = t2
		else: clear_order(u); u.hold_pos = true; u.order = {"type": "hold"}
		return
	var rt2 = u.order.get("returnTo", null)
	if rt2 != null and Cfg.dist(u.x, u.y, rt2.x, rt2.y) > 12.0 * Cfg.TILE:
		clear_order(u); u.order = {"type": "move", "x": rt2.x, "y": rt2.y}; set_path(u, rt2.x, rt2.y); return
	engage(u, t, dt)

func engage(u: Unit, t, dt: float) -> void:
	if u.in_range(t):
		u.path = []
		if u.def.get("minRange", 0) > 0 and u.dist_to(t) < float(u.def["minRange"]) * Cfg.TILE:
			var a = atan2(u.y - t.y, u.x - t.x)
			steer_to(u, u.x + cos(a) * 60.0, u.y + sin(a) * 60.0, dt); return
		try_attack(u, t, dt)
	else:
		u.repath -= dt
		if u.repath <= 0.0 and (u.path_target == null or Cfg.dist(u.path_target.x, u.path_target.y, t.x, t.y) > Cfg.TILE * 1.5 or u.path.is_empty()):
			set_path(u, t.x, t.y); u.repath = 0.5 + randf() * 0.4
		follow_path(u, dt, Callable())

func follow_path(u: Unit, dt: float, on_done: Callable) -> void:
	if u.pending_path != null:
		if path_calls < 14:
			var pp: Vector2 = u.pending_path; set_path(u, pp.x, pp.y)
		if u.path.is_empty(): return
	if u.path.is_empty():
		if on_done.is_valid(): on_done.call()
		return
	var wp: Vector2 = u.path[0]
	var d = Cfg.dist(u.x, u.y, wp.x, wp.y)
	var step = u.stat("speed") * dt
	if d <= maxf(step, 6.0):
		u.x = wp.x; u.y = wp.y; u.path.pop_front()
		if u.path.is_empty() and on_done.is_valid(): on_done.call()
		return
	if not u.flying:
		var nx = u.x + (wp.x - u.x) / d * minf(step + 10.0, d); var ny = u.y + (wp.y - u.y) / d * minf(step + 10.0, d)
		if map.is_blocked(int(nx / Cfg.TILE), int(ny / Cfg.TILE), false):
			u.stuck += dt
			if u.stuck > 0.3:
				u.stuck = 0.0
				var last: Vector2 = u.path[u.path.size() - 1]
				set_path(u, last.x, last.y)
				if u.path.is_empty() and on_done.is_valid(): on_done.call()
			return
	u.stuck = 0.0
	steer_to(u, wp.x, wp.y, dt)

func steer_to(u: Unit, x: float, y: float, dt: float) -> void:
	var d = Cfg.dist(u.x, u.y, x, y)
	if d < 0.01: return
	var step = minf(d, u.stat("speed") * dt)
	var nx = u.x + (x - u.x) / d * step; var ny = u.y + (y - u.y) / d * step
	if u.flying or not map.is_blocked(int(nx / Cfg.TILE), int(ny / Cfg.TILE), false):
		u.x = nx; u.y = ny
	u.facing = atan2(y - u.y, x - u.x)
	if u.def.get("spreads", false) and u.affinity() != null: map.add_layer_source(u.affinity(), u.x, u.y, 2.5, 2.0)

func separate_units() -> void:
	var us = []
	for e in entities:
		if e.kind == "unit" and not e.dead: us.append(e)
	var cell = 48.0; var grid = {}
	for u in us:
		var k = Vector2i(int(u.x / cell), int(u.y / cell))
		if not grid.has(k): grid[k] = []
		grid[k].append(u)
	for u in us:
		var cx = int(u.x / cell); var cy = int(u.y / cell)
		for gy in range(cy - 1, cy + 2):
			for gx in range(cx - 1, cx + 2):
				var k = Vector2i(gx, gy)
				if not grid.has(k): continue
				for v in grid[k]:
					if v == u or v.flying != u.flying or v.id < u.id: continue
					var d = Cfg.dist(u.x, u.y, v.x, v.y); var mn = u.radius + v.radius
					if d < mn and d > 0.01:
						var push = (mn - d) / 2.0 * 0.6; var nx = (u.x - v.x) / d; var ny = (u.y - v.y) / d
						var um = 0.0 if u.hold_pos else 1.0; var vm = 0.0 if v.hold_pos else 1.0
						u.x += nx * push * um; u.y += ny * push * um; v.x -= nx * push * vm; v.y -= ny * push * vm
					elif d <= 0.01:
						u.x += randf_range(-2, 2); u.y += randf_range(-2, 2)
		u.x = clampf(u.x, Cfg.TILE, Cfg.WORLD_W - Cfg.TILE); u.y = clampf(u.y, Cfg.TILE, Cfg.WORLD_H - Cfg.TILE)
		if not u.flying and map.is_blocked(u.tile_x(), u.tile_y(), false):
			var nf = map.nearest_free(u.tile_x(), u.tile_y(), false)
			u.x += (nf.x * Cfg.TILE + Cfg.TILE / 2.0 - u.x) * 0.3; u.y += (nf.y * Cfg.TILE + Cfg.TILE / 2.0 - u.y) * 0.3

func gather_behaviour(u: Unit, dt: float) -> void:
	var g: Dictionary = u.gather
	if g["phase"] == "toNode":
		if g["node"] == null or g["node"]["amount"] <= 0:
			g["node"] = nearest_node(u, "primary")
			if g["node"] == null: clear_order(u); return
			set_path(u, g["node"]["x"], g["node"]["y"])
		if Cfg.dist(u.x, u.y, g["node"]["x"], g["node"]["y"]) < Cfg.TILE * 1.6:
			g["phase"] = "gathering"; g["timer"] = 3.0; u.path = []
		else:
			var nd: Dictionary = g["node"]
			follow_path(u, dt, func():
				if Cfg.dist(u.x, u.y, nd["x"], nd["y"]) > Cfg.TILE * 1.6: set_path(u, nd["x"], nd["y"]))
	elif g["phase"] == "gathering":
		g["timer"] -= dt
		if g["timer"] <= 0.0:
			var take = minf(5.0, g["node"]["amount"]); g["node"]["amount"] -= take; g["carrying"] = take
			g["phase"] = "toDrop"
			var d = nearest_dropoff(u); g["drop"] = d
			if d != null: set_path(u, d.x, d.y)
			else: clear_order(u); return
	elif g["phase"] == "toDrop":
		var d = g.get("drop", null)
		if d == null or d.dead or not d.complete():
			d = nearest_dropoff(u); g["drop"] = d
		if d == null: clear_order(u); return
		if u.dist_to(d) < Cfg.TILE * 0.9:
			var p = u.player()
			p.res["p"] += g["carrying"] * p.income_mul; p.stats["p"] += g["carrying"]; g["carrying"] = 0.0; g["phase"] = "toNode"
			if g["node"] == null or g["node"]["amount"] <= 0: g["node"] = nearest_node(u, "primary")
			if g["node"] == null: clear_order(u); return
			set_path(u, g["node"]["x"], g["node"]["y"])
		else:
			follow_path(u, dt, func(): set_path(u, d.x, d.y))

func build_behaviour(u: Unit, dt: float) -> void:
	var b = u.build_task
	if b == null or b.dead or b.complete():
		clear_order(u)
		if b != null and not b.dead and b.complete() and u.faction().get("gathers", false):
			var nd = nearest_node(u, "primary")
			if nd != null: order_gather([u], nd)
		return
	if u.dist_to(b) < Cfg.TILE * 0.8:
		b.builders += 1; u.path = []
	else:
		follow_path(u, dt, func():
			if u.dist_to(b) >= Cfg.TILE * 0.8: set_path(u, b.x, b.y))

func cast_behaviour(u: Unit, dt: float) -> void:
	var o: Dictionary = u.order
	var ab: Dictionary = GData.abilities[o["ability"]]
	var t = o.get("target", null)
	if t != null and t.dead: clear_order(u); return
	var tx: float = t.x if t != null else o["x"]; var ty: float = t.y if t != null else o["y"]
	var rng = float(ab.get("range", 0)) * Cfg.TILE
	var d = u.dist_to(t) if t != null else Cfg.dist(u.x, u.y, tx, ty)
	if d <= rng + 2.0:
		u.path = []
		cast_ability(u, o["ability"], t, tx, ty)
		clear_order(u)
	else:
		if u.path_target == null or Cfg.dist(u.path_target.x, u.path_target.y, tx, ty) > Cfg.TILE or u.path.is_empty(): set_path(u, tx, ty)
		follow_path(u, dt, Callable())

# ---------- abilities ----------
func can_cast(u: Unit, id: String) -> Dictionary:
	if not GData.abilities.has(id): return {"ok": false, "why": "?"}
	var ab: Dictionary = GData.abilities[id]
	if ab.get("passive", false): return {"ok": false, "why": "Passive"}
	if ab.get("ult", false) and u.level < 5: return {"ok": false, "why": "Requires hero level 5"}
	if u.cooldowns.get(id, 0.0) > 0.0: return {"ok": false, "why": "Cooldown " + str(ceili(u.cooldowns[id])) + "s"}
	if u.buff_flag("silence"): return {"ok": false, "why": "Silenced"}
	if ab.get("cost", null) != null and not u.player().can_afford(ab["cost"]): return {"ok": false, "why": "Not enough resources"}
	return {"ok": true}

func order_cast(u: Unit, id: String, target, x: float, y: float) -> bool:
	var c = can_cast(u, id)
	if not c["ok"]:
		if u.owner == human: msg(c["why"], "warn")
		return false
	var ab: Dictionary = GData.abilities[id]
	if ab.get("target", "none") == "none":
		cast_ability(u, id, null, u.x, u.y); return true
	clear_order(u)
	u.order = {"type": "cast", "ability": id, "target": target, "x": x, "y": y}
	return true

func cast_ability(caster: Unit, id: String, target, x: float, y: float) -> bool:
	var c = can_cast(caster, id)
	if not c["ok"]: return false
	var ab: Dictionary = GData.abilities[id]
	if ab.get("cost", null) != null: caster.player().pay(ab["cost"])
	caster.cooldowns[id] = float(ab.get("cooldown", 0))
	Abilities.cast(self, id, caster, target, x, y)
	emit("cast", caster.x, caster.y, caster.owner, {"ult": ab.get("ult", false)})
	caster.attack_timer = maxf(caster.attack_timer, 0.4)
	return true

func building_cast(b: Building, id: String, target = null, x := 0.0, y := 0.0) -> bool:
	var ab: Dictionary = GData.abilities[id]
	if b.cooldowns.get(id, 0.0) > 0.0:
		if b.owner == human: msg("Cooldown", "warn")
		return false
	if ab.get("cost", null) != null and not b.player().can_afford(ab["cost"]):
		if b.owner == human: msg("Not enough resources", "warn")
		return false
	if ab.get("cost", null) != null: b.player().pay(ab["cost"])
	b.cooldowns[id] = float(ab.get("cooldown", 0))
	Abilities.cast(self, id, b, target, x if x != 0.0 else b.x, y if y != 0.0 else b.y)
	emit("cast", b.x, b.y, b.owner, {"ult": ab.get("ult", false)})
	return true

# ---------- vision ----------
var _discs = {}   # tile radius -> PackedInt32Array of (dx, dy) pairs inside the circle
var _mark_seen = {}

func compute_vision(owner: int) -> void:
	var p: GPlayer = players[owner]
	p.vision = p.explored.duplicate()
	_mark_seen.clear()
	for e in entities:
		if e.dead or e.owner != owner: continue
		var r: float = e.stat("sight") if e.kind == "unit" else (e.stat("sight") if e.complete() else 4.0 * Cfg.TILE)
		_mark_vision(p, e.x, e.y, r)
	for r in p.reveal: _mark_vision(p, r["x"], r["y"], r["r"])

func _disc(rt: int) -> PackedInt32Array:
	if _discs.has(rt): return _discs[rt]
	var out = PackedInt32Array(); var r2 = rt * rt
	for dy in range(-rt, rt + 1):
		for dx in range(-rt, rt + 1):
			if dx * dx + dy * dy <= r2: out.append(dx); out.append(dy)
	_discs[rt] = out
	return out

func _mark_vision(p: GPlayer, x: float, y: float, r: float) -> void:
	var cx = int(x / Cfg.TILE); var cy = int(y / Cfg.TILE); var rt = ceili(r / Cfg.TILE)
	var key = Vector3i(cx, cy, rt)
	if _mark_seen.has(key): return
	_mark_seen[key] = true
	var disc = _disc(rt); var w = map.w; var h = map.h
	var vis = p.vision; var exp = p.explored
	for i in range(0, disc.size(), 2):
		var tx = cx + disc[i]; var ty = cy + disc[i + 1]
		if tx < 0 or ty < 0 or tx >= w or ty >= h: continue
		var idx = ty * w + tx
		vis[idx] = 2; exp[idx] = 1
	p.vision = vis; p.explored = exp

# ================= COMBAT =================
func try_attack(u: Unit, t, dt: float) -> void:
	u.facing = atan2(t.y - u.y, t.x - u.x)
	if u.attack_timer > 0.0: return
	u.attack_timer = u.stat("cd")
	var dmg = u.stat("dmg")
	var type = "magic" if u.def.get("magic", false) else "physical"
	if float(u.def.get("range", 1)) > 1.6:
		var kind = "shell" if u.def.get("type", "") == "siege" else ("bolt" if u.def.get("magic", false) else "arrow")
		projectiles.append({"x": u.x, "y": u.y, "target": t, "speed": 9.0 * Cfg.TILE, "dmg": dmg, "source": u, "type": type, "splash": float(u.def.get("splash", 0)), "color": u.faction()["color"], "kind": kind})
		emit("shoot", u.x, u.y, u.owner, {"kind": kind})
	else:
		hit(u, t, dmg, type, float(u.def.get("splash", 0)))
		add_effect({"type": "slash", "x": t.x, "y": t.y, "color": u.faction()["color"], "t": 0.15})

func hit(source, t, dmg: float, type: String, splash: float) -> void:
	if splash > 0.0:
		var src_air: bool = source.def.get("air", false) if source.kind == "unit" else false
		for e in nearby(t.x, t.y, splash * Cfg.TILE, func(e): return e.owner != source.owner and e.owner >= 0 and (e.kind == "unit" or e.kind == "building")):
			if e.kind == "unit" and e.flying and not src_air and e != t: continue
			damage(e, dmg if e == t else dmg * 0.6, source, type)
		add_effect({"type": "burst", "x": t.x, "y": t.y, "r": splash * Cfg.TILE, "color": source.faction()["color"], "t": 0.35})
	else:
		damage(t, dmg, source, type)
	if source.kind == "unit":
		if source.def.get("shock", 0) > 0 and t.kind == "unit": damage(t, float(source.def["shock"]), source, "true")
		if source.def.get("chain", 0) > 0 and t.kind == "unit": chain_lightning(source, t, dmg * 0.5, int(source.def["chain"]))
		if float(source.def.get("range", 1)) <= 1.6 and source.player().eff("meleeDot", "add") > 0.0 and t.kind == "unit":
			var b = t.add_buff("plague", 6.0, {"dot": 3.0}); b["source"] = source
		var ls = source.stat("lifesteal")
		if ls > 0.0: source.hp = minf(source.max_hp, source.hp + dmg * ls)

func chain_lightning(source, from, dmg: float, count: int) -> void:
	var cur = from; var hit_set = {from.id: true}
	var src_air: bool = source.def.get("air", true) if source.kind == "unit" else true
	for i in range(count):
		var cands = enemies_near(source.owner, cur.x, cur.y, 4.0 * Cfg.TILE).filter(func(e): return not hit_set.has(e.id) and (src_air or not e.flying))
		if cands.is_empty(): break
		var cx: float = cur.x; var cy: float = cur.y
		cands.sort_custom(func(a, b): return Cfg.dist(a.x, a.y, cx, cy) < Cfg.dist(b.x, b.y, cx, cy))
		var nxt = cands[0]
		add_effect({"type": "lightning", "x1": cur.x, "y1": cur.y, "x2": nxt.x, "y2": nxt.y, "color": "#bfe8ff", "t": 0.25})
		damage(nxt, dmg, source, "magic")
		if nxt.kind == "unit" and nxt.def.get("mechanical", false): nxt.add_buff("stun", 1.0, {"stun": true})
		hit_set[nxt.id] = true; cur = nxt; dmg *= 0.8

func damage(t, amount: float, source, type: String, silent := false) -> float:
	if t == null or t.dead or amount <= 0.0: return 0.0
	var dmg = amount
	if type != "true":
		var armor = t.stat("armor")
		if type == "magic": armor *= 0.5
		dmg = maxf(amount * 0.15, amount - armor)
	if source != null and source.kind == "unit" and source.def.get("vsUndead", 0) > 0 and t.kind == "unit" and t.def.get("undead", false): dmg *= float(source.def["vsUndead"])
	if t.kind == "unit":
		dmg *= t.stat("dmgTaken")
		if source != null and ((source.kind == "unit" and float(source.def.get("range", 1)) > 1.6) or source.kind == "building"):
			dmg *= t.buff_mul("rangedTakenMul")
			if t.faction_id() == "tempest" and t.player().tier >= 2:
				var base = base_of(t.owner)
				if base != null and base.relocate == null and Cfg.dist(base.x, base.y, t.x, t.y) < 8.0 * Cfg.TILE: dmg *= 0.75
		if t.buff_flag("invisible") and not silent: t.remove_buff("invisible")
	elif t.kind == "building":
		if source != null and source.kind == "unit" and source.def.get("vsBuilding", 0) > 0: dmg *= float(source.def["vsBuilding"])
	if t.kind == "unit" and t.hp - dmg <= 0.0 and t.has_buff("undying") and t.cooldowns.get("undying", 0.0) <= 0.0:
		t.cooldowns["undying"] = 90.0; t.hp = maxf(1.0, t.max_hp * 0.15)
		add_effect({"type": "text", "x": t.x, "y": t.y - 16, "text": "UNDYING", "color": "#c9a0ff", "t": 1.0})
		return 0.0
	if t.kind == "unit" and t.shield > 0.0 and type != "true":
		var ab = minf(t.shield, dmg); t.shield -= ab; dmg -= ab; t.shield_delay = 5.0
	t.hp -= dmg
	if not silent:
		t.flash = 0.12
		emit("hit", t.x, t.y, t.owner, {"dmg": dmg})
	if not silent and t.kind == "unit" and t.is_hero and dmg > 5.0:
		add_effect({"type": "text", "x": t.x + randf_range(-8, 8), "y": t.y - 18, "text": str(roundi(dmg)), "color": "#ff8", "t": 0.6})
	if t.kind == "unit" and source != null and not source.dead and (t.order["type"] == "idle" or t.order["type"] == "hold") and t.can_attack(source) and float(t.def.get("dmg", 0)) > 0.0 and not t.is_worker():
		t.order = {"type": "attack", "target": source, "returnTo": (null if t.hold_pos else Vector2(t.x, t.y)), "hold": t.hold_pos}; t.target = source
	if t.kind == "unit" and t.is_worker() and source != null and t.faction().get("gathers", false) and t.order["type"] == "gather" and Cfg.dist(t.x, t.y, source.x, source.y) < 3.0 * Cfg.TILE:
		var b = base_of(t.owner)
		if b != null:
			t.order = {"type": "move", "x": b.x, "y": b.y + 2.0 * Cfg.TILE}; set_path(t, b.x, b.y + 2.0 * Cfg.TILE)
	if t.hp <= 0.0: kill(t, source, false)
	if t.owner == human and source != null and source.owner != human and last_attack_msg < time - 12.0:
		last_attack_msg = time; msg(t.name() + " is under attack!", "warn"); attack_ping = {"x": t.x, "y": t.y, "t": 4.0}; emit("warn", t.x, t.y, human)
	return dmg

func kill(t, source, expire := false) -> void:
	if t.dead: return
	t.dead = true
	if not expire or t.kind == "building":
		emit("death", t.x, t.y, t.owner, {"building": t.kind == "building", "big": t.kind == "unit" and (t.is_hero or float(t.def.get("supply", 0)) >= 3.0)})
	var killer: GPlayer = players[source.owner] if source != null else null
	if t.kind == "unit":
		if killer != null and killer != t.player():
			killer.kills += 1; t.player().losses += 1
			var xpv = 8.0 + float(t.def.get("supply", 0)) * 8.0 + (60.0 if t.is_hero else 0.0)
			for hh in heroes(killer.index):
				if Cfg.dist(hh.x, hh.y, t.x, t.y) < 10.0 * Cfg.TILE: hh.gain_xp(xpv)
		update_supply(t.owner)
		if not expire and t.def.get("undead", false) and not t.death_once and not t.is_hero:
			for hh in heroes(t.owner):
				if hh.def_id == "tyvaris" and Cfg.dist(hh.x, hh.y, t.x, t.y) < 6.0 * Cfg.TILE:
					var nu = spawn_unit(t.owner, "skeleton_warrior", t.x, t.y); nu.death_once = true; nu.lifetime = 45.0
					add_effect({"type": "ring", "x": t.x, "y": t.y, "r": 20.0, "color": "#c9a0ff", "t": 0.6})
					break
		for p in players:
			if p.faction_id != "abyss": continue
			var near = false
			for e in entities:
				if not e.dead and e.owner == p.index and Cfg.dist(e.x, e.y, t.x, t.y) < 8.0 * Cfg.TILE: near = true; break
			if near:
				var souls = 4.0 + float(t.def.get("supply", 0)) * 5.0 + (40.0 if t.is_hero else 0.0)
				if t.owner == p.index: souls *= 0.5
				if p.tier >= 2: souls *= 1.25
				souls *= p.income_mul
				p.res["p"] += souls; p.stats["p"] += souls
				if p.index == human: add_effect({"type": "text", "x": t.x, "y": t.y - 10, "text": "+" + str(roundi(souls)) + " souls", "color": "#c9a0ff", "t": 0.9})
		if t.has_buff("curse_undeath") and not expire:
			var cb = t.get_buff("curse_undeath")
			if cb["owner"] >= 0 and cb["owner"] != t.owner:
				var nu2 = spawn_unit(cb["owner"], "skeleton_warrior", t.x, t.y); nu2.lifetime = 60.0; nu2.death_once = true
				add_effect({"type": "ring", "x": t.x, "y": t.y, "r": 22.0, "color": "#8b3cff", "t": 0.6})
		for b in buildings():
			if b.def.get("wall", false) and b.faction_id() == "abyss" and Cfg.dist(b.x, b.y, t.x, t.y) < 2.5 * Cfg.TILE: b.hp = minf(b.max_hp, b.hp + 60.0)
		if not expire and not t.is_hero: corpses.append(Corpse.new(self, t.owner, t.def_id, t.x, t.y, t.flying))
		if not expire and t.def.get("rebirth", false) and not t.reborn:
			respawns.append({"owner": t.owner, "defId": t.def_id, "x": t.x, "y": t.y, "t": 4.0})
			add_effect({"type": "ring", "x": t.x, "y": t.y, "r": 30.0, "color": "#ffb347", "t": 1.0})
		if t.is_hero:
			t.player().hero_cooldowns[t.def_id] = 60.0
			msg(t.name() + " has fallen." + (" They may be resummoned in 60s." if t.owner == human else ""), "warn" if t.owner == human else "good")
		add_effect({"type": "death", "x": t.x, "y": t.y, "color": t.faction()["color"], "t": 0.6, "flying": t.flying})
	elif t.kind == "building":
		map.set_blocked(t.tx, t.ty, t.w, t.h, false, t.def.get("blocksAir", false))
		if t.node != null: t.node["building"] = null
		for q in t.queue: t.player().refund(q["cost"])
		update_supply(t.owner)
		add_effect({"type": "burst", "x": t.x, "y": t.y, "r": t.w * Cfg.TILE * 0.7, "color": "#ff9b6a", "t": 0.8})
		if t.def.get("isBase", false): msg(("Your " if t.owner == human else "The enemy ") + t.name() + " has been destroyed!", "warn" if t.owner == human else "good")
		elif t.owner == human: msg(t.name() + " destroyed!", "warn")

func update_projectiles(dt: float) -> void:
	var keep = []
	for p in projectiles:
		var t = p["target"]
		if t == null or t.dead: continue
		var d = Cfg.dist(p["x"], p["y"], t.x, t.y); var step: float = p["speed"] * dt
		if d <= step:
			hit(p["source"], t, p["dmg"], p["type"], p["splash"])
			if p["kind"] == "bolt": add_effect({"type": "spark", "x": t.x, "y": t.y, "color": p["color"], "t": 0.2})
		else:
			p["x"] += (t.x - p["x"]) / d * step; p["y"] += (t.y - p["y"]) / d * step
			keep.append(p)
	projectiles = keep

func update_corpses(dt: float) -> void:
	for c in corpses: c.t -= dt
	corpses = corpses.filter(func(c): return c.t > 0.0 and not c.dead)

func update_mines() -> void:
	for m in buildings():
		if not m.def.get("mine", false) or not m.complete(): continue
		var en = enemies_near(m.owner, m.x, m.y, 1.5 * Cfg.TILE).filter(func(e): return not e.flying)
		if not en.is_empty():
			for e in enemies_near(m.owner, m.x, m.y, 3.5 * Cfg.TILE):
				var b = e.add_buff("plague", 10.0, {"dot": 3.0, "dmgMul": 0.7}); b["source"] = m
			add_effect({"type": "burst", "x": m.x, "y": m.y, "r": 3.5 * Cfg.TILE, "color": "#7fe07f", "t": 0.8})
			kill(m, null)

func update_tower(b: Building, dt: float) -> void:
	if b.attack_timer > 0.0: b.attack_timer -= dt; return
	var tw: Dictionary = b.def.get("tower", {"dmg": 8, "range": 5, "cd": 1.5, "air": false})
	var rng = b.tower_range()
	var air: bool = tw.get("air", false)
	var cands = enemies_near(b.owner, b.x, b.y, rng).filter(func(e): return (air or not e.flying) and (not e.invisible() or detected(b.owner, e)))
	if cands.is_empty(): b.attack_timer = 0.1; return
	var pref_air: bool = tw.get("prefAir", false)
	cands.sort_custom(func(a, c): return ((-1000.0 if (pref_air and a.flying) else 0.0) + b.dist_to(a)) < ((-1000.0 if (pref_air and c.flying) else 0.0) + b.dist_to(c)))
	var t = cands[0]
	b.attack_timer = float(tw.get("cd", 1.5))
	var dmg = b.tower_dmg()
	if b.faction_id() == "tempest":
		add_effect({"type": "lightning", "x1": b.x, "y1": b.y - 20, "x2": t.x, "y2": t.y, "color": "#bfe8ff", "t": 0.25})
		damage(t, dmg, b, "magic")
		if tw.get("chain", 0) > 0: chain_lightning(b, t, dmg * 0.6, int(tw["chain"]))
	else:
		var splash = float(tw.get("splash", 0))
		var aff = b.affinity()
		var col = "#ffe680" if aff == "light" else ("#8fffa0" if aff == "grove" else "#c9a0ff")
		projectiles.append({"x": b.x, "y": b.y - 16, "target": t, "speed": (7.0 if splash > 0 else 10.0) * Cfg.TILE, "dmg": dmg, "source": b, "type": "magic", "color": col, "kind": "shell" if splash > 0 else "bolt", "splash": splash})
		if tw.get("leech", 0) > 0:
			for a in allies_near(b.owner, b.x, b.y, 4.0 * Cfg.TILE):
				if a.def.get("undead", false): a.hp = minf(a.max_hp, a.hp + dmg * float(tw["leech"]) * 0.3)

func try_heal(u: Unit) -> void:
	var rng = maxf(u.stat("range"), 4.0 * Cfg.TILE)
	var best = null; var br = 0.95
	for a in allies_near(u.owner, u.x, u.y, rng):
		if a == u: continue
		var r: float = a.hp / a.max_hp
		if r < br: br = r; best = a
	if best == null: return
	u.attack_timer = u.stat("cd") * 1.5
	best.hp = minf(best.max_hp, best.hp + u.stat("heal"))
	add_effect({"type": "lightning", "x1": u.x, "y1": u.y, "x2": best.x, "y2": best.y, "color": "#8fffa0" if u.affinity() == "grove" else "#fff2b0", "t": 0.25})

func try_raise_dead(u: Unit) -> void:
	if u.cooldowns.get("raise", 0.0) > 0.0: return
	var c = null
	for co in corpses:
		if not co.dead and not co.flying and Cfg.dist(co.x, co.y, u.x, u.y) < 5.0 * Cfg.TILE: c = co; break
	if c == null: return
	if u.player().supply_used + 1 > u.player().supply_cap: return
	c.dead = true; u.cooldowns["raise"] = 4.0
	var nu = spawn_unit(u.owner, "skeleton_warrior", c.x, c.y); nu.lifetime = 50.0; nu.death_once = true
	add_effect({"type": "ring", "x": c.x, "y": c.y, "r": 18.0, "color": "#8b3cff", "t": 0.5})
	if u.order["type"] == "attackmove" or u.order["type"] == "attack":
		if u.target != null and not u.target.dead: order_attack([nu], u.target)
		else: order_move([nu], u.x, u.y, true)

func update_hero_passives(h: Unit, dt: float) -> void:
	h.aura_timer -= dt
	if h.aura_timer > 0.0: return
	h.aura_timer = 0.25
	match h.def_id:
		"tyvaris":
			for a in allies_near(h.owner, h.x, h.y, 6.0 * Cfg.TILE):
				if a != h: a.add_buff("pale_king", 0.4, {"dmgMul": 1.1})
		"neratha":
			for a in allies_near(h.owner, h.x, h.y, 6.0 * Cfg.TILE): a.add_buff("undying", 0.4, {})
		"rykan":
			for a in allies_near(h.owner, h.x, h.y, 6.0 * Cfg.TILE):
				if a.flying and a != h: a.add_buff("skyfury", 0.4, {"armorAdd": 2, "dmgMul": 1.15})
			if not h.def.has("chain"): h.def["chain"] = 2
		"lyrian":
			var base = base_of(h.owner)
			if base != null and Cfg.dist(base.x, base.y, h.x, h.y) < 6.0 * Cfg.TILE and base.hp < base.max_hp: base.hp = minf(base.max_hp, base.hp + 1.25)

func apply_unit_aura(u: Unit, dt: float) -> void:
	var a: Dictionary = u.def["aura"]
	u.aura_timer -= dt
	if u.aura_timer > 0.0: return
	u.aura_timer = 0.3
	var r = float(a["radius"]) * Cfg.TILE
	match a["id"]:
		"death_aura":
			for e in enemies_near(u.owner, u.x, u.y, r):
				damage(e, 1.2, u, "magic", true); e.add_buff("death_aura", 0.4, {"dmgMul": 0.85})
			map.add_layer_source("blight", u.x, u.y, 4.0, 2.0)
		"dawn_aura":
			for e in enemies_near(u.owner, u.x, u.y, r): damage(e, 1.5, u, "magic", true)
			for al in allies_near(u.owner, u.x, u.y, r): Abilities.heal_unit(al, 1.5)
		"heart_aura":
			for e in enemies_near(u.owner, u.x, u.y, r):
				if not e.flying: e.add_buff("rooted_heart", 0.4, {"speedMul": 0.5})
			for al in allies_near(u.owner, u.x, u.y, r): Abilities.heal_unit(al, 1.8)
		"archangel_aura":
			for al in allies_near(u.owner, u.x, u.y, r):
				if al.max_shield > 0: al.shield = minf(al.stat("maxShield"), al.shield + 2.4)
			for e in enemies_near(u.owner, u.x, u.y, r):
				if e.def.get("undead", false): damage(e, 2.4, u, "magic", true)
	if a["id"] != "death_aura" and u.def.get("spreads", false) and u.affinity() != null: map.add_layer_source(u.affinity(), u.x, u.y, 4.0, 2.0)

# ================= WARDS (area effects) =================
func update_wards(dt: float) -> void:
	for wd in wards:
		wd["t"] -= dt
		if wd.has("follow"):
			if wd["follow"].dead: wd["t"] = 0.0; continue
			wd["x"] = wd["follow"].x; wd["y"] = wd["follow"].y
		wd["tick"] = wd.get("tick", 0.0) + dt
		var allies = allies_near(wd["owner"], wd["x"], wd["y"], wd["r"], true)
		var enemies = enemies_near(wd["owner"], wd["x"], wd["y"], wd["r"], true)
		var mul: float = wd.get("mul", 1.0)
		match wd["kind"]:
			"corruption":
				map.add_layer_source("blight", wd["x"], wd["y"], wd["r"] / Cfg.TILE, 3.0)
				for a in allies:
					if a.kind == "unit" and a.def.get("undead", false): a.hp = minf(a.max_hp, a.hp + 4.0 * dt)
				for e in enemies:
					if e.kind == "unit": e.add_buff("ward_slow", 0.3, {"speedMul": 0.8})
			"veil":
				for e in enemies:
					if e.kind == "unit": e.add_buff("veil", 0.3, {"speedMul": 0.7, "dmgMul": 0.75})
				for a in allies:
					if a.kind == "unit" and a.def.get("undead", false) and a.attack_timer <= 0.0 and a.order["type"] != "attack": a.add_buff("invisible", 0.4, {"invisible": true})
			"curse":
				for e in enemies:
					if e.kind == "unit": e.add_buff("curse_undeath", 0.5, {})["owner"] = wd["owner"]
			"zephyr":
				for a in allies:
					if a.kind == "unit": a.add_buff("zephyr", 0.3, {"rangedTakenMul": 0.4})
					elif a.hp < a.max_hp: a.hp = minf(a.max_hp, a.hp + 8.0 * dt)
			"cloud":
				for e in enemies:
					if e.kind == "unit": e.add_buff("cloud", 0.3, {"speedMul": 0.7}); damage(e, 6.0 * dt, null, "magic", true)
				for a in allies:
					if a.kind == "unit": a.hp = minf(a.max_hp, a.hp + 4.0 * dt)
			"eye":
				for a in allies:
					if a.kind == "unit": a.add_buff("eye_storm", 0.3, {"dmgTakenMul": 0.6, "dmgMul": 1.25})
				for e in enemies:
					if e.kind == "unit": e.add_buff("eye_slow", 0.3, {"speedMul": 0.6})
				if wd["tick"] > 0.8 and not enemies.is_empty():
					wd["tick"] = 0.0; var e = enemies.pick_random()
					add_effect({"type": "lightning", "x1": e.x, "y1": e.y - 180, "x2": e.x, "y2": e.y, "color": "#fff", "t": 0.25}); damage(e, 35.0, wd.get("follow", null), "magic")
			"hurricane":
				for e in enemies:
					if e.kind == "unit":
						e.add_buff("hurricane", 0.3, {"speedMul": 0.5, "dmgMul": 0.6} if e.flying else {"speedMul": 0.15, "dmgMul": 0.5}); damage(e, (12.0 if e.flying else 8.0) * dt, null, "magic", true)
				for a in allies:
					if a.kind == "unit" and not (a.is_hero and a.def_id == "alyssia"):
						a.add_buff("hurricane", 0.3, {"speedMul": 0.8 if a.flying else 0.5}); damage(a, 3.0 * dt, null, "magic", true)
				if wd["tick"] > 0.5:
					wd["tick"] = 0.0; var eu = enemies.filter(func(e): return e.kind == "unit")
					if not eu.is_empty():
						var e2 = eu.pick_random()
						add_effect({"type": "lightning", "x1": e2.x + randf_range(-40, 40), "y1": e2.y - 200, "x2": e2.x, "y2": e2.y, "color": "#fff", "t": 0.25}); damage(e2, 30.0, null, "magic")
			"sanctify":
				map.add_layer_source("light", wd["x"], wd["y"], wd["r"] / Cfg.TILE, 3.0)
				for a in allies:
					if a.kind == "unit": a.add_buff("sanctified", 0.3, {"dmgTakenMul": 0.85}); Abilities.heal_unit(a, 3.0 * dt)
				for e in enemies:
					if e.kind == "unit": e.add_buff("sanctify_weak", 0.3, {"dmgMul": 0.85})
			"sunfire":
				for e in enemies:
					damage(e, 40.0 * dt * mul, wd.get("source", null), "magic", true)
					if e.kind == "unit": e.add_buff("blind", 0.3, {"dmgMul": 0.6})
				for a in allies:
					if a.kind == "unit": Abilities.heal_unit(a, 12.0 * dt)
			"grove":
				map.add_layer_source("grove", wd["x"], wd["y"], wd["r"] / Cfg.TILE, 3.0)
				for a in allies:
					if a.kind == "unit": Abilities.heal_unit(a, 4.0 * dt)
				for e in enemies:
					if e.kind == "unit" and not e.flying: e.add_buff("vines", 0.3, {"speedMul": 0.7})
			"vines":
				for e in enemies:
					if e.kind == "unit" and not e.flying: e.add_buff("entangled", 0.3, {"speedMul": 0.15}); damage(e, 5.0 * dt, wd.get("source", null), "physical", true)
			"bloom":
				for a in allies:
					if a.kind == "unit": Abilities.heal_unit(a, 25.0 * dt); a.add_buff("bloom", 0.3, {"regen": 3})
			"heaven":
				if wd["tick"] > 0.5:
					wd["tick"] = 0.0
					if not enemies.is_empty():
						var e3 = enemies.pick_random()
						add_effect({"type": "lightning", "x1": e3.x + randf_range(-30, 30), "y1": e3.y - 220, "x2": e3.x, "y2": e3.y, "color": "#fff7d0", "t": 0.3}); damage(e3, 60.0 * mul, wd.get("source", null), "magic")
	wards = wards.filter(func(wd): return wd["t"] > 0.0)
	if weather["storm"] != null:
		var s: Dictionary = weather["storm"]; s["tick"] = s.get("tick", 0.0) + dt
		if s["tick"] > 0.7:
			s["tick"] = 0.0
			var en = units().filter(func(u): return u.owner != s["owner"])
			if not en.is_empty():
				var e = en.pick_random()
				add_effect({"type": "lightning", "x1": e.x + randf_range(-60, 60), "y1": e.y - 220, "x2": e.x, "y2": e.y, "color": "#fff", "t": 0.25}); damage(e, 18.0, null, "magic")
	if clarity != null:
		clarity["t"] -= dt
		if clarity["t"] <= 0.0: clarity = null
