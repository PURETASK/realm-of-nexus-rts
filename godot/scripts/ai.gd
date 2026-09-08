class_name AIController
extends RefCounted
## AI opponent (mirrors js/ai.js)

const BUILD_ORDERS := {
	"abyss": [
		{"b": "soul_well", "node": "primary"}, {"b": "grim_crypt"}, {"b": "occult_den"}, {"b": "soul_well", "node": "primary"}, {"b": "soul_obelisk"},
		{"b": "grim_crypt"}, {"b": "corruption_spire"}, {"tier": 2}, {"b": "corruption_crucible"}, {"b": "necromancer_spire"}, {"b": "flesh_forge"},
		{"b": "soul_obelisk"}, {"b": "reliquary"}, {"b": "soul_well", "node": "primary"}, {"b": "grim_crypt"}, {"tier": 3}, {"b": "void_gate"}, {"b": "cathedral_of_decay"}, {"b": "flesh_forge"}],
	"tempest": [
		{"b": "aetherforge", "node": "primary"}, {"b": "gale_barracks"}, {"b": "aetherforge", "node": "primary"}, {"b": "stormcall_tower"}, {"b": "aerie"},
		{"b": "stormcall_array", "node": "secondary"}, {"b": "aetherforge", "node": "primary"}, {"b": "thunderhead_tower"}, {"b": "gale_barracks"}, {"tier": 2},
		{"b": "tempest_forge"}, {"b": "stratosanct"}, {"b": "cyclone_totem"}, {"b": "aetherforge", "node": "primary"}, {"b": "aerie"}, {"tier": 3},
		{"b": "stormseer_conclave"}, {"b": "celestial_bastion"}, {"b": "maelstrom_altar"}],
	"radiance": [
		{"b": "sunstone_vault", "node": "primary"}, {"b": "solar_crucible"}, {"b": "radiant_shrine"}, {"b": "sunstone_vault", "node": "primary"}, {"b": "blazing_bastion"},
		{"b": "solar_crucible"}, {"b": "dawnwatch_beacon"}, {"tier": 2}, {"b": "heliarch_spire"}, {"b": "phoenix_roost"},
		{"b": "blazing_bastion"}, {"b": "sunstone_vault", "node": "primary"}, {"b": "solar_relay"}, {"b": "pyrestorm_battery"}, {"tier": 3}, {"b": "solar_crucible"}, {"b": "phoenix_roost"}],
	"verdance": [
		{"b": "groveheart_nexus", "node": "primary"}, {"b": "bloomforge"}, {"b": "verdant_sigil_hall"}, {"b": "groveheart_nexus", "node": "primary"}, {"b": "rootwarden_bastion"},
		{"b": "sapwood_granary"}, {"b": "bloomforge"}, {"tier": 2}, {"b": "cycle_sanctuary"}, {"b": "spirit_tree"}, {"b": "wild_den"},
		{"b": "rootwarden_bastion"}, {"b": "groveheart_nexus", "node": "primary"}, {"b": "sylvan_waystone"}, {"tier": 3}, {"b": "world_seed_altar"}, {"b": "spirit_tree"}],
	"sanctuary": [
		{"b": "sanctified_vault", "node": "primary"}, {"b": "beaconwright_hall"}, {"b": "sacrosanct_shrine"}, {"b": "sanctified_vault", "node": "primary"}, {"b": "radiant_tower"},
		{"b": "beaconwright_hall"}, {"b": "lightborne_relay"}, {"tier": 2}, {"b": "hall_of_luminaries"}, {"b": "concord_hall"}, {"b": "griffin_aerie"},
		{"b": "radiant_tower"}, {"b": "sanctified_vault", "node": "primary"}, {"b": "eternal_bell_spire"}, {"b": "siege_chapel"}, {"tier": 3}, {"b": "altar_of_tears"}, {"b": "hall_of_luminaries"}],
}
const RESEARCH := {
	"abyss": ["dark_blessing", "necrotic_armor", "blight_plague", "grave_march", "vampiric_relics", "death_fog"],
	"tempest": ["stormsteel_weapons", "static_shield", "forecast", "lightweight_alloy", "overcharge", "tribute_efficiency", "storm_amplification"],
	"radiance": ["blessed_steel", "sunforged_plate", "daybreak", "phoenix_fire", "radiant_wards", "eternal_dawn"],
	"verdance": ["sharpened_thorns", "ironbark", "wild_growth", "symbiosis", "deep_roots", "everwood_blessing"],
	"sanctuary": ["blessed_arms", "aegis_plating", "greater_wards", "divine_favor", "sanctified_walls", "martyrdom"],
}
const HERO_ORDER := {"abyss": ["tyvaris", "malazar", "neratha"], "tempest": ["rykan", "alyssia", "lyrian"], "radiance": ["aurelian", "solaris", "seraphine"], "verdance": ["kael", "sylvara", "elowen"], "sanctuary": ["isolde", "cassiel", "adaline"]}
const ECON_ABILITIES := ["trade_winds", "blessed_tithe", "bountiful_harvest", "tithe_of_faith"]
const HEAL_ABILITIES := ["healing_light", "mend", "mend_wounds"]

var g
var owner = 0
var p: GPlayer
var f: Dictionary
var fid = ""
var timer = 0.0
var order_idx = 0
var mode = "build"
var attack_group = []
var attack_start = 0.0
var attack_supply = 0.0
var attack_target = null
var next_attack_supply = 0.0
var last_defend = 0.0
var ability_timer = 0.0
var worker_target = 4
var reserve = 0.0        # primary resource kept back for the current build-order step (tier upgrade or building)

## How much primary resource to keep in the bank for the current step. A tier upgrade reserves its full cost
## once a small army exists; a building reserves its cost once the army is a bit larger.
func compute_reserve(step, army_supply: float) -> float:
	if step == null or mode == "defend": return 0.0
	if step.has("tier"):
		var tc: Dictionary = f["tiers"][int(step["tier"]) - 1].get("cost", {})
		return float(tc.get("p", 0)) if (army_supply >= 8 or g.time > 300) else 0.0
	var bc: Dictionary = f["buildings"][step["b"]].get("cost", {})
	if army_supply < 12: return 0.0
	return float(bc.get("p", 0)) * (0.5 if g.time > 480 else 1.0)

func current_step():
	var order: Array = BUILD_ORDERS[fid]
	return order[order_idx] if order_idx < order.size() else null

func _init(game, own: int) -> void:
	g = game; owner = own; p = game.players[own]; f = p.faction; fid = p.faction_id
	next_attack_supply = float(g.difficulty["attackSupply"])
	worker_target = 9 if f.get("gathers", false) else 4

func update(dt: float) -> void:
	if p.defeated: return
	ability_timer -= dt
	if ability_timer <= 0.0:
		ability_timer = 1.2; use_abilities()
	timer -= dt
	if timer > 0.0: return
	timer = 1.0 * float(g.difficulty["buildDelay"]) + 0.3
	var base = g.base_of(owner)
	if base == null: return
	var army_supply = 0.0
	for u in army(): army_supply += float(u.def.get("supply", 0))
	reserve = compute_reserve(current_step(), army_supply)
	manage_workers(base)
	manage_production(base)
	manage_build(base)
	manage_army(base)

func workers() -> Array:
	return g.units(owner).filter(func(u): return u.is_worker())

func army() -> Array:
	return g.units(owner).filter(func(u): return not u.is_worker())

func manage_workers(base) -> void:
	var ws = workers()
	var saving_for_tier = current_step() != null and current_step().has("tier") and reserve > 0.0
	var want = worker_target if not saving_for_tier else int(worker_target * 0.6)
	if ws.size() < want and base.queue.is_empty() and g.can_queue(base, {"type": "unit", "id": f["worker"]})["ok"]:
		g.enqueue(base, {"type": "unit", "id": f["worker"]})
	if f.get("gathers", false):
		for w in ws:
			if w.order["type"] == "idle":
				var nd = g.nearest_node(w, "primary")
				if nd != null: g.order_gather([w], nd)

func manage_build(base) -> void:
	var order: Array = BUILD_ORDERS[fid]
	var ws = workers()
	var incomplete = g.buildings(owner).filter(func(b): return not b.complete())
	for b in incomplete:
		var has_builder = false
		for w in ws:
			if w.build_task == b: has_builder = true
		if not has_builder:
			var w = free_worker(ws)
			if w != null:
				g.clear_order(w); w.order = {"type": "build", "building": b}; w.build_task = b; g.set_path(w, b.x, b.y)
	if incomplete.size() >= 2: return
	var step = order[order_idx] if order_idx < order.size() else null
	if step == null:
		var opts = []
		for id in f["buildings"]:
			var d: Dictionary = f["buildings"][id]
			if d.get("isBase", false) or d.has("needsNode") or d.get("wall", false) or d.get("mine", false) or d.get("tier", 1) > p.tier: continue
			if d.has("trains") or (d.has("tower") and d["tower"].get("dmg", 0) > 0): opts.append(id)
		if opts.is_empty() or g.buildings(owner).size() > 26: return
		step = {"b": opts.pick_random()}
	if step.has("tier"):
		if p.tier >= int(step["tier"]): order_idx += 1; return
		var c = g.can_queue(base, {"type": "tier"})
		if c["ok"]:
			if base.queue.size() < 2:
				g.enqueue(base, {"type": "tier"}); order_idx += 1
		elif c["why"].begins_with("Requires"):
			# the prerequisite structure is missing (or still under construction): build it, never skip the tier
			var req: String = f["tiers"][p.tier].get("requires", "")
			if req != "" and not owns_building(req): try_build(req, base, ws, null)
		return
	var bid: String = step["b"]
	var d2: Dictionary = f["buildings"][bid]
	if d2.get("tier", 1) > p.tier:
		var c2 = g.can_queue(base, {"type": "tier"})
		if c2["ok"] and base.queue.size() < 2: g.enqueue(base, {"type": "tier"})
		elif c2["why"].begins_with("Requires"):
			var req2: String = f["tiers"][p.tier].get("requires", "")
			if req2 != "" and not owns_building(req2): try_build(req2, base, ws, null)
		return
	var result = try_build(bid, base, ws, step.get("node", null))
	if result == "built" or result == "nospot": order_idx += 1

func owns_building(bid: String) -> bool:
	for b in g.buildings(owner):
		if b.def_id == bid: return true
	for b in g.buildings(owner):
		for w in workers():
			if w.build_task == b and b.def_id == bid: return true
	return false

## Tries to start a building. Returns "built", "wait" (money or worker), or "nospot".
func try_build(bid: String, base, ws: Array, node_type) -> String:
	var d2: Dictionary = f["buildings"][bid]
	if not p.can_afford(d2.get("cost", {})): return "wait"
	var w2 = free_worker(ws)
	if w2 == null: return "wait"
	var spot = null
	if node_type == null and d2.has("needsNode"): node_type = d2["needsNode"]
	if node_type != null: spot = find_node_spot(node_type, base)
	else: spot = find_spot(bid, d2, base, "front" if (d2.has("tower") or d2.has("aura")) else "back")
	if spot == null: return "nospot"
	return "built" if g.order_build([w2], bid, spot.x, spot.y) != null else "wait"

func free_worker(ws: Array) -> Variant:
	for w in ws:
		if w.order["type"] == "idle": return w
	for w in ws:
		if w.order["type"] == "gather" and w.gather["phase"] != "toDrop": return w
	for w in ws:
		if w.order["type"] != "build": return w
	return null

func find_node_spot(type: String, base) -> Variant:
	var bid = f["nodeBuilding"].get(type, null)
	if bid == null: return null
	var nodes = g.map.nodes.filter(func(nd): return nd["type"] == type and nd["building"] == null and nd["amount"] > 0 and g.can_place(owner, bid, nd["tx"], nd["ty"]))
	nodes.sort_custom(func(a, b): return Cfg.dist(a["x"], a["y"], base.x, base.y) < Cfg.dist(b["x"], b["y"], base.x, base.y))
	if nodes.is_empty(): return null
	var nd: Dictionary = nodes[0]
	if Cfg.dist(nd["x"], nd["y"], base.x, base.y) > (40 if type == "secondary" else 26) * Cfg.TILE: return null
	return Vector2i(nd["tx"], nd["ty"])

func find_spot(bid: String, d: Dictionary, base, pref: String):
	var enemy_base = g.base_of(1 - owner)
	var dirx = signf(enemy_base.x - base.x) if enemy_base != null else -1.0
	var diry = signf(enemy_base.y - base.y) if enemy_base != null else -1.0
	var best = null; var bs = INF
	var bw = int(d.get("w", 1)); var bh = int(d.get("h", 1))
	for r in range(3, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r: continue
				if randf() < 0.5: continue
				var tx: int = base.tx + dx; var ty: int = base.ty + dy
				if not g.can_place(owner, bid, tx, ty): continue
				if not g.map.area_free(tx - 1, ty - 1, bw + 2, bh + 2, true): continue
				var score = float(r)
				if pref == "front": score -= (dx * dirx + dy * diry) * 0.6
				else: score += (dx * dirx + dy * diry) * 0.3
				if score < bs: bs = score; best = Vector2i(tx, ty)
		if best != null and r > 5: return best
	return best

## Secondary resource the current build-order step still needs (0 when the step has no secondary cost)
func step_secondary_need() -> float:
	var step = current_step()
	if step == null: return 0.0
	var cost: Dictionary = f["tiers"][int(step["tier"]) - 1].get("cost", {}) if step.has("tier") else f["buildings"][step["b"]].get("cost", {})
	return float(cost.get("s", 0))

func manage_production(base) -> void:
	var need_s = step_secondary_need()
	for h in HERO_ORDER[fid]:
		var have = false
		for x in g.heroes(owner):
			if x.def_id == h: have = true
		if have: continue
		var hcost = float(f["heroes"][h].get("cost", {}).get("p", 0))
		if g.heroes(owner).size() > 0 and p.res["p"] - hcost < reserve: break
		if base.queue.is_empty() and g.can_queue(base, {"type": "hero", "id": h})["ok"]: g.enqueue(base, {"type": "hero", "id": h})
		break
	for b in g.buildings(owner):
		if not b.complete() or not b.queue.is_empty() or not b.def.has("research"): continue
		for rid in RESEARCH[fid]:
			if not b.def["research"].has(rid): continue
			if p.res["p"] - float(f["research"][rid].get("cost", {}).get("p", 0)) < reserve: continue
			if p.res["s"] - float(f["research"][rid].get("cost", {}).get("s", 0)) < need_s: continue
			if g.can_queue(b, {"type": "research", "id": rid})["ok"] and randf() < 0.5:
				g.enqueue(b, {"type": "research", "id": rid}); break
	for b in g.buildings(owner):
		if not b.complete() or not b.def.has("trains") or b.def.get("isBase", false) or b.queue.size() >= 2: continue
		var opts = []
		for id in b.def["trains"]:
			if f["units"].has(id):
				var d: Dictionary = f["units"][id]
				if d.get("tier", 1) <= p.tier and not d.get("unique", false): opts.append(id)
		if opts.is_empty(): continue
		var pick: String = opts[opts.size() - 1] if (p.res["p"] > 600 or randf() < 0.6) else opts.pick_random()
		var d2: Dictionary = f["units"][pick]
		if p.res["p"] - float(d2.get("cost", {}).get("p", 0)) < reserve and g.time > 90: continue
		var us = float(d2.get("cost", {}).get("s", 0))
		if us > 0.0 and current_step() != null and current_step().has("tier") and p.res["s"] - us < need_s: continue
		if g.can_queue(b, {"type": "unit", "id": pick})["ok"]: g.enqueue(b, {"type": "unit", "id": pick})
	if p.res["c"] >= 1.0:
		if fid == "abyss":
			for b in g.buildings(owner):
				if b.def_id == "cathedral_of_decay" and b.complete() and b.queue.is_empty() and g.can_queue(b, {"type": "unit", "id": "deathlord"})["ok"]:
					g.enqueue(b, {"type": "unit", "id": "deathlord"}); break
		elif fid == "tempest":
			for b in g.buildings(owner):
				if b.def_id == "maelstrom_altar" and b.complete() and mode == "attack" and g.weather["storm"] == null:
					g.building_cast(b, "eye_of_auranth"); break
		else:
			for b in g.buildings(owner):
				if b.complete() and b.def.has("catalystGen") and b.def.has("trains") and b.queue.is_empty():
					for uid in b.def["trains"]:
						if f["units"][uid].get("unique", false) and g.can_queue(b, {"type": "unit", "id": uid})["ok"]:
							g.enqueue(b, {"type": "unit", "id": uid}); break
	if mode == "attack":
		for b in g.buildings(owner):
			if b.complete() and b.def.has("abilities"):
				for id in b.def["abilities"]:
					if (id == "solar_surge" or id == "toll_the_bell") and b.cooldowns.get(id, 0.0) <= 0.0: g.building_cast(b, id)
	for b in g.buildings(owner):
		if b.def.has("converter"): b.toggles["convert"] = p.res["p"] > 250 or (need_s > p.res["s"] and p.res["p"] > 120)
	if fid == "abyss" and p.res["p"] < 80 and army().size() > 20:
		for b in g.buildings(owner):
			if b.def_id == "soul_well" and b.complete() and b.cooldowns.get("sacrifice", 0.0) <= 0.0: g.building_cast(b, "sacrifice"); break

func manage_army(base) -> void:
	var ar = army()
	var enemy_base = g.base_of(1 - owner)
	var supply = 0.0
	for u in ar: supply += float(u.def.get("supply", 0))
	supply += g.heroes(owner).size() * 3
	var threats = g.enemies_near(owner, base.x, base.y, 14 * Cfg.TILE, false)
	var under_attack = []
	for b in g.buildings(owner):
		if not g.enemies_near(owner, b.x, b.y, 8 * Cfg.TILE).is_empty(): under_attack.append(b)
	if (not threats.is_empty() or not under_attack.is_empty()) and mode != "attack":
		var tgt = threats[0] if not threats.is_empty() else null
		if tgt == null:
			var en = g.enemies_near(owner, under_attack[0].x, under_attack[0].y, 8 * Cfg.TILE)
			if not en.is_empty(): tgt = en[0]
		if tgt != null and g.time - last_defend > 3.0:
			last_defend = g.time
			g.order_move(ar.filter(func(u): return u.order["type"] != "attack"), tgt.x, tgt.y, true)
		mode = "defend"
		return
	var fx = base.x + (signf(enemy_base.x - base.x) if enemy_base != null else 0.0) * 5 * Cfg.TILE
	var fy = base.y + (signf(enemy_base.y - base.y) if enemy_base != null else 0.0) * 5 * Cfg.TILE
	if mode == "defend" and threats.is_empty():
		mode = "build"; g.order_move(ar, fx, fy, true)
	if mode == "build":
		var idle = ar.filter(func(u): return u.order["type"] == "idle" and Cfg.dist(u.x, u.y, base.x, base.y) > 9 * Cfg.TILE)
		if not idle.is_empty(): g.order_move(idle, fx, fy, true)
		var threshold = next_attack_supply if g.time < 900 else minf(next_attack_supply, 14.0)
		if supply >= threshold and enemy_base != null and g.time >= float(g.difficulty["firstAttack"]):
			mode = "attack"; attack_group = ar.duplicate(); attack_start = g.time; attack_supply = supply
			var eb = g.buildings(1 - owner).filter(func(b): return g.time > 600 or not b.def.get("isBase", false))
			eb.sort_custom(func(a, b): return Cfg.dist(a.x, a.y, base.x, base.y) < Cfg.dist(b.x, b.y, base.x, base.y))
			var tgt2 = eb[0] if not eb.is_empty() else enemy_base
			g.order_move(ar, tgt2.x, tgt2.y, true)
			attack_target = tgt2
			next_attack_supply += float(g.difficulty["attackGrowth"])
	elif mode == "attack":
		var alive = attack_group.filter(func(u): return not u.dead)
		var cur = 0.0
		for u in alive: cur += float(u.def.get("supply", 0)) + (3.0 if u.is_hero else 0.0)
		if cur < attack_supply * 0.35 or g.time - attack_start > 150:
			mode = "build"; g.order_move(alive, base.x, base.y + 3 * Cfg.TILE, true); return
		if attack_target == null or attack_target.dead:
			var eb2 = g.buildings(1 - owner)
			if eb2.is_empty(): return
			var rx: float = alive[0].x if not alive.is_empty() else base.x
			var ry: float = alive[0].y if not alive.is_empty() else base.y
			eb2.sort_custom(func(a, b): return Cfg.dist(a.x, a.y, rx, ry) < Cfg.dist(b.x, b.y, rx, ry))
			attack_target = eb2[0]; g.order_move(alive, eb2[0].x, eb2[0].y, true)
		else:
			var idle2 = alive.filter(func(u): return u.order["type"] == "idle")
			if not idle2.is_empty(): g.order_move(idle2, attack_target.x, attack_target.y, true)
		for u in ar:
			if not attack_group.has(u) and u.order["type"] == "idle":
				attack_group.append(u)
				if attack_target != null: g.order_move([u], attack_target.x, attack_target.y, true)

func use_abilities() -> void:
	for h in g.heroes(owner):
		var enemies = g.enemies_near(owner, h.x, h.y, 7 * Cfg.TILE, true)
		var eu = enemies.filter(func(e): return e.kind == "unit")
		for id in h.abilities:
			var ab: Dictionary = GData.abilities.get(id, {})
			if ab.is_empty() or ab.get("passive", false): continue
			if not g.can_cast(h, id)["ok"]: continue
			var best = null; var bn = 0
			for e in eu:
				var n = g.enemies_near(owner, e.x, e.y, 3 * Cfg.TILE).size()
				if n > bn: bn = n; best = e
			var in_range: bool = best != null and h.dist_to(best) <= float(ab.get("range", 0)) * Cfg.TILE + 20
			var is_ult: bool = ab.get("ult", false)
			match ab.get("target", "none"):
				"enemy":
					if best != null and in_range and (not is_ult or bn >= 3): g.cast_ability(h, id, best, best.x, best.y)
				"point":
					if id == "nether_portal":
						if best != null and h.hp < h.max_hp * 0.35:
							var b = g.base_of(owner)
							if b != null: g.cast_ability(h, id, null, h.x + (b.x - h.x) * 0.5, h.y + (b.y - h.y) * 0.5)
					elif id == "call_of_the_armada":
						if best != null and bn >= 3: g.cast_ability(h, id, null, best.x, best.y)
					elif id == "corruption_ward" or id == "zephyr_ward":
						if eu.size() >= 2: g.cast_ability(h, id, null, h.x, h.y)
					elif best != null and in_range and (not is_ult or bn >= 4): g.cast_ability(h, id, null, best.x, best.y)
				"none":
					if id == "eye_of_clarity" or ECON_ABILITIES.has(id):
						if g.time > 120: g.cast_ability(h, id, null, h.x, h.y)
					elif id == "sacrificial_surge":
						if eu.size() >= 4 and g.allies_near(owner, h.x, h.y, 4 * Cfg.TILE).size() > 4: g.cast_ability(h, id, null, h.x, h.y)
					elif eu.size() >= (4 if is_ult else 2): g.cast_ability(h, id, null, h.x, h.y)
				"ally":
					if id == "dark_pact":
						for bb in g.buildings(owner):
							if not bb.queue.is_empty() and Cfg.dist(bb.x, bb.y, h.x, h.y) < 6 * Cfg.TILE and h.hp > h.max_hp * 0.6:
								g.cast_ability(h, id, bb, bb.x, bb.y); break
					elif HEAL_ABILITIES.has(id):
						var w = null; var wr = 0.6
						for a in g.allies_near(owner, h.x, h.y, float(ab.get("range", 6)) * Cfg.TILE):
							if a.hp / a.max_hp < wr: wr = a.hp / a.max_hp; w = a
						if w != null: g.cast_ability(h, id, w, w.x, w.y)
