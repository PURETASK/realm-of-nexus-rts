class_name Unit
extends RefCounted
## A unit or hero (mirrors js/entities.js Unit)

var id = 0
var kind = "unit"
var game = null
var owner = 0
var x = 0.0
var y = 0.0
var hp = 1.0
var max_hp = 1.0
var dead = false
var flash = 0.0           # seconds of hit flash left (presentation only)
var def_id = ""
var def: Dictionary = {}
var is_hero = false
var flying = false
var radius = 10.0
var max_shield = 0.0
var shield = 0.0
var shield_delay = 0.0
var buffs = []            # [{id, t, mods, source, owner}]
var cooldowns = {}
var order = {"type": "idle"}
var path = []             # Array of Vector2
var path_target = null     # Vector2 or null
var pending_path = null
var target = null
var attack_timer = 0.0
var facing = 0.0
var level = 1
var xp = 0.0
var lifetime = 0.0
var gather = {"carrying": 0.0, "node": null, "phase": "toNode", "timer": 0.0}
var build_task = null
var abilities = []
var aura_timer = 0.0
var stuck = 0.0
var hold_pos = false
var death_once = false
var reborn = false
var repath = 0.0
var scan_timer = 0.0
var _stat_cache = {}
var _stat_frame = -1

func _init(g, own: int, did: String, px: float, py: float) -> void:
	game = g; owner = own; x = px; y = py
	id = g.next_id()
	def_id = did
	def = GData.unit_def(faction(), did)
	is_hero = def.get("type", "") == "hero"
	flying = bool(def.get("flying", false))
	var sup = float(def.get("supply", 0))
	radius = 14.0 if is_hero else (14.0 if (def.get("type", "") == "siege" or sup >= 5) else (12.0 if sup >= 3 else 10.0))
	max_hp = float(def.get("hp", 1)); hp = max_hp
	max_shield = float(def.get("shield", 0)); shield = max_shield
	abilities = def.get("abilities", [])

func player() -> GPlayer:
	return game.players[owner]

func faction() -> Dictionary:
	return game.players[owner].faction

func faction_id() -> String:
	return game.players[owner].faction_id

func affinity():
	return faction().get("affinity", null)

func name() -> String:
	return def.get("name", def_id)

func tile_x() -> int: return int(x / Cfg.TILE)
func tile_y() -> int: return int(y / Cfg.TILE)
func is_worker() -> bool: return def.get("type", "") == "worker"
func is_combat() -> bool: return not is_worker()

func has_buff(bid: String) -> bool:
	for b in buffs:
		if b["id"] == bid: return true
	return false

func get_buff(bid: String) -> Variant:
	for b in buffs:
		if b["id"] == bid: return b
	return null

func add_buff(bid: String, dur: float, mods: Dictionary) -> Dictionary:
	var ex: Variant = get_buff(bid)
	if ex != null:
		ex["t"] = maxf(ex["t"], dur)
		if not mods.is_empty(): ex["mods"] = mods
		return ex
	var b = {"id": bid, "t": dur, "mods": mods, "source": null, "owner": -1}
	buffs.append(b)
	return b

func remove_buff(bid: String) -> void:
	buffs = buffs.filter(func(b): return b["id"] != bid)

func buff_mul(key: String) -> float:
	var m = 1.0
	for b in buffs:
		if b["mods"].has(key): m *= float(b["mods"][key])
	return m

func buff_add(key: String) -> float:
	var m = 0.0
	for b in buffs:
		if b["mods"].has(key): m += float(b["mods"][key])
	return m

func buff_flag(key: String) -> bool:
	for b in buffs:
		if b["mods"].get(key, false): return true
	return false

func layer(lname: String) -> float:
	return game.map.layer_at_world(lname, x, y)

func on_blight() -> bool: return layer("blight") > 0.3

func on_own_layer() -> bool:
	var a = affinity()
	return a != null and layer(a) > 0.3

func on_hostile_layer() -> bool:
	var a = affinity()
	for l in Cfg.LAYERS:
		if l != a and layer(l) > 0.3: return true
	return false

func stunned() -> bool: return buff_flag("stun")
func invisible() -> bool: return buff_flag("invisible")

## Stats are cached for the current simulation tick (buffs applied mid-tick show up next tick).
func stat(sname: String) -> float:
	if _stat_frame != game.frame:
		_stat_cache.clear(); _stat_frame = game.frame
	var cached = _stat_cache.get(sname)
	if cached != null: return cached
	var v: float
	if game.profiling:
		var _t = Time.get_ticks_usec(); v = _stat_impl(sname); game._pt("  (unit.stat)", _t)
	else: v = _stat_impl(sname)
	_stat_cache[sname] = v
	return v

func _stat_impl(sname: String) -> float:
	var p = player(); var fid = faction_id(); var storm = game.weather["storm"]
	var lvl = (level - 1) if is_hero else 0
	match sname:
		"dmg":
			var d = float(def.get("dmg", 0)) + lvl * 3.0 + p.eff("dmg", "add", self)
			var m = buff_mul("dmgMul")
			if on_own_layer(): m *= 1.1
			if on_hostile_layer(): m *= 0.9
			if on_blight() and fid != "abyss" and game.abyss_tier() >= 3: m *= 0.85
			if fid == "tempest" and storm != null: m *= 1.1
			if fid != "tempest" and storm != null and not flying: m *= 0.9
			return d * m
		"armor":
			return float(def.get("armor", 0)) + (floorf(lvl * 0.5) if is_hero else 0.0) + buff_add("armorAdd") + p.eff("armor", "add", self)
		"speed":
			var s = float(def.get("speed", 3)) * Cfg.TILE * buff_mul("speedMul")
			if on_own_layer(): s *= p.eff("affinitySpeed", "mul", self) * (1.15 if affinity() == "grove" else 1.05)
			if not flying and affinity() != "grove" and layer("grove") > 0.3: s *= 0.85
			if on_blight() and fid != "abyss": s *= 0.9
			if flying: s *= p.eff("flyingSpeed", "mul", self)
			if storm != null:
				if fid == "tempest": s *= (1.3 if p.tier >= 3 else 1.15)
				else: s *= 0.75
			return s
		"cd": return float(def.get("cd", 1)) / buff_mul("atkSpeedMul")
		"range": return float(def.get("range", 1)) * Cfg.TILE
		"sight": return float(def.get("sight", 6)) * Cfg.TILE * (0.8 if (storm != null and fid != "tempest") else 1.0)
		"dmgTaken":
			var m2 = buff_mul("dmgTakenMul")
			if fid == "tempest" and storm != null and p.tier >= 3: m2 *= 0.8
			return m2
		"lifesteal": return float(def.get("lifesteal", 0)) + buff_add("lifesteal") + p.eff("lifesteal", "add", self)
		"regen":
			var rg = buff_add("regen") + p.eff("regen", "add", self)
			if is_hero: rg += 1.0
			if on_own_layer(): rg += 1.5
			return rg
		"maxShield": return max_shield * p.eff("shieldMul", "mul", self)
		"heal": return float(def.get("heal", 0)) * p.eff("healMul", "mul", self)
	return 0.0

func xp_to_level() -> float:
	return 80.0 * level

func gain_xp(v: float) -> void:
	if not is_hero or level >= 10: return
	xp += v
	while xp >= xp_to_level() and level < 10:
		xp -= xp_to_level(); level += 1
		max_hp = float(def["hp"]) + (level - 1) * 35.0; hp = minf(max_hp, hp + 60.0)
		game.add_effect({"type": "text", "x": x, "y": y - 20, "text": "LEVEL " + str(level), "color": "#ffd479", "t": 1.5})
		if owner == game.human: game.msg(name() + " reached level " + str(level), "good")

func can_attack(t) -> bool:
	if t == null or t.dead: return false
	if t.kind == "unit" and t.flying and not def.get("air", false): return false
	if float(def.get("dmg", 0)) <= 0.0: return false
	return true

func dist_to(e) -> float:
	if e.kind == "building":
		return Cfg.dist_to_rect(x, y, e.tx * Cfg.TILE, e.ty * Cfg.TILE, e.w * Cfg.TILE, e.h * Cfg.TILE) - radius
	return Cfg.dist(x, y, e.x, e.y) - radius - e.radius

func in_range(e) -> bool:
	return dist_to(e) <= stat("range") + 4.0
