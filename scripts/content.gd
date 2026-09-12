extends "res://scripts/fx.gd"

# ---------------------------------------------------------------------------
# Content layer (top of the chain, wired to main.tscn).
#
#   * Music keeps playing on the menu and the game-over screen (the crash cuts
#     it for impact; here it resumes).
#   * A "SECTEUR" banner announces each biome transition.
#   * A new pickup: the violet x2 orb doubles score for a few seconds.
# ---------------------------------------------------------------------------

const BIOME_NAMES := ["INDUSTRIEL", "RÉACTEUR", "ÉNERGIE", "LABORATOIRE", "CRYO", "TOXIQUE"]
const DOUBLE_CHANCE := 0.12
const DOUBLE_MS := 6000

var _last_biome := -1
var _dbl_until := 0
var _dbl_accum := 0.0
var _content_toast: Label

func _ready() -> void:
	super._ready()
	_build_content_toast()

# --- Music on menu / game over --------------------------------------------

func _resume_music() -> void:
	if music_player and music_enabled and not music_player.playing:
		_play_track(music_index)

func _show_menu() -> void:
	super._show_menu()
	_resume_music()

func _show_game_over() -> void:
	super._show_game_over()
	_resume_music()

# --- Run flow -------------------------------------------------------------

func _begin_game() -> void:
	_last_biome = -1
	_dbl_until = 0
	_dbl_accum = 0.0
	super._begin_game()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not (started and alive):
		return
	var b := _current_biome()
	if b != _last_biome:
		if _last_biome != -1 and b >= 0 and b < BIOME_NAMES.size():
			_toast("SECTEUR : %s" % BIOME_NAMES[b], Color(0.5, 0.9, 1.0))
		_last_biome = b
	if Time.get_ticks_msec() < _dbl_until:
		_dbl_accum += speed * delta
		var whole := int(_dbl_accum)
		if whole > 0:
			bonus_points += whole
			_dbl_accum -= float(whole)

# --- x2 score orb ---------------------------------------------------------

func _reset_pickup(holder: Node3D, z: float) -> void:
	super._reset_pickup(holder, z)
	if int(holder.get_meta("type", 0)) == 0 and randf() < DOUBLE_CHANCE:
		var visual := holder.get_child(0) as Node3D
		for c in visual.get_children():
			c.queue_free()
		var violet := _mat(Color(0.72, 0.35, 1.0), Color(0.6, 0.12, 1.0), 5.5, 0.1, 0.12)
		var gem := SphereMesh.new()
		gem.radius = 0.27
		gem.height = 0.54
		gem.radial_segments = 6
		gem.rings = 3
		var gmi := MeshInstance3D.new()
		gmi.mesh = gem
		gmi.material_override = violet
		visual.add_child(gmi)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.32
		ring.outer_radius = 0.40
		ring.rings = 12
		ring.ring_segments = 6
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = violet
		rm.rotation_degrees.x = 90.0
		visual.add_child(rm)
		holder.set_meta("type", 2)

func _collect(holder: Node) -> void:
	var t := int(holder.get_meta("type", 0))
	super._collect(holder)
	if t == 2:
		_dbl_until = Time.get_ticks_msec() + DOUBLE_MS
		_toast("SCORE ×2 !", Color(0.82, 0.45, 1.0))
		_flash(holder.position, Color(0.82, 0.45, 1.0))

# --- Toast ----------------------------------------------------------------

func _build_content_toast() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	_content_toast = Label.new()
	_content_toast.add_theme_font_size_override("font_size", 36)
	_content_toast.position = Vector2(120, 320)
	_content_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_toast.visible = false
	layer.add_child(_content_toast)

func _toast(text: String, color: Color) -> void:
	if _content_toast == null:
		return
	_content_toast.text = text
	_content_toast.modulate = Color(color.r, color.g, color.b, 1.0)
	_content_toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_content_toast, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _content_toast.visible = false)
