extends "res://scripts/polish.gd"

# ---------------------------------------------------------------------------
# Missions layer (top of the chain, wired to main.tscn).
#
# Three cumulative objectives (graze N hazards, collect N orbs, bank N points,
# trigger N overdrives) that persist across runs. Completing one pays coins and
# rerolls that slot with a fresh goal, giving a steady "one more run" pull. Built
# on the existing near-miss, pickup, overdrive, score and coin systems; progress
# and the active set live in user://missions.cfg.
# ---------------------------------------------------------------------------

const MISSIONS_CONFIG := "user://missions.cfg"
const MISSION_REWARD := 120
const MISSION_COUNT := 3
const MISSION_TYPES := ["nearmiss", "cores", "score", "overdrive"]

var lt_nearmiss := 0
var lt_cores := 0
var lt_score := 0
var lt_overdrive := 0
var _missions: Array = []

var _mission_panel: Control
var _mission_rows: Array = []
var _mission_toast: Label

func _ready() -> void:
	_load_missions()
	super._ready()
	_build_missions_ui()
	_refresh_missions_ui()

# --- Data -----------------------------------------------------------------

func _lt(type: String) -> int:
	match type:
		"nearmiss": return lt_nearmiss
		"cores": return lt_cores
		"score": return lt_score
		"overdrive": return lt_overdrive
	return 0

func _rand_target(type: String) -> int:
	match type:
		"nearmiss": return randi_range(15, 40)
		"cores": return randi_range(10, 25)
		"score": return randi_range(3000, 8000)
		"overdrive": return randi_range(2, 5)
	return 10

func _reroll(i: int) -> void:
	var type: String = MISSION_TYPES[randi() % MISSION_TYPES.size()]
	_missions[i] = {"type": type, "target": _rand_target(type), "base": _lt(type)}

func _load_missions() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(MISSIONS_CONFIG) == OK:
		lt_nearmiss = int(cfg.get_value("lt", "nearmiss", 0))
		lt_cores = int(cfg.get_value("lt", "cores", 0))
		lt_score = int(cfg.get_value("lt", "score", 0))
		lt_overdrive = int(cfg.get_value("lt", "overdrive", 0))
		for i in range(MISSION_COUNT):
			var type: String = str(cfg.get_value("m%d" % i, "type", ""))
			if type in MISSION_TYPES:
				_missions.append({
					"type": type,
					"target": int(cfg.get_value("m%d" % i, "target", 10)),
					"base": int(cfg.get_value("m%d" % i, "base", 0)),
				})
	while _missions.size() < MISSION_COUNT:
		_missions.append({})
		_reroll(_missions.size() - 1)

func _save_missions() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("lt", "nearmiss", lt_nearmiss)
	cfg.set_value("lt", "cores", lt_cores)
	cfg.set_value("lt", "score", lt_score)
	cfg.set_value("lt", "overdrive", lt_overdrive)
	for i in range(_missions.size()):
		var m: Dictionary = _missions[i]
		cfg.set_value("m%d" % i, "type", m["type"])
		cfg.set_value("m%d" % i, "target", m["target"])
		cfg.set_value("m%d" % i, "base", m["base"])
	cfg.save(MISSIONS_CONFIG)

func _check_missions() -> void:
	var rewarded := 0
	for i in range(_missions.size()):
		var m: Dictionary = _missions[i]
		if _lt(m["type"]) - int(m["base"]) >= int(m["target"]):
			coins += MISSION_REWARD
			rewarded += MISSION_REWARD
			_reroll(i)
	if rewarded > 0:
		_save_missions()
		_save_shop()
		_update_coin_labels()
		_refresh_missions_ui()
		_show_mission_toast(rewarded)

# --- Progress hooks -------------------------------------------------------

func _near_miss(pos: Vector3) -> void:
	super._near_miss(pos)
	lt_nearmiss += 1
	_check_missions()

func _collect(holder: Node) -> void:
	var t := int(holder.get_meta("type", 0))
	super._collect(holder)
	if t == 0:
		lt_cores += 1
		_check_missions()

func _start_overdrive() -> void:
	super._start_overdrive()
	lt_overdrive += 1
	_check_missions()

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive:
		lt_score += _total_score()
		_save_missions()
		_check_missions()

func _show_menu() -> void:
	super._show_menu()
	_refresh_missions_ui()
	if _mission_panel:
		_mission_panel.visible = false

# --- UI -------------------------------------------------------------------

func _build_missions_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	if _menu_panel:
		var mv := _menu_panel.get_child(0) as VBoxContainer
		if mv:
			var btn := Button.new()
			btn.text = "🎯  MISSIONS"
			btn.custom_minimum_size = Vector2(460, 96)
			btn.add_theme_font_size_override("font_size", 38)
			btn.pressed.connect(_open_missions)
			mv.add_child(btn)

	var panel := _centered_panel(layer)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	_mission_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label("MISSIONS", 34, Color(0.4, 0.92, 1.0)))
	for i in range(MISSION_COUNT):
		var row := _label("", 18, Color(0.9, 0.94, 1.0))
		box.add_child(row)
		_mission_rows.append(row)
	box.add_child(_label("Chaque mission accomplie rapporte %d ●" % MISSION_REWARD, 14, Color(0.68, 0.74, 0.86)))
	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(300, 84)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(_close_missions)
	box.add_child(close)

	_mission_toast = Label.new()
	_mission_toast.add_theme_font_size_override("font_size", 34)
	_mission_toast.modulate = Color(1.0, 0.9, 0.4)
	_mission_toast.position = Vector2(90, 205)
	_mission_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_toast.visible = false
	layer.add_child(_mission_toast)

func _mission_desc(m: Dictionary) -> String:
	var target := int(m["target"])
	var prog := clampi(_lt(m["type"]) - int(m["base"]), 0, target)
	var t := ""
	match m["type"]:
		"nearmiss": t = "Frôle %d obstacles" % target
		"cores": t = "Ramasse %d orbes" % target
		"score": t = "Cumule %d points" % target
		"overdrive": t = "Déclenche %d surchauffes" % target
	return "%s   —   %d/%d" % [t, prog, target]

func _refresh_missions_ui() -> void:
	for i in range(_mission_rows.size()):
		if i < _missions.size():
			(_mission_rows[i] as Label).text = _mission_desc(_missions[i])

func _open_missions() -> void:
	_refresh_missions_ui()
	if _mission_panel:
		_mission_panel.visible = true

func _close_missions() -> void:
	if _mission_panel:
		_mission_panel.visible = false

func _show_mission_toast(amount: int) -> void:
	if _mission_toast == null:
		return
	_mission_toast.text = "MISSION ✓  +%d ●" % amount
	_mission_toast.modulate = Color(1.0, 0.9, 0.4, 1.0)
	_mission_toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_mission_toast, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _mission_toast.visible = false)
