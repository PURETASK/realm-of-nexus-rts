class_name Building
extends RefCounted
## A structure (mirrors js/entities.js Building)

var id = 0
var kind = "building"
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
var tx = 0
var ty = 0
var w = 1
var h = 1
var progress = 0.0
var build_time = 1.0
var queue = []          # [{type, id, time, elapsed, cost}]
var rally = null         # Vector2 or null
var cooldowns = {}
var attack_timer = 0.0
var toggles = {"convert": true}
var spawn_timer = 0.0
var catalyst_timer = 0.0
var relocate = null      # Dictionary or null
var node = null
var builders = 0
var radius = 16.0
var dark_pact = 0.0
var flying = false

func _init(g, own: int, did: String, ptx: int, pty: int, complete: bool) -> void:
	game = g; owner = own; def_id = did
	id = g.next_id()
	def = faction()["buildings"][did]
	tx = ptx; ty = pty; w = int(def.get("w", 1)); h = int(def.get("h", 1))
	x = (tx + w / 2.0) * Cfg.TILE; y = (ty + h / 2.0) * Cfg.TILE
	max_hp = float(def.get("hp", 100))
	hp = max_hp if complete else maxf(1.0, max_hp * 0.1)
	progress = 1.0 if complete else 0.0
	build_time = maxf(1.0, float(def.get("time", 1)))
	radius = maxi(w, h) * Cfg.TILE / 2.0

func player() -> GPlayer: return game.players[owner]
func faction() -> Dictionary: return game.players[owner].faction
func faction_id() -> String: return game.players[owner].faction_id
func affinity(): return faction().get("affinity", null)

func name() -> String:
	if def.get("isBase", false):
		return faction()["tiers"][player().tier - 1]["name"]
	return def.get("name", def_id)

func complete() -> bool: return progress >= 1.0
func invisible() -> bool: return bool(def.get("invisible", false))
func is_worker() -> bool: return false
func is_hero() -> bool: return false

func stat(sname: String) -> float:
	if sname == "armor": return float(def.get("armor", 0)) + player().eff("structArmor", "add")
	if sname == "sight": return float(def.get("sight", 6)) * Cfg.TILE
	return 0.0

func tower_dmg() -> float:
	var tw: Dictionary = def.get("tower", {})
	var d = float(tw.get("dmg", 0))
	if def.get("isBase", false) and faction_id() == "tempest":
		d = [8.0, 12.0, 30.0][player().tier - 1]
	d *= player().eff("towerDmg", "mul")
	if player().has_buff("solar_surge"): d *= 1.5
	if faction_id() == "tempest" and game.weather["storm"] != null: d *= 1.25
	var a = affinity()
	if a != null and game.map.layer_at_world(a, x, y) > 0.3 and tw.has("layerBonus"): d *= float(tw["layerBonus"])
	return d

func tower_range() -> float:
	var tw: Dictionary = def.get("tower", {})
	var r = float(tw.get("range", 0))
	if tw.get("blightRange", 0) > 0 and game.map.corruption_at_world(x, y) > 0.3: r += float(tw["blightRange"])
	return r * Cfg.TILE

func dist_to(e) -> float:
	if e.kind == "building":
		return Cfg.dist(x, y, e.x, e.y) - radius - e.radius
	return Cfg.dist_to_rect(e.x, e.y, tx * Cfg.TILE, ty * Cfg.TILE, w * Cfg.TILE, h * Cfg.TILE) - e.radius
