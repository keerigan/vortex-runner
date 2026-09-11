extends "res://scripts/optimize.gd"

# ---------------------------------------------------------------------------
# Ship selection layer (top of the chain, wired to main.tscn).
#
# Four craft with genuine trade-offs, unlocked by best score and chosen from the
# menu. Each ship tweaks only cleanly-hookable values, so nothing below is
# rewritten:
#   * hitbox     -> scales the ship collision shapes AND hit_pad_scale (the pad
#                   used by _check_hits, the reliable hit test);
#   * speed      -> multiplies the top speed the progression layer sets;
#   * score      -> a passive bonus-point trickle;
#   * shield     -> shield charges granted at the start of the run;
#   * accent     -> recolours the ship's glowing trims for a signature look.
#
# The choice is persisted to user://ship.cfg (kept separate from the score file
# so neither overwrites the other).
# ---------------------------------------------------------------------------

const SHIP_CONFIG := "user://ship.cfg"

# emission energy of the ship's bright trims after neon's _tame_ship clamps them
# to 1.8; anything at/above this is a glowing accent we recolour per craft.
const ACCENT_ENERGY := 1.75

var SHIPS := [
	{"name": "ÉCLAIREUR", "accent": Color(0.14, 0.92, 1.0), "hitbox": 1.0, "speed": 1.0, "score": 1.0, "shield": 0, "unlock": 0, "perk": "Polyvalent"},
	{"name": "BLINDÉ", "accent": Color(1.0, 0.55, 0.12), "hitbox": 1.1, "speed": 0.95, "score": 1.0, "shield": 1, "unlock": 2000, "perk": "Démarre avec un bouclier"},
	{"name": "INTERCEPTEUR", "accent": Color(1.0, 0.26, 0.22), "hitbox": 1.0, "speed": 1.12, "score": 1.18, "shield": 0, "unlock": 6000, "perk": "+ vitesse, + score (risqué)"},
	{"name": "FURTIF", "accent": Color(0.72, 0.35, 1.0), "hitbox": 0.72, "speed": 1.03, "score": 1.05, "shield": 0, "unlock": 12000, "perk": "Hitbox très réduite"},
]

var _selected_ship := 0
var _ship_score_accum := 0.0
var _base_hit_sizes: Array = []
var _ship_name_label: Label
var _ship_perk_label: Label
var _ship_lock_label: Label
var _play_button: Button

func _ready() -> void:
	_load_ship_selection()          # before super so the ship builds in its colour
	super._ready()
	_build_ship_selector()
	_validate_selection()
	_refresh_ship_ui()

# Capture the ship's collision sizes as soon as they are built, so a fast retry
# (which begins the run from inside _ready) still has the base sizes to scale.
func _add_ship_collisions() -> void:
	super._add_ship_collisions()
	_capture_hit_sizes()

func _ship() -> Dictionary:
	return SHIPS[_selected_ship]

func _unlocked(index: int) -> bool:
	return best_score >= int(SHIPS[index]["unlock"])

# --- Persistence ----------------------------------------------------------

func _load_ship_selection() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SHIP_CONFIG) == OK:
		_selected_ship = clampi(int(cfg.get_value("ship", "selected", 0)), 0, SHIPS.size() - 1)

func _save_ship_selection() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ship", "selected", _selected_ship)
	cfg.save(SHIP_CONFIG)

# --- Visuals --------------------------------------------------------------

func _build_ship() -> void:
	super._build_ship()
	_apply_ship_visual()

func _apply_ship_visual() -> void:
	if ship_visual:
		_recolor_accents(ship_visual, _ship()["accent"])

func _recolor_accents(node: Node, accent: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = (child as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.emission_enabled and sm.emission_energy_multiplier >= ACCENT_ENERGY:
					sm.albedo_color = accent
					sm.emission = accent
		_recolor_accents(child, accent)

# --- Hitbox ---------------------------------------------------------------

func _capture_hit_sizes() -> void:
	_base_hit_sizes.clear()
	if ship == null:
		return
	for child in ship.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var cs := child as CollisionShape3D
			_base_hit_sizes.append({"cs": cs, "size": (cs.shape as BoxShape3D).size})

func _apply_ship_hitbox() -> void:
	var h := float(_ship()["hitbox"])
	hit_pad_scale = h
	for entry in _base_hit_sizes:
		var cs: CollisionShape3D = entry["cs"]
		if is_instance_valid(cs) and cs.shape is BoxShape3D:
			(cs.shape as BoxShape3D).size = entry["size"] * h

# --- Run flow -------------------------------------------------------------

func _begin_game() -> void:
	if not _unlocked(_selected_ship):
		_selected_ship = 0
	_apply_ship_hitbox()
	shield_charges = int(_ship()["shield"])
	_ship_score_accum = 0.0
	super._begin_game()

func _show_menu() -> void:
	super._show_menu()
	_refresh_ship_ui()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not started or not alive:
		return
	var s := _ship()
	max_speed *= float(s["speed"])
	var extra := float(s["score"]) - 1.0
	if extra > 0.0:
		_ship_score_accum += speed * delta * extra
		var whole := int(_ship_score_accum)
		if whole > 0:
			bonus_points += whole
			_ship_score_accum -= float(whole)

# --- Menu selector UI -----------------------------------------------------

func _build_ship_selector() -> void:
	if _menu_panel == null:
		return
	var vbox := _menu_panel.get_child(0) as VBoxContainer
	if vbox == null:
		return
	for c in vbox.get_children():
		if c is Button:
			_play_button = c as Button
			break

	var sel := VBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(64, 56)
	prev_btn.add_theme_font_size_override("font_size", 26)
	prev_btn.pressed.connect(_prev_ship)
	row.add_child(prev_btn)
	_ship_name_label = Label.new()
	_ship_name_label.add_theme_font_size_override("font_size", 24)
	_ship_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_name_label.custom_minimum_size = Vector2(230, 0)
	_ship_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_ship_name_label)
	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(64, 56)
	next_btn.add_theme_font_size_override("font_size", 26)
	next_btn.pressed.connect(_next_ship)
	row.add_child(next_btn)
	sel.add_child(row)

	_ship_perk_label = Label.new()
	_ship_perk_label.add_theme_font_size_override("font_size", 15)
	_ship_perk_label.modulate = Color(0.72, 0.8, 0.92)
	_ship_perk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_perk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel.add_child(_ship_perk_label)

	_ship_lock_label = Label.new()
	_ship_lock_label.add_theme_font_size_override("font_size", 14)
	_ship_lock_label.modulate = Color(1.0, 0.72, 0.32)
	_ship_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel.add_child(_ship_lock_label)

	vbox.add_child(sel)
	vbox.move_child(sel, 3)

func _prev_ship() -> void:
	_selected_ship = (_selected_ship - 1 + SHIPS.size()) % SHIPS.size()
	_on_ship_changed()

func _next_ship() -> void:
	_selected_ship = (_selected_ship + 1) % SHIPS.size()
	_on_ship_changed()

func _on_ship_changed() -> void:
	_apply_ship_visual()
	_refresh_ship_ui()
	if _unlocked(_selected_ship):
		_save_ship_selection()

func _validate_selection() -> void:
	if not _unlocked(_selected_ship):
		_selected_ship = 0
		_apply_ship_visual()
		_save_ship_selection()

func _refresh_ship_ui() -> void:
	var locked := not _unlocked(_selected_ship)
	if _ship_name_label:
		_ship_name_label.text = str(_ship()["name"])
		_ship_name_label.modulate = Color(0.52, 0.57, 0.66) if locked else _ship()["accent"]
	if _ship_perk_label:
		_ship_perk_label.text = str(_ship()["perk"])
	if _ship_lock_label:
		_ship_lock_label.visible = locked
		if locked:
			_ship_lock_label.text = "🔒 Débloqué à %d  (record %d)" % [int(_ship()["unlock"]), best_score]
	if _play_button:
		_play_button.disabled = locked
		_play_button.text = "🔒 VERROUILLÉ" if locked else "▶   JOUER"
