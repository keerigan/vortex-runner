extends "res://scripts/daily.gd"

# ---------------------------------------------------------------------------
# Particle FX layer (top of the chain, wired to main.tscn).
#
#   * Two engine trails behind the ship's thrusters (the long-open "réacteurs
#     et particules" roadmap item) that lengthen during Overdrive.
#   * A one-shot spark burst when the ship is destroyed.
#
# CPUParticles3D is used (not GPU) so it renders reliably in the gl_compatibility
# renderer on mobile. Additive, unshaded, billboarded quads keep it cheap.
# ---------------------------------------------------------------------------

var _trails: Array = []
var _burst: CPUParticles3D

func _ready() -> void:
	super._ready()
	_build_trails()
	_build_burst()

func _particle_material(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _quad(size: float, col: Color, energy: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _particle_material(col, energy)
	return q

func _build_trails() -> void:
	if ship_visual == null:
		return
	for x: float in [-0.36, 0.36]:
		var p := CPUParticles3D.new()
		p.amount = 22
		p.lifetime = 0.45
		p.position = Vector3(x, -0.06, 1.5)
		p.direction = Vector3(0.0, 0.0, 1.0)   # stream out behind the ship
		p.spread = 8.0
		p.initial_velocity_min = 7.0
		p.initial_velocity_max = 10.0
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 0.10
		p.scale_amount_max = 0.20
		p.color = Color(0.4, 0.92, 1.0)
		p.mesh = _quad(0.5, Color(0.4, 0.92, 1.0), 4.0)
		ship_visual.add_child(p)
		_trails.append(p)

func _build_burst() -> void:
	if ship == null:
		return
	_burst = CPUParticles3D.new()
	_burst.amount = 48
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 0.9
	_burst.lifetime = 0.7
	_burst.direction = Vector3(0.0, 0.0, 0.0)
	_burst.spread = 180.0
	_burst.initial_velocity_min = 5.0
	_burst.initial_velocity_max = 12.0
	_burst.gravity = Vector3.ZERO
	_burst.scale_amount_min = 0.12
	_burst.scale_amount_max = 0.28
	_burst.color = Color(1.0, 0.5, 0.15)
	_burst.mesh = _quad(0.6, Color(1.0, 0.5, 0.15), 5.0)
	ship.add_child(_burst)

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive and _burst:
		_burst.restart()
		_burst.emitting = true

func _process(delta: float) -> void:
	super._process(delta)
	var od := _overdrive_active()
	for p in _trails:
		var cp := p as CPUParticles3D
		cp.initial_velocity_max = 16.0 if od else 10.0
		cp.scale_amount_max = 0.32 if od else 0.20
