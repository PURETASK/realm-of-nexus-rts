class_name Abilities
## Ability implementations for all five factions (metadata comes from data/abilities.json)

static func dmg_mul(g, c) -> float:
	var m = c.player().eff("abilityDmg", "mul")
	if c.kind == "unit" and c.is_hero: m *= 1.0 + (c.level - 1) * 0.08
	return m

static func storm_dur(g, c, base: float) -> float:
	return base * c.player().eff("stormDur", "mul")

static func heal_unit(a, amount: float) -> void:
	if a == null or a.dead or a.kind != "unit": return
	a.hp = minf(a.max_hp, a.hp + amount)
	if a.max_shield > 0: a.shield = minf(a.stat("maxShield"), a.shield + amount * 0.5)

static func heal_any(a, amount_unit: float, amount_building: float) -> void:
	if a.kind == "unit": heal_unit(a, amount_unit)
	else: a.hp = minf(a.max_hp, a.hp + amount_building)

static func ward(g, owner: int, x: float, y: float, t: float, r_tiles: float, kind: String, extra := {}) -> Dictionary:
	var wd = {"owner": owner, "x": x, "y": y, "t": t, "r": r_tiles * Cfg.TILE, "kind": kind, "tick": 0.0}
	for k in extra: wd[k] = extra[k]
	g.wards.append(wd)
	return wd

static func teleport_group(g, allies: Array, x: float, y: float) -> void:
	var i = 0
	for a in allies:
		var ang = i * 2.4; var r = sqrt(i) * 22.0; i += 1
		var nx = x + cos(ang) * r; var ny = y + sin(ang) * r
		if not a.flying:
			var nf: Vector2i = g.map.nearest_free(int(nx / Cfg.TILE), int(ny / Cfg.TILE), false)
			nx = nf.x * Cfg.TILE + Cfg.TILE / 2.0; ny = nf.y * Cfg.TILE + Cfg.TILE / 2.0
		a.x = nx; a.y = ny; a.path = []
		if a.order["type"] == "move" or a.order["type"] == "attackmove": g.clear_order(a)

static func revive_corpses(g, c, x: float, y: float, r: float, max_n: int, hp_frac: float) -> int:
	var n = 0
	for co in g.corpses:
		if co.dead or co.owner != c.owner or Cfg.dist(co.x, co.y, x, y) > r: continue
		var d = GData.unit_def(c.faction(), co.def_id)
		if d.is_empty() or d.get("unique", false): continue
		if c.player().supply_used + int(d.get("supply", 0)) > c.player().supply_cap: break
		co.dead = true
		var u = g.spawn_unit(c.owner, co.def_id, co.x, co.y); u.hp = u.max_hp * hp_frac
		g.add_effect({"type": "ring", "x": co.x, "y": co.y, "r": 24.0, "color": "#fff2b0", "t": 0.8})
		n += 1
		if n >= max_n: break
	if n == 0 and c.owner == g.human: g.msg("No fallen allies nearby to raise", "warn")
	return n

static func nearby_allies(g, c, r_tiles: float) -> Array:
	return g.allies_near(c.owner, c.x, c.y, r_tiles * Cfg.TILE)

static func nearby_enemies(g, c, r_tiles: float, incl := false) -> Array:
	return g.enemies_near(c.owner, c.x, c.y, r_tiles * Cfg.TILE, incl)

static func ring(g, x: float, y: float, r: float, color: String, t := 1.0) -> void:
	g.add_effect({"type": "ring", "x": x, "y": y, "r": r, "color": color, "t": t})

static func burst(g, x: float, y: float, r: float, color: String, t := 0.5) -> void:
	g.add_effect({"type": "burst", "x": x, "y": y, "r": r, "color": color, "t": t})

static func bolt(g, x1: float, y1: float, x2: float, y2: float, color: String, t := 0.3) -> void:
	g.add_effect({"type": "lightning", "x1": x1, "y1": y1, "x2": x2, "y2": y2, "color": color, "t": t})

static func shout(g, c, text: String, color: String) -> void:
	g.add_effect({"type": "text", "x": c.x, "y": c.y - 20, "text": text, "color": color, "t": 1.5})

static func prosperity(g, c, label: String, color: String) -> void:
	g.add_player_buff(c.player(), "prosperity", 20.0); shout(g, c, label, color)

static func step_group(g, c, x: float, y: float, color: String) -> void:
	var al = nearby_allies(g, c, 3.0)
	ring(g, c.x, c.y, 3.0 * Cfg.TILE, color, 0.8)
	teleport_group(g, al, x, y)
	ring(g, x, y, 3.0 * Cfg.TILE, color, 0.8)

static func cast(g, id: String, c, t, x: float, y: float) -> void:
	var m = dmg_mul(g, c)
	var T = Cfg.TILE
	match id:
		# ===== ABYSS =====
		"soulcleaver":
			var dmg: float = c.stat("dmg") * 3.0 * m
			g.add_effect({"type": "slash", "x": t.x, "y": t.y, "color": "#c9a0ff", "t": 0.3, "big": true})
			g.damage(t, dmg, c, "physical")
			if t.dead:
				c.hp = minf(c.max_hp, c.hp + 80.0)
				for a in nearby_allies(g, c, 5.0): a.hp = minf(a.max_hp, a.hp + 30.0)
		"dread_banner":
			ring(g, c.x, c.y, 6 * T, "#8b3cff")
			for a in nearby_allies(g, c, 6.0): a.add_buff("dread_banner", 12.0, {"dmgMul": 1.25, "dmgTakenMul": 0.8})
			for e in nearby_enemies(g, c, 6.0): e.add_buff("dread", 12.0, {"atkSpeedMul": 0.75})
		"sacrificial_surge":
			var cands = nearby_allies(g, c, 4.0).filter(func(a): return not a.is_hero and not a.is_worker())
			if cands.is_empty():
				if c.owner == g.human: g.msg("No lesser unit to sacrifice nearby", "warn")
				c.cooldowns["sacrificial_surge"] = 0.0; return
			cands.sort_custom(func(a, b): return a.def.get("supply", 0) < b.def.get("supply", 0))
			var v = cands[0]; g.kill(v, c, true); c.player().res["p"] += 40.0
			for a in nearby_allies(g, c, 6.0): a.add_buff("surge", 8.0, {"speedMul": 1.4, "dmgMul": 1.3})
			burst(g, v.x, v.y, 40.0, "#ff4b6e")
		"harvest_soul":
			var b = t.add_buff("harvest", 6.0, {"dot": 10.0 * m}); b["source"] = c
			c.player().res["p"] += 30.0
			t.add_buff("curse_undeath", 6.0, {})["owner"] = c.owner
			bolt(g, c.x, c.y, t.x, t.y, "#c9a0ff", 0.4)
		"corruption_ward":
			ward(g, c.owner, x, y, 30.0, 4.0, "corruption"); ring(g, x, y, 4 * T, "#8b3cff")
		"dark_pact":
			if t.kind != "building": c.cooldowns["dark_pact"] = 0.0; return
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.25); t.dark_pact = 20.0; ring(g, t.x, t.y, 40.0, "#ff4b6e")
		"void_bolt":
			bolt(g, c.x, c.y, t.x, t.y, "#8b3cff"); g.damage(t, 90.0 * m, c, "magic")
			var n = 0
			for e in g.enemies_near(c.owner, t.x, t.y, 3 * T):
				if e == t or n >= 3: continue
				n += 1; bolt(g, t.x, t.y, e.x, e.y, "#8b3cff"); g.damage(e, 40.0 * m, c, "magic")
				if e.kind == "unit": e.add_buff("silence", 3.0, {"silence": true})
		"nightmare_veil":
			ward(g, c.owner, x, y, 10.0, 4.0, "veil"); ring(g, x, y, 4 * T, "#2a1050")
		"nether_portal":
			var al = nearby_allies(g, c, 3.0)
			ring(g, c.x, c.y, 3 * T, "#8b3cff", 0.8)
			for e in g.enemies_near(c.owner, x, y, 2.5 * T): e.add_buff("banish", 2.0, {"stun": true, "invisible": true, "dmgTakenMul": 0})
			teleport_group(g, al, x, y); ring(g, x, y, 3 * T, "#8b3cff", 0.8)
		"curse_of_undeath":
			for e in g.enemies_near(c.owner, x, y, 6 * T): e.add_buff("curse_undeath", 12.0, {})["owner"] = c.owner
			ward(g, c.owner, x, y, 12.0, 6.0, "curse"); ring(g, x, y, 6 * T, "#8b3cff", 1.2)
		"sacrifice":
			var cands2 = nearby_allies(g, c, 4.0).filter(func(a): return not a.is_hero)
			if cands2.is_empty():
				if c.owner == g.human: g.msg("No unit near the well to sacrifice", "warn")
				c.cooldowns["sacrifice"] = 0.0; return
			cands2.sort_custom(func(a, b): return (a.def.get("supply", 0) + (1 if a.is_worker() else 0)) < (b.def.get("supply", 0) + (1 if b.is_worker() else 0)))
			var v2 = cands2[0]; g.kill(v2, c, true); c.player().res["p"] += 60.0; burst(g, v2.x, v2.y, 30.0, "#ff4b6e")
		"toggle_convert":
			c.toggles["convert"] = not c.toggles["convert"]
		# ===== TEMPEST =====
		"thunderstrike":
			bolt(g, t.x, t.y - 200, t.x, t.y, "#ffffff"); burst(g, t.x, t.y, 2 * T, "#bfe8ff", 0.4)
			for e in g.enemies_near(c.owner, t.x, t.y, 2 * T, true):
				g.damage(e, (110.0 if e == t else 50.0) * m, c, "magic")
				if e.kind == "unit" and e.def.get("mechanical", false): e.add_buff("stun", 2.0, {"stun": true})
		"wind_rally":
			ring(g, c.x, c.y, 7 * T, "#8fd3ff", 0.8)
			for a in nearby_allies(g, c, 7.0): a.add_buff("wind_rally", storm_dur(g, c, 8.0), {"speedMul": 1.45, "atkSpeedMul": 1.15})
		"eye_of_the_storm":
			ward(g, c.owner, c.x, c.y, storm_dur(g, c, 12.0), 5.0, "eye", {"follow": c})
		"trade_winds":
			g.add_player_buff(c.player(), "trade_winds", 20.0); shout(g, c, "TRADE WINDS", "#8fd3ff")
		"zephyr_ward":
			ward(g, c.owner, x, y, storm_dur(g, c, 15.0), 4.0, "zephyr"); ring(g, x, y, 4 * T, "#8fd3ff")
		"call_of_the_armada":
			for i in range(2):
				var u = g.spawn_unit(c.owner, "thunderhawk", x + randf_range(-30, 30), y + randf_range(-30, 30)); u.lifetime = 60.0
			for i in range(4):
				var u2 = g.spawn_unit(c.owner, "armada_trooper", x + randf_range(-30, 30), y + randf_range(-30, 30)); u2.lifetime = 60.0
			ring(g, x, y, 3 * T, "#8fd3ff"); g.update_supply(c.owner)
		"chain_lightning":
			bolt(g, c.x, c.y, t.x, t.y, "#ffffff"); g.damage(t, 80.0 * m, c, "magic"); g.chain_lightning(c, t, 64.0 * m, 5)
		"cloudburst":
			ward(g, c.owner, x, y, storm_dur(g, c, 10.0), 3.5, "cloud")
			g.weather["cloud"].append({"x": x, "y": y, "r": 3.5 * T, "t": storm_dur(g, c, 10.0), "heavy": false})
			for nd in g.map.nodes:
				if nd["type"] == "primary" and Cfg.dist(nd["x"], nd["y"], x, y) < 3.5 * T:
					nd["amount"] = minf(nd["max"], nd["amount"] + 400.0)
					g.add_effect({"type": "text", "x": nd["x"], "y": nd["y"] - 10, "text": "+400 ore", "color": "#8fd3ff", "t": 1.2})
		"eye_of_clarity":
			c.player().reveal.append({"x": Cfg.WORLD_W / 2, "y": Cfg.WORLD_H / 2, "r": Cfg.WORLD_W, "t": 8.0})
			g.clarity = {"owner": c.owner, "t": 8.0}; g.vision_timer = 0.0; shout(g, c, "EYE OF CLARITY", "#8fd3ff")
		"hurricane_maelstrom":
			ward(g, c.owner, x, y, storm_dur(g, c, 10.0), 6.0, "hurricane")
			g.weather["cloud"].append({"x": x, "y": y, "r": 6 * T, "t": storm_dur(g, c, 10.0), "heavy": true})
		"relocate":
			pass
		"eye_of_auranth":
			g.weather["storm"] = {"until": storm_dur(g, c, 30.0), "owner": c.owner, "tick": 0.0}
			g.msg("THE EYE OF AURANTH OPENS — a storm engulfs the realm!", "good" if c.owner == g.human else "warn")
		# ===== RADIANCE =====
		"sun_smite":
			burst(g, t.x, t.y, 2 * T, "#ffd55a", 0.4)
			for e in g.enemies_near(c.owner, t.x, t.y, 2 * T, true): g.damage(e, (100.0 if e == t else 40.0) * m, c, "magic")
			heal_unit(c, 30.0)
		"rally_of_dawn":
			ring(g, c.x, c.y, 6 * T, "#ffd55a")
			for a in nearby_allies(g, c, 6.0): a.add_buff("rally_dawn", 12.0, {"armorAdd": 2, "dmgMul": 1.2})
		"blinding_flare":
			burst(g, x, y, 4 * T, "#ffffff")
			for e in g.enemies_near(c.owner, x, y, 4 * T): e.add_buff("blind", 5.0, {"dmgMul": 0.5}); e.remove_buff("invisible")
			c.player().reveal.append({"x": x, "y": y, "r": 5 * T, "t": 5.0})
		"judgment_of_the_sun":
			ward(g, c.owner, x, y, 5.0, 4.0, "sunfire", {"source": c, "mul": m}); ring(g, x, y, 4 * T, "#ffd55a")
		"healing_light":
			heal_any(t, 150.0 * (1.0 + (c.level - 1) * 0.1), 100.0); bolt(g, c.x, c.y, t.x, t.y, "#fff2b0")
		"sanctified_ground":
			ward(g, c.owner, x, y, 20.0, 4.0, "sanctify"); ring(g, x, y, 4 * T, "#ffd55a")
		"blessed_tithe":
			prosperity(g, c, "BLESSED TITHE", "#ffd55a")
		"resurrection":
			revive_corpses(g, c, x, y, 5 * T, 5, 0.5); ring(g, x, y, 5 * T, "#fff2b0", 1.2)
		"solar_lance":
			bolt(g, c.x, c.y, t.x, t.y, "#fff7a0"); g.damage(t, 120.0 * m, c, "magic")
			var n2 = 0
			for e in g.enemies_near(c.owner, t.x, t.y, 2.5 * T):
				if e == t or n2 >= 2: continue
				n2 += 1; g.damage(e, 60.0 * m, c, "magic")
		"dawnstrike":
			burst(g, x, y, 3 * T, "#ffe680")
			for e in g.enemies_near(c.owner, x, y, 3 * T, true):
				g.damage(e, 70.0 * m, c, "magic")
				if e.kind == "unit": e.add_buff("blind", 3.0, {"dmgMul": 0.6})
		"light_step":
			step_group(g, c, x, y, "#fff7a0")
		"supernova":
			burst(g, c.x, c.y, 7 * T, "#ffffff", 0.8)
			for e in nearby_enemies(g, c, 7.0, true): g.damage(e, 220.0 * m, c, "magic")
			for a in nearby_allies(g, c, 7.0): heal_unit(a, 100.0)
		"solar_surge":
			for u in g.units(c.owner): u.add_buff("solar_surge", 15.0, {"dmgMul": 1.2})
			g.add_player_buff(c.player(), "solar_surge", 15.0)
			g.msg("Solar Surge! The relay floods the realm with light.", "good" if c.owner == g.human else "warn")
		# ===== VERDANCE =====
		"briar_charge":
			teleport_group(g, [c], t.x + 20, t.y)
			g.add_effect({"type": "slash", "x": t.x, "y": t.y, "color": "#7ee08a", "t": 0.3, "big": true})
			g.damage(t, 110.0 * m, c, "physical")
			if t.kind == "unit": t.add_buff("rooted", 2.0, {"speedMul": 0})
		"bark_skin":
			ring(g, c.x, c.y, 6 * T, "#7ee08a")
			for a in nearby_allies(g, c, 6.0): a.add_buff("bark_skin", 12.0, {"armorAdd": 3, "regen": 2})
		"thorn_burst":
			ward(g, c.owner, x, y, 6.0, 3.0, "vines", {"source": c}); ring(g, x, y, 3 * T, "#4caf50")
		"wrath_of_the_wild":
			for i in range(4):
				var u3 = g.spawn_unit(c.owner, "dire_stag", x + randf_range(-30, 30), y + randf_range(-30, 30)); u3.lifetime = 60.0
			ring(g, x, y, 3 * T, "#7ee08a"); g.update_supply(c.owner)
		"mend":
			heal_any(t, 150.0 * (1.0 + (c.level - 1) * 0.1), 100.0); bolt(g, c.x, c.y, t.x, t.y, "#8fffa0")
		"seed_the_land":
			ward(g, c.owner, x, y, 30.0, 4.0, "grove"); ring(g, x, y, 4 * T, "#7ee08a")
		"bountiful_harvest":
			prosperity(g, c, "BOUNTIFUL HARVEST", "#7ee08a")
		"bloom_of_life":
			ward(g, c.owner, c.x, c.y, 8.0, 8.0, "bloom", {"follow": c}); ring(g, c.x, c.y, 8 * T, "#c8ffd0", 1.2)
		"spirit_bolt":
			bolt(g, c.x, c.y, t.x, t.y, "#a8ffb0"); g.damage(t, 90.0 * m, c, "magic"); g.chain_lightning(c, t, 50.0 * m, 2)
		"entangle":
			ward(g, c.owner, x, y, 8.0, 4.0, "vines", {"source": c}); ring(g, x, y, 4 * T, "#4caf50")
		"spirit_walk":
			step_group(g, c, x, y, "#a8ffb0")
		"everwood_awakening":
			for i in range(6):
				var u4 = g.spawn_unit(c.owner, "everwood_spirit", c.x + randf_range(-40, 40), c.y + randf_range(-40, 40)); u4.lifetime = 45.0
			ring(g, c.x, c.y, 3 * T, "#a8ffb0"); g.update_supply(c.owner)
		"waystep":
			if t == null or t.kind != "building" or t.def_id != "sylvan_waystone" or t == c or not t.complete():
				if c.owner == g.human: g.msg("Target another completed Sylvan Waystone", "warn")
				c.cooldowns["waystep"] = 0.0; return
			var al2 = nearby_allies(g, c, 3.0)
			if al2.is_empty(): c.cooldowns["waystep"] = 0.0; return
			ring(g, c.x, c.y, 3 * T, "#9fffe0", 0.8); teleport_group(g, al2, t.x, t.y + 1.5 * T); ring(g, t.x, t.y, 3 * T, "#9fffe0", 0.8)
		# ===== SANCTUARY =====
		"holy_strike":
			var dmg2: float = c.stat("dmg") * 3.0 * m * (2.0 if t.def.get("undead", false) else 1.0)
			g.add_effect({"type": "slash", "x": t.x, "y": t.y, "color": "#fff7d0", "t": 0.3, "big": true})
			g.damage(t, dmg2, c, "magic"); c.shield = minf(c.stat("maxShield"), c.shield + 40.0)
		"shield_wall":
			ring(g, c.x, c.y, 6 * T, "#9fe0ff")
			for a in nearby_allies(g, c, 6.0):
				a.add_buff("shield_wall", 12.0, {"dmgTakenMul": 0.8}); a.shield = minf(a.stat("maxShield") + 80.0, a.shield + 80.0)
		"banner_of_order":
			ring(g, c.x, c.y, 6 * T, "#fff7d0")
			for a in nearby_allies(g, c, 6.0): a.add_buff("banner_order", 12.0, {"dmgMul": 1.2})
			for e in nearby_enemies(g, c, 6.0): e.add_buff("order_awe", 12.0, {"atkSpeedMul": 0.75})
		"divine_intervention":
			ring(g, c.x, c.y, 7 * T, "#ffffff", 1.2)
			for a in nearby_allies(g, c, 7.0): a.add_buff("intervention", 4.0, {"dmgTakenMul": 0})
		"mend_wounds":
			if t.kind == "unit":
				heal_unit(t, 160.0 * (1.0 + (c.level - 1) * 0.1)); t.shield = t.stat("maxShield")
			else: t.hp = minf(t.max_hp, t.hp + 100.0)
			bolt(g, c.x, c.y, t.x, t.y, "#fff7d0")
		"consecrate":
			ward(g, c.owner, x, y, 20.0, 4.0, "sanctify"); ring(g, x, y, 4 * T, "#fff7d0")
		"tithe_of_faith":
			prosperity(g, c, "TITHE OF FAITH", "#fff7d0")
		"mass_resurrection":
			revive_corpses(g, c, x, y, 5 * T, 5, 0.5); ring(g, x, y, 5 * T, "#fff7d0", 1.2)
		"smite":
			var mm: float = m * (1.5 if t.def.get("undead", false) else 1.0)
			bolt(g, t.x, t.y - 200, t.x, t.y, "#fff7d0"); g.damage(t, 110.0 * mm, c, "magic")
		"banish_corruption":
			var mp: GMap = g.map; var cx = int(x / T); var cy = int(y / T)
			for ty in range(cy - 4, cy + 5):
				for tx in range(cx - 4, cx + 5):
					if mp.in_bounds(tx, ty) and Cfg.dist(tx, ty, cx, cy) <= 4: mp.layers["blight"][mp.idx(tx, ty)] = 0.0
			for e in g.enemies_near(c.owner, x, y, 4 * T):
				e.buffs = e.buffs.filter(func(b): return b["mods"].has("dot") or b["mods"].has("stun") or b["mods"].has("silence"))
				if e.def.get("undead", false): g.damage(e, 80.0 * m, c, "magic")
			ward(g, c.owner, x, y, 10.0, 4.0, "sanctify"); burst(g, x, y, 4 * T, "#ffffff", 0.6)
		"celestial_step":
			step_group(g, c, x, y, "#fff7d0")
		"wrath_of_heaven":
			ward(g, c.owner, x, y, 5.0, 5.0, "heaven", {"source": c, "mul": m}); ring(g, x, y, 5 * T, "#fff7d0")
		"toll_the_bell":
			for u in g.units(c.owner): u.add_buff("bell_toll", 15.0, {"dmgMul": 1.2, "speedMul": 1.15})
			g.msg("The Eternal Bell tolls! The faithful rally.", "good" if c.owner == g.human else "warn")
		_:
			push_warning("Unknown ability " + id)
