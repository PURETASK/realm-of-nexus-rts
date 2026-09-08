class_name GPlayer
extends RefCounted

var index = 0
var faction: Dictionary = {}
var faction_id = ""
var is_ai = false
var color = Color.WHITE
var res = {"p": 0.0, "s": 0.0, "c": 0.0}
var tier = 1
var research = {}          # set of research ids (id -> true)
var supply_used = 0
var supply_cap = 0
var hero_cooldowns = {}
var vision = PackedByteArray()   # 0 unseen, 1 explored, 2 visible
var explored = PackedByteArray() # 0 unseen, 1 explored (persistent half of vision)
var lyrian = false               # set each tick: does this player field the hero Lyrian
var reveal = []                  # [{x,y,r,t}]
var income_mul = 1.0
var defeated = false
var kills = 0
var losses = 0
var stats = {"p": 0.0, "s": 0.0}
var buffs = {}                   # id -> remaining seconds

func _init(i: int, fid: String, ai: bool, col: String) -> void:
	index = i; faction_id = fid; faction = GData.factions[fid]; is_ai = ai; color = Color(col)
	var sr: Dictionary = faction.get("startRes", {})
	res = {"p": float(sr.get("p", 0)), "s": float(sr.get("s", 0)), "c": float(sr.get("c", 0))}
	vision.resize(Cfg.MAP_W * Cfg.MAP_H); vision.fill(0)
	explored.resize(Cfg.MAP_W * Cfg.MAP_H); explored.fill(0)

func can_afford(cost) -> bool:
	if cost == null or cost.is_empty(): return true
	return res["p"] >= cost.get("p", 0) and res["s"] >= cost.get("s", 0) and res["c"] >= cost.get("c", 0)

func pay(cost) -> void:
	if cost == null or cost.is_empty(): return
	res["p"] -= cost.get("p", 0); res["s"] -= cost.get("s", 0); res["c"] -= cost.get("c", 0)

func refund(cost) -> void:
	if cost == null or cost.is_empty(): return
	res["p"] += cost.get("p", 0); res["s"] += cost.get("s", 0); res["c"] += cost.get("c", 0)

func has_research(id: String) -> bool:
	return research.has(id)

## Sum (mode "add") or product (mode "mul") of a research effect key, honouring per-unit conditions
func eff(key: String, mode: String, unit = null) -> float:
	var v = 1.0 if mode == "mul" else 0.0
	var rdefs: Dictionary = faction["research"]
	for id in research.keys():
		if not rdefs.has(id): continue
		var e = rdefs[id].get("effect", null)
		if e == null or not e.has(key): continue
		if unit != null:
			if e.get("minTier", 0) > 0 and unit.def.get("tier", 1) < e["minTier"]: continue
			if e.get("undeadOnly", false) and not unit.def.get("undead", false): continue
			if e.get("onAffinity", false) and not unit.on_own_layer(): continue
		if mode == "mul": v *= float(e[key])
		else: v += float(e[key])
	return v

func has_buff(id: String) -> bool:
	return buffs.get(id, 0.0) > 0.0
