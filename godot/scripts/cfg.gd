class_name Cfg
## Global constants (mirrors js/config.js)

const TILE := 32.0
const MAP_W := 80
const MAP_H := 60
const WORLD_W := 2560.0
const WORLD_H := 1920.0
const MAX_SUPPLY := 150
const CORPSE_LIFETIME := 20.0
const VISION_REFRESH := 0.2
const CORRUPTION_DECAY := 0.004
const CORRUPTION_GROW := 0.12
const LAYERS := ["blight", "light", "grove"]
const PLAYER_COLORS := ["#3fa9f5", "#ff5a3c"]
const HUD_H := 190.0

static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))

static func dist_to_rect(px: float, py: float, rx: float, ry: float, rw: float, rh: float) -> float:
	var cx = clampf(px, rx, rx + rw)
	var cy = clampf(py, ry, ry + rh)
	return dist(px, py, cx, cy)

static func cost_str(cost, faction: Dictionary) -> String:
	if cost == null or cost.is_empty():
		return "Free"
	var r: Dictionary = faction["resources"]
	var parts = []
	if cost.get("p", 0) > 0: parts.append(str(int(cost["p"])) + " " + r["primary"]["short"])
	if cost.get("s", 0) > 0: parts.append(str(int(cost["s"])) + " " + r["secondary"]["short"])
	if cost.get("c", 0) > 0: parts.append(str(int(cost["c"])) + " " + r["catalyst"]["short"])
	return ", ".join(parts) if parts.size() > 0 else "Free"

static func fmt_time(s: float) -> String:
	var t = int(s)
	return "%d:%02d" % [t / 60, t % 60]
