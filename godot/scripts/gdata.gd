class_name GData
## Loads the faction / ability / difficulty data exported from the JavaScript source of truth
## (run `node tools/export_data.js` in the project root to regenerate godot/data/*.json).

static var factions: Dictionary = {}
static var abilities: Dictionary = {}
static var difficulty: Dictionary = {}
static var loaded = false

static func load_all() -> void:
	if loaded:
		return
	factions = _read("res://data/factions.json")
	abilities = _read("res://data/abilities.json")
	difficulty = _read("res://data/difficulty.json")
	loaded = true

static func _read(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return {}
	var v = JSON.parse_string(f.get_as_text())
	if typeof(v) != TYPE_DICTIONARY:
		push_error("Bad JSON in " + path)
		return {}
	return v

static func unit_def(faction: Dictionary, id: String) -> Dictionary:
	if faction["units"].has(id):
		return faction["units"][id]
	if faction["heroes"].has(id):
		return faction["heroes"][id]
	return {}

static func faction_ids() -> Array:
	return factions.keys()
