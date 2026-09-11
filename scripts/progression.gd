extends "res://scripts/neon_polish.gd"

# ---------------------------------------------------------------------------
# Progression layer. Purely additive on top of the neon polish build:
#   * persistent best score (user://scores.cfg, same idiom as the audio config);
#   * a real difficulty ramp - obstacles recycle closer together and the top
#     speed creeps up as the run gets longer;
#   * collectible pickups (gold data cores that build a score chain multiplier,
#     and green shields that absorb one otherwise-fatal hit);
#   * the extra HUD (best / chain / shield) and small synthesised pickup SFX.
#
# Everything hooks the existing overridable seams (_ready, _physics_process,
# _hit, _reset_obstacle, _make_ui) and always calls super first, so the ship,
# corridor, biomes, hazards, curve and audio built below are untouched.
# ---------------------------------------------------------------------------

const SCORE_CONFIG := "user://scores.cfg"
const PICKUP_COUNT := 6
const CHAIN_WINDOW := 6.0     # seconds a chain survives without a fresh core
const CHAIN_MAX := 12
const SHIELD_MAX := 1
const DIFFICULTY_DISTANCE := 6500.0

var best_score := 0
var bonus_points := 0
var chain := 0
var chain_timer := 0.0
var shield_charges := 0
var _new_best := false
var _invuln_ms := 0

var pickup_root: Node3D
var fx_player: AudioStreamPlayer
var _core_sound: AudioStreamWAV
var _shield_sound: AudioStreamWAV
var _shieldbreak_sound: AudioStreamWAV
var _shield_bubble: MeshInstance3D

var _best_label: Label
var _chain_label: Label
var _shield_label: Label
var _version_label: Label

func _ready() -> void:
	super._ready()
	_load_best()
	_update_best_label()
	_core_sound = _make_tone(680.0, 1180.0, 0.12, 0.5)
	_shield_sound = _make_tone(420.0, 780.0, 0.22, 0.5)
	_shieldbreak_sound = _make_tone(900.0, 260.0, 0.20, 0.6)
	fx_player = AudioStreamPlayer.new()
	fx_player.volume_db = -3.0
	add_child(fx_player)
	_make_shield_bubble()
	_spawn_pickups()

# --- Difficulty -----------------------------------------------------------

func _difficulty() -> float:
	return clampf(score / DIFFICULTY_DISTANCE, 0.0, 1.0)

# The far respawn distance is squeezed as difficulty rises, so the random
# hazards fill a shorter stretch of tunnel and arrive more often. The three
# fixed-index opening hazards ignore z, so they are left exactly as-is.
func _reset_obstacle(area: Area3D, z: float) -> void:
	var dz := lerpf(z, z * 0.82, _difficulty())
	super._reset_obstacle(area, dz)

# --- Frame update ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive:
		return
	max_speed = 58.0 + 5.0 * _difficulty()
	chain_timer = maxf(0.0, chain_timer - delta)
	if chain_timer <= 0.0:
		chain = 0
	_update_pickups(delta)
	_update_shield_visual()
	_update_hud()

func _total_score() -> int:
	return int(score) + bonus_points

func _mult() -> float:
	return 1.0 + float(chain) * 0.5

# --- Pickups --------------------------------------------------------------

func _spawn_pickups() -> void:
	pickup_root = Node3D.new()
	pickup_root.name = "Pickups"
	add_child(pickup_root)
	for i in range(PICKUP_COUNT):
		_reset_pickup(_create_pickup(), -64.0 - float(i) * 22.0)

func _create_pickup() -> Node3D:
	var holder := Node3D.new()
	var visual := Node3D.new()
	holder.add_child(visual)
	pickup_root.add_child(holder)
	return holder

func _reset_pickup(holder: Node3D, z: float) -> void:
	var visual := holder.get_child(0) as Node3D
	for c in visual.get_children():
		c.queue_free()
	var is_shield := randf() < 0.30
	if is_shield:
		var green := _mat(Color(0.25, 1.0, 0.55), Color(0.05, 1.0, 0.45), 5.5, 0.0, 0.15)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.30
		ring.outer_radius = 0.42
		ring.rings = 16
		ring.ring_segments = 8
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = green
		visual.add_child(rm)
		var core := SphereMesh.new()
		core.radius = 0.16
		core.height = 0.32
		var cm := MeshInstance3D.new()
		cm.mesh = core
		cm.material_override = green
		visual.add_child(cm)
		holder.set_meta("type", 1)
	else:
		var gold := _mat(Color(1.0, 0.80, 0.24), Color(1.0, 0.62, 0.05), 5.5, 0.10, 0.12)
		var gem := SphereMesh.new()
		gem.radius = 0.24
		gem.height = 0.52
		gem.radial_segments = 6
		gem.rings = 3
		var gmi := MeshInstance3D.new()
		gmi.mesh = gem
		gmi.material_override = gold
		visual.add_child(gmi)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.30
		ring.outer_radius = 0.36
		ring.rings = 14
		ring.ring_segments = 6
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = gold
		rm.rotation_degrees.x = 90.0
		visual.add_child(rm)
		holder.set_meta("type", 0)
	var bx := randf_range(-3.0, 3.0)
	var by := randf_range(-1.7, 1.1)
	holder.position = Vector3(bx, by, z)
	holder.set_meta("bx", bx)
	holder.set_meta("by", by)
	holder.set_meta("active", true)
	holder.visible = true

func _update_pickups(delta: float) -> void:
	if pickup_root == null:
		return
	var sp := ship.global_position
	for child in pickup_root.get_children():
		var holder := child as Node3D
		holder.position.z += speed * delta
		var visual := holder.get_child(0) as Node3D
		visual.rotation_degrees.y += 120.0 * delta
		if holder.position.z > 3.0:
			_reset_pickup(holder, randf_range(-180.0, -120.0))
			continue
		var off := _curve_at(-holder.position.z)
		holder.position.x = float(holder.get_meta("bx", 0.0)) + off.x
		holder.position.y = float(holder.get_meta("by", 0.0)) + off.y
		if bool(holder.get_meta("active", false)) and absf(holder.position.z - sp.z) < 1.1:
			if sp.distance_to(holder.global_position) < 0.98:
				_collect(holder)

func _collect(holder: Node3D) -> void:
	holder.set_meta("active", false)
	holder.visible = false
	var t := int(holder.get_meta("type", 0))
	if t == 1:
		shield_charges = mini(SHIELD_MAX, shield_charges + 1)
		_play_fx(_shield_sound)
		_flash(holder.position, Color(0.3, 1.0, 0.6))
	else:
		chain = mini(CHAIN_MAX, chain + 1)
		chain_timer = CHAIN_WINDOW
		bonus_points += int(120.0 * _mult())
		_play_fx(_core_sound)
		_flash(holder.position, Color(1.0, 0.8, 0.3))

# --- Shield / collision ---------------------------------------------------

func _make_shield_bubble() -> void:
	_shield_bubble = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.95
	sphere.height = 1.9
	_shield_bubble.mesh = sphere
	var bm := _mat(Color(0.2, 1.0, 0.6), Color(0.1, 1.0, 0.5), 1.4, 0.0, 0.2)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.2, 1.0, 0.6, 0.18)
	_shield_bubble.material_override = bm
	_shield_bubble.visible = false
	ship.add_child(_shield_bubble)

func _update_shield_visual() -> void:
	if _shield_bubble == null:
		return
	var on := shield_charges > 0
	_shield_bubble.visible = on
	if on:
		var pulse := 1.0 + 0.06 * sin(elapsed * 6.0)
		if Time.get_ticks_msec() < _invuln_ms:
			pulse += 0.15
		_shield_bubble.scale = Vector3(pulse, pulse, pulse)

# Intercept hits: honour i-frames, spend a shield if one is charged, and only
# otherwise fall through to the real death handled by the lower layers.
func _hit(body: Node) -> void:
	if not alive:
		return
	if Time.get_ticks_msec() < _invuln_ms:
		return
	if shield_charges > 0:
		shield_charges -= 1
		_invuln_ms = Time.get_ticks_msec() + 900
		_play_fx(_shieldbreak_sound)
		_flash(ship.global_position, Color(0.3, 1.0, 0.7))
		return
	super._hit(body)
	if not alive:
		_finalize_score()

func _finalize_score() -> void:
	var total := _total_score()
	_new_best = total > best_score
	if _new_best:
		best_score = total
		_save_best()
	_update_best_label()

# --- Persistence ----------------------------------------------------------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SCORE_CONFIG) == OK:
		best_score = int(cfg.get_value("score", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.save(SCORE_CONFIG)

# --- HUD ------------------------------------------------------------------

func _hud_layer() -> CanvasLayer:
	for child in get_children():
		if child is CanvasLayer:
			return child as CanvasLayer
	return null

func _make_ui() -> void:
	super._make_ui()
	var layer := _hud_layer()
	if layer == null:
		return
	for control in layer.get_children():
		if control is Label and (control as Label).text.begins_with("VORTEX // RUNNER"):
			_version_label = control as Label
	if _version_label:
		_version_label.visible = false

	_best_label = Label.new()
	_best_label.position = Vector2(24, 66)
	_best_label.add_theme_font_size_override("font_size", 18)
	_best_label.modulate = Color(1.0, 0.85, 0.4, 0.92)
	_best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_best_label)

	_chain_label = Label.new()
	_chain_label.position = Vector2(24, 96)
	_chain_label.add_theme_font_size_override("font_size", 30)
	_chain_label.modulate = Color(1.0, 0.8, 0.3)
	_chain_label.pivot_offset = Vector2(20, 20)
	_chain_label.visible = false
	_chain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_chain_label)

	_shield_label = Label.new()
	_shield_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_shield_label.position = Vector2(-260, 34)
	_shield_label.add_theme_font_size_override("font_size", 22)
	_shield_label.modulate = Color(0.4, 1.0, 0.65)
	_shield_label.text = "◈ BOUCLIER"
	_shield_label.visible = false
	_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_shield_label)

func _update_best_label() -> void:
	if _best_label:
		_best_label.text = "MEILLEUR  %06d" % best_score

func _update_hud() -> void:
	if ui_label:
		ui_label.text = "%06d  //  %03d" % [_total_score(), int(speed)]
	if _chain_label:
		if chain > 0:
			_chain_label.visible = true
			_chain_label.text = "x%.1f" % _mult()
			var p := 1.0 + 0.12 * sin(elapsed * 12.0)
			_chain_label.scale = Vector2(p, p)
		else:
			_chain_label.visible = false
	if _shield_label:
		_shield_label.visible = shield_charges > 0

# Toggled by the menu layer when entering / leaving gameplay.
func _set_playing_hud(is_playing: bool) -> void:
	if ui_label:
		ui_label.visible = is_playing
	if _best_label:
		_best_label.visible = is_playing
	if _version_label:
		_version_label.visible = false
	if not is_playing:
		if _chain_label:
			_chain_label.visible = false
		if _shield_label:
			_shield_label.visible = false

# --- FX -------------------------------------------------------------------

func _play_fx(stream: AudioStream) -> void:
	if fx_player and stream:
		fx_player.stream = stream
		fx_player.play()

func _flash(pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	m.mesh = sphere
	var mat := _mat(color, color, 6.0, 0.0, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.position = pos
	add_child(m)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(3.0, 3.0, 3.0), 0.35)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.set_parallel(false)
	tw.tween_callback(Callable(m, "queue_free"))

func _make_tone(f0: float, f1: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var frame_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in range(frame_count):
		var t := float(i) / float(sample_rate)
		var prog := t / duration
		var freq := lerpf(f0, f1, prog)
		var env := sin(PI * prog)
		var sample := sin(TAU * freq * t) * env * volume
		sample = tanh(sample * 1.2) * 0.9
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xff
		data[i * 2 + 1] = (value >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
