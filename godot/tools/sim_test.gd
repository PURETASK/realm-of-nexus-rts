extends SceneTree
## Headless smoke test: runs AI-vs-AI matches and an ability sweep, writes results to res://sim_result.txt
##   godot --headless --path godot -s tools/sim_test.gd

func _init() -> void:
	var out = []
	var T0 = Time.get_ticks_msec()
	GData.load_all()
	printerr("[%d ms] data loaded" % (Time.get_ticks_msec() - T0))
	out.append("factions: " + ", ".join(GData.faction_ids()) + " | abilities: " + str(GData.abilities.size()))
	# ability sweep
	var g = Game.new({"playerFaction": "radiance", "aiFaction": "abyss", "difficulty": "normal", "seed": 42})
	for p in g.players:
		p.res = {"p": 9999.0, "s": 9999.0, "c": 2.0}; p.tier = 3
	var base = g.base_of(0)
	var hx: float = base.x + 9 * Cfg.TILE; var hy: float = base.y - 5 * Cfg.TILE
	var dummies = []
	for i in range(5):
		var d = g.spawn_unit(1, "skeleton_warrior", hx + 4 * Cfg.TILE + randf_range(-40, 40), hy + randf_range(-40, 40))
		d.max_hp = 5000.0; d.hp = 5000.0; g.clear_order(d); d.hold_pos = true; d.order = {"type": "hold"}; dummies.append(d)
	var cast_ok = 0; var cast_fail = []
	for fid in ["radiance", "verdance", "sanctuary", "abyss", "tempest"]:
		printerr("[%d ms] sweep %s" % [Time.get_ticks_msec() - T0, fid])
		g.players[0].faction = GData.factions[fid]; g.players[0].faction_id = fid; g.players[0].research = {}
		for hid in GData.factions[fid]["heroes"]:
			var h = g.spawn_unit(0, hid, hx + randf_range(-20, 20), hy + randf_range(-20, 20)); h.level = 6; h.max_hp = 5000.0; h.hp = 2500.0
			printerr("[%d ms]   hero %s" % [Time.get_ticks_msec() - T0, hid])
			for aid in h.abilities:
				var ab: Dictionary = GData.abilities[aid]
				if ab.get("passive", false): continue
				var t = dummies[0]
				var tgt = t if ab["target"] == "enemy" else ((h if (aid.contains("mend") or aid.contains("healing")) else base) if ab["target"] == "ally" else null)
				var ok = g.cast_ability(h, aid, tgt, t.x, t.y)
				if ok: cast_ok += 1
				else: cast_fail.append(fid + "." + aid)
				for k in range(20): g.update(1.0 / 30.0)
		for bid in GData.factions[fid]["buildings"]:
			var bd: Dictionary = GData.factions[fid]["buildings"][bid]
			if not bd.has("abilities"): continue
			printerr("[%d ms]   building %s" % [Time.get_ticks_msec() - T0, bid])
			var b = g.place_building(0, bid, base.tx + 6, base.ty + 6, true)
			var b2 = g.place_building(0, bid, base.tx + 9, base.ty + 6, true) if bid == "sylvan_waystone" else null
			for aid in bd["abilities"]:
				if aid == "relocate": continue
				var ok2 = g.building_cast(b, aid, b2, b.x, b.y)
				if ok2: cast_ok += 1
				else: cast_fail.append(fid + "." + bid + "." + aid)
				for k in range(10): g.update(1.0 / 30.0)
			g.kill(b, null)
			if b2 != null: g.kill(b2, null)
		for uid in GData.factions[fid]["units"]:
			var u = g.spawn_unit(0, uid, hx + randf_range(-60, 60), hy + 60 + randf_range(-30, 30))
			if u.def.get("rebirth", false): g.kill(u, dummies[0])
		for k in range(30 * 4): g.update(1.0 / 30.0)
		for u in g.units(0): g.kill(u, null, true)
		g.update(1.0 / 30.0)
	printerr("[%d ms] sweep done" % (Time.get_ticks_msec() - T0))
	out.append("abilities cast ok: %d, failed: %s" % [cast_ok, ", ".join(cast_fail) if not cast_fail.is_empty() else "none"])
	# matches
	for pair in [["abyss", "tempest"], ["radiance", "verdance"], ["sanctuary", "abyss"]]:
		var gm = Game.new({"playerFaction": pair[0], "aiFaction": pair[1], "difficulty": "normal", "seed": 7})
		gm.players[0].is_ai = true
		var ai0 = AIController.new(gm, 0)
		var t0 = Time.get_ticks_msec(); var max_ents = 0; var worst = 0.0
		var steps = 0
		while steps < 30 * int(OS.get_environment("SIM_SECONDS") if OS.get_environment("SIM_SECONDS") != "" else "900") and not gm.over:
			var s0 = Time.get_ticks_usec()
			gm.update(1.0 / 30.0); ai0.update(1.0 / 30.0)
			var st = (Time.get_ticks_usec() - s0) / 1000.0
			if st > worst: worst = st
			max_ents = maxi(max_ents, gm.entities.size())
			steps += 1
			if steps % 900 == 0: printerr("[%d ms] %s vs %s t=%d ents=%d" % [Time.get_ticks_msec() - T0, pair[0], pair[1], int(gm.time), gm.entities.size()])
		out.append("%s vs %s: over=%s winner=%d time=%d realMs=%d maxEnts=%d worstStepMs=%.1f tiers=%d/%d kills=%d/%d bld=%d/%d" % [pair[0], pair[1], str(gm.over), gm.winner, int(gm.time), Time.get_ticks_msec() - t0, max_ents, worst, gm.players[0].tier, gm.players[1].tier, gm.players[0].kills, gm.players[1].kills, gm.buildings(0).size(), gm.buildings(1).size()])
	var text = "\n".join(out)
	print(text)
	var f = FileAccess.open("res://sim_result.txt", FileAccess.WRITE)
	if f != null: f.store_string(text + "\n")
	quit()
