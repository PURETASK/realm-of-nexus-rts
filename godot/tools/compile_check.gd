extends SceneTree
## Loads every script so Godot compiles it; prints failures.  godot --headless -s tools/compile_check.gd
func _init() -> void:
	var bad = 0
	for p in ["cfg", "gdata", "gmap", "gplayer", "unit", "building", "corpse", "game", "abilities", "ai", "world_view", "hud", "sfx", "main"]:
		var s = load("res://scripts/%s.gd" % p)
		if s == null or not s.can_instantiate():
			printerr("COMPILE FAILED: " + p); bad += 1
		else: printerr("ok: " + p)
	printerr("compile check done, failures: %d" % bad)
	quit(bad)
