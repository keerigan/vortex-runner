extends "res://scripts/visual_overhaul.gd"

func _make_world() -> void:
	super._make_world()
	# Offset the camera slightly: the reference reads as a place, not a perfect vanishing-point test.
	camera.position = Vector3(0.62, -0.28, 8.15)
	camera.rotation_degrees = Vector3(-2.4, -3.8, -0.35)
	camera.fov = 66.0
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.2, -1.1, 1.7)
	fill.light_color = Color(0.64, 0.18, 0.95)
	fill.light_energy = 3.2
	fill.omni_range = 7.0
	add_child(fill)

func _build_ship() -> void:
	super._build_ship()
	var upgrade = load("res://scripts/ship_upgrade.gd")
	if upgrade:
		upgrade.decorate(self, ship_visual, Callable(self, "_box"), Callable(self, "_cylinder"), Callable(self, "_mat"))

func _build_corridor_section(section: Node3D, index: int) -> void:
	super._build_corridor_section(section, index)
	var charcoal := _mat(Color(0.045, 0.052, 0.068), Color(0.006, 0.008, 0.014), 0.04, 0.90, 0.18)
	var steel := _mat(Color(0.40, 0.43, 0.49), Color(0.018, 0.02, 0.03), 0.10, 0.76, 0.22)
	var pale := _mat(Color(0.64, 0.64, 0.66), Color(0.025, 0.025, 0.035), 0.10, 0.56, 0.26)
	var cyan := _mat(Color(0.11, 0.88, 1.0), Color(0.0, 0.76, 1.0), 5.2, 0.16, 0.06)
	var violet := _mat(Color(0.48, 0.16, 0.68), Color(0.62, 0.08, 0.90), 2.4, 0.20, 0.10)
	var amber := _mat(Color(0.92, 0.31, 0.045), Color(1.0, 0.14, 0.01), 3.8, 0.15, 0.08)

	# Broad ceiling ribs with service channels between them reduce the chess-board feel.
	for x: float in [-3.6, -1.8, 0.0, 1.8, 3.6]:
		_box(section, Vector3(x, 1.76, 0.0), Vector3(1.20, 0.18, 6.15), charcoal)
	for z: float in [-2.45, 2.45]:
		_box(section, Vector3(0.0, 1.62, z), Vector3(8.45, 0.13, 0.34), steel)

	# Large irregular wall modules: deliberately not mirrored every section.
	var featured_side := -1.0 if index % 3 != 1 else 1.0
	if index % 3 == 0:
		_box(section, Vector3(featured_side * 3.72, -0.55, -0.65), Vector3(0.62, 1.65, 2.10), pale, Vector3(0.0, 0.0, featured_side * 7.0))
		_cylinder(section, Vector3(featured_side * 3.34, -0.62, -0.70), 0.72, 0.30, charcoal, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 3.14, -0.62, -0.70), 0.48, 0.35, cyan, Vector3(0.0, 0.0, 90.0))
	if index % 4 == 1:
		for y: float in [-1.15, -0.55, 0.05]:
			_cylinder(section, Vector3(featured_side * 3.52, y, 0.25), 0.13, 5.0, charcoal, Vector3(90.0, 0.0, 0.0))
		_box(section, Vector3(featured_side * 3.30, 0.65, 0.45), Vector3(0.10, 0.65, 1.75), violet)

	# Sparse warm guidance lamps, avoiding the old all-cyan arcade runway.
	for lane_x: float in [-2.85, 2.85]:
		if (index + int(abs(lane_x))) % 3 == 0:
			_box(section, Vector3(lane_x, -3.00, -1.65), Vector3(0.44, 0.045, 0.13), amber)

	# Actual light pools on selected modules.
	if index % 4 == 0:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(featured_side * 2.8, -0.25, -1.0)
		lamp.light_color = Color(0.34, 0.12, 0.62) if index % 8 == 0 else Color(0.02, 0.58, 0.92)
		lamp.light_energy = 3.5
		lamp.omni_range = 5.5
		section.add_child(lamp)

func _update_camera(delta: float) -> void:
	# Keep the asymmetric composition while still following the player's movement subtly.
	var target := Vector3(0.62 + ship.position.x * 0.045, -0.28 + ship.position.y * 0.018, 8.15)
	camera.position = camera.position.lerp(target, clampf(delta * 1.6, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 66.0 + (speed - 13.0) * 0.08, clampf(delta * 1.3, 0.0, 1.0))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 1.0 // REVIEW"
