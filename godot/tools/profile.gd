extends SceneTree
## Profiles one AI-vs-AI match: godot --headless --path godot -s tools/profile.gd
func _init() -> void:
	GData.load_all()
	var secs = int(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else 300
	var gm = Game.new({"playerFaction": "abyss", "aiFaction": "tempest", "difficulty": "normal", "seed": 7})
	gm.players[0].is_ai = true
	var ai0 = AIController.new(gm, 0)
	gm.profiling = true
	var t0 = Time.get_ticks_usec(); var steps = 0; var worst = 0.0; var worst_t = 0.0; var ai_us = 0
	var hist = {}  # entity-count bucket -> [ticks, usec]
	while steps < 30 * secs and not gm.over:
		var s0 = Time.get_ticks_usec()
		gm.update(1.0 / 30.0)
		var s1 = Time.get_ticks_usec()
		ai0.update(1.0 / 30.0)
		ai_us += Time.get_ticks_usec() - s1
		var st = (s1 - s0) / 1000.0
		if st > worst: worst = st; worst_t = gm.time
		var bucket = int(gm.entities.size() / 20) * 20
		if not hist.has(bucket): hist[bucket] = [0, 0]
		hist[bucket][0] += 1; hist[bucket][1] += (s1 - s0)
		steps += 1
	var total = Time.get_ticks_usec() - t0
	print("match: t=%d ents_end=%d steps=%d total=%dms avg_tick=%.2fms worst=%.1fms (at t=%d) ai0=%dms" % [int(gm.time), gm.entities.size(), steps, total / 1000, total / 1000.0 / steps, worst, int(worst_t), ai_us / 1000])
	print("-- per section (ms total, %% of update):")
	var upd = 0
	for k in gm.prof: upd += gm.prof[k]
	var keys = gm.prof.keys(); keys.sort_custom(func(a, b): return gm.prof[a] > gm.prof[b])
	for k in keys: print("  %-18s %7d ms  %5.1f%%" % [k, gm.prof[k] / 1000, 100.0 * gm.prof[k] / maxi(upd, 1)])
	print("-- avg tick ms by entity count:")
	var bk = hist.keys(); bk.sort()
	for b in bk: print("  %3d-%3d ents: %.2f ms (%d ticks)" % [b, b + 19, hist[b][1] / 1000.0 / hist[b][0], hist[b][0]])
	quit()
