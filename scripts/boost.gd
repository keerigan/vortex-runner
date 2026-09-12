extends "res://scripts/health.gd"

# ---------------------------------------------------------------------------
# Overdrive / boost layer (top of the chain, wired to main.tscn).
#
# The risk/reward hook: skimming hazards (near misses) and grabbing data cores
# charge a boost meter. When it fills, Overdrive fires automatically - a few
# seconds of invincibility, higher top speed, doubled score and a bright screen
# wash - then the meter drains back to empty. Because near misses charge it, the
# player is pushed to graze danger on purpose, which is what makes "one more run"
# stick. Built on the existing near-miss, pickup, combo and health systems.
# ---------------------------------------------------------------------------

const OVERDRIVE_MS := 4000
const BOOST_PER_NEARMISS := 0.16
const BOOST_PER_CORE := 0.22
const BOOST_PASSIVE_PER_SEC := 0.05
const OVERDRIVE_SPEED_MUL := 1.30
const BAR_W := 185.0

var _boost_gain_mul := 1.0    # raised by the shop's "fast boost" upgrade
var _boost := 0.0
var _overdrive_until := 0
var _od_accum := 0.0
var _boost_bg: ColorRect
var _boost_fill: ColorRect
var _od_overlay: ColorRect
var _od_label: Label
var _boost_sound: AudioStreamWAV

func _ready() -> void:
	super._ready()
	_boost_sound = _make_tone(420.0, 1600.0, 0.35, 0.4)
	_build_boost_ui()

func _build_boost_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	_od_overlay = ColorRect.new()
	_od_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_od_overlay.color = Color(0.1, 0.8, 1.0, 0.0)
	_od_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_od_overlay)

	_boost_bg = ColorRect.new()
	_boost_bg.position = Vector2(24, 150)
	_boost_bg.size = Vector2(BAR_W, 12)
	_boost_bg.color = Color(0.10, 0.13, 0.18, 0.7)
	_boost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_boost_bg)

	_boost_fill = ColorRect.new()
	_boost_fill.position = Vector2(24, 150)
	_boost_fill.size = Vector2(0, 12)
	_boost_fill.color = Color(0.15, 0.85, 1.0, 0.95)
	_boost_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_boost_fill)

	_od_label = Label.new()
	_od_label.text = "⚡ SURCHAUFFE ⚡"
	_od_label.position = Vector2(120, 150)
	_od_label.add_theme_font_size_override("font_size", 26)
	_od_label.modulate = Color(1.0, 0.9, 0.4)
	_od_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_od_label.visible = false
	layer.add_child(_od_label)

func _begin_game() -> void:
	_boost = 0.0
	_overdrive_until = 0
	_od_accum = 0.0
	_update_boost_ui()
	super._begin_game()

func _overdrive_active() -> bool:
	return Time.get_ticks_msec() < _overdrive_until

func _add_boost(amount: float) -> void:
	if not started or not alive or _overdrive_active():
		return
	_boost = clampf(_boost + amount * _boost_gain_mul, 0.0, 1.0)
	if _boost >= 1.0:
		_start_overdrive()

func _start_overdrive() -> void:
	_overdrive_until = Time.get_ticks_msec() + OVERDRIVE_MS
	_invuln_ms = _overdrive_until          # invincible for the whole burst
	_od_accum = 0.0
	_play_fx(_boost_sound)
	_shake = maxf(_shake, 0.8)

# Feed the meter from the two skill sources.
func _near_miss(pos: Vector3) -> void:
	super._near_miss(pos)
	_add_boost(BOOST_PER_NEARMISS)

func _collect(holder: Node) -> void:
	var t := int(holder.get_meta("type", 0))
	super._collect(holder)
	if t == 0:
		_add_boost(BOOST_PER_CORE)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if started and alive and _overdrive_active():
		_boost = clampf(float(_overdrive_until - Time.get_ticks_msec()) / float(OVERDRIVE_MS), 0.0, 1.0)
		max_speed *= OVERDRIVE_SPEED_MUL
		# doubled score: add a second helping of the distance gained this frame
		_od_accum += speed * delta
		var whole := int(_od_accum)
		if whole > 0:
			bonus_points += whole
			_od_accum -= float(whole)
		if ship_visual:
			ship_visual.visible = true      # solid (invincible), not the i-frame blink
	elif started and alive:
		_add_boost(BOOST_PASSIVE_PER_SEC * delta)   # slow trickle so it always builds
	_update_boost_ui()

func _update_boost_ui() -> void:
	var active := _overdrive_active()
	if _boost_fill:
		_boost_fill.size.x = BAR_W * _boost
		if active:
			_boost_fill.color = Color(1.0, 0.85, 0.3, 0.98)
		elif _boost >= 1.0:
			_boost_fill.color = Color(0.6, 1.0, 1.0, 0.98)
		else:
			_boost_fill.color = Color(0.15, 0.85, 1.0, 0.95)
	if _od_label:
		_od_label.visible = active
	if _od_overlay:
		if active:
			var pulse := 0.10 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.02)
			_od_overlay.color = Color(0.15, 0.85, 1.0, pulse)
		elif _od_overlay.color.a != 0.0:
			_od_overlay.color = Color(0.1, 0.8, 1.0, 0.0)

func _set_playing_hud(is_playing: bool) -> void:
	super._set_playing_hud(is_playing)
	if _boost_bg:
		_boost_bg.visible = is_playing
	if _boost_fill:
		_boost_fill.visible = is_playing
	if not is_playing:
		if _od_label:
			_od_label.visible = false
		if _od_overlay:
			_od_overlay.color = Color(0.1, 0.8, 1.0, 0.0)
