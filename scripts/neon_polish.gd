extends "res://scripts/music_system.gd"

# ---------------------------------------------------------------------------
# Neon polish layer (top of the chain). Purely additive - it overrides only
# _make_world / _update_world / _update_camera / _reset_obstacle and always
# calls super first, so the ship, audio, biomes and hazards built by the lower
# layers are left completely untouched.
#
#  * cranks the environment glow + filmic tonemap so the neon actually blooms;
#  * bends the corridor into gentle flowing S-curves. The offset is a spatial
#    sine that is zero at the ship, so what you see far ahead turns while the
#    near field (where you dodge) stays perfectly straight - collisions and
#    hitboxes are therefore unchanged;
#  * banks the camera into the turn;
#  * parks a soft glowing ring cluster at the vanishing point.
# ---------------------------------------------------------------------------

const CURVE_AMP_X := 3.2
const CURVE_FREQ_X := 0.018
const CURVE_AMP_Y := 1.0
const CURVE_FREQ_Y := 0.024

var _glow_root: Node3D
var _glow_rings: Array[MeshInstance3D] = []

func _make_world() -> void:
	super._make_world()
	_enhance_glow()
	_add_vanishing_glow()

func _enhance_glow() -> void:
	# Lower layers already animate ambient/fog per biome but never touch glow or
	# the tonemapper, so tuning them here is safe and persistent. Property access
	# mirrors the (already CI-passing) idiom used by the biome layers.
	var levels: Array[float] = [0.4, 0.85, 1.0, 1.0, 0.8, 0.55, 0.35]
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			child.environment.tonemap_exposure = 1.10
			child.environment.glow_enabled = true
			child.environment.glow_normalized = true
			child.environment.glow_intensity = 1.15
			child.environment.glow_strength = 1.05
			child.environment.glow_bloom = 0.22
			child.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
			child.environment.glow_hdr_threshold = 0.80
			for i in range(levels.size()):
				child.environment.set_glow_level(i, levels[i])

func _add_vanishing_glow() -> void:
	_glow_root = Node3D.new()
	_glow_root.name = "VanishingGlow"
	_glow_root.position = Vector3(0.0, -0.4, -46.0)
	add_child(_glow_root)
	var tints: Array[Color] = [Color(0.20, 0.90, 1.0), Color(0.10, 0.75, 1.0), Color(0.50, 0.30, 1.0)]
	for i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 2.0 + float(i) * 0.7
		torus.outer_radius = 2.28 + float(i) * 0.7
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position.z = -float(i) * 5.0
		var c: Color = tints[i]
		ring.material_override = _mat(c, c, 6.0 - float(i) * 1.4, 0.0, 0.1)
		_glow_root.add_child(ring)
		_glow_rings.append(ring)

# Spatial sine centreline offset - bounded, and zero at the ship (depth 0).
func _curve_at(depth: float) -> Vector2:
	var wx := score + depth
	var ox := CURVE_AMP_X * (sin(wx * CURVE_FREQ_X) - sin(score * CURVE_FREQ_X))
	var oy := CURVE_AMP_Y * (sin(wx * CURVE_FREQ_Y + 1.7) - sin(score * CURVE_FREQ_Y + 1.7))
	return Vector2(ox, oy)

func _reset_obstacle(area: Area3D, z: float) -> void:
	super._reset_obstacle(area, z)
	# Record the straight-lane base so the curve can be reapplied every frame
	# without drifting.
	area.set_meta("base_x", area.position.x)
	area.set_meta("base_y", area.position.y)

func _update_world(delta: float) -> void:
	super._update_world(delta)
	# Corridor sections ride the centreline (their base is 0,0).
	for child in corridor_root.get_children():
		var section := child as Node3D
		var soff := _curve_at(-section.position.z)
		section.position.x = soff.x
		section.position.y = soff.y
	# Streaks keep their fixed random lane; capture it once.
	for child in streak_root.get_children():
		var streak := child as Node3D
		if not streak.has_meta("bx"):
			streak.set_meta("bx", streak.position.x)
			streak.set_meta("by", streak.position.y)
		var koff := _curve_at(-streak.position.z)
		streak.position.x = float(streak.get_meta("bx")) + koff.x
		streak.position.y = float(streak.get_meta("by")) + koff.y
	# Obstacles ride their recorded lane so they stay inside the curved tunnel.
	for child in obstacle_root.get_children():
		var area := child as Area3D
		var bx := float(area.get_meta("base_x", area.position.x))
		var by := float(area.get_meta("base_y", area.position.y))
		var aoff := _curve_at(-area.position.z)
		area.position.x = bx + aoff.x
		area.position.y = by + aoff.y
	# Keep the vanishing glow on the curved centreline.
	if _glow_root:
		var goff := _curve_at(-_glow_root.position.z)
		_glow_root.position.x = goff.x
		_glow_root.position.y = -0.4 + goff.y

func _update_camera(delta: float) -> void:
	super._update_camera(delta)
	# Bank into the turn based on the centreline slope at the ship.
	var slope := CURVE_AMP_X * CURVE_FREQ_X * cos(score * CURVE_FREQ_X)
	camera.rotation_degrees.z = lerpf(camera.rotation_degrees.z, -slope * 13.0, clampf(delta * 2.0, 0.0, 1.0))

# --- Floor neon: a thin luminous centre line + side rails added on top of every
# section so the floor reads as neon tech instead of a washed slab with a black
# pit down the middle. As children of the section they inherit the curve.
func _add_floor_glow(section: Node3D) -> void:
	var line := _mat(Color(0.30, 0.90, 1.0), Color(0.10, 0.80, 1.0), 2.4, 0.10, 0.12)
	_box(section, Vector3(0.0, -3.19, 0.0), Vector3(0.20, 0.05, SECTION_LENGTH * 0.98), line)
	for x: float in [-2.0, 2.0]:
		_box(section, Vector3(x, -3.18, 0.0), Vector3(0.055, 0.04, SECTION_LENGTH * 0.94), line)

func _build_corridor_section(section: Node3D, index: int) -> void:
	super._build_corridor_section(section, index)
	_add_floor_glow(section)

func _rebuild_section_for_biome(section: Node3D, biome: int, serial: int) -> void:
	super._rebuild_section_for_biome(section, biome, serial)
	_add_floor_glow(section)

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 4.0 // NEON CURVE"
