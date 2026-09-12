extends "res://scripts/collisions.gd"

# ---------------------------------------------------------------------------
# Health layer (top of the chain, wired to main.tscn).
#
# A body hit no longer ends the run instantly: the ship has a small health bar,
# so runs last longer and a single clip is recoverable. Order of protection on a
# hit: active i-frames ignore it; a charged shield absorbs it (handled below);
# otherwise one HP is lost with brief invulnerability, a red flash, a thud and a
# shake; the run ends only when the last HP is spent.
# ---------------------------------------------------------------------------

const MAX_HP := 3      # default; upper layers (shop) may raise max_hp up to HP_CAP
const HP_CAP := 5

var max_hp := MAX_HP
var hp := MAX_HP
var _hp_pips: Array = []
var _dmg_overlay: ColorRect
var _dmg_sound: AudioStreamWAV

func _ready() -> void:
	super._ready()
	_dmg_sound = _make_tone(300.0, 120.0, 0.18, 0.5)
	_build_health_ui()
	hp = max_hp
	_update_health_ui()

func _build_health_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	_dmg_overlay = ColorRect.new()
	_dmg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_overlay.color = Color(1.0, 0.1, 0.1, 0.0)
	_dmg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_dmg_overlay)
	for i in range(HP_CAP):
		var pip := ColorRect.new()
		pip.position = Vector2(24 + i * 40, 128)
		pip.size = Vector2(34, 15)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(pip)
		_hp_pips.append(pip)

func _update_health_ui() -> void:
	for i in range(_hp_pips.size()):
		var pip: ColorRect = _hp_pips[i]
		pip.color = Color(0.2, 1.0, 0.5, 0.95) if i < hp else Color(0.25, 0.28, 0.34, 0.55)

func _set_playing_hud(is_playing: bool) -> void:
	super._set_playing_hud(is_playing)
	for i in range(_hp_pips.size()):
		(_hp_pips[i] as ColorRect).visible = is_playing and i < max_hp
	if _dmg_overlay:
		_dmg_overlay.color = Color(1.0, 0.1, 0.1, 0.0)

func _begin_game() -> void:
	hp = max_hp
	_update_health_ui()
	super._begin_game()

func _hit(body: Node) -> void:
	if not alive:
		return
	if Time.get_ticks_msec() < _invuln_ms:
		return
	if shield_charges > 0:
		super._hit(body)          # shield absorbs the hit (progression layer)
		return
	if hp > 1:
		hp -= 1
		_invuln_ms = Time.get_ticks_msec() + 900
		_update_health_ui()
		_damage_feedback()
		return
	hp = 0
	_update_health_ui()
	super._hit(body)              # last HP spent -> death

func _damage_feedback() -> void:
	_shake = maxf(_shake, 0.9)
	_play_fx(_dmg_sound)
	if _dmg_overlay:
		_dmg_overlay.color = Color(1.0, 0.12, 0.12, 0.42)
		var tw := create_tween()
		tw.tween_property(_dmg_overlay, "color:a", 0.0, 0.45)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Blink the ship while invulnerable so the player reads the i-frames.
	if ship_visual:
		var invuln := started and alive and Time.get_ticks_msec() < _invuln_ms
		ship_visual.visible = (not invuln) or (int(Time.get_ticks_msec() / 80) % 2 == 0)
