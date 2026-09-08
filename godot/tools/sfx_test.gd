extends SceneTree
## Exercises every synthesized sound and event mapping without a window.
func _init() -> void:
	var sfx = Sfx.new(); root.add_child(sfx)
	await process_frame
	var t0 = Time.get_ticks_msec()
	printerr("library: %d sounds, built in %d ms" % [sfx.streams.size(), t0 - Time.get_ticks_msec()])
	for k in sfx.streams: sfx.play(k, 100.0, 100.0)
	for ev in [{"type": "hit", "x": 1.0, "y": 1.0, "owner": 0, "dmg": 60.0}, {"type": "death", "x": 1.0, "y": 1.0, "owner": 1, "building": true}, {"type": "cast", "x": 1.0, "y": 1.0, "owner": 0, "ult": true}, {"type": "tier", "x": 1.0, "y": 1.0, "owner": 0}, {"type": "shoot", "x": 1.0, "y": 1.0, "owner": 0, "kind": "shell"}, {"type": "select", "x": 0.0, "y": 0.0, "owner": 0}]:
		printerr("%s -> shake %.1f" % [ev["type"], sfx.handle(ev, 0)])
	await process_frame
	printerr("sfx test done")
	quit()
