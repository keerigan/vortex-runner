extends "res://scripts/visual_overhaul.gd"

func _make_world() -> void:
	super._make_world()
	camera.position = Vector3(0.10, -0.46, 8.10)
	camera.rotation_degrees = Vector3(-2.2, -0.65, -0.12)
	camera.fov = 63.0
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.6, -0.8, 1.3)
	fill.light_color = Color(0.56, 0.18, 0.90)
	fill.light_energy = 3.0
	fill.omni_range = 7.0
	add_child(fill)

func _build_ship() -> void:
	super._build_ship()
	var upgrade = load("res://scripts/ship_upgrade.gd")
	if upgrade:
		upgrade.decorate(self, ship_visual, Callable(self, "_box"), Callable(self, "_cylinder"), Callable(self, "_mat"))

func _build_corridor_section(section: Node3D, index: int) -> void:
	# Purposefully rebuilt from scratch: no inherited arcade grid or micro-neon rows.
	var dark := _mat(Color(0.020, 0.024, 0.035), Color(0.004, 0.005, 0.010), 0.02, 0.90, 0.20)
	var gunmetal := _mat(Color(0.085, 0.095, 0.125), Color(0.008, 0.009, 0.016), 0.05, 0.88, 0.22)
	var steel := _mat(Color(0.30, 0.32, 0.37), Color(0.018, 0.018, 0.028), 0.10, 0.72, 0.24)
	var pale := _mat(Color(0.58, 0.58, 0.62), Color(0.028, 0.025, 0.040), 0.16, 0.54, 0.28)
	var deck := _mat(Color(0.29, 0.25, 0.35), Color(0.16, 0.055, 0.24), 0.48, 0.44, 0.28)
	var deck_light := _mat(Color(0.43, 0.35, 0.50), Color(0.28, 0.09, 0.40), 0.72, 0.38, 0.24)
	var cyan := _mat(Color(0.12, 0.90, 1.0), Color(0.0, 0.78, 1.0), 5.7, 0.14, 0.06)
	var violet := _mat(Color(0.45, 0.16, 0.62), Color(0.58, 0.08, 0.84), 2.5, 0.20, 0.10)
	var amber := _mat(Color(0.92, 0.33, 0.055), Color(1.0, 0.15, 0.01), 4.1, 0.15, 0.08)

	# Floor: broad, continuous surfaces like the reference rather than an arcade runway.
	_box(section, Vector3(0.0, -3.32, 0.0), Vector3(9.7, 0.34, SECTION_LENGTH), deck)
	_box(section, Vector3(-2.65, -3.10, 0.0), Vector3(3.15, 0.10, SECTION_LENGTH * 0.95), deck_light)
	_box(section, Vector3(2.65, -3.10, 0.0), Vector3(3.15, 0.10, SECTION_LENGTH * 0.95), deck_light)
	_box(section, Vector3(0.0, -3.04, 0.0), Vector3(1.28, 0.07, SECTION_LENGTH * 0.98), dark)
	for x: float in [-4.15, -1.08, 1.08, 4.15]:
		_box(section, Vector3(x, -3.02, 0.0), Vector3(0.035, 0.018, SECTION_LENGTH * 0.88), gunmetal)

	# Thick side shells and angled lower housings.
	for side: float in [-1.0, 1.0]:
		_box(section, Vector3(side * 4.82, -0.35, 0.0), Vector3(0.54, 5.65, SECTION_LENGTH), gunmetal)
		_box(section, Vector3(side * 4.38, 1.65, 0.0), Vector3(1.05, 1.45, SECTION_LENGTH * 0.96), steel, Vector3(0.0, 0.0, side * -17.0))
		_box(section, Vector3(side * 4.32, -2.18, 0.0), Vector3(0.82, 1.42, SECTION_LENGTH * 0.94), pale, Vector3(0.0, 0.0, side * 11.0))

		# Three substantial machinery pods per module.
		for k in range(3):
			var z := -2.20 + float(k) * 2.20
			_box(section, Vector3(side * 4.00, -1.42, z), Vector3(0.66, 1.10, 1.15), steel)
			_cylinder(section, Vector3(side * 3.62, -1.40, z), 0.34, 0.45, gunmetal, Vector3(0.0, 0.0, 90.0))
			_cylinder(section, Vector3(side * 3.42, -1.40, z), 0.23, 0.48, pale, Vector3(0.0, 0.0, 90.0))
			if (index + k) % 4 == 0:
				_cylinder(section, Vector3(side * 3.18, -1.40, z), 0.11, 0.50, cyan, Vector3(0.0, 0.0, 90.0))

		# The signature continuous light strip from the target image.
		_box(section, Vector3(side * 4.46, 0.72, 0.0), Vector3(0.09, 0.10, SECTION_LENGTH * 0.97), cyan)

	# Ceiling: broad plates, cable trays and only a few light lines.
	_box(section, Vector3(0.0, 2.30, 0.0), Vector3(9.55, 0.34, SECTION_LENGTH), dark)
	for x: float in [-3.35, -1.68, 0.0, 1.68, 3.35]:
		_box(section, Vector3(x, 2.08, 0.0), Vector3(1.08, 0.16, SECTION_LENGTH * 0.96), gunmetal)
	for x: float in [-3.05, 3.05]:
		_cylinder(section, Vector3(x, 1.82, 0.0), 0.12, SECTION_LENGTH * 0.92, steel, Vector3(90.0, 0.0, 0.0))
		_cylinder(section, Vector3(x + (0.34 if x < 0.0 else -0.34), 1.82, 0.0), 0.08, SECTION_LENGTH * 0.92, steel, Vector3(90.0, 0.0, 0.0))

	# Structural portal every two modules.
	if index % 2 == 0:
		_box(section, Vector3(-4.30, -0.15, -2.90), Vector3(0.38, 5.10, 0.48), pale, Vector3(0.0, 0.0, -7.0))
		_box(section, Vector3(4.30, -0.15, -2.90), Vector3(0.38, 5.10, 0.48), pale, Vector3(0.0, 0.0, 7.0))
		_box(section, Vector3(0.0, 1.94, -2.90), Vector3(8.20, 0.30, 0.48), pale)
		_box(section, Vector3(0.0, 1.72, -2.63), Vector3(7.65, 0.085, 0.10), cyan)

	# Big asymmetrical landmarks make each stretch feel authored instead of repeated.
	var featured_side := -1.0 if index % 6 < 3 else 1.0
	if index % 5 == 0:
		_cylinder(section, Vector3(featured_side * 3.28, -0.45, -0.65), 0.92, 0.34, gunmetal, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 3.06, -0.45, -0.65), 0.68, 0.38, pale, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 2.84, -0.45, -0.65), 0.42, 0.42, cyan, Vector3(0.0, 0.0, 90.0))
		_cylinder(section, Vector3(featured_side * 2.61, -0.45, -0.65), 0.20, 0.46, dark, Vector3(0.0, 0.0, 90.0))
	if index % 5 == 2:
		_box(section, Vector3(featured_side * 3.35, -0.10, 0.10), Vector3(0.45, 2.25, 2.0), steel, Vector3(0.0, 0.0, featured_side * 8.0))
		_box(section, Vector3(featured_side * 3.08, -0.05, 0.10), Vector3(0.08, 1.25, 1.25), violet)

	# Warm hazard accents are sparse and architectural.
	if index % 4 == 1:
		_box(section, Vector3(featured_side * 3.55, -2.72, -1.25), Vector3(0.46, 0.06, 0.15), amber)

	# Local pools of real light create purple/cyan wash on neutral surfaces.
	if index % 4 == 0:
		var local_light := OmniLight3D.new()
		local_light.position = Vector3(featured_side * 2.65, -0.25, -0.8)
		local_light.light_color = Color(0.08, 0.62, 1.0) if index % 8 == 0 else Color(0.62, 0.18, 0.88)
		local_light.light_energy = 3.4
		local_light.omni_range = 5.8
		section.add_child(local_light)

func _update_camera(delta: float) -> void:
	var target := Vector3(0.10 + ship.position.x * 0.022, -0.46 + ship.position.y * 0.010, 8.10)
	camera.position = camera.position.lerp(target, clampf(delta * 1.5, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 63.0 + (speed - 13.0) * 0.07, clampf(delta * 1.2, 0.0, 1.0))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 1.2 // REVIEW"
