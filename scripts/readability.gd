extends "res://scripts/ships.gd"

# ---------------------------------------------------------------------------
# Readability layer (top of the chain, wired to main.tscn).
#
# Hazards were dark and easy to miss against the tunnel. Each obstacle gets a
# translucent red "danger" glow aura so it reads clearly from far away. The aura
# mesh and material are built once and shared; the halo node is parented to the
# Area3D (not the visual, which the biome layer rebuilds every recycle) so it is
# added a single time per obstacle and survives recycling - no per-frame or
# per-recycle allocation. It is a plain MeshInstance3D, so it never interferes
# with the CollisionShape3D scan in _check_hits.
# ---------------------------------------------------------------------------

var _aura_mat: StandardMaterial3D
var _aura_mesh: SphereMesh

func _ready() -> void:
	_aura_mat = _make_aura_material()
	_aura_mesh = _make_aura_mesh()
	super._ready()

func _make_aura_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.32, 0.12, 0.30)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.30, 0.10)
	m.emission_energy_multiplier = 3.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _make_aura_mesh() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.8
	s.radial_segments = 12
	s.rings = 6
	return s

func _reset_obstacle(area: Area3D, z: float) -> void:
	super._reset_obstacle(area, z)
	if area.get_node_or_null("Aura") == null:
		_add_aura(area)

func _add_aura(area: Area3D) -> void:
	if _aura_mat == null or _aura_mesh == null:
		return
	var halo := MeshInstance3D.new()
	halo.name = "Aura"
	halo.mesh = _aura_mesh
	halo.material_override = _aura_mat
	halo.scale = Vector3(1.15, 0.85, 0.9)
	area.add_child(halo)
