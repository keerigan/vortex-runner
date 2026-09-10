extends "res://scripts/visual_overhaul.gd"

func _make_world() -> void:
	super._make_world()
	camera.position = Vector3(0.08, -0.38, 8.00)
	camera.rotation_degrees = Vector3(-0.8, -0.45, -0.10)
	camera.fov = 65.0
	var cool_fill := OmniLight3D.new()
	cool_fill.position = Vector3(-2.8, -0.6, 1.4)
	cool_fill.light_color = Color(0.18, 0.52, 0.95)
	cool_fill.light_energy = 3.8
	cool_fill.omni_range = 7.4
	add_child(cool_fill)
	var warm_fill := OmniLight3D.new()
	warm_fill.position = Vector3(2.6, -1.4, -4.0)
	warm_fill.light_color = Color(0.64, 0.15, 0.48)
	warm_fill.light_energy = 2.4
	warm_fill.omni_range = 6.0
	add_child(warm_fill)

func _build_ship() -> void:
	# Build parent resources first, then deliberately remove the legacy prototype geometry.
	super._build_ship()
	for child in ship_visual.get_children():
		child.free()
	engines.clear()
	engine_trails.clear()
	var upgrade = load("res://scripts/ship_upgrade.gd")
	if upgrade:
		upgrade.decorate(self, ship_visual, Callable(self, "_box"), Callable(self, "_cylinder"), Callable(self, "_mat"))

func _build_corridor_section(section: Node3D, index: int) -> void:
	var dark := _mat(Color(0.018, 0.022, 0.032), Color(0.003, 0.004, 0.009), 0.02, 0.91, 0.20)
	var gunmetal := _mat(Color(0.080, 0.090, 0.115), Color(0.007, 0.008, 0.015), 0.05, 0.88, 0.22)
	var steel := _mat(Color(0.31, 0.33, 0.38), Color(0.016, 0.018, 0.028), 0.10, 0.72, 0.24)
	var pale := _mat(Color(0.62, 0.62, 0.66), Color(0.03, 0.028, 0.045), 0.16, 0.54, 0.27)
	var deck := _mat(Color(0.30, 0.26, 0.35), Color(0.15, 0.050, 0.22), 0.45, 0.44, 0.28)
	var deck_light := _mat(Color(0.46, 0.39, 0.52), Color(0.24, 0.07, 0.33), 0.62, 0.36, 0.23)
	var cyan := _mat(Color(0.14, 0.91, 1.0), Color(0.0, 0.78, 1.0), 4.2, 0.14, 0.06)
	var violet := _mat(Color(0.43, 0.15, 0.58), Color(0.54, 0.07, 0.78), 2.0, 0.20, 0.10)
	var amber := _mat(Color(0.94, 0.34, 0.06), Color(1.0, 0.15, 0.01), 3.6, 0.15, 0.08)

	_box(section, Vector3(0.0, -3.30, 0.0), Vector3(9.7, 0.34, SECTION_LENGTH), deck)
	_box(section, Vector3(-2.62, -3.08, 0.0), Vector3(3.22, 0.10, SECTION_LENGTH * 0.95), deck_light)
	_box(section, Vector3(2.62, -3.08, 0.0), Vector3(3.22, 0.10, SECTION_LENGTH * 0.95), deck_light)
	_box(section, Vector3(0.0, -3.01, 0.0), Vector3(1.18, 0.08, SECTION_LENGTH * 0.99), dark)
	for x: float in [-4.12, -1.04, 1.04, 4.12]:
		_box(section, Vector3(x, -2.99, 0.0), Vector3(0.035, 0.018, SECTION_LENGTH * 0.88), gunmetal)

	for side: float in [-1.0, 1.0]:
		_box(section, Vector3(side * 4.82, -0.30, 0.0), Vector3(0.58, 5.72, SECTION_LENGTH), gunmetal)
		_box(section, Vector3(side * 4.34, 1.48, 0.0), Vector3(1.08, 1.56, SECTION_LENGTH * 0.96), steel, Vector3(0.0, 0.0, side * -17.0))
		_box(section, Vector3(side * 4.28, -2.14, 0.0), Vector3(0.86, 1.48, SECTION_LENGTH * 0.94), pale, Vector3(0.0, 0.0, side * 11.0))
		_box(section, Vector3(side * 3.90, -0.15, 0.0), Vector3(0.40, 0.34, SECTION_LENGTH * 0.90), dark)
		for k in range(3):
			var z := -2.15 + float(k) * 2.18
			_box(section, Vector3(side * 4.00, -1.40, z), Vector3(0.68, 1.12, 1.12), steel)
			_cylinder(section, Vector3(side * 3.62, -1.38, z), 0.35, 0.45, gunmetal, Vector3(0.0, 0.0, 90.0))
			_cylinder(section, Vector3(side * 3.41, -1.38, z), 0.23, 0.48, pale, Vector3(0.0, 0.0, 90.0))
			if (index + k) % 7 == 0:
				_cylinder(section, Vector3(side * 3.18, -1.38, z), 0.105, 0.50, cyan, Vector3(0.0, 0.0, 90.0))
		_box(section, Vector3(side * 4.43, 0.66, 0.0), Vector3(0.09, 0.095, SECTION_LENGTH * 0.96), cyan)

	_box(section, Vector3(0.0, 2.18, 0.0), Vector3(9.55, 0.38, SECTION_LENGTH), dark)
	for x: float in [-3.50, -1.75, 0.0, 1.75, 3.50]:
		_box(section, Vector3(x, 1.94, 0.0), Vector3(1.18, 0.19, SECTION_LENGTH * 0.96), gunmetal)
	for x: float in [-3.05, -2.68, 2.68, 3.05]:
		_cylinder(section, Vector3(x, 1.68, 0.0), 0.10, SECTION_LENGTH * 0.92, steel, Vector3(90.0, 0.0, 0.0))
	for z: float in [-2.55, 2.55]:
		_box(section, Vector3(0.0, 1.72, z), Vector3(8.30, 0.18, 0.32), steel)

	if index % 2 == 0:
		_box(section, Vector3(-4.27, -0.12, -2.90), Vector3(0.40, 5.15, 0.50), pale, Vector3(0.0, 0.0, -7.0))
		_box(section, Vector3(4.27, -0.12, -2.90), Vector3(0.40, 5.15, 0.50), pale, Vector3(0.0, 0.0, 7.0))
		_box(section, Vector3(0.0, 1.78, -2.90), Vector3(8.15, 0.32, 0.50), pale)
		_box(section, Vector3(0.0, 1.56, -2.62), Vector3(7.62, 0.085, 0.10), cyan)

	var featured_side := -1.0 if index % 6 < 3 else 1.0
	if index % 5 == 0:
		_cylinder(section, Vector3(featured_side * 3.20, -0.48, -0.72), 1.02, 0.36, gunmetal, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 2.96, -0.48, -0.72), 0.76, 0.40, pale, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 2.72, -0.48, -0.72), 0.48, 0.44, cyan, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 2.47, -0.48, -0.72), 0.21, 0.48, dark, Vector3(0.0, 0.0, 90.0))
		_box(section, Vector3(featured_side * 3.52, -0.48, -0.72), Vector3(0.30, 2.25, 2.30), steel, Vector3(0.0, 0.0, featured_side * 7.0))
	if index % 5 == 2:
		_box(section, Vector3(featured_side * 3.36, -0.02, 0.10), Vector3(0.48, 2.25, 2.0), steel, Vector3(0.0, 0.0, featured_side * 8.0))
		_box(section, Vector3(featured_side * 3.08, -0.02, 0.10), Vector3(0.08, 1.22, 1.20), violet)
	if index % 4 == 1:
		_box(section, Vector3(featured_side * 3.52, -2.70, -1.20), Vector3(0.48, 0.06, 0.15), amber)

	if index % 4 == 0:
		var local_light := OmniLight3D.new()
		local_light.position = Vector3(featured_side * 2.60, -0.18, -0.75)
		local_light.light_color = Color(0.10, 0.60, 1.0) if index % 8 == 0 else Color(0.60, 0.18, 0.84)
		local_light.light_energy = 3.8
		local_light.omni_range = 5.8
		section.add_child(local_light)

func _update_camera(delta: float) -> void:
	var target := Vector3(0.08 + ship.position.x * 0.020, -0.38 + ship.position.y * 0.010, 8.00)
	camera.position = camera.position.lerp(target, clampf(delta * 1.5, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 65.0 + (speed - 13.0) * 0.07, clampf(delta * 1.2, 0.0, 1.0))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 1.5 // REVIEW"
