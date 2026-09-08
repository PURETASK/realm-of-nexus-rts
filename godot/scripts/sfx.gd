class_name Sfx
extends Node
## Procedural sound effects and game-feel helpers. Every sound is synthesized at startup into an
## AudioStreamWAV, so no audio files are needed; drop real .wav/.ogg files in res://assets/sfx/<name>.wav
## later and they replace the synthesized ones automatically.

const RATE := 22050
const POOL := 12
var streams = {}
var players = []
var last_play = {}
var master_db = 0.0
var muted = false
var camera: Camera2D
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7
	for i in range(POOL):
		var pl = AudioStreamPlayer2D.new(); pl.max_distance = 1500.0; pl.attenuation = 1.4; pl.bus = "Master"
		add_child(pl); players.append(pl)
	_build_library()

# ---------- synthesis ----------
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var s = AudioStreamWAV.new(); s.format = AudioStreamWAV.FORMAT_16_BITS; s.mix_rate = RATE; s.stereo = false
	var bytes = PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	s.data = bytes
	return s

## Additive synth: freq_from -> freq_to over dur seconds, exponential decay, optional noise mix
func _synth(dur: float, f0: float, f1: float, decay: float, noise: float, wave := "sine", gain := 0.8) -> PackedFloat32Array:
	var n = int(dur * RATE); var out = PackedFloat32Array(); out.resize(n)
	var phase = 0.0; var t = 0.0; var dt = 1.0 / RATE
	var lp = 0.0
	for i in range(n):
		var k = float(i) / n
		var f = f0 + (f1 - f0) * k
		phase += f * dt * TAU
		var v: float
		match wave:
			"square": v = 1.0 if fmod(phase, TAU) < PI else -1.0
			"saw": v = fmod(phase, TAU) / PI - 1.0
			"tri": v = absf(fmod(phase, TAU) / PI - 1.0) * 2.0 - 1.0
			_: v = sin(phase)
		if noise > 0.0:
			var nz = _rng.randf_range(-1.0, 1.0)
			lp += (nz - lp) * 0.35  # crude low-pass so the noise is not pure hiss
			v = v * (1.0 - noise) + lp * noise * 1.6
		var env = exp(-decay * t) * minf(1.0, i / (0.004 * RATE))  # 4 ms attack
		out[i] = v * env * gain
		t += dt
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_s := 0.0) -> PackedFloat32Array:
	var off = int(offset_s * RATE); var n = maxi(a.size(), b.size() + off)
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(a.size()): out[i] += a[i]
	for i in range(b.size()): out[i + off] += b[i]
	return out

func _build_library() -> void:
	var L = {}
	L["hit"] = _synth(0.09, 180, 90, 40.0, 0.7, "tri", 0.7)
	L["hit_heavy"] = _mix(_synth(0.2, 120, 50, 18.0, 0.6, "tri", 0.9), _synth(0.12, 60, 40, 25.0, 0.0, "sine", 0.6))
	L["shoot_arrow"] = _synth(0.12, 900, 300, 30.0, 0.9, "sine", 0.35)
	L["shoot_bolt"] = _synth(0.16, 300, 1200, 18.0, 0.15, "saw", 0.35)
	L["shoot_shell"] = _synth(0.3, 90, 40, 12.0, 0.8, "tri", 0.8)
	L["death"] = _mix(_synth(0.35, 420, 110, 9.0, 0.3, "saw", 0.5), _synth(0.2, 200, 60, 20.0, 0.8, "tri", 0.5), 0.03)
	L["death_big"] = _mix(_synth(0.7, 160, 40, 5.0, 0.4, "saw", 0.7), _synth(0.5, 50, 30, 6.0, 0.9, "tri", 0.8))
	L["death_building"] = _mix(_synth(0.9, 70, 30, 4.0, 0.9, "tri", 0.9), _synth(0.6, 40, 25, 5.0, 0.0, "sine", 0.7), 0.1)
	L["ready"] = _mix(_synth(0.18, 660, 660, 12.0, 0.0, "sine", 0.4), _synth(0.3, 990, 990, 9.0, 0.0, "sine", 0.4), 0.12)
	L["tier"] = _mix(_mix(_synth(0.25, 523, 523, 8.0, 0.0, "sine", 0.4), _synth(0.25, 659, 659, 8.0, 0.0, "sine", 0.4), 0.15), _synth(0.5, 784, 784, 5.0, 0.0, "sine", 0.45), 0.3)
	L["cast"] = _synth(0.3, 250, 1400, 9.0, 0.1, "sine", 0.45)
	L["ult"] = _mix(_synth(0.6, 80, 600, 5.0, 0.2, "saw", 0.5), _synth(0.8, 40, 30, 4.0, 0.7, "tri", 0.7), 0.1)
	L["select"] = _synth(0.06, 800, 1100, 45.0, 0.0, "square", 0.18)
	L["ack"] = _mix(_synth(0.05, 700, 700, 50.0, 0.0, "square", 0.16), _synth(0.06, 1000, 1000, 45.0, 0.0, "square", 0.16), 0.06)
	L["error"] = _synth(0.18, 140, 120, 15.0, 0.0, "square", 0.25)
	L["warn"] = _mix(_synth(0.15, 880, 880, 10.0, 0.0, "square", 0.22), _synth(0.2, 660, 660, 8.0, 0.0, "square", 0.22), 0.16)
	L["build_done"] = _mix(_synth(0.1, 300, 300, 20.0, 0.6, "tri", 0.4), _synth(0.25, 520, 520, 10.0, 0.0, "sine", 0.35), 0.08)
	L["gather"] = _synth(0.05, 1400, 900, 60.0, 0.5, "tri", 0.15)
	for k in L:
		var path = "res://assets/sfx/%s.wav" % k
		if FileAccess.file_exists(path) and ResourceLoader.exists(path): streams[k] = load(path)
		else: streams[k] = _wav(L[k])

# ---------- playback ----------
## Plays a sound at a world position (or non-positionally when x < 0). min_gap limits spam per sound.
func play(name: String, x := -1.0, y := 0.0, db := 0.0, min_gap := 0.05, pitch_var := 0.08) -> void:
	if muted or not streams.has(name): return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_play.get(name, -1.0) < min_gap: return
	last_play[name] = now
	var pl: AudioStreamPlayer2D = null
	for p in players:
		if not p.playing: pl = p; break
	if pl == null: pl = players[_rng.randi() % POOL]
	pl.stream = streams[name]
	pl.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	pl.volume_db = master_db + db
	if x < 0.0 and camera != null:
		pl.global_position = camera.get_screen_center_position()
	else:
		pl.global_position = Vector2(x, y)
	pl.play()

## Translate a simulation event ({type, x, y, ...}) into sound. human is the local player's index.
func handle(ev: Dictionary, human: int) -> float:
	var shake = 0.0
	var mine: bool = ev.get("owner", -1) == human
	match ev["type"]:
		"hit":
			var d: float = ev.get("dmg", 0.0)
			if d >= 45.0: play("hit_heavy", ev["x"], ev["y"], -2.0, 0.08); shake = 2.5
			else: play("hit", ev["x"], ev["y"], -8.0, 0.045)
		"shoot":
			play("shoot_" + str(ev.get("kind", "arrow")), ev["x"], ev["y"], -6.0, 0.06, 0.15)
		"death":
			if ev.get("building", false): play("death_building", ev["x"], ev["y"], 2.0, 0.1); shake = 9.0
			elif ev.get("big", false): play("death_big", ev["x"], ev["y"], 0.0, 0.1); shake = 5.0
			else: play("death", ev["x"], ev["y"], -4.0, 0.06, 0.2)
		"ready":
			if mine: play("ready", -1.0, 0.0, -4.0, 0.2)
		"tier":
			if mine: play("tier", -1.0, 0.0, 0.0, 0.5)
		"build_done":
			if mine: play("build_done", -1.0, 0.0, -4.0, 0.2)
		"cast":
			if ev.get("ult", false): play("ult", ev["x"], ev["y"], 2.0, 0.3); shake = 6.0
			else: play("cast", ev["x"], ev["y"], -3.0, 0.1, 0.2)
		"select": play("select", -1.0, 0.0, -6.0, 0.05, 0.02)
		"ack": play("ack", -1.0, 0.0, -6.0, 0.08, 0.05)
		"error": play("error", -1.0, 0.0, -4.0, 0.15)
		"warn": play("warn", -1.0, 0.0, -2.0, 1.0)
		"gather": play("gather", ev["x"], ev["y"], -10.0, 0.2, 0.3)
	return shake
