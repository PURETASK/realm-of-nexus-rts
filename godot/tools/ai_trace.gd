extends SceneTree
## Traces AI economy/tech state every 60 s for one match. P0/P1 env pick factions, SIM_SECONDS caps.
func _init() -> void:
	GData.load_all()
	var a = OS.get_environment("P0") if OS.get_environment("P0") != "" else "tempest"
	var b = OS.get_environment("P1") if OS.get_environment("P1") != "" else "abyss"
	var cap = int(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else 900
	var gm = Game.new({"playerFaction": a, "aiFaction": b, "difficulty": "normal", "seed": 11})
	gm.players[0].is_ai = true
	var ais = [AIController.new(gm, 0), gm.ai]
	var steps = 0; var next_report = 0.0
	while steps < 30 * cap and not gm.over:
		gm.update(1.0 / 30.0); ais[0].update(1.0 / 30.0); steps += 1
		if gm.time >= next_report:
			next_report += 60.0
			for i in range(2):
				var p = gm.players[i]; var ai = ais[i]; var base = gm.base_of(i)
				var order: Array = AIController.BUILD_ORDERS[p.faction_id]
				var step = order[ai.order_idx] if ai.order_idx < order.size() else null
				var tier_why = gm.can_queue(base, {"type": "tier"})["why"] if base != null and not gm.can_queue(base, {"type": "tier"})["ok"] else "ok" if base != null else "no base"
				var q = ""
				if base != null:
					for it in base.queue: q += it["type"] + ":" + str(it.get("id", "")) + " "
				var army = 0
				for u in gm.units(i):
					if not u.is_worker(): army += 1
				printerr("t=%4d P%d %-9s tier=%d step=%s res=%d/%d/%d sup=%d/%d workers=%d army=%d blds=%d gathered=%d mode=%s baseq=[%s] tier:%s" % [int(gm.time), i, p.faction_id, p.tier, str(step), int(p.res["p"]), int(p.res["s"]), int(p.res["c"]), p.supply_used, p.supply_cap, gm.units(i).filter(func(u): return u.is_worker()).size(), army, gm.buildings(i).size(), int(p.stats["p"]), ai.mode, q, tier_why])
	printerr("over=%s winner=%d t=%d" % [str(gm.over), gm.winner, int(gm.time)])
	quit()
