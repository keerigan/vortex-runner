extends "res://scripts/missions.gd"

# ---------------------------------------------------------------------------
# Daily challenge + streak layer (top of the chain, wired to main.tscn).
#
#   * Streak: the first run of each new calendar day pays a coin bonus that grows
#     with the run of consecutive days played; miss a day and it resets.
#   * Daily challenge: one date-seeded goal (same for everyone that day), tracked
#     across the day's runs; clearing it once pays a bigger reward.
#
# Reuses the missions layer's lifetime counters and the shop's coin wallet;
# state persists to user://daily.cfg. A reason to come back every day.
# ---------------------------------------------------------------------------

const DAILY_CONFIG := "user://daily.cfg"
const DAILY_REWARD := 200
const CH_TYPES := ["score", "cores", "nearmiss", "overdrive"]

var last_day := -1
var streak := 0
var challenge_done := false
var _ch_base := 0
var _daily_bonus := 0

var _daily_streak_label: Label
var _daily_ch_label: Label
var _daily_toast: Label

func _ready() -> void:
	_load_daily()
	super._ready()
	_build_daily_ui()
	_refresh_daily_ui()

# --- Date / challenge definition (deterministic per day) -------------------

func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _ch_type() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = _today()
	return CH_TYPES[rng.randi() % CH_TYPES.size()]

func _ch_target() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = _today() + 9973
	match _ch_type():
		"score": return rng.randi_range(4000, 9000)
		"cores": return rng.randi_range(12, 25)
		"nearmiss": return rng.randi_range(20, 40)
		"overdrive": return rng.randi_range(3, 6)
	return 10

func _daily_desc() -> String:
	var target := _ch_target()
	match _ch_type():
		"score": return "%d pts" % target
		"cores": return "%d orbes" % target
		"nearmiss": return "%d frôlements" % target
		"overdrive": return "%d surchauffes" % target
	return ""

# --- Persistence ----------------------------------------------------------

func _load_daily() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_CONFIG) == OK:
		last_day = int(cfg.get_value("daily", "last_day", -1))
		streak = int(cfg.get_value("daily", "streak", 0))
		challenge_done = bool(cfg.get_value("daily", "challenge_done", false))
		_ch_base = int(cfg.get_value("daily", "ch_base", 0))

func _save_daily() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("daily", "last_day", last_day)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "challenge_done", challenge_done)
	cfg.set_value("daily", "ch_base", _ch_base)
	cfg.save(DAILY_CONFIG)

# --- Run flow -------------------------------------------------------------

func _begin_game() -> void:
	_check_new_day()
	super._begin_game()

func _check_new_day() -> void:
	var today := _today()
	if today == last_day:
		return
	if today == last_day + 1:
		streak += 1
	else:
		streak = 1
	_daily_bonus = 40 + 10 * mini(streak, 10)
	coins += _daily_bonus
	last_day = today
	challenge_done = false
	_ch_base = _lt(_ch_type())          # snapshot so today's progress starts at 0
	_save_daily()
	_save_shop()
	_update_coin_labels()
	_refresh_daily_ui()
	_show_daily_toast("SÉRIE %d J   +%d ●" % [streak, _daily_bonus])

func _check_daily_challenge() -> void:
	if challenge_done:
		return
	if _lt(_ch_type()) - _ch_base >= _ch_target():
		challenge_done = true
		coins += DAILY_REWARD
		_save_daily()
		_save_shop()
		_update_coin_labels()
		_refresh_daily_ui()
		_show_daily_toast("DÉFI DU JOUR ✓   +%d ●" % DAILY_REWARD)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if started and alive:
		_check_daily_challenge()

func _show_menu() -> void:
	super._show_menu()
	_check_daily_challenge()
	_refresh_daily_ui()

# --- UI -------------------------------------------------------------------

func _build_daily_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	if _menu_panel:
		var mv := _menu_panel.get_child(0) as VBoxContainer
		if mv:
			_daily_streak_label = _label("🔥 Série : 0 j", 20, Color(1.0, 0.6, 0.3))
			mv.add_child(_daily_streak_label)
			mv.move_child(_daily_streak_label, 4)
			_daily_ch_label = _label("Défi du jour", 16, Color(0.7, 0.9, 1.0))
			mv.add_child(_daily_ch_label)
			mv.move_child(_daily_ch_label, 5)
	_daily_toast = Label.new()
	_daily_toast.add_theme_font_size_override("font_size", 34)
	_daily_toast.modulate = Color(1.0, 0.7, 0.3)
	_daily_toast.position = Vector2(70, 260)
	_daily_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_toast.visible = false
	layer.add_child(_daily_toast)

func _refresh_daily_ui() -> void:
	if _daily_streak_label:
		_daily_streak_label.text = "🔥 Série : %d j" % streak
	if _daily_ch_label:
		var prog := clampi(_lt(_ch_type()) - _ch_base, 0, _ch_target())
		var status := "✓" if challenge_done else "%d/%d" % [prog, _ch_target()]
		_daily_ch_label.text = "Défi du jour : %s  %s" % [_daily_desc(), status]

func _show_daily_toast(text: String) -> void:
	if _daily_toast == null:
		return
	_daily_toast.text = text
	_daily_toast.modulate = Color(1.0, 0.7, 0.3, 1.0)
	_daily_toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_daily_toast, "modulate:a", 0.0, 0.9)
	tw.tween_callback(func(): _daily_toast.visible = false)
