class_name HUD
extends Control
## In-game HUD (mirrors js/ui.js): top bar, selection panel, command card, minimap, message log

var game: Game
var main = null
var wv: WorldView
var top_labels = {}
var sel_text: RichTextLabel
var sel_box: VBoxContainer
var queue_box: HBoxContainer
var multi_box: HFlowContainer
var cmd_grid: GridContainer
var log_box: VBoxContainer
var minimap: Minimap
var pause_btn: Button
var quit_btn: Button
var commands = []
var last_sig = ""
var timer = 0.0
var build_menu = false

static func make_theme() -> Theme:
	var th = Theme.new()
	var mk = func(bg: String, border: String) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color.html(bg); sb.border_color = Color.html(border)
		sb.set_border_width_all(1); sb.set_content_margin_all(4)
		return sb
	th.set_stylebox("normal", "Button", mk.call("#1e2438", "#4a5170"))
	th.set_stylebox("hover", "Button", mk.call("#2c3552", "#8fa0d8"))
	th.set_stylebox("pressed", "Button", mk.call("#3a3420", "#ffd479"))
	th.set_stylebox("disabled", "Button", mk.call("#15182a", "#2c3145"))
	th.set_stylebox("focus", "Button", mk.call("#2c3552", "#8fa0d8"))
	th.set_color("font_color", "Button", Color.html("#dddddd"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color.html("#666a80"))
	th.set_font_size("font_size", "Button", 11)
	th.set_stylebox("panel", "PanelContainer", mk.call("#0f1220", "#2c3145"))
	th.set_stylebox("panel", "TooltipPanel", mk.call("#0a0c14", "#5a6390"))
	th.set_color("font_color", "TooltipLabel", Color.html("#dddddd"))
	th.set_color("font_color", "Label", Color.html("#dddddd"))
	th.set_font_size("font_size", "Label", 13)
	th.set_color("default_color", "RichTextLabel", Color.html("#dddddd"))
	th.set_font_size("normal_font_size", "RichTextLabel", 12)
	th.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	return th

func setup(g: Game, m, world_view: WorldView) -> void:
	game = g; main = m; wv = world_view
	for c in get_children(): c.queue_free()
	theme = make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top bar
	var top = PanelContainer.new(); top.custom_minimum_size = Vector2(0, 34); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); add_child(top)
	var hb = HBoxContainer.new(); hb.add_theme_constant_override("separation", 22); top.add_child(hb)
	for key in ["resP", "resS", "resC", "supply"]:
		var l = Label.new(); hb.add_child(l); top_labels[key] = l
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(spacer)
	for key in ["weather", "tier", "clock"]:
		var l = Label.new(); hb.add_child(l); top_labels[key] = l
	top_labels["tier"].add_theme_color_override("font_color", Color.html("#ffd479"))
	top_labels["weather"].add_theme_color_override("font_color", Color.html("#8fd3ff"))
	pause_btn = Button.new(); pause_btn.text = "Pause"; hb.add_child(pause_btn)
	quit_btn = Button.new(); quit_btn.text = "Quit"; hb.add_child(quit_btn)
	# bottom bar
	var bottom = PanelContainer.new(); bottom.custom_minimum_size = Vector2(0, Cfg.HUD_H); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN; bottom.offset_top = -Cfg.HUD_H; add_child(bottom)
	var bh = HBoxContainer.new(); bh.add_theme_constant_override("separation", 8); bottom.add_child(bh)
	minimap = Minimap.new(); minimap.hud = self; minimap.custom_minimum_size = Vector2(188, 176); bh.add_child(minimap)
	sel_box = VBoxContainer.new(); sel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(sel_box)
	sel_text = RichTextLabel.new(); sel_text.bbcode_enabled = true; sel_text.fit_content = true; sel_text.scroll_active = false; sel_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; sel_text.custom_minimum_size = Vector2(300, 90); sel_box.add_child(sel_text)
	queue_box = HBoxContainer.new(); sel_box.add_child(queue_box)
	multi_box = HFlowContainer.new(); sel_box.add_child(multi_box)
	cmd_grid = GridContainer.new(); cmd_grid.columns = 4; cmd_grid.custom_minimum_size = Vector2(372, 0); cmd_grid.add_theme_constant_override("h_separation", 5); cmd_grid.add_theme_constant_override("v_separation", 5); bh.add_child(cmd_grid)
	# log
	log_box = VBoxContainer.new(); log_box.position = Vector2(12, 0); log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(log_box)
	last_sig = ""

func _process(dt: float) -> void:
	if game == null: return
	timer -= dt
	if timer > 0.0: return
	timer = 0.1
	var p: GPlayer = game.players[game.human]; var f = p.faction; var r: Dictionary = f["resources"]
	top_labels["resP"].text = "%s %s: %d" % [r["primary"]["icon"], r["primary"]["name"], int(p.res["p"])]
	top_labels["resS"].text = "%s %s: %d" % [r["secondary"]["icon"], r["secondary"]["name"], int(p.res["s"])]
	top_labels["resC"].text = "%s %s: %d" % [r["catalyst"]["icon"], r["catalyst"]["name"], int(p.res["c"])]
	top_labels["supply"].text = "Supply: %d / %d" % [p.supply_used, p.supply_cap]
	top_labels["supply"].add_theme_color_override("font_color", Color.html("#ff9b6a") if p.supply_used >= p.supply_cap else Color.WHITE)
	top_labels["tier"].text = "Tier %d — %s" % [p.tier, f["tiers"][p.tier - 1]["name"]]
	top_labels["weather"].text = ("STORM %ds" % ceili(game.weather["storm"]["until"])) if game.weather["storm"] != null else ("Eye of Clarity" if game.clarity != null else "")
	top_labels["clock"].text = Cfg.fmt_time(game.time)
	for c in log_box.get_children(): c.queue_free()
	for m in game.messages:
		var l = Label.new(); l.text = m["text"]
		l.add_theme_color_override("font_color", Color.html("#ff9b6a") if m["cls"] == "warn" else (Color.html("#9dff9d") if m["cls"] == "good" else Color.html("#eeeeee")))
		l.modulate.a = minf(1.0, m["t"] / 2.0)
		log_box.add_child(l)
	log_box.position = Vector2(12, size.y - Cfg.HUD_H - 10 - game.messages.size() * 20)
	render_selection()
	render_commands()

func render_selection() -> void:
	var sel = game.selection
	for c in queue_box.get_children(): c.queue_free()
	for c in multi_box.get_children(): c.queue_free()
	var f: Dictionary = game.players[game.human].faction
	if sel.is_empty():
		sel_text.text = "[color=#aab]%s — %s\n\n%s[/color]" % [f["name"], f["tagline"], f["blurb"]]
		return
	if sel.size() == 1:
		var e = sel[0]
		var txt = "[b][font_size=16]%s[/font_size][/b]" % e.name()
		if e.kind == "unit" and e.is_hero: txt += "  [color=#ffd479]Lv %d · %s[/color]" % [e.level, e.def.get("title", "")]
		var hp_col = "#3fd66a" if e.hp / e.max_hp > 0.5 else ("#ffd479" if e.hp / e.max_hp > 0.25 else "#ff5a3c")
		txt += "\n[color=%s]%d / %d[/color]%s" % [hp_col, ceili(e.hp), int(e.max_hp), "" if e.owner == game.human else " [color=#ff9b6a](Enemy)[/color]"]
		if e.kind == "unit":
			txt += "\n[color=#9ab]Dmg %d · Armor %d · Range %s · Speed %.1f%s%s%s[/color]" % [roundi(e.stat("dmg")), int(e.stat("armor")), str(e.def.get("range", 1)), e.stat("speed") / Cfg.TILE, " · Flying" if e.flying else "", " · Anti-air" if e.def.get("air", false) else "", (" · Expires %ds" % ceili(e.lifetime)) if e.lifetime > 0 else ""]
			if e.is_hero: txt += "\n[color=#9ab]XP %d / %d[/color]" % [int(e.xp), int(e.xp_to_level())]
			if e.max_shield > 0: txt += "\n[color=#9fe0ff]Shield %d / %d[/color]" % [ceili(e.shield), roundi(e.stat("maxShield"))]
			var bl = []
			for b in e.buffs:
				if b["t"] > 0.5: bl.append(b["id"].replace("_", " "))
			if not bl.is_empty(): txt += "\n[color=#8fd3ff]Effects: %s[/color]" % ", ".join(bl)
			if e.is_worker() and e.gather["carrying"] > 0: txt += "\nCarrying %d %s" % [int(e.gather["carrying"]), f["resources"]["primary"]["short"]]
			txt += "\n[color=#aab]%s[/color]" % e.def.get("desc", "")
		else:
			var extra = ""
			if e.node != null: extra += " · Node: %s" % ("∞" if e.node["amount"] >= 1e8 else str(int(e.node["amount"])))
			if e.def.has("converter"): extra += " · Conversion %s" % ("ON" if e.toggles["convert"] else "OFF")
			if e.def.has("catalystGen"): extra += " · Catalyst in %ds" % ceili(float(e.def["catalystGen"]["every"]) - e.catalyst_timer)
			txt += "\n[color=#9ab]Armor %d%s[/color]" % [int(e.stat("armor")), extra]
			if not e.complete(): txt += "\nConstructing: %d%%%s" % [int(e.progress * 100), "" if (e.builders > 0 or e.def.get("grows", false)) else " [color=#ff9b6a](no builder!)[/color]"]
			if e.relocate != null: txt += "\n[color=#8fd3ff]Relocating: %s[/color]" % e.relocate["phase"]
			txt += "\n[color=#aab]%s[/color]" % e.def.get("desc", "")
			if not e.queue.is_empty() and e.owner == game.human:
				var i = 0
				for q in e.queue:
					var nm: String
					if q["type"] == "tier": nm = f["tiers"][game.players[game.human].tier]["name"]
					elif q["type"] == "research": nm = f["research"][q["id"]]["name"]
					else: nm = GData.unit_def(f, q["id"]).get("name", q["id"])
					var b = Button.new(); b.text = nm + ((" %d%%" % int(q["elapsed"] / q["time"] * 100)) if i == 0 else ""); b.tooltip_text = "Click to cancel"
					var idx = i
					b.pressed.connect(func(): game.dequeue(e, idx))
					queue_box.add_child(b); i += 1
		sel_text.text = txt
	else:
		sel_text.text = "[b][font_size=16]%d selected[/font_size][/b]" % sel.size()
		for e in sel:
			var b = Button.new(); b.custom_minimum_size = Vector2(36, 30)
			b.text = ("*" if (e.kind == "unit" and e.is_hero) else "") + WorldView.abbrev(e.name()); b.tooltip_text = "%s  %d/%d" % [e.name(), ceili(e.hp), int(e.max_hp)]
			var ent = e
			b.pressed.connect(func(): game.selection = [ent])
			multi_box.add_child(b)

func build_commands() -> Array:
	var g = game; var p: GPlayer = g.players[g.human]; var f = p.faction
	var sel = g.selection.filter(func(e): return e.owner == g.human)
	var cmds = []
	if sel.is_empty(): return cmds
	var units = sel.filter(func(e): return e.kind == "unit"); var blds = sel.filter(func(e): return e.kind == "building")
	var inp = main
	if not units.is_empty():
		var has_worker = units.any(func(u): return u.is_worker())
		if build_menu and has_worker:
			for id in f["buildings"]:
				var d: Dictionary = f["buildings"][id]
				if d.get("isBase", false): continue
				var locked: bool = d.get("tier", 1) > p.tier; var afford = p.can_afford(d.get("cost", {}))
				var tip = "%s\n%s\n%s · %ds · Tier %d" % [d["name"], d.get("desc", ""), Cfg.cost_str(d.get("cost", {}), f), int(d.get("time", 0)), int(d.get("tier", 1))]
				if d.has("needsNode"): tip += "\nMust be placed on a " + ("resource node" if d["needsNode"] == "primary" else "vent")
				var bid: String = id
				cmds.append({"label": d["name"], "key": d.get("hotkey", ""), "cost": Cfg.cost_str(d.get("cost", {}), f), "tip": tip, "disabled": locked or not afford, "why": ("Requires Tier %d" % int(d.get("tier", 1))) if locked else "Not enough resources", "active": inp.pending != null and inp.pending["kind"] == "build" and inp.pending.get("defId", "") == id, "act": func(): inp.pending = {"kind": "build", "defId": bid}})
			cmds.append({"label": "Cancel", "key": "Escape", "tip": "Close build menu", "act": func(): build_menu = false; inp.pending = null})
			return cmds
		cmds.append({"label": "Move", "key": "M", "tip": "Move to a point (right-click also moves)", "active": inp.pending != null and inp.pending["kind"] == "move", "act": func(): inp.pending = {"kind": "move"}})
		cmds.append({"label": "Stop", "key": "S", "tip": "Stop all actions", "act": func(): g.order_stop(units)})
		cmds.append({"label": "Hold", "key": "H", "tip": "Hold position", "act": func(): g.order_hold(units)})
		if units.any(func(u): return float(u.def.get("dmg", 0)) > 0 and not u.is_worker()):
			cmds.append({"label": "Attack", "key": "A", "tip": "Attack-move: engage enemies met along the way", "active": inp.pending != null and inp.pending["kind"] == "attack", "act": func(): inp.pending = {"kind": "attack"}})
		if has_worker:
			cmds.append({"label": "Build", "key": "B", "tip": "Open the structure menu", "act": func(): build_menu = true; inp.pending = null})
			if f.get("gathers", false): cmds.append({"label": "Gather", "key": "G", "tip": "Gather %s from a resource node (or right-click a node)" % f["resources"]["primary"]["name"], "active": inp.pending != null and inp.pending["kind"] == "gather", "act": func(): inp.pending = {"kind": "gather"}})
		var hs = units.filter(func(u): return u.is_hero)
		if hs.size() == 1:
			var h = hs[0]
			for id in h.abilities:
				var ab: Dictionary = GData.abilities[id]; var c = g.can_cast(h, id)
				var tip = "%s%s\n%s\n%s" % [ab["name"], " (Ultimate, hero level 5)" if ab.get("ult", false) else "", ab.get("desc", ""), "Passive" if ab.get("passive", false) else ("Cooldown %ds%s" % [int(ab.get("cooldown", 0)), (" · Range %s" % str(ab["range"])) if ab.get("range", 0) > 0 else ""])]
				var aid: String = id; var hero = h
				cmds.append({"label": ab["name"], "key": ab.get("key", ""), "tip": tip, "disabled": not c["ok"], "why": c.get("why", ""), "cd": 0.0 if ab.get("passive", false) else h.cooldowns.get(id, 0.0) / maxf(1.0, float(ab.get("cooldown", 1))), "active": inp.pending != null and inp.pending["kind"] == "cast" and inp.pending.get("ability", "") == id,
					"act": func():
						if ab.get("passive", false): return
						if ab.get("target", "none") == "none": g.order_cast(hero, aid, null, hero.x, hero.y)
						else: inp.pending = {"kind": "cast", "ability": aid, "caster": hero}})
		return cmds
	if blds.size() == 1:
		var b = blds[0]
		if not b.complete():
			cmds.append({"label": "Cancel construction", "key": "Escape", "tip": "Refund 75% and remove", "act": func():
				p.refund({"p": float(b.def.get("cost", {}).get("p", 0)) * 0.75, "s": float(b.def.get("cost", {}).get("s", 0)) * 0.75}); g.kill(b, null); g.selection = []})
			return cmds
		for id in b.def.get("trains", []):
			var d = GData.unit_def(f, id)
			if d.is_empty(): continue
			var c = g.can_queue(b, {"type": "unit", "id": id}); var uid: String = id
			cmds.append({"label": d["name"], "key": d.get("hotkey", ""), "cost": Cfg.cost_str(d.get("cost", {}), f), "tip": "%s\n%s\n%s · %ds · Supply %d · Tier %d\nHP %d · Dmg %d · Armor %d · Range %s · Speed %s" % [d["name"], d.get("desc", ""), Cfg.cost_str(d.get("cost", {}), f), int(d.get("time", 0)), int(d.get("supply", 0)), int(d.get("tier", 1)), int(d.get("hp", 0)), int(d.get("dmg", 0)), int(d.get("armor", 0)), str(d.get("range", 1)), str(d.get("speed", 3))], "disabled": not c["ok"], "why": c.get("why", ""), "act": func(): g.enqueue(b, {"type": "unit", "id": uid})})
		if b.def.get("isBase", false):
			for id in f["heroes"]:
				var d: Dictionary = f["heroes"][id]; var c = g.can_queue(b, {"type": "hero", "id": id}); var hid: String = id
				var abn = []
				for a in d.get("abilities", []): abn.append(GData.abilities[a]["name"])
				cmds.append({"label": "* " + d["name"], "key": d.get("hotkey", ""), "cost": Cfg.cost_str(d.get("cost", {}), f), "tip": "%s, %s\n%s hero\n%s\n%s · %ds\nAbilities: %s" % [d["name"], d.get("title", ""), d.get("role", ""), d.get("desc", ""), Cfg.cost_str(d.get("cost", {}), f), int(d.get("time", 30)), ", ".join(abn)], "disabled": not c["ok"], "why": c.get("why", ""), "act": func(): g.enqueue(b, {"type": "hero", "id": hid})})
			if p.tier < 3:
				var t: Dictionary = f["tiers"][p.tier]; var c = g.can_queue(b, {"type": "tier"})
				cmds.append({"label": "^ " + t["name"], "key": "U", "cost": Cfg.cost_str(t.get("cost", {}), f), "tip": "Ascend to %s\n%s\n%s · %ds · Requires %s" % [t["name"], t.get("desc", ""), Cfg.cost_str(t.get("cost", {}), f), int(t.get("time", 60)), f["buildings"][t["requires"]]["name"]], "disabled": not c["ok"], "why": c.get("why", ""), "act": func(): g.enqueue(b, {"type": "tier"})})
		for id in b.def.get("research", []):
			var r: Dictionary = f["research"][id]; var c = g.can_queue(b, {"type": "research", "id": id}); var rid: String = id
			cmds.append({"label": "~ " + r["name"], "key": r.get("hotkey", ""), "cost": Cfg.cost_str(r.get("cost", {}), f), "tip": "%s\n%s\n%s · %ds · Tier %d" % [r["name"], r.get("desc", ""), Cfg.cost_str(r.get("cost", {}), f), int(r.get("time", 30)), int(r.get("tier", 1))], "disabled": not c["ok"], "why": c.get("why", ""), "done": p.has_research(id), "act": func(): g.enqueue(b, {"type": "research", "id": rid})})
		for id in b.def.get("abilities", []):
			var ab: Dictionary = GData.abilities[id]; var aid: String = id
			var on_cd: bool = b.cooldowns.get(id, 0.0) > 0.0; var afford: bool = ab.get("cost", null) == null or p.can_afford(ab["cost"])
			var lbl: String = ab["name"] + ((" (ON)" if b.toggles["convert"] else " (OFF)") if id == "toggle_convert" else "")
			cmds.append({"label": lbl, "key": ab.get("key", ""), "tip": "%s\n%s\n%s%s" % [ab["name"], ab.get("desc", ""), ("Cooldown %ds" % int(ab["cooldown"])) if ab.get("cooldown", 0) > 0 else "", (" · " + Cfg.cost_str(ab["cost"], f)) if ab.get("cost", null) != null else ""], "disabled": on_cd or not afford or b.relocate != null, "why": "Cooldown" if on_cd else "Not enough resources", "cd": b.cooldowns.get(id, 0.0) / maxf(1.0, float(ab.get("cooldown", 1))), "active": inp.pending != null and inp.pending["kind"] == "relocate",
				"act": func():
					if aid == "relocate": inp.pending = {"kind": "relocate", "building": b}
					elif ab.get("target", "none") != "none": inp.pending = {"kind": "bcast", "building": b, "ability": aid}
					else: g.building_cast(b, aid)})
		if b.def.has("trains") and not b.def.get("isBase", false):
			cmds.append({"label": "Rally", "key": "Y", "tip": "Set rally point (or right-click with the building selected)", "active": inp.pending != null and inp.pending["kind"] == "rally", "act": func(): inp.pending = {"kind": "rally", "building": b}})
	return cmds

func render_commands() -> void:
	commands = build_commands()
	var sig = ""
	for c in commands: sig += c["label"] + ("d" if c.get("disabled", false) else "") + ("a" if c.get("active", false) else "") + ("k" if c.get("done", false) else "") + str(roundi(c.get("cd", 0.0) * 20)) + "|"
	if sig == last_sig: return
	last_sig = sig
	for c in cmd_grid.get_children(): c.queue_free()
	for c in commands:
		var b = Button.new(); b.custom_minimum_size = Vector2(84, 54); b.clip_text = true
		b.text = ("[%s] " % ("Esc" if c.get("key", "") == "Escape" else c.get("key", ""))) + ("v " if c.get("done", false) else "") + c["label"] + (("\n" + c["cost"]) if c.has("cost") else "")
		b.tooltip_text = c.get("tip", "") + (("\n" + c["why"]) if (c.get("disabled", false) and c.get("why", "") != "") else "")
		b.disabled = c.get("disabled", false)
		if c.get("active", false): b.add_theme_stylebox_override("normal", theme.get_stylebox("pressed", "Button"))
		if c.get("cd", 0.0) > 0.0: b.modulate = Color(0.7, 0.7, 0.7)
		var cmd = c
		b.pressed.connect(func():
			if cmd.get("disabled", false):
				if cmd.get("why", "") != "": game.msg(cmd["why"], "warn")
				return
			cmd["act"].call(); last_sig = "")
		cmd_grid.add_child(b)

func handle_key(k: String) -> bool:
	commands = build_commands()
	for c in commands:
		if c.get("key", "") == k:
			if c.get("disabled", false):
				if c.get("why", "") != "": game.msg(c["why"], "warn")
				return true
			c["act"].call(); last_sig = ""
			return true
	return false

## Minimap is layered like the world view: ground and terrain layers behind (shader-composed),
## entities in the control itself, then fog and the overlay (ping, view rectangle) on top.
class Minimap extends Control:
	var hud: HUD
	var drag = false
	var parts = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		for name in ["ground", "layers", "fog", "overlay"]:
			var p = MiniPart.new(); p.hud = hud; p.part = name
			p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.show_behind_parent = name == "ground" or name == "layers"
			if name == "layers":
				var sh = Shader.new(); sh.code = WorldView.LAYER_SHADER
				var m = ShaderMaterial.new(); m.shader = sh; p.material = m
			elif name == "fog":
				var sh2 = Shader.new(); sh2.code = WorldView.FOG_SHADER
				var m2 = ShaderMaterial.new(); m2.shader = sh2; m2.set_shader_parameter("strength", 0.8); p.material = m2
				p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(p); parts.append(p)
	func _process(_dt: float) -> void:
		queue_redraw()
		for p in parts: p.queue_redraw()
	func _gui_input(ev: InputEvent) -> void:
		if hud == null or hud.game == null: return
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT: drag = ev.pressed
			if ev.pressed: hud.main.on_minimap(ev.position.x / size.x * Cfg.WORLD_W, ev.position.y / size.y * Cfg.WORLD_H, ev.button_index)
		elif ev is InputEventMouseMotion and drag:
			hud.main.on_minimap(ev.position.x / size.x * Cfg.WORLD_W, ev.position.y / size.y * Cfg.WORLD_H, MOUSE_BUTTON_LEFT)
	func _draw() -> void:
		if hud == null or hud.game == null or hud.wv == null or hud.wv.mini_terrain_tex == null: return
		var g: Game = hud.game; var W = size.x; var H = size.y; var sx = W / Cfg.WORLD_W; var sy = H / Cfg.WORLD_H
		for nd in g.map.nodes:
			draw_rect(Rect2(nd["x"] * sx - 1.5, nd["y"] * sy - 1.5, 3, 3), Color.html("#5ad0e6") if nd["type"] == "primary" else Color.html("#48d67f"))
		for e in g.entities:
			if e.dead: continue
			if e.owner != g.human and not g.can_see(g.human, e): continue
			if e.invisible() and e.owner != g.human: continue
			var c = Color.html("#5fff8a") if e.owner == g.human else Color.html("#ff5a3c")
			if e.kind == "building": draw_rect(Rect2(e.tx * W / Cfg.MAP_W, e.ty * H / Cfg.MAP_H, maxf(2, e.w * W / Cfg.MAP_W), maxf(2, e.h * H / Cfg.MAP_H)), c)
			else: draw_rect(Rect2(e.x * sx - 1, e.y * sy - 1, 3 if e.is_hero else 2, 3 if e.is_hero else 2), c)

class MiniPart extends Control:
	var hud: HUD
	var part = ""
	func _draw() -> void:
		if hud == null or hud.game == null or hud.wv == null: return
		var g: Game = hud.game; var W = size.x; var H = size.y; var sx = W / Cfg.WORLD_W; var sy = H / Cfg.WORLD_H
		match part:
			"ground":
				if hud.wv.mini_terrain_tex != null: draw_texture_rect(hud.wv.mini_terrain_tex, Rect2(0, 0, W, H), false)
			"layers":
				if hud.wv.layer_texs.is_empty(): return
				var m: ShaderMaterial = material
				m.set_shader_parameter("blight_tex", hud.wv.layer_texs["blight"])
				m.set_shader_parameter("light_tex", hud.wv.layer_texs["light"])
				m.set_shader_parameter("grove_tex", hud.wv.layer_texs["grove"])
				draw_texture_rect(hud.wv.layer_texs["blight"], Rect2(0, 0, W, H), false)
			"fog":
				if hud.wv.fog_tex != null: draw_texture_rect(hud.wv.fog_tex, Rect2(0, 0, W, H), false)
			"overlay":
				if g.attack_ping != null and g.attack_ping["t"] > 0.0:
					g.attack_ping["t"] -= 0.016
					draw_arc(Vector2(g.attack_ping["x"] * sx, g.attack_ping["y"] * sy), 4 + (sin(hud.wv.blink * 10) + 1) * 3, 0, TAU, 12, Color.html("#ff5a3c"), 2.0)
				var vr = hud.wv.view_rect
				draw_rect(Rect2(vr.position.x * sx, vr.position.y * sy, vr.size.x * sx, vr.size.y * sy), Color.WHITE, false, 1.0)
