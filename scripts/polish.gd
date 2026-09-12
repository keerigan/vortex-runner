extends "res://scripts/shop.gd"

# ---------------------------------------------------------------------------
# HUD & boost polish layer (top of the chain, wired to main.tscn).
#
#   * A dark rounded backdrop behind the top-left HUD so score / HP / boost read
#     clearly over the bright tunnel (it sits at the back of the canvas and only
#     shows while playing).
#   * A glowing aura around the ship during Overdrive so the boost is obvious on
#     the craft itself, not just via the screen wash.
# ---------------------------------------------------------------------------

var _hud_backdrop: Panel
var _od_aura: MeshInstance3D

func _ready() -> void:
	super._ready()
	_build_hud_backdrop()
	_build_overdrive_aura()

func _build_hud_backdrop() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	_hud_backdrop = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.52)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.2, 0.7, 1.0, 0.22)
	sb.set_border_width_all(1)
	_hud_backdrop.add_theme_stylebox_override("panel", sb)
	_hud_backdrop.position = Vector2(12, 14)
	_hud_backdrop.size = Vector2(262, 156)
	_hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_backdrop.visible = false
	layer.add_child(_hud_backdrop)
	layer.move_child(_hud_backdrop, 0)   # behind the HUD labels

func _set_playing_hud(is_playing: bool) -> void:
	super._set_playing_hud(is_playing)
	if _hud_backdrop:
		_hud_backdrop.visible = is_playing

func _build_overdrive_aura() -> void:
	if ship == null:
		return
	_od_aura = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.15
	sphere.height = 2.3
	sphere.radial_segments = 16
	sphere.rings = 8
	_od_aura.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.9, 1.0, 0.20)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.9, 1.0)
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_od_aura.material_override = m
	_od_aura.visible = false
	ship.add_child(_od_aura)

func _process(delta: float) -> void:
	super._process(delta)
	if _od_aura:
		var on := _overdrive_active()
		_od_aura.visible = on
		if on:
			var p := 1.0 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.02)
			_od_aura.scale = Vector3(p, p, p)
