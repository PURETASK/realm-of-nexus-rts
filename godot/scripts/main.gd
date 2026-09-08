extends Node2D
## Bootstrap: menu, game loop, camera, mouse/keyboard input (mirrors js/main.js + js/input.js)

var game: Game = null
var wv: WorldView
var cam: Camera2D
var hud: HUD
var ui_layer: CanvasLayer
var menu: Control
var end_panel: Control
var end_title: Label
var end_text: Label
var chosen_faction = "abyss"
var ai_option: OptionButton
var diff_option: OptionButton
var faction_buttons = {}
# input state
var mouse_world = Vector2.ZERO
var drag_start = null
var dragging = false
var pending = null
var ghost = null
var click_marker = null
var last_group_key = ""
var last_group_time = 0.0
var _auto_frames = 0
var sfx: Sfx
var shake = 0.0
var settings = {}
var pause_panel: Control
var settings_panel: Control
var rebinding = ""
var key_buttons = {}
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SETTINGS := {"volume": 0.8, "sound": true, "shake": true, "edge_scroll": true,
	"keys": {"pause": KEY_P, "center": KEY_SPACE, "army": KEY_F1, "hero": KEY_F2, "idle_worker": KEY_TAB, "mute": KEY_M},
	"remap": {"A": "A", "S": "S", "H": "H", "Q": "Q", "W": "W", "E": "E", "R": "R"}}
const KEY_LABELS := {"pause": "Pause", "center": "Centre on base / last attack", "army": "Select army", "hero": "Select hero", "idle_worker": "Select idle worker", "mute": "Mute sound",
	"A": "Attack-move", "S": "Stop", "H": "Hold position", "Q": "Hero ability 1", "W": "Hero ability 2", "E": "Hero ability 3", "R": "Hero ability 4"}

func _ready() -> void:
	GData.load_all()
	wv = WorldView.new(); add_child(wv)
	cam = Camera2D.new(); cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER; add_child(cam); cam.make_current()
	sfx = Sfx.new(); add_child(sfx); sfx.camera = cam
	_load_settings(); _apply_settings()
	ui_layer = CanvasLayer.new(); add_child(ui_layer)
	hud = HUD.new(); hud.visible = false; ui_layer.add_child(hud)
	_build_menu()
	_build_end_panel()
	_build_pause_menu()
	_build_settings_panel()
	if OS.get_environment("AUTOSTART") != "": call_deferred("start_game")

func _build_menu() -> void:
	menu = Control.new(); menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu.theme = HUD.make_theme(); ui_layer.add_child(menu)
	var bg = ColorRect.new(); bg.color = Color.html("#0b0e1a"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu.add_child(bg)
	var center = CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu.add_child(center)
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 14); vb.alignment = BoxContainer.ALIGNMENT_CENTER; center.add_child(vb)
	var title = Label.new(); title.text = "REALM OF NEXUS"; title.add_theme_font_size_override("font_size", 46); title.add_theme_color_override("font_color", Color.WHITE); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(title)
	var sub = Label.new(); sub.text = "CORE FACTION MECHANICS — SKIRMISH"; sub.add_theme_color_override("font_color", Color.html("#9aabbb")); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(sub)
	var flow = HFlowContainer.new(); flow.alignment = FlowContainer.ALIGNMENT_CENTER; flow.custom_minimum_size = Vector2(1400, 0); vb.add_child(flow)
	for fid in GData.faction_ids():
		var f: Dictionary = GData.factions[fid]
		var b = Button.new(); b.custom_minimum_size = Vector2(260, 190); b.toggle_mode = true
		var hn = []
		for h in f["heroes"].values(): hn.append(h["name"])
		b.text = "%s%s\n%s\n\n%s\n\n%s" % [f["name"], "  [PROVISIONAL]" if f.get("provisional", false) else "", f["tagline"], _wrap(f["blurb"], 44), _wrap("Heroes: " + " · ".join(hn), 44)]
		b.add_theme_color_override("font_color", Color.html(f["color"]))
		b.add_theme_font_size_override("font_size", 11)
		var id: String = fid
		b.pressed.connect(func(): _choose_faction(id))
		flow.add_child(b); faction_buttons[fid] = b
	var opts = HBoxContainer.new(); opts.alignment = BoxContainer.ALIGNMENT_CENTER; opts.add_theme_constant_override("separation", 20); vb.add_child(opts)
	var l1 = Label.new(); l1.text = "Opponent:"; opts.add_child(l1)
	ai_option = OptionButton.new()
	for fid in GData.faction_ids(): ai_option.add_item(GData.factions[fid]["name"])
	ai_option.add_item("Random"); ai_option.select(GData.faction_ids().find("tempest")); opts.add_child(ai_option)
	var l2 = Label.new(); l2.text = "Difficulty:"; opts.add_child(l2)
	diff_option = OptionButton.new()
	for d in ["easy", "normal", "hard"]: diff_option.add_item(GData.difficulty[d]["name"])
	diff_option.select(1); opts.add_child(diff_option)
	var start = Button.new(); start.text = "BEGIN THE WAR"; start.custom_minimum_size = Vector2(260, 44); start.add_theme_font_size_override("font_size", 20); start.pressed.connect(start_game); vb.add_child(start)
	var sbtn = Button.new(); sbtn.text = "Settings"; sbtn.custom_minimum_size = Vector2(160, 32); sbtn.pressed.connect(func(): settings_panel.visible = true); vb.add_child(sbtn)
	var help = Label.new(); help.text = "Left-click select · Drag box select · Right-click move / attack / gather · A attack-move · S stop · H hold · Ctrl+1-9 groups\nArrow keys / edge scroll / minimap camera · Space jumps to last attack · F1 army · F2 hero · Tab idle worker · Q W E R hero abilities · Esc cancel · P pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; help.add_theme_color_override("font_color", Color.html("#778899")); help.add_theme_font_size_override("font_size", 12); vb.add_child(help)
	_choose_faction(chosen_faction)

static func _wrap(text: String, width: int) -> String:
	var out = ""; var line = ""
	for w in text.split(" "):
		if line.length() + w.length() + 1 > width:
			out += line + "\n"; line = w
		else: line = w if line == "" else line + " " + w
	return out + line

func _choose_faction(fid: String) -> void:
	chosen_faction = fid
	for k in faction_buttons: faction_buttons[k].button_pressed = (k == fid)

func _build_end_panel() -> void:
	end_panel = PanelContainer.new(); end_panel.visible = false; end_panel.theme = HUD.make_theme(); ui_layer.add_child(end_panel)
	end_panel.custom_minimum_size = Vector2(520, 200); end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb = VBoxContainer.new(); vb.alignment = BoxContainer.ALIGNMENT_CENTER; end_panel.add_child(vb)
	end_title = Label.new(); end_title.add_theme_font_size_override("font_size", 48); end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(end_title)
	end_text = Label.new(); end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(end_text)
	var b = Button.new(); b.text = "Back to Menu"; b.pressed.connect(func(): end_panel.visible = false; stop_game()); vb.add_child(b)

func start_game() -> void:
	var ids = GData.faction_ids()
	var ai_f: String = ids[ai_option.selected] if ai_option.selected < ids.size() else ids.pick_random()
	var diff: String = ["easy", "normal", "hard"][diff_option.selected]
	menu.visible = false
	game = Game.new({"playerFaction": chosen_faction, "aiFaction": ai_f, "difficulty": diff})
	wv.setup(game, self)
	hud.setup(game, self, wv); hud.visible = true
	hud.pause_btn.pressed.connect(toggle_pause)
	hud.quit_btn.pressed.connect(stop_game)
	var base = game.base_of(0)
	game.camera = Vector2(base.x - view_size().x / 2, base.y - view_size().y / 2)
	game.msg("Enemy: %s (%s). Destroy every enemy structure." % [GData.factions[ai_f]["name"], GData.difficulty[diff]["name"]], "warn")
	pending = null; ghost = null; drag_start = null; dragging = false

func stop_game() -> void:
	game = null
	wv.game = null; hud.visible = false; hud.game = null; wv.queue_redraw()
	if hud.pause_btn.pressed.is_connected(toggle_pause): hud.pause_btn.pressed.disconnect(toggle_pause)
	if hud.quit_btn.pressed.is_connected(stop_game): hud.quit_btn.pressed.disconnect(stop_game)
	menu.visible = true

func toggle_pause() -> void:
	if game == null: return
	game.paused = not game.paused

func view_size() -> Vector2:
	var vs = get_viewport_rect().size
	return Vector2(vs.x, vs.y - Cfg.HUD_H)

func _process(dt: float) -> void:
	if game == null:
		if OS.get_environment("SCREENSHOT") != "" and OS.get_environment("AUTOSTART") == "":
			_auto_frames += 1
			if _auto_frames == 60:
				get_viewport().get_texture().get_image().save_png(OS.get_environment("SCREENSHOT")); printerr("[menu] screenshot saved"); get_tree().quit()
		return
	dt = minf(dt, 0.05)
	_update_camera(dt)
	game.update(dt)
	_drain_events(dt)
	if click_marker != null: click_marker["t"] -= dt
	wv.view_rect = Rect2(game.camera, view_size())
	cam.position = game.camera + view_size() / 2.0
	if game.over and not game.ended:
		game.ended = true; _show_end()
	if OS.get_environment("AUTOSTART") != "":
		_auto_frames += 1
		if _auto_frames % 100 == 0: printerr("[autostart] frame %d t=%.1f ents=%d msgs=%d hud_children=%d" % [_auto_frames, game.time, game.entities.size(), game.messages.size(), hud.get_child_count()])
		if _auto_frames == 200: printerr("[autostart] window=%s viewport=%s hud.size=%s hud.pos=%s children=%s" % [get_window().size, get_viewport_rect().size, hud.size, hud.position, hud.get_children().map(func(c): return "%s@%s/%s" % [c.get_class(), c.position, c.size])])
		if _auto_frames == 150 and OS.get_environment("SHOWPANEL") == "pause": _open_pause()
		if _auto_frames == 150 and OS.get_environment("SHOWPANEL") == "settings": settings_panel.visible = true
		if _auto_frames == 240 and OS.get_environment("SCREENSHOT") != "":
			var img = get_viewport().get_texture().get_image()
			img.save_png(OS.get_environment("SCREENSHOT")); printerr("[autostart] screenshot saved"); get_tree().quit()

## Turn simulation events into sound and screen shake
func _drain_events(dt: float) -> void:
	var vr = wv.view_rect.grow(200.0)
	for ev in game.events:
		var sh = sfx.handle(ev, game.human)
		if sh > 0.0 and settings["shake"] and vr.has_point(Vector2(ev["x"], ev["y"])): shake = maxf(shake, sh)
	game.events.clear()
	if shake > 0.05:
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake *= exp(-dt * 9.0)
	else:
		shake = 0.0; cam.offset = Vector2.ZERO

func _update_camera(dt: float) -> void:
	var sp = 700.0 * dt
	if Input.is_key_pressed(KEY_LEFT): game.camera.x -= sp
	if Input.is_key_pressed(KEY_RIGHT): game.camera.x += sp
	if Input.is_key_pressed(KEY_UP): game.camera.y -= sp
	if Input.is_key_pressed(KEY_DOWN): game.camera.y += sp
	var m = get_viewport().get_mouse_position(); var vs = get_viewport_rect().size; var edge = 14.0
	if settings["edge_scroll"] and m.x >= 0 and m.y >= 0 and m.x <= vs.x and m.y <= vs.y:
		if m.x < edge: game.camera.x -= sp
		if m.x > vs.x - edge: game.camera.x += sp
		if m.y < edge and m.y > 34: game.camera.y -= sp
		if m.y > view_size().y - edge and m.y < view_size().y + 4: game.camera.y += sp
	var v = view_size()
	game.camera.x = clampf(game.camera.x, 0, maxf(0, Cfg.WORLD_W - v.x))
	game.camera.y = clampf(game.camera.y, 0, maxf(0, Cfg.WORLD_H - v.y))
	mouse_world = wv.get_global_mouse_position()
	mouse_world.x = clampf(mouse_world.x, 0, Cfg.WORLD_W); mouse_world.y = clampf(mouse_world.y, 0, Cfg.WORLD_H)

func _show_end() -> void:
	var win = game.winner == 0; var p: GPlayer = game.players[0]
	var t = end_title; var s = end_text
	t.text = "VICTORY" if win else "DEFEAT"; t.add_theme_color_override("font_color", Color.html("#ffd479") if win else Color.html("#ff5a3c"))
	s.text = "%s\nTime %s · Kills %d · Losses %d · %s gathered %d" % [("The %s reigns over the realm." % p.faction["name"]) if win else ("Your domain has fallen to the %s." % game.players[1].faction["name"]), Cfg.fmt_time(game.time), p.kills, p.losses, p.faction["resources"]["primary"]["name"], int(p.stats["p"])]
	end_panel.visible = true

# ---------- settings, pause menu ----------
func _load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	var cf = ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK: return
	for k in ["volume", "sound", "shake", "edge_scroll"]: settings[k] = cf.get_value("game", k, settings[k])
	for k in settings["keys"]: settings["keys"][k] = int(cf.get_value("keys", k, settings["keys"][k]))
	for k in settings["remap"]: settings["remap"][k] = str(cf.get_value("remap", k, settings["remap"][k]))

func _save_settings() -> void:
	var cf = ConfigFile.new()
	for k in ["volume", "sound", "shake", "edge_scroll"]: cf.set_value("game", k, settings[k])
	for k in settings["keys"]: cf.set_value("keys", k, settings["keys"][k])
	for k in settings["remap"]: cf.set_value("remap", k, settings["remap"][k])
	cf.save(SETTINGS_PATH)

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings["volume"]))))
	if sfx != null: sfx.muted = not settings["sound"]

func _build_pause_menu() -> void:
	pause_panel = PanelContainer.new(); pause_panel.visible = false; pause_panel.theme = HUD.make_theme(); ui_layer.add_child(pause_panel)
	pause_panel.custom_minimum_size = Vector2(320, 0); pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 10); pause_panel.add_child(vb)
	var t = Label.new(); t.text = "PAUSED"; t.add_theme_font_size_override("font_size", 30); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	for entry in [["Resume", _resume], ["Settings", func(): settings_panel.visible = true], ["Quit to menu", func(): _resume(); stop_game()]]:
		var b = Button.new(); b.text = entry[0]; b.custom_minimum_size = Vector2(280, 36); b.pressed.connect(entry[1]); vb.add_child(b)

func _open_pause() -> void:
	if game == null: return
	game.paused = true; pause_panel.visible = true

func _resume() -> void:
	pause_panel.visible = false; settings_panel.visible = false
	if game != null: game.paused = false

func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new(); settings_panel.visible = false; settings_panel.theme = HUD.make_theme(); ui_layer.add_child(settings_panel)
	settings_panel.custom_minimum_size = Vector2(560, 0); settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); settings_panel.add_child(vb)
	var t = Label.new(); t.text = "SETTINGS"; t.add_theme_font_size_override("font_size", 26); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 12); vb.add_child(row)
	var vl = Label.new(); vl.text = "Master volume"; vl.custom_minimum_size = Vector2(160, 0); row.add_child(vl)
	var slider = HSlider.new(); slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.05; slider.value = float(settings["volume"]); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v): settings["volume"] = v; _apply_settings(); _save_settings()); row.add_child(slider)
	for entry in [["sound", "Sound effects"], ["shake", "Screen shake"], ["edge_scroll", "Edge scrolling"]]:
		var cb = CheckButton.new(); cb.text = entry[1]; cb.button_pressed = settings[entry[0]]
		var key: String = entry[0]
		cb.toggled.connect(func(on): settings[key] = on; _apply_settings(); _save_settings()); vb.add_child(cb)
	var hl = Label.new(); hl.text = "Hotkeys (click a key, then press the new one)"; hl.add_theme_color_override("font_color", Color.html("#ffd479")); vb.add_child(hl)
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 4); vb.add_child(grid)
	for action in ["pause", "center", "army", "hero", "idle_worker", "mute", "A", "S", "H", "Q", "W", "E", "R"]:
		var l = Label.new(); l.text = KEY_LABELS[action]; grid.add_child(l)
		var b = Button.new(); b.custom_minimum_size = Vector2(110, 26)
		var a: String = action
		b.pressed.connect(func(): _start_rebind(a)); grid.add_child(b); key_buttons[action] = b
	_refresh_key_buttons()
	var hint = Label.new(); hint.text = "Ctrl+1-9 control groups, arrow keys and minimap move the camera, Esc cancels."; hint.add_theme_color_override("font_color", Color.html("#778899")); hint.add_theme_font_size_override("font_size", 12); vb.add_child(hint)
	var btns = HBoxContainer.new(); btns.alignment = BoxContainer.ALIGNMENT_CENTER; btns.add_theme_constant_override("separation", 12); vb.add_child(btns)
	var reset = Button.new(); reset.text = "Reset defaults"; reset.pressed.connect(func(): settings = DEFAULT_SETTINGS.duplicate(true); _apply_settings(); _save_settings(); _refresh_key_buttons(); slider.value = settings["volume"]); btns.add_child(reset)
	var close = Button.new(); close.text = "Close"; close.pressed.connect(func(): settings_panel.visible = false; rebinding = ""; _refresh_key_buttons()); btns.add_child(close)

func _key_name(action: String) -> String:
	if settings["keys"].has(action): return OS.get_keycode_string(settings["keys"][action])
	return settings["remap"][action]

func _refresh_key_buttons() -> void:
	for a in key_buttons: key_buttons[a].text = ("press a key..." if rebinding == a else _key_name(a))

func _start_rebind(action: String) -> void:
	rebinding = action; _refresh_key_buttons()

func _finish_rebind(keycode: int) -> void:
	if keycode != KEY_ESCAPE:
		if settings["keys"].has(rebinding): settings["keys"][rebinding] = keycode
		else: settings["remap"][rebinding] = OS.get_keycode_string(keycode)
		_save_settings()
	rebinding = ""; _refresh_key_buttons()

# ---------- input ----------
func entity_at(x: float, y: float):
	var best = null; var bd = INF
	for e in game.entities:
		if e.dead: continue
		if e.owner != game.human and not game.can_see(game.human, e): continue
		if e.invisible() and e.owner != game.human and not game.detected(game.human, e): continue
		if e.kind == "building":
			if x >= e.tx * Cfg.TILE and x < (e.tx + e.w) * Cfg.TILE and y >= e.ty * Cfg.TILE and y < (e.ty + e.h) * Cfg.TILE:
				var d = Cfg.dist(x, y, e.x, e.y) + 100.0
				if d < bd: bd = d; best = e
		else:
			var d = Cfg.dist(x, y, e.x, e.y - (14.0 if e.flying else 0.0))
			if d < e.radius + 6 and d < bd: bd = d; best = e
	return best

func node_at(x: float, y: float) -> Variant:
	for nd in game.map.nodes:
		if Cfg.dist(x, y, nd["x"], nd["y"]) < Cfg.TILE * 1.2: return nd
	return null

func _unhandled_input(ev: InputEvent) -> void:
	if game == null: return
	if ev is InputEventMouseButton:
		var pos = get_viewport().get_mouse_position()
		if pos.y > view_size().y: return
		mouse_world = wv.get_global_mouse_position()
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if pending != null: issue_pending(mouse_world.x, mouse_world.y, entity_at(mouse_world.x, mouse_world.y)); return
				if ev.double_click:
					var ent = entity_at(mouse_world.x, mouse_world.y)
					if ent != null and ent.kind == "unit" and ent.owner == game.human:
						var vr = wv.view_rect
						game.selection = game.units(game.human).filter(func(u): return u.def_id == ent.def_id and vr.has_point(Vector2(u.x, u.y)))
					drag_start = null; return
				drag_start = mouse_world; dragging = false
			else: _on_left_up(ev.shift_pressed)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			if pending != null: pending = null; hud.build_menu = false; return
			issue_context(mouse_world.x, mouse_world.y, entity_at(mouse_world.x, mouse_world.y))
	elif ev is InputEventMouseMotion:
		mouse_world = wv.get_global_mouse_position()
		if drag_start != null and drag_start.distance_to(mouse_world) > 6: dragging = true
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if rebinding != "": _finish_rebind(ev.keycode); return
		if ev.keycode == settings["keys"]["mute"]:
			settings["sound"] = not settings["sound"]; _apply_settings(); _save_settings(); game.msg("Sound " + ("on" if settings["sound"] else "off")); return
		_on_key(ev)

func _on_left_up(shift: bool) -> void:
	if drag_start == null: return
	var before = game.selection.duplicate()
	if dragging:
		var a: Vector2 = drag_start; var b = mouse_world
		var x0 = minf(a.x, b.x); var x1 = maxf(a.x, b.x); var y0 = minf(a.y, b.y); var y1 = maxf(a.y, b.y)
		var sel = game.units(game.human).filter(func(u): return u.x >= x0 and u.x <= x1 and u.y >= y0 and u.y <= y1)
		if sel.any(func(u): return u.is_combat()): sel = sel.filter(func(u): return u.is_combat())
		if sel.is_empty():
			var bs = game.buildings(game.human).filter(func(bb): return bb.x >= x0 and bb.x <= x1 and bb.y >= y0 and bb.y <= y1)
			if not bs.is_empty(): sel = [bs[0]]
		if shift:
			for e in sel:
				if not game.selection.has(e): game.selection.append(e)
		else: game.selection = sel
	else:
		var ent = entity_at(mouse_world.x, mouse_world.y)
		if ent != null:
			if shift and ent.owner == game.human:
				if game.selection.has(ent): game.selection.erase(ent)
				else: game.selection.append(ent)
			else: game.selection = [ent]
		elif not shift: game.selection = []
	if not game.selection.is_empty() and game.selection != before: game.emit("select", 0.0, 0.0, game.human)
	hud.build_menu = false
	drag_start = null; dragging = false

func marker(x: float, y: float, color: String) -> void:
	click_marker = {"x": x, "y": y, "color": color, "t": 0.5}
	game.emit("ack", x, y, game.human)

func issue_pending(x: float, y: float, ent) -> void:
	var g = game; var p: Dictionary = pending
	var sel = g.selection.filter(func(e): return e.owner == g.human); var units = sel.filter(func(e): return e.kind == "unit")
	match p["kind"]:
		"move": g.order_move(units, x, y, false); marker(x, y, "#5fff8a")
		"attack":
			if ent != null and ent.owner != g.human and ent.owner >= 0: g.order_attack(units, ent)
			else: g.order_move(units, x, y, true)
			marker(x, y, "#ff5a3c")
		"gather":
			var nd = node_at(x, y)
			if nd != null and nd["type"] == "primary": g.order_gather(units, nd)
			else: g.msg("Target a resource node", "warn")
		"build":
			if ghost != null:
				var b = g.order_build(units, p["defId"], ghost["tx"], ghost["ty"])
				if b != null: hud.build_menu = false
				else: return
		"relocate":
			if ghost != null and not g.order_relocate(p["building"], ghost["tx"], ghost["ty"]): return
		"rally": p["building"].rally = Vector2(x, y)
		"bcast":
			var ab: Dictionary = GData.abilities[p["ability"]]
			if ab["target"] == "ally" and (ent == null or ent.owner != g.human): g.msg("Select a friendly target", "warn"); return
			if ab["target"] == "enemy" and (ent == null or ent.owner == g.human or ent.owner < 0): g.msg("Select an enemy target", "warn"); return
			if not g.building_cast(p["building"], p["ability"], ent, x, y): return
			marker(x, y, "#8fd3ff")
		"cast":
			var ab2: Dictionary = GData.abilities[p["ability"]]; var h = p["caster"]
			if h == null or h.dead: pending = null; return
			if ab2["target"] == "enemy":
				if ent == null or ent.owner == g.human or ent.owner < 0: g.msg("Select an enemy target", "warn"); return
				g.order_cast(h, p["ability"], ent, ent.x, ent.y)
			elif ab2["target"] == "ally":
				if ent == null or ent.owner != g.human: g.msg("Select a friendly target", "warn"); return
				g.order_cast(h, p["ability"], ent, ent.x, ent.y)
			else: g.order_cast(h, p["ability"], null, x, y)
			marker(x, y, "#8fd3ff")
	pending = null; ghost = null

func issue_context(x: float, y: float, ent) -> void:
	var g = game
	var sel = g.selection.filter(func(e): return e.owner == g.human)
	if sel.is_empty(): return
	var units = sel.filter(func(e): return e.kind == "unit"); var blds = sel.filter(func(e): return e.kind == "building")
	if not units.is_empty():
		if ent != null and ent.owner != g.human and ent.owner >= 0: g.order_attack(units, ent); marker(x, y, "#ff5a3c"); return
		var nd = node_at(x, y)
		if nd != null and nd["type"] == "primary" and units.any(func(u): return u.is_worker() and u.faction().get("gathers", false)):
			g.order_gather(units.filter(func(u): return u.is_worker()), nd); g.order_move(units.filter(func(u): return not u.is_worker()), x, y, false); marker(x, y, "#c9a0ff"); return
		if ent != null and ent.kind == "building" and ent.owner == g.human and not ent.complete() and units.any(func(u): return u.is_worker()):
			for w in units.filter(func(u): return u.is_worker()):
				g.clear_order(w); w.order = {"type": "build", "building": ent}; w.build_task = ent; g.set_path(w, ent.x, ent.y)
			return
		g.order_move(units, x, y, false); marker(x, y, "#5fff8a")
	elif blds.size() == 1 and blds[0].def.has("trains"):
		blds[0].rally = Vector2(x, y); marker(x, y, "#ffd479")

func on_minimap(wx: float, wy: float, button: int) -> void:
	if game == null: return
	if button == MOUSE_BUTTON_RIGHT: issue_context(wx, wy, null); return
	if pending != null and (pending["kind"] == "attack" or pending["kind"] == "move"): issue_pending(wx, wy, null); return
	game.camera = Vector2(wx - view_size().x / 2, wy - view_size().y / 2)

func _center_on(x: float, y: float) -> void:
	game.camera = Vector2(x - view_size().x / 2, y - view_size().y / 2)

func _on_key(ev: InputEventKey) -> void:
	var g = game
	var kc = ev.keycode
	if kc == KEY_ESCAPE:
		if settings_panel.visible: settings_panel.visible = false; return
		if pause_panel.visible: _resume(); return
		if pending != null: pending = null; return
		if hud.build_menu: hud.build_menu = false; return
		if not g.selection.is_empty(): g.selection = []; return
		_open_pause(); return
	if kc == settings["keys"]["pause"]: toggle_pause(); return
	if kc == settings["keys"]["center"]:
		if g.attack_ping != null and g.attack_ping["t"] > 0.0: _center_on(g.attack_ping["x"], g.attack_ping["y"])
		else:
			var b = g.base_of(g.human)
			if b != null: _center_on(b.x, b.y)
		return
	if kc >= KEY_0 and kc <= KEY_9:
		var k = str(kc - KEY_0)
		if ev.ctrl_pressed: g.groups[k] = g.selection.filter(func(e): return e.owner == g.human)
		elif g.groups.has(k) and not g.groups[k].is_empty():
			g.selection = g.groups[k].filter(func(e): return not e.dead)
			if last_group_key == k and g.time - last_group_time < 0.4 and not g.selection.is_empty(): _center_on(g.selection[0].x, g.selection[0].y)
			last_group_key = k; last_group_time = g.time
		return
	if kc == settings["keys"]["army"]: g.selection = g.units(g.human).filter(func(u): return u.is_combat()); return
	if kc == settings["keys"]["hero"]:
		var hs = g.heroes(g.human)
		if not hs.is_empty(): g.selection = [hs[0]]; _center_on(hs[0].x, hs[0].y)
		return
	if kc == settings["keys"]["idle_worker"]:
		var idle = g.units(g.human).filter(func(u): return u.is_worker() and u.order["type"] == "idle")
		if not idle.is_empty(): g.selection = [idle[0]]; _center_on(idle[0].x, idle[0].y)
		return
	if ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed: return
	var ks = OS.get_keycode_string(kc)
	for orig in settings["remap"]:
		if settings["remap"][orig] == ks and orig != ks: ks = orig; break
	hud.handle_key(ks)
