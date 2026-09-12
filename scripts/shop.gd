extends "res://scripts/boost.gd"

# ---------------------------------------------------------------------------
# Coins + shop layer (top of the chain, wired to main.tscn).
#
# Meta-progression loop: every run pays out coins (data cores collected + a cut
# of the score), banked persistently. From the menu a shop spends them on
# permanent upgrades - extra HP, a starting shield, an orb magnet, faster boost
# charge - which make longer runs, which earn more coins. All choices persist to
# user://shop.cfg and are applied at the start of each run; nothing below is
# rewritten (HP cap and boost-gain multiplier are the two hooks added earlier).
# ---------------------------------------------------------------------------

const SHOP_CONFIG := "user://shop.cfg"
const CORE_COINS := 2
const SCORE_PER_COIN := 150

var coins := 0
var up_extra_hp := 0
var up_start_shield := false
var up_magnet := false
var up_fast_boost := false

var _run_coins := 0
var _last_payout := 0

var _shop_panel: Control
var _shop_coins_label: Label
var _menu_coins_label: Label
var _over_coins_label: Label
var _buy_buttons: Dictionary = {}

func _ready() -> void:
	_load_shop()
	super._ready()
	_build_shop_ui()
	_refresh_shop()

# --- Persistence ----------------------------------------------------------

func _load_shop() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SHOP_CONFIG) == OK:
		coins = int(cfg.get_value("shop", "coins", 0))
		up_extra_hp = clampi(int(cfg.get_value("shop", "extra_hp", 0)), 0, 2)
		up_start_shield = bool(cfg.get_value("shop", "start_shield", false))
		up_magnet = bool(cfg.get_value("shop", "magnet", false))
		up_fast_boost = bool(cfg.get_value("shop", "fast_boost", false))

func _save_shop() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "extra_hp", up_extra_hp)
	cfg.set_value("shop", "start_shield", up_start_shield)
	cfg.set_value("shop", "magnet", up_magnet)
	cfg.set_value("shop", "fast_boost", up_fast_boost)
	cfg.save(SHOP_CONFIG)

# --- Run flow -------------------------------------------------------------

func _begin_game() -> void:
	max_hp = MAX_HP + up_extra_hp
	_boost_gain_mul = 1.25 if up_fast_boost else 1.0
	_run_coins = 0
	super._begin_game()
	if up_start_shield and shield_charges < 1:
		shield_charges = 1

func _collect(holder: Node) -> void:
	var t := int(holder.get_meta("type", 0))
	super._collect(holder)
	if t == 0:
		_run_coins += CORE_COINS

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive:
		_last_payout = _run_coins + int(_total_score() / SCORE_PER_COIN)
		coins += _last_payout
		_save_shop()
		_update_coin_labels()

func _show_menu() -> void:
	super._show_menu()
	_update_coin_labels()
	_refresh_shop()
	if _shop_panel:
		_shop_panel.visible = false

func _show_game_over() -> void:
	super._show_game_over()
	if _over_coins_label:
		_over_coins_label.text = "PIÈCES  +%d   (total %d)" % [_last_payout, coins]

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if up_magnet and started and alive and pickup_root:
		var sp := ship.global_position
		for child in pickup_root.get_children():
			var holder := child as Node3D
			if not bool(holder.get_meta("active", false)):
				continue
			var pz := holder.position.z
			if pz > sp.z - 20.0 and pz < sp.z + 2.0:
				holder.set_meta("bx", move_toward(float(holder.get_meta("bx", 0.0)), sp.x, 7.0 * delta))
				holder.set_meta("by", move_toward(float(holder.get_meta("by", 0.0)), sp.y, 7.0 * delta))

# --- Shop economy ---------------------------------------------------------

func _item_owned(kind: String) -> bool:
	match kind:
		"hp": return up_extra_hp >= 2
		"shield": return up_start_shield
		"magnet": return up_magnet
		"fastboost": return up_fast_boost
	return false

func _item_price(kind: String) -> int:
	match kind:
		"hp": return 150 if up_extra_hp == 0 else 400
		"shield": return 250
		"magnet": return 300
		"fastboost": return 200
	return 0

func _buy(kind: String) -> void:
	if _item_owned(kind):
		return
	var price := _item_price(kind)
	if coins < price:
		return
	coins -= price
	match kind:
		"hp": up_extra_hp += 1
		"shield": up_start_shield = true
		"magnet": up_magnet = true
		"fastboost": up_fast_boost = true
	_save_shop()
	_refresh_shop()

# --- UI -------------------------------------------------------------------

func _build_shop_ui() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	if _menu_panel:
		var mv := _menu_panel.get_child(0) as VBoxContainer
		if mv:
			_menu_coins_label = _label("PIÈCES  0", 20, Color(1.0, 0.85, 0.4))
			mv.add_child(_menu_coins_label)
			mv.move_child(_menu_coins_label, 3)
			var shop_btn := Button.new()
			shop_btn.text = "🛒  BOUTIQUE"
			shop_btn.custom_minimum_size = Vector2(300, 60)
			shop_btn.add_theme_font_size_override("font_size", 24)
			shop_btn.pressed.connect(_open_shop)
			mv.add_child(shop_btn)
	if _over_panel:
		var ov := _over_panel.get_child(0) as VBoxContainer
		if ov:
			_over_coins_label = _label("PIÈCES  +0", 20, Color(1.0, 0.85, 0.4))
			ov.add_child(_over_coins_label)
			ov.move_child(_over_coins_label, 3)
	_build_shop_panel(layer)

func _build_shop_panel(layer: CanvasLayer) -> void:
	var panel := _centered_panel(layer)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # block taps to the menu behind
	panel.visible = false
	_shop_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label("BOUTIQUE", 34, Color(0.4, 0.92, 1.0)))
	_shop_coins_label = _label("PIÈCES  0", 22, Color(1.0, 0.85, 0.4))
	box.add_child(_shop_coins_label)
	box.add_child(_shop_row("hp", "+1 POINT DE VIE", "Un cœur de plus (jusqu'à +2)"))
	box.add_child(_shop_row("shield", "BOUCLIER DE DÉPART", "Commence chaque partie protégé"))
	box.add_child(_shop_row("magnet", "AIMANT À ORBES", "Les orbes sont attirées vers toi"))
	box.add_child(_shop_row("fastboost", "SURCHAUFFE RAPIDE", "La jauge se remplit +25 %"))
	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(200, 54)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_shop)
	box.add_child(close)

func _shop_row(kind: String, name: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _label(name, 19, Color(0.92, 0.95, 1.0))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(n)
	var d := _label(desc, 13, Color(0.68, 0.74, 0.86))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(d)
	row.add_child(texts)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(128, 54)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_buy.bind(kind))
	row.add_child(btn)
	_buy_buttons[kind] = btn
	return row

func _open_shop() -> void:
	_refresh_shop()
	if _shop_panel:
		_shop_panel.visible = true

func _close_shop() -> void:
	if _shop_panel:
		_shop_panel.visible = false

func _refresh_shop() -> void:
	_update_coin_labels()
	for kind in _buy_buttons.keys():
		var btn: Button = _buy_buttons[kind]
		if _item_owned(kind):
			btn.text = "MAX" if kind == "hp" else "OK"
			btn.disabled = true
		else:
			btn.text = "%d ●" % _item_price(kind)
			btn.disabled = coins < _item_price(kind)

func _update_coin_labels() -> void:
	if _menu_coins_label:
		_menu_coins_label.text = "PIÈCES  %d" % coins
	if _shop_coins_label:
		_shop_coins_label.text = "PIÈCES  %d" % coins
