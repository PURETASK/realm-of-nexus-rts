class_name WorldView
extends Node2D
## Draws the world (mirrors js/render.js). Keeps the current 2D art theme: faction-tinted bodies, gold/purple/green terrain layers.

var game: Game
var main = null
var view_rect = Rect2(0, 0, 1600, 710)
var blink = 0.0
var terrain_tex: ImageTexture
var mini_terrain_tex: ImageTexture
var ground_view: Node2D
var layer_view: Node2D
var layer_texs = {}          # layer name -> ImageTexture (FORMAT_RF, one texel per tile)
var layer_timer = 0.0
var fog_view: Node2D
var fog_tex: ImageTexture    # FORMAT_R8 copy of the human player's vision array
var fog_timer = 0.0

const LAYER_SHADER := """
shader_type canvas_item;
uniform sampler2D blight_tex : filter_nearest;
uniform sampler2D light_tex : filter_nearest;
uniform sampler2D grove_tex : filter_nearest;
vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	if (a <= 0.0) return vec4(0.0);
	return vec4((src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / a, a);
}
void fragment() {
	float g = texture(grove_tex, UV).r; float b = texture(blight_tex, UV).r; float l = texture(light_tex, UV).r;
	vec4 c = vec4(0.0);
	if (g > 0.05) c = over(c, vec4(40.0 / 255.0, 150.0 / 255.0, 60.0 / 255.0, g * 0.5));
	if (b > 0.05) c = over(c, vec4(90.0 / 255.0, 20.0 / 255.0, 140.0 / 255.0, b * 0.55));
	if (l > 0.05) c = over(c, vec4(1.0, 215.0 / 255.0, 110.0 / 255.0, l * 0.3));
	COLOR = c;
}
"""

const FOG_SHADER := """
shader_type canvas_item;
uniform float strength = 1.0;
void fragment() {
	float v = texture(TEXTURE, UV).r * 255.0;   // 0 unseen, 1 explored, 2 visible (linear-filtered between tiles)
	float a = v < 1.0 ? mix(0.92, 0.47, v) : mix(0.47, 0.0, clamp(v - 1.0, 0.0, 1.0));
	COLOR = vec4(0.0, 0.0, 0.03, a * strength);
}
"""
var font: Font
var sprite_cache = {}   # "units/acolyte" -> Texture2D or null once looked up

## Optional art: res://assets/sprites/<kind>/<id>.png. Units: a single top-down sprite facing right, or an
## 8-frame horizontal strip (E, SE, S, SW, W, NW, N, NE). Buildings: one image scaled to the footprint.
## Missing files fall back to the glyph renderer, so art can land one asset at a time.
func _sprite(kind: String, id: String) -> Texture2D:
	var key = kind + "/" + id
	if sprite_cache.has(key): return sprite_cache[key]
	var path = "res://assets/sprites/%s/%s.png" % [kind, id]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(path)) if not path.begins_with("res://") or OS.has_feature("editor") or not ResourceLoader.exists(path) else null
		if img != null and not img.is_empty(): tex = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path): tex = load(path)
	sprite_cache[key] = tex
	return tex

func _draw_unit_sprite(tex: Texture2D, x: float, y: float, r: float, facing: float, tint: Color) -> void:
	var fh = float(tex.get_height())
	var scale = (r * 2.0 + 16.0) / fh
	if tex.get_width() >= int(fh) * 8:
		var idx = int(round(fmod(facing + TAU, TAU) / (TAU / 8.0))) % 8
		var dst = Rect2(x - fh * scale / 2.0, y - fh * scale / 2.0, fh * scale, fh * scale)
		draw_texture_rect_region(tex, dst, Rect2(idx * fh, 0, fh, fh), tint)
	else:
		draw_set_transform(Vector2(x, y), facing, Vector2(scale, scale))
		draw_texture(tex, -tex.get_size() / 2.0, tint)
		draw_set_transform_matrix(Transform2D())

const FILLS := {"abyss": "#2a1a3a", "tempest": "#1d2c3d", "radiance": "#3f3014", "verdance": "#1a3320", "sanctuary": "#2c2f48"}

static func col(hex: String, a := 1.0) -> Color:
	var c = Color.html(hex)
	c.a = a
	return c

func setup(g: Game, m) -> void:
	game = g; main = m
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prerender_terrain()
	for name in Cfg.LAYERS:
		layer_texs[name] = ImageTexture.create_from_image(_layer_image(name))
	fog_tex = ImageTexture.create_from_image(_fog_image())
	if ground_view == null:
		ground_view = GroundView.new(); ground_view.wv = self; ground_view.show_behind_parent = true
		ground_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; add_child(ground_view)
		layer_view = LayerView.new(); layer_view.wv = self; layer_view.show_behind_parent = true; add_child(layer_view)
		var lsh = Shader.new(); lsh.code = LAYER_SHADER
		var lmat = ShaderMaterial.new(); lmat.shader = lsh; layer_view.material = lmat
		fog_view = FogView.new(); fog_view.wv = self; add_child(fog_view)
		var fsh = Shader.new(); fsh.code = FOG_SHADER
		var fmat = ShaderMaterial.new(); fmat.shader = fsh; fog_view.material = fmat
	var mat: ShaderMaterial = layer_view.material
	mat.set_shader_parameter("blight_tex", layer_texs["blight"])
	mat.set_shader_parameter("light_tex", layer_texs["light"])
	mat.set_shader_parameter("grove_tex", layer_texs["grove"])
	fog_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ground_view.queue_redraw(); layer_view.queue_redraw()

func _layer_image(name: String) -> Image:
	var data: PackedFloat32Array = game.map.layers[name]
	return Image.create_from_data(Cfg.MAP_W, Cfg.MAP_H, false, Image.FORMAT_RF, data.to_byte_array())

func _fog_image() -> Image:
	var p: GPlayer = game.players[game.human]
	return Image.create_from_data(Cfg.MAP_W, Cfg.MAP_H, false, Image.FORMAT_R8, p.vision)

func _prerender_terrain() -> void:
	var m = game.map
	var img = Image.create(int(Cfg.WORLD_W), int(Cfg.WORLD_H), false, Image.FORMAT_RGB8)
	var T = int(Cfg.TILE)
	for ty in range(Cfg.MAP_H):
		for tx in range(Cfg.MAP_W):
			var v = (sin(tx * 0.7) + cos(ty * 0.9) + sin((tx + ty) * 0.35)) * 4.0
			img.fill_rect(Rect2i(tx * T, ty * T, T, T), Color8(int(38 + v), int(52 + v), int(32 + v)))
	for d in m.decor:
		var r = int(d["r"])
		img.fill_rect(Rect2i(int(d["x"]) - r, int(d["y"]) - r, r * 2, r * 2), Color8(58, 86, 44) if d["t"] == 0 else Color8(78, 70, 54))
	for ty in range(Cfg.MAP_H):
		for tx in range(Cfg.MAP_W):
			if m.terrain[m.idx(tx, ty)] == 0: continue
			img.fill_rect(Rect2i(tx * T, ty * T, T, T), Color8(74, 77, 85))
			img.fill_rect(Rect2i(tx * T + 3, ty * T + 3, T - 10, T - 12), Color8(92, 96, 104))
			img.fill_rect(Rect2i(tx * T, ty * T + T - 5, T, 5), Color8(51, 54, 60))
	terrain_tex = ImageTexture.create_from_image(img)
	var mini = Image.create(Cfg.MAP_W, Cfg.MAP_H, false, Image.FORMAT_RGB8)
	for ty in range(Cfg.MAP_H):
		for tx in range(Cfg.MAP_W):
			mini.set_pixel(tx, ty, Color8(85, 88, 95) if m.terrain[m.idx(tx, ty)] == 1 else Color8(43, 58, 36))
	mini_terrain_tex = ImageTexture.create_from_image(mini)

func _process(dt: float) -> void:
	if game == null: return
	blink += dt
	layer_timer -= dt
	if layer_timer <= 0.0:
		layer_timer = 0.15
		for name in Cfg.LAYERS: layer_texs[name].update(_layer_image(name))
	fog_timer -= dt
	if fog_timer <= 0.0:
		fog_timer = 0.2; fog_tex.update(_fog_image())
	queue_redraw()
	ground_view.queue_redraw()
	fog_view.queue_redraw()

func visible_to_human(e) -> bool:
	return game.can_see(game.human, e)

func _draw() -> void:
	if game == null: return
	var vr = view_rect
	_draw_nodes()
	_draw_wards()
	for c in game.corpses: _draw_corpse(c)
	var ents = game.entities.filter(func(e): return not e.dead and e.x > vr.position.x - 120 and e.x < vr.end.x + 120 and e.y > vr.position.y - 120 and e.y < vr.end.y + 120)
	for b in ents:
		if b.kind == "building" and b.relocate == null: _draw_building(b)
	for u in ents:
		if u.kind == "unit" and not u.flying: _draw_unit(u)
	for p in game.projectiles: _draw_projectile(p)
	for u in ents:
		if u.kind == "unit" and u.flying: _draw_unit(u)
	for b in ents:
		if b.kind == "building" and b.relocate != null: _draw_building(b)
	_draw_effects()
	_draw_clouds()
	if main != null: _draw_input_overlay()

func _draw_nodes() -> void:
	for nd in game.map.nodes:
		if nd["building"] != null: continue
		var x: float = nd["x"]; var y: float = nd["y"]; var depleted: bool = nd["amount"] <= 0
		if nd["type"] == "primary":
			var c = col("#4d4f58") if depleted else col("#5ad0e6")
			for i in range(5):
				var a = i * 1.3; var r = 12.0 + (i % 2) * 6.0
				draw_polygon(PackedVector2Array([Vector2(x + cos(a) * 6, y + sin(a) * 6), Vector2(x + cos(a + 0.4) * r, y + sin(a + 0.4) * r - 6), Vector2(x + cos(a + 0.8) * 6, y + sin(a + 0.8) * 6)]), PackedColorArray([c]))
			draw_circle(Vector2(x, y - 4), 7.0, col("#3c3d44") if depleted else col("#9ff0ff"))
			if not depleted:
				draw_rect(Rect2(x - 18, y + 20, 36, 4), Color.BLACK)
				draw_rect(Rect2(x - 18, y + 20, 36.0 * nd["amount"] / nd["max"], 4), col("#5ad0e6"))
		else:
			draw_circle(Vector2(x, y), 20.0, col("#245a3a"))
			draw_circle(Vector2(x, y), 12.0, col("#48d67f"))
			var p = fmod(blink * 2.0, 1.0)
			draw_arc(Vector2(x, y), 12.0 + p * 16.0, 0, TAU, 24, Color(120 / 255.0, 1, 170 / 255.0, 1.0 - p), 2.0)

func _draw_corpse(c) -> void:
	var a = minf(1.0, c.t / 5.0)
	_ellipse(Vector2(c.x, c.y + 4), 10.0, 5.0, Color(80 / 255.0, 70 / 255.0, 70 / 255.0, a))
	draw_rect(Rect2(c.x - 4, c.y - 1, 8, 3), Color(200 / 255.0, 190 / 255.0, 180 / 255.0, a * 0.7))

func _ellipse(center: Vector2, rx: float, ry: float, color: Color, filled := true, width := 2.0) -> void:
	var pts = PackedVector2Array()
	for i in range(24):
		var a = i / 24.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	if filled: draw_polygon(pts, PackedColorArray([color]))
	else:
		pts.append(pts[0]); draw_polyline(pts, color, width)

static func abbrev(name: String) -> String:
	var out = ""
	for w in name.split(" "):
		var ww = ""
		for ch in w:
			if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z"): ww += ch
		if ww == "" or ww == "of" or ww == "the": continue
		out += ww[0].to_upper()
		if out.length() >= 3: break
	return out

func _draw_building(b) -> void:
	if not visible_to_human(b): return
	if b.def.get("invisible", false) and b.owner != game.human and not game.detected(game.human, b): return
	var T = Cfg.TILE
	var px = b.tx * T; var py = b.ty * T; var w = b.w * T; var h = b.h * T
	var lift = 0.0
	if b.relocate != null:
		var r: Dictionary = b.relocate
		lift = r["t"] / 2.0 * 30.0 if r["phase"] == "lift" else ((1.0 - r["t"] / 2.0) * 30.0 if r["phase"] == "land" else 30.0)
	var dx: float = (b.x - w / 2.0) if b.relocate != null else px
	var dy: float = ((b.y - h / 2.0) if b.relocate != null else py) - lift
	var fc: String = b.faction()["color"]; var pc: Color = b.player().color
	if b.relocate != null: _ellipse(Vector2(b.x, b.y + h / 2.0), w / 2.0, h / 4.0, Color(0, 0, 0, 0.35))
	var sel = game.selection.has(b)
	var btex: Texture2D = null
	if b.def.get("isBase", false): btex = _sprite("buildings", b.def_id + "_t" + str(b.player().tier))
	if btex == null: btex = _sprite("buildings", b.def_id)
	if btex != null:
		var ratio = float(btex.get_height()) / float(btex.get_width())
		var sh = w * ratio
		draw_texture_rect(btex, Rect2(dx, dy + h - sh, w, sh), false, Color(1, 1, 1, 1) if b.complete() else Color(0.6, 0.6, 0.7, 0.75))
		draw_rect(Rect2(dx + 1, dy + 1, w - 2, h - 2), Color.WHITE if sel else Color(pc.r, pc.g, pc.b, 0.6), false, 2.0 if sel else 1.0)
	else:
		draw_rect(Rect2(dx + 2, dy + 2, w - 4, h - 4), col(FILLS.get(b.faction_id(), "#222222")) if b.complete() else col("#222222"))
		draw_rect(Rect2(dx + 2, dy + 2, w - 4, h - 4), Color.WHITE if sel else pc, false, 3.0 if sel else 2.0)
	var glyph = col(fc, 0.55 if b.complete() else 0.25)
	if btex != null:
		pass
	elif b.def.get("isBase", false):
		draw_polygon(PackedVector2Array([Vector2(dx + w / 2.0, dy + 8), Vector2(dx + w - 10, dy + h - 10), Vector2(dx + 10, dy + h - 10)]), PackedColorArray([glyph]))
	elif b.def.has("tower"):
		draw_circle(Vector2(dx + w / 2.0, dy + h / 2.0), w * 0.3, glyph)
	elif b.def.get("wall", false):
		draw_rect(Rect2(dx + 4, dy + 4, w - 8, h - 8), Color(120 / 255.0, 220 / 255.0, 1, 0.5) if b.def.get("blocksAir", false) else col("#8a8478"))
	else:
		draw_rect(Rect2(dx + 8, dy + 8, w - 16, h - 16), glyph)
	if b.def.has("needsNode") and b.node != null:
		draw_circle(Vector2(dx + w / 2.0, dy + h / 2.0), 6.0, col("#5ad0e6") if b.def["needsNode"] == "primary" else col("#48d67f"))
	if b.def.has("converter") and b.toggles["convert"] and b.complete():
		draw_circle(Vector2(dx + w / 2.0, dy + h / 2.0), 8.0, Color(200 / 255.0, 120 / 255.0, 1, 0.5 + 0.5 * sin(blink * 6.0)))
	if btex == null:
		var label: String = ["I", "II", "III"][b.player().tier - 1] if b.def.get("isBase", false) else abbrev(b.def.get("name", ""))
		var fs = 13 if b.w >= 3 else (11 if b.w == 2 else 9)
		draw_string(font, Vector2(dx, dy + h / 2.0 + fs / 2.0 + (6 if b.def.get("isBase", false) else 0)), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color.WHITE)
	if not b.complete():
		draw_rect(Rect2(dx, dy - 8, w, 5), Color.BLACK); draw_rect(Rect2(dx, dy - 8, w * b.progress, 5), col("#ffd479"))
	if sel or b.hp < b.max_hp:
		var f = b.hp / b.max_hp
		draw_rect(Rect2(dx, dy - 3, w, 4), Color.BLACK)
		draw_rect(Rect2(dx, dy - 3, w * f, 4), col("#3fd66a") if f > 0.5 else (col("#ffd479") if f > 0.25 else col("#ff5a3c")))
	if b.flash > 0.0: draw_rect(Rect2(dx + 2, dy + 2, w - 4, h - 4), Color(1, 1, 1, 0.35))
	if b.dark_pact > 0.0: draw_rect(Rect2(dx - 2, dy - 2, w + 4, h + 4), col("#ff4b6e"), false, 2.0)
	if not b.queue.is_empty() and b.owner == game.human:
		var q: Dictionary = b.queue[0]
		draw_rect(Rect2(dx + 4, dy + h - 8, w - 8, 4), Color.BLACK); draw_rect(Rect2(dx + 4, dy + h - 8, (w - 8) * q["elapsed"] / q["time"], 4), col("#8fd3ff"))
	if sel and b.rally != null and b.owner == game.human:
		draw_line(Vector2(b.x, b.y), b.rally, col("#ffd479"), 1.0)
		draw_polygon(PackedVector2Array([b.rally + Vector2(0, -12), b.rally + Vector2(10, -8), b.rally + Vector2(0, -4)]), PackedColorArray([col("#ffd479")]))
		draw_rect(Rect2(b.rally.x - 1, b.rally.y - 12, 2, 12), col("#ffd479"))
	if sel and b.def.has("tower") and b.def["tower"].get("dmg", 0) > 0: draw_arc(Vector2(b.x, b.y), b.tower_range(), 0, TAU, 48, Color(1, 1, 1, 0.25), 1.0)
	if sel and b.def.has("aura"): draw_arc(Vector2(b.x, b.y), float(b.def["aura"]["radius"]) * T, 0, TAU, 48, Color(1, 1, 1, 0.25), 1.0)

func _draw_unit(u) -> void:
	var is_own = u.owner == game.human
	if not is_own and not visible_to_human(u): return
	if u.invisible() and not is_own and not game.detected(game.human, u): return
	if u.has_buff("banish"): return
	var sel = game.selection.has(u)
	var pc: Color = u.player().color; var fc = col(u.faction()["color"])
	if u.invisible(): pc.a = 0.45; fc.a = 0.45
	if u.flash > 0.0: pc = pc.lerp(Color.WHITE, 0.7); fc = Color.WHITE
	var lift = 14.0 if u.flying else 0.0
	var x: float = u.x; var y: float = u.y - lift; var r: float = u.radius
	if u.flying: _ellipse(Vector2(u.x, u.y + 6), r, r * 0.5, Color(0, 0, 0, 0.3))
	if sel: _ellipse(Vector2(u.x, u.y + (6 if u.flying else 2)), r + 4, (r + 4) * 0.6, col("#5fff8a") if is_own else col("#ff6a6a"), false, 2.0)
	var t: String = u.def.get("type", "")
	var utex = _sprite("units", u.def_id)
	if utex != null:
		_ellipse(Vector2(u.x, u.y + (6 if u.flying else 2)), r + 1, (r + 1) * 0.6, Color(pc.r, pc.g, pc.b, 0.7), false, 2.0)
		_draw_unit_sprite(utex, x, y, r, u.facing, Color(1, 1, 1, pc.a))
		if u.flash > 0.0: draw_circle(Vector2(x, y), r + 2, Color(1, 1, 1, 0.45))
		_draw_unit_overlays(u, x, y, r, sel, is_own)
		return
	var pts = PackedVector2Array()
	if u.is_hero:
		for i in range(10):
			var a = -PI / 2.0 + i * PI / 5.0; var rr = r * 0.5 if i % 2 == 1 else r + 2
			pts.append(Vector2(x + cos(a) * rr, y + sin(a) * rr))
	elif t == "ranged":
		pts = PackedVector2Array([Vector2(x + cos(u.facing) * r, y + sin(u.facing) * r), Vector2(x + cos(u.facing + 2.4) * r, y + sin(u.facing + 2.4) * r), Vector2(x + cos(u.facing - 2.4) * r, y + sin(u.facing - 2.4) * r)])
	elif t == "caster":
		pts = PackedVector2Array([Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y)])
	elif t == "siege":
		pts = PackedVector2Array([Vector2(x - r, y - r * 0.8), Vector2(x + r, y - r * 0.8), Vector2(x + r, y + r * 0.8), Vector2(x - r, y + r * 0.8)])
	else:
		var rr2 = r * 0.8 if t == "worker" else r
		for i in range(16):
			var a = i / 16.0 * TAU
			pts.append(Vector2(x + cos(a) * rr2, y + sin(a) * rr2))
	draw_polygon(pts, PackedColorArray([pc]))
	var outline = pts.duplicate(); outline.append(pts[0]); draw_polyline(outline, fc, 2.0)
	if u.flying:
		var wv = sin(blink * 12.0 + u.id) * 3.0
		draw_line(Vector2(x - r - 8, y - 4 + wv), Vector2(x - r + 2, y), fc, 2.0); draw_line(Vector2(x + r + 8, y - 4 + wv), Vector2(x + r - 2, y), fc, 2.0)
	if t == "worker":
		draw_line(Vector2(x + cos(u.facing) * 4, y + sin(u.facing) * 4), Vector2(x + cos(u.facing) * (r + 6), y + sin(u.facing) * (r + 6)), col("#dddddd"), 2.0)
		if u.gather["carrying"] > 0: draw_circle(Vector2(x - 6, y - 8), 4.0, col("#c9a0ff"))
	elif not u.is_hero and t != "siege":
		draw_line(Vector2(x, y), Vector2(x + cos(u.facing) * (r + 3), y + sin(u.facing) * (r + 3)), Color.WHITE, 1.5)
	if u.is_hero: draw_string(font, Vector2(x - 20, y + 4), str(u.level), HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color.BLACK)
	_draw_unit_overlays(u, x, y, r, sel, is_own)

## Status overlays shared by the glyph and sprite renderers: unique ring, stun, bars, range circle
func _draw_unit_overlays(u, x: float, y: float, r: float, sel: bool, is_own: bool) -> void:
	if u.def.get("unique", false): draw_arc(Vector2(x, y), r + 5 + sin(blink * 4.0) * 2, 0, TAU, 24, col("#ff4b6e"), 2.0)
	if u.stunned(): draw_string(font, Vector2(x - 20, y - r - 6), "*", HORIZONTAL_ALIGNMENT_CENTER, 40, 12, col("#ffd479"))
	if sel or u.hp < u.max_hp or u.is_hero:
		var bw = maxf(20.0, r * 2 + 4)
		draw_rect(Rect2(x - bw / 2, y - r - 8, bw, 4), Color.BLACK)
		var f = u.hp / u.max_hp
		draw_rect(Rect2(x - bw / 2, y - r - 8, bw * f, 4), col("#3fd66a") if f > 0.5 else (col("#ffd479") if f > 0.25 else col("#ff5a3c")))
		if u.is_hero and is_own:
			draw_rect(Rect2(x - bw / 2, y - r - 4, bw, 2), col("#3a3a55")); draw_rect(Rect2(x - bw / 2, y - r - 4, bw * minf(1.0, u.xp / u.xp_to_level()), 2), col("#c9a0ff"))
		if u.max_shield > 0:
			draw_rect(Rect2(x - bw / 2, y - r - 11, bw, 3), col("#112233")); draw_rect(Rect2(x - bw / 2, y - r - 11, bw * minf(1.0, u.shield / maxf(1.0, u.stat("maxShield"))), 3), col("#9fe0ff"))
	if sel and is_own and float(u.def.get("range", 1)) > 1.6: draw_arc(Vector2(u.x, u.y), u.stat("range"), 0, TAU, 48, Color(1, 1, 1, 0.15), 1.0)

func _draw_projectile(p: Dictionary) -> void:
	var t = p["target"]
	if p["kind"] == "shell": draw_circle(Vector2(p["x"], p["y"] - 10), 5.0, col("#e8e0d0"))
	elif p["kind"] == "bolt":
		draw_circle(Vector2(p["x"], p["y"]), 4.0, col(p["color"]))
		draw_line(Vector2(p["x"], p["y"]), Vector2(p["x"] - (t.x - p["x"]) * 0.15, p["y"] - (t.y - p["y"]) * 0.15), col(p["color"], 0.5), 2.0)
	else:
		var a = atan2(t.y - p["y"], t.x - p["x"])
		draw_line(Vector2(p["x"] - cos(a) * 6, p["y"] - sin(a) * 6), Vector2(p["x"] + cos(a) * 6, p["y"] + sin(a) * 6), col("#eeeeee"), 2.0)

func _draw_wards() -> void:
	var colors = {"corruption": "#8b3cff", "veil": "#1a0830", "curse": "#c040ff", "zephyr": "#8fd3ff", "cloud": "#7fa8c8", "eye": "#ffffff", "hurricane": "#9fc4ff", "sanctify": "#ffd55a", "sunfire": "#ffb347", "grove": "#7ee08a", "vines": "#4caf50", "bloom": "#c8ffd0", "heaven": "#fff7d0"}
	for wd in game.wards:
		var c: String = colors.get(wd["kind"], "#ffffff")
		var center = Vector2(wd["x"], wd["y"])
		draw_arc(center, wd["r"], 0, TAU, 48, col(c, 0.6), 2.0)
		draw_circle(center, wd["r"], col(c, 0.45 if wd["kind"] == "veil" else 0.08))
		if wd["kind"] == "corruption":
			draw_rect(Rect2(wd["x"] - 4, wd["y"] - 18, 8, 22), col("#8b3cff")); draw_circle(Vector2(wd["x"], wd["y"] - 20), 7.0, col("#8b3cff"))
		if wd["kind"] == "zephyr": draw_rect(Rect2(wd["x"] - 3, wd["y"] - 20, 6, 24), col("#8fd3ff"))
		if wd["kind"] == "hurricane" or wd["kind"] == "eye":
			for i in range(3):
				var s = fmod(blink * (2 + i), TAU)
				draw_arc(center, wd["r"] * (0.3 + i * 0.25), s, s + 2.0, 16, col(c, 0.4), 2.0)

func _draw_clouds() -> void:
	for c in game.weather["cloud"]:
		var cc = Color(30 / 255.0, 40 / 255.0, 70 / 255.0, 0.45) if c["heavy"] else Color(80 / 255.0, 100 / 255.0, 130 / 255.0, 0.35)
		for i in range(6):
			var a = i * 1.05 + blink * 0.3; var rr: float = c["r"] * 0.55
			draw_circle(Vector2(c["x"] + cos(a) * rr * 0.6, c["y"] - 20 + sin(a) * rr * 0.4), rr * 0.7, cc)
		for i in range(25):
			var rx: float = c["x"] + (sin(i * 12.9 + 1) * 0.5 + 0.5) * c["r"] * 2 - c["r"]
			var ry: float = c["y"] + ((sin(i * 7.3) * 0.5 + 0.5) * c["r"] * 2 - c["r"]) + fmod(blink * 300 + i * 37, 60.0)
			if Cfg.dist(rx, ry, c["x"], c["y"]) > c["r"]: continue
			draw_line(Vector2(rx, ry), Vector2(rx - 2, ry + 8), Color(180 / 255.0, 200 / 255.0, 1, 0.5), 1.0)

func _draw_effects() -> void:
	for e in game.effects:
		var p: float = 1.0 - e["t"] / e["max"]
		var c: Color = col(e.get("color", "#ffffff"))
		match e["type"]:
			"ring":
				draw_arc(Vector2(e["x"], e["y"]), maxf(1.0, e["r"] * (0.3 + 0.7 * p)), 0, TAU, 48, Color(c.r, c.g, c.b, 1.0 - p), 3.0)
			"burst":
				draw_circle(Vector2(e["x"], e["y"]), maxf(1.0, e["r"] * (0.4 + 0.6 * p)), Color(c.r, c.g, c.b, (1.0 - p) * 0.5))
			"lightning":
				var pts = PackedVector2Array([Vector2(e["x1"], e["y1"])])
				for i in range(1, 9):
					var tt = i / 8.0
					var jx = sin(i * 7.1 + e["x1"]) * 14.0 if i < 8 else 0.0
					var jy = cos(i * 5.3 + e["y1"]) * 14.0 if i < 8 else 0.0
					pts.append(Vector2(lerpf(e["x1"], e["x2"], tt) + jx, lerpf(e["y1"], e["y2"], tt) + jy))
				draw_polyline(pts, Color(1, 1, 1, 0.4), 6.0 * (1.0 - p) + 0.5)
				draw_polyline(pts, c, 3.0 * (1.0 - p) + 1.0)
			"slash":
				draw_arc(Vector2(e["x"], e["y"]), (22.0 if e.get("big", false) else 12.0) * (0.5 + p), -0.8, 0.8, 8, Color(c.r, c.g, c.b, 1.0 - p), 4.0 if e.get("big", false) else 2.0)
			"spark":
				for i in range(5):
					var a = i * 1.26
					draw_rect(Rect2(e["x"] + cos(a) * 10 * p, e["y"] + sin(a) * 10 * p, 3, 3), Color(c.r, c.g, c.b, 1.0 - p))
			"text":
				draw_string(font, Vector2(e["x"] - 60, e["y"] - p * 20), e["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(c.r, c.g, c.b, 1.0 - p))
			"death":
				for i in range(6):
					var a = i * 1.05
					draw_circle(Vector2(e["x"] + cos(a) * 18 * p, e["y"] - (14 if e.get("flying", false) else 0) + sin(a) * 18 * p), maxf(0.5, 4.0 * (1.0 - p)), Color(c.r, c.g, c.b, (1.0 - p) * 0.7))

func _draw_input_overlay() -> void:
	var inp = main
	var mw: Vector2 = inp.mouse_world
	if inp.dragging and inp.drag_start != null:
		var a: Vector2 = inp.drag_start
		var r = Rect2(minf(a.x, mw.x), minf(a.y, mw.y), absf(mw.x - a.x), absf(mw.y - a.y))
		draw_rect(r, Color(95 / 255.0, 1, 138 / 255.0, 0.1)); draw_rect(r, col("#5fff8a"), false, 1.0)
	var pend = inp.pending
	if pend != null and (pend["kind"] == "build" or pend["kind"] == "relocate"):
		var d: Dictionary = game.players[game.human].faction["buildings"][pend["defId"]] if pend["kind"] == "build" else game.base_of(game.human).def
		var bw = int(d.get("w", 1)); var bh = int(d.get("h", 1))
		var tx = int(mw.x / Cfg.TILE) - bw / 2; var ty = int(mw.y / Cfg.TILE) - bh / 2
		var ok: bool
		if pend["kind"] == "build": ok = game.can_place(game.human, pend["defId"], tx, ty)
		else:
			var b = game.base_of(game.human)
			game.map.set_blocked(b.tx, b.ty, b.w, b.h, false, false); ok = game.map.area_free(tx, ty, bw, bh, false); game.map.set_blocked(b.tx, b.ty, b.w, b.h, true, false)
		var rr = Rect2(tx * Cfg.TILE, ty * Cfg.TILE, bw * Cfg.TILE, bh * Cfg.TILE)
		draw_rect(rr, Color(95 / 255.0, 1, 138 / 255.0, 0.35) if ok else Color(1, 80 / 255.0, 80 / 255.0, 0.35)); draw_rect(rr, col("#5fff8a") if ok else col("#ff5050"), false, 1.0)
		var cc = rr.get_center()
		if d.has("tower"): draw_arc(cc, float(d["tower"].get("range", 0)) * Cfg.TILE, 0, TAU, 48, Color(1, 1, 1, 0.3), 1.0)
		if d.has("aura"): draw_arc(cc, float(d["aura"]["radius"]) * Cfg.TILE, 0, TAU, 48, Color(1, 1, 1, 0.3), 1.0)
		inp.ghost = {"tx": tx, "ty": ty, "ok": ok}
	if pend != null and pend["kind"] == "cast":
		var ab: Dictionary = GData.abilities[pend["ability"]]
		var radii = {"corruption_ward": 4, "nightmare_veil": 4, "curse_of_undeath": 6, "zephyr_ward": 4, "cloudburst": 3.5, "hurricane_maelstrom": 6, "call_of_the_armada": 2, "nether_portal": 2.5, "thunderstrike": 2, "void_bolt": 3, "sanctified_ground": 4, "consecrate": 4, "seed_the_land": 4, "thorn_burst": 3, "entangle": 4, "judgment_of_the_sun": 4, "wrath_of_heaven": 5, "blinding_flare": 4, "dawnstrike": 3, "banish_corruption": 4, "resurrection": 5, "mass_resurrection": 5}
		if radii.has(pend["ability"]): draw_arc(mw, float(radii[pend["ability"]]) * Cfg.TILE, 0, TAU, 48, Color(1, 1, 1, 0.5), 1.0)
		for u in game.selection:
			if u.kind == "unit" and ab.get("range", 0) > 0: draw_arc(Vector2(u.x, u.y), float(ab["range"]) * Cfg.TILE, 0, TAU, 48, Color(140 / 255.0, 200 / 255.0, 1, 0.3), 1.0)
	if pend != null and (pend["kind"] == "attack" or pend["kind"] == "move" or pend["kind"] == "gather"):
		draw_arc(mw, 10.0, 0, TAU, 16, col("#ff5a3c") if pend["kind"] == "attack" else col("#5fff8a"), 2.0)
	if inp.click_marker != null and inp.click_marker["t"] > 0.0:
		var m: Dictionary = inp.click_marker
		draw_arc(Vector2(m["x"], m["y"]), maxf(1.0, 6 + (0.5 - m["t"]) * 24), 0, TAU, 16, col(m["color"]), 2.0)

class GroundView extends Node2D:
	var wv: WorldView
	func _draw() -> void:
		if wv == null or wv.game == null: return
		var vr = wv.view_rect
		draw_texture_rect_region(wv.terrain_tex, vr, vr)

class LayerView extends Node2D:
	var wv: WorldView
	func _draw() -> void:
		if wv == null or wv.game == null: return
		draw_texture_rect(wv.layer_texs["blight"], Rect2(0, 0, Cfg.WORLD_W, Cfg.WORLD_H), false)

class FogView extends Node2D:
	var wv: WorldView
	func _draw() -> void:
		if wv == null or wv.game == null: return
		draw_texture_rect(wv.fog_tex, Rect2(0, 0, Cfg.WORLD_W, Cfg.WORLD_H), false)
		if wv.game.weather["storm"] != null:
			var vr = wv.view_rect
			draw_rect(vr, Color(10 / 255.0, 20 / 255.0, 50 / 255.0, 0.35))
			for i in range(120):
				var rx = vr.position.x + fmod(i * 97.0, vr.size.x); var ry = vr.position.y + fmod(i * 53.0 + wv.blink * 500.0, vr.size.y)
				draw_line(Vector2(rx, ry), Vector2(rx - 3, ry + 12), Color(200 / 255.0, 220 / 255.0, 1, 0.35), 1.0)
