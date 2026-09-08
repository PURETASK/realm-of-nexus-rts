extends SceneTree
## Balance worker: plays the matches listed in JOBS ("p0:p1:difficulty:seed;...") with both seats AI-controlled
## and appends one JSON line per match to OUT.  Player 0 is a normal AI in the human seat; player 1 gets the
## difficulty's income multiplier.  SIM_SECONDS caps each match (default 1200).
func _init() -> void:
	GData.load_all()
	var jobs = OS.get_environment("JOBS").split(";", false)
	var cap = int(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else 1200
	var f = FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
	for j in jobs:
		var q = j.split(":")
		var gm = Game.new({"playerFaction": q[0], "aiFaction": q[1], "difficulty": q[2], "seed": int(q[3])})
		gm.players[0].is_ai = true
		var ai0 = AIController.new(gm, 0)
		var steps = 0; var peak = [0, 0]; var first_blood = -1.0; var t0 = Time.get_ticks_msec()
		while steps < 30 * cap and not gm.over:
			gm.update(1.0 / 30.0); ai0.update(1.0 / 30.0); steps += 1
			if steps % 30 == 0:
				peak[0] = maxi(peak[0], gm.players[0].supply_used); peak[1] = maxi(peak[1], gm.players[1].supply_used)
				if first_blood < 0.0 and (gm.players[0].kills + gm.players[1].kills) > 0: first_blood = gm.time
		var rec = {"p0": q[0], "p1": q[1], "diff": q[2], "seed": int(q[3]), "over": gm.over, "winner": gm.winner, "time": int(gm.time),
			"tiers": [gm.players[0].tier, gm.players[1].tier], "kills": [gm.players[0].kills, gm.players[1].kills],
			"peak_supply": peak, "first_blood": int(first_blood), "gathered": [gm.players[0].stats, gm.players[1].stats],
			"buildings_alive": [gm.buildings(0).size(), gm.buildings(1).size()], "produced": gm.produced, "real_ms": Time.get_ticks_msec() - t0}
		f.store_line(JSON.stringify(rec)); f.flush()
		printerr("%s vs %s %s seed %s -> winner %d at %ds (%d ms)" % [q[0], q[1], q[2], q[3], gm.winner, int(gm.time), rec["real_ms"]])
	quit()
