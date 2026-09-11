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

# Sections recycle only once they are fully behind the camera (~7.85), so a
# whole block never visibly vanishes in front of the player. The base build
# recycled at z=1.65 (about 6 units IN FRONT of the camera), which is what made
# the tunnel "advance by blocks".
const RECYCLE_Z := 11.6

var _glow_root: Node3D
var _glow_rings: Array[MeshInstance3D] = []

func _make_world() -> void:
	super._make_world()
	_enhance_glow()
	_add_vanishing_glow()

# The lower layers build the ship with very hot emissive materials (engines at
# energy 8-10) and strong on-board lights, which blows the hull into a white
# blob once glow is on. We keep their ship exactly as-is and only clamp the
# worst offenders afterwards, so it still glows but reads as a ship.
func _build_ship() -> void:
	super._build_ship()
	_tame_ship(ship_visual)

func _tame_ship(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.emission_enabled and sm.emission_energy_multiplier > 1.8:
					sm.emission_energy_multiplier = 1.8
		elif child is OmniLight3D:
			var light := child as OmniLight3D
			if light.light_energy > 4.0:
				light.light_energy = 4.0
		_tame_ship(child)

func _enhance_glow() -> void:
	# Lower layers already animate ambient/fog per biome but never touch glow or
	# the tonemapper, so tuning them here is safe and persistent. Property access
	# mirrors the (already CI-passing) idiom used by the biome layers.
	# Restrained glow: only genuinely bright emissive edges bloom, and the halo
	# stays tight. Filmic tonemap is kept because it rolls highlights off softly
	# (less blown-out than the default linear mapping).
	# Subtle glow: only the brightest neon edges bloom, and only slightly. No
	# constant bloom, high HDR threshold, low intensity - a hint of neon, not a
	# light show.
	var levels: Array[float] = [0.10, 0.26, 0.34, 0.22, 0.10, 0.04, 0.0]
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			child.environment.tonemap_exposure = 0.95
			child.environment.glow_enabled = true
			child.environment.glow_normalized = true
			child.environment.glow_intensity = 0.42
			child.environment.glow_strength = 0.80
			child.environment.glow_bloom = 0.0
			child.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
			child.environment.glow_hdr_threshold = 1.30
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
		torus.rings = 24            # lighter than the default 64 for cheaper frames
		torus.ring_segments = 10
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position.z = -float(i) * 5.0
		var c: Color = tints[i]
		ring.material_override = _mat(c, c, 2.0 - float(i) * 0.5, 0.0, 0.1)
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

# Reimplemented (instead of super) so sections recycle behind the camera.
# Mirrors the base biome update (biome env + advance/recycle/rebuild + streaks +
# obstacles) and folds in the curve, obstacle lanes and reliable collisions.
func _update_world(delta: float) -> void:
	var biome := _current_biome()
	_update_biome_environment(delta, biome)
	var advance := speed * delta
	# Corridor sections: advance, recycle only when behind the camera, ride curve.
	for child in corridor_root.get_children():
		var section := child as Node3D
		section.position.z += advance
		if section.position.z > RECYCLE_Z:
			section.position.z -= SECTION_COUNT * SECTION_LENGTH
			var old_biome := int(section.get_meta("biome", 0))
			if old_biome != biome:
				_rebuild_section_for_biome(section, biome, section.get_index())
		var soff := _curve_at(-section.position.z)
		section.position.x = soff.x
		section.position.y = soff.y
	# Streaks (fixed random lane captured once).
	for child in streak_root.get_children():
		var streak := child as Node3D
		streak.position.z += advance * 1.25
		if streak.position.z > RECYCLE_Z:
			streak.position.z = randf_range(-120.0, -80.0)
		if not streak.has_meta("bx"):
			streak.set_meta("bx", streak.position.x)
			streak.set_meta("by", streak.position.y)
		var koff := _curve_at(-streak.position.z)
		streak.position.x = float(streak.get_meta("bx")) + koff.x
		streak.position.y = float(streak.get_meta("by")) + koff.y
	# Obstacles recycle just after passing the ship (they must never reach the
	# camera), and ride their recorded lane along the curve.
	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += advance
		area.rotation_degrees.z += (16.0 + speed * 0.20) * delta
		if area.position.z > 2.2:
			_reset_obstacle(area, randf_range(-190.0, -140.0))
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
	# Reliable, tunnelling-proof collisions (see _check_hits).
	_check_hits()

# The base game relies on Area3D.body_entered, but the ship is teleported by
# direct position assignment every frame, so at high speed obstacles sweep past
# the ship between physics ticks and the signal never fires (~half are missed).
# We test every frame against the real collision shapes instead: an oriented
# point-in-box / sphere test at the ship, padded by the ship's own size.
func _check_hits() -> void:
	if not alive:
		return
	var sp := ship.global_position
	var pad := Vector3(0.30, 0.20, 0.34)   # approximate ship half-size
	for child in obstacle_root.get_children():
		var area := child as Area3D
		if absf(area.position.z - sp.z) > 3.0:
			continue
		for c in area.get_children():
			if c is CollisionShape3D:
				var cs := c as CollisionShape3D
				var shape := cs.shape
				if shape is BoxShape3D:
					var h: Vector3 = (shape as BoxShape3D).size * 0.5 + pad
					var local: Vector3 = cs.global_transform.affine_inverse() * sp
					if absf(local.x) < h.x and absf(local.y) < h.y and absf(local.z) < h.z:
						_hit(ship)
						return
				elif shape is SphereShape3D:
					if sp.distance_to(cs.global_position) < (shape as SphereShape3D).radius + 0.30:
						_hit(ship)
						return

func _update_camera(delta: float) -> void:
	super._update_camera(delta)
	# Bank into the turn based on the centreline slope at the ship.
	var slope := CURVE_AMP_X * CURVE_FREQ_X * cos(score * CURVE_FREQ_X)
	camera.rotation_degrees.z = lerpf(camera.rotation_degrees.z, -slope * 13.0, clampf(delta * 2.0, 0.0, 1.0))

# --- Floor neon: a thin luminous centre line + side rails added on top of every
# section so the floor reads as neon tech instead of a washed slab with a black
# pit down the middle. As children of the section they inherit the curve.
func _add_floor_glow(section: Node3D) -> void:
	var line := _mat(Color(0.30, 0.90, 1.0), Color(0.10, 0.80, 1.0), 1.5, 0.10, 0.12)
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
					control.text = "VORTEX // RUNNER 4.4 // NO POP"
