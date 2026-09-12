extends "res://scripts/content.gd"

# ---------------------------------------------------------------------------
# Extras layer (top of the chain, wired to main.tscn).
#
# A pause button + overlay (Resume / Menu). Soft pause: it just freezes the game
# update and swallows steering input while paused, instead of get_tree().paused,
# which keeps it simple and avoids process-mode juggling with the layered update.
# ---------------------------------------------------------------------------

var _paused := false
var _pause_button: Button
var _pause_panel: Control

func _ready() -> void:
	super._ready()
	_build_pause_ui()

func _build_pause_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	_pause_button = Button.new()
	_pause_button.text = "⏸"
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-116, 128)
	_pause_button.size = Vector2(96, 96)
	_pause_button.add_theme_font_size_override("font_size", 44)
	_pause_button.visible = false
	_pause_button.pressed.connect(_pause)
	layer.add_child(_pause_button)

	var panel := _centered_panel(layer)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	_pause_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label("PAUSE", 56, Color(0.4, 0.92, 1.0)))
	var resume := Button.new()
	resume.text = "▶  REPRENDRE"
	resume.custom_minimum_size = Vector2(460, 110)
	resume.add_theme_font_size_override("font_size", 44)
	resume.pressed.connect(_resume)
	box.add_child(resume)
	var to_menu_btn := Button.new()
	to_menu_btn.text = "MENU"
	to_menu_btn.custom_minimum_size = Vector2(300, 86)
	to_menu_btn.add_theme_font_size_override("font_size", 32)
	to_menu_btn.pressed.connect(_pause_to_menu)
	box.add_child(to_menu_btn)

func _pause() -> void:
	if not started or not alive or _paused:
		return
	_paused = true
	if _pause_panel:
		_pause_panel.visible = true
	if _pause_button:
		_pause_button.visible = false

func _resume() -> void:
	_paused = false
	if _pause_panel:
		_pause_panel.visible = false
	if _pause_button and started and alive:
		_pause_button.visible = true

func _pause_to_menu() -> void:
	_paused = false
	_to_menu()

func _set_playing_hud(is_playing: bool) -> void:
	super._set_playing_hud(is_playing)
	if _pause_button:
		_pause_button.visible = is_playing
	if not is_playing:
		_paused = false
		if _pause_panel:
			_pause_panel.visible = false

func _show_game_over() -> void:
	super._show_game_over()
	if _pause_button:
		_pause_button.visible = false
	_resume()

func _physics_process(delta: float) -> void:
	if _paused:
		return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _paused:
		return
	super._unhandled_input(event)
