extends "res://scripts/progression.gd"

# ---------------------------------------------------------------------------
# Menu + run-flow layer (top of the chain, wired to main.tscn).
#
#   * A main menu gates the run: physics only advance once the player taps
#     JOUER. While the menu is up the tunnel drifts slowly as a live backdrop.
#   * A richer game-over panel shows the run score, the best score and a
#     "NOUVEAU RECORD" banner, and a single tap replays instantly (skipping the
#     menu via a static flag that survives the scene reload the base game uses).
#
# All gameplay input still flows to the lower layers via super; only the menu
# and dead states are intercepted here.
# ---------------------------------------------------------------------------

static var _skip_intro := false

var started := false
var _menu_panel: Control
var _over_panel: Control
var _menu_best: Label
var _over_score: Label
var _over_best: Label
var _over_newbest: Label

func _ready() -> void:
	super._ready()
	_build_menu_ui()
	if _skip_intro:
		_skip_intro = false
		if _menu_panel:
			_menu_panel.visible = false
		# Defer so the whole _ready chain (upper layers' HUD) is built first.
		call_deferred("_begin_game")
	else:
		_show_menu()

func _physics_process(delta: float) -> void:
	if not started:
		_idle_drift(delta)
		return
	super._physics_process(delta)

# Slow ambient scroll so the menu reads as a live scene, not a frozen frame.
func _idle_drift(delta: float) -> void:
	var d := 7.0 * delta
	for child in corridor_root.get_children():
		var section := child as Node3D
		section.position.z += d
		if section.position.z > RECYCLE_Z:
			section.position.z -= SECTION_COUNT * SECTION_LENGTH
	for child in streak_root.get_children():
		var streak := child as Node3D
		streak.position.z += d * 1.25
		if streak.position.z > RECYCLE_Z:
			streak.position.z = randf_range(-120.0, -80.0)
	if ship_visual:
		ship_visual.position.y = sin(float(Time.get_ticks_msec()) * 0.0015) * 0.05

# --- Flow -----------------------------------------------------------------

func _begin_game() -> void:
	started = true
	if _menu_panel:
		_menu_panel.visible = false
	if _over_panel:
		_over_panel.visible = false
	if game_over_label:
		game_over_label.visible = false
	if ship_visual:
		ship_visual.position.y = 0.0
	_set_playing_hud(true)

func _show_menu() -> void:
	started = false
	_set_playing_hud(false)
	if _over_panel:
		_over_panel.visible = false
	if game_over_label:
		game_over_label.visible = false
	if _menu_best:
		_menu_best.text = "MEILLEUR  %06d" % best_score
	if _menu_panel:
		_menu_panel.visible = true

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive:
		_show_game_over()

func _show_game_over() -> void:
	if game_over_label:
		game_over_label.visible = false
	if _over_score:
		_over_score.text = "SCORE  %06d" % _total_score()
	if _over_best:
		_over_best.text = "MEILLEUR  %06d" % best_score
	if _over_newbest:
		_over_newbest.visible = _new_best
	if _over_panel:
		_over_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if not alive:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_play_again()
		return
	super._unhandled_input(event)

func _play_again() -> void:
	_skip_intro = true
	get_tree().reload_current_scene()

func _to_menu() -> void:
	_skip_intro = false
	get_tree().reload_current_scene()

# --- UI construction ------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.86)
	sb.border_color = Color(0.15, 0.8, 1.0, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(40)
	return sb

func _centered_panel(layer: CanvasLayer) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	return panel

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * 1.5))   # UI scaled up for the 1080-wide canvas
	l.modulate = color
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_menu_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return

	# --- Main menu ---
	var menu := _centered_panel(layer)
	_menu_panel = menu
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(box)
	box.add_child(_label("VORTEX RUNNER", 44, Color(0.4, 0.92, 1.0)))
	box.add_child(_label("T U N N E L   I N F I N I", 15, Color(0.6, 0.7, 0.85, 0.8)))
	_menu_best = _label("MEILLEUR  000000", 22, Color(1.0, 0.85, 0.4))
	box.add_child(_menu_best)
	var play := Button.new()
	play.text = "▶   JOUER"
	play.custom_minimum_size = Vector2(460, 116)
	play.add_theme_font_size_override("font_size", 46)
	play.pressed.connect(_begin_game)
	box.add_child(play)
	box.add_child(_label("Glisse pour piloter\nAttrape les orbes dorées  •  ◈ bouclier", 15, Color(0.68, 0.74, 0.86, 0.85)))

	# --- Game over ---
	var over := _centered_panel(layer)
	_over_panel = over
	over.visible = false
	var obox := VBoxContainer.new()
	obox.add_theme_constant_override("separation", 20)
	obox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(obox)
	obox.add_child(_label("SIGNAL PERDU", 42, Color(1.0, 0.32, 0.28)))
	_over_score = _label("SCORE  000000", 28, Color(0.92, 0.95, 1.0))
	obox.add_child(_over_score)
	_over_best = _label("MEILLEUR  000000", 20, Color(1.0, 0.85, 0.4))
	obox.add_child(_over_best)
	_over_newbest = _label("★  NOUVEAU RECORD  ★", 22, Color(1.0, 0.86, 0.35))
	_over_newbest.visible = false
	obox.add_child(_over_newbest)
	obox.add_child(_label("TOUCHE POUR REJOUER", 20, Color(0.55, 0.9, 1.0, 0.9)))
	var menu_button := Button.new()
	menu_button.text = "MENU"
	menu_button.custom_minimum_size = Vector2(300, 86)
	menu_button.add_theme_font_size_override("font_size", 32)
	menu_button.pressed.connect(_to_menu)
	obox.add_child(menu_button)
