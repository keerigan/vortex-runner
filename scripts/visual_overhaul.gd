extends "res://scripts/main.gd"

func _make_world() -> void:
	super._make_world()
	# A camera-side key light makes the fighter readable instead of a black silhouette.
	var hero := SpotLight3D.new()
	hero.position = Vector3(0.0, 1.2, 6.2)
	hero.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	hero.light_color = Color(0.68, 0.80, 1.0)
	hero.light_energy = 5.5
	hero.spot_range = 15.0
	hero.spot_angle = 42.0
	hero.shadow_enabled = true
	add_child(hero)
	var warm := OmniLight3D.new()
	warm.position = Vector3(0.0, -2.0, -8.0)
	warm.light_color = Color(1.0, 0.18, 0.08)
	warm.light_energy = 2.2
	warm.omni_range = 8.0
	add_child(warm)
	camera.fov = 68.0
	camera.position = Vector3(0.0, -0.05, 8.4)

func _build_ship() -> void:
	super._build_ship()
	var cyan := _mat(Color(0.10, 0.90, 1.0), Color(0.0, 0.75, 1.0), 9.0, 0.2, 0.06)
	var metal := _mat(Color(0.48, 0.54, 0.64), Color(0.02, 0.03, 0.05), 0.2, 0.82, 0.16)
	# Mechanical engine rings and wing-tip position lights around the dedicated mesh.
	for x: float in [-0.30, 0.30]:
		_cylinder(ship_visual, Vector3(x, -0.08, 1.43), 0.16, 0.08, metal)
		_cylinder(ship_visual, Vector3(x, -0.08, 1.50), 0.105, 0.09, cyan)
	for x: float in [-1.90, 1.90]:
		_box(ship_visual, Vector3(x, 0.03, 0.35), Vector3(0.08, 0.06, 0.28), cyan)

func _build_corridor_section(section: Node3D, index: int) -> void:
	super._build_corridor_section(section, index)
	var gunmetal := _mat(Color(0.12, 0.14, 0.19), Color(0.01, 0.015, 0.025), 0.08, 0.88, 0.18)
	var steel := _mat(Color(0.42, 0.45, 0.52), Color(0.025, 0.03, 0.045), 0.12, 0.74, 0.20)
	var pale := _mat(Color(0.62, 0.64, 0.68), Color(0.035, 0.035, 0.045), 0.10, 0.58, 0.24)
	var cyan := _mat(Color(0.12, 0.86, 1.0), Color(0.0, 0.78, 1.0), 5.0, 0.18, 0.08)
	var amber := _mat(Color(0.95, 0.38, 0.06), Color(1.0, 0.18, 0.01), 4.0, 0.2, 0.10)
	# Ceiling cassette: breaks the huge featureless black slab visible on phone.
	_box(section, Vector3(0.0, 2.18, 0.0), Vector3(5.4, 0.16, 6.55), gunmetal)
	for x: float in [-2.35, -1.18, 0.0, 1.18, 2.35]:
		_box(section, Vector3(x, 2.04, 0.0), Vector3(0.72, 0.08, 5.9), steel)
	for z: float in [-2.4, 0.0, 2.4]:
		_box(section, Vector3(0.0, 1.94, z), Vector3(5.8, 0.12, 0.18), pale)
	# Long luminous strips are recessed between ceiling plates, not floating bars.
	_box(section, Vector3(-2.82, 1.91, 0.0), Vector3(0.07, 0.055, 5.7), cyan)
	_box(section, Vector3(2.82, 1.91, 0.0), Vector3(0.07, 0.055, 5.7), cyan)
	# Layered wall ribs and diagonal braces create real depth in portrait.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.45, 0.0, 2.45]:
			_box(section, Vector3(side * 4.38, -0.15, z), Vector3(0.30, 4.2, 0.26), steel, Vector3(0.0, 0.0, side * 7.0))
			_box(section, Vector3(side * 4.05, 0.45, z + 0.32), Vector3(0.18, 2.1, 0.20), gunmetal, Vector3(0.0, 0.0, side * 28.0))
		# Three large conduits with clamps instead of tiny repeated neon blocks.
		for y: float in [-1.75, -1.30, -0.85]:
			_cylinder(section, Vector3(side * 3.92, y, 0.0), 0.11, 6.0, gunmetal, Vector3(90, 0, 0))
		for z: float in [-2.1, 0.0, 2.1]:
			_box(section, Vector3(side * 3.90, -1.30, z), Vector3(0.22, 1.25, 0.14), pale)
	# Floor plating with raised mechanical islands and inset lamps.
	for x: float in [-3.25, -2.25, 2.25, 3.25]:
		_box(section, Vector3(x, -3.08, 0.0), Vector3(0.78, 0.12, 5.85), gunmetal)
		for z: float in [-2.2, 0.0, 2.2]:
			_box(section, Vector3(x, -2.99, z), Vector3(0.46, 0.045, 0.16), cyan if index % 3 else amber)
	# Landmark machinery: each few sections get a different large silhouette.
	if index % 5 == 0:
		var side := -1.0 if index % 10 == 0 else 1.0
		_cylinder(section, Vector3(side * 3.45, -0.55, -1.0), 1.05, 0.30, gunmetal, Vector3(0, 0, 90))
		_cylinder(section, Vector3(side * 3.25, -0.55, -1.0), 0.78, 0.34, steel, Vector3(0, 0, 90))
		_cylinder(section, Vector3(side * 3.04, -0.55, -1.0), 0.52, 0.38, cyan, Vector3(0, 0, 90))
		for angle: float in [0.0, 45.0, 90.0, 135.0]:
			_box(section, Vector3(side * 2.82, -0.55, -1.0), Vector3(0.10, 1.35, 0.12), pale, Vector3(angle, 0, 0))
	# Local lights move with the modular tunnel and actually shade its surfaces.
	if index % 3 == 0:
		var local_light := OmniLight3D.new()
		local_light.position = Vector3(-2.7 if index % 2 == 0 else 2.7, 0.25, -1.4)
		local_light.light_color = Color(0.06, 0.68, 1.0) if index % 2 == 0 else Color(0.70, 0.16, 0.90)
		local_light.light_energy = 2.4
		local_light.omni_range = 6.0
		section.add_child(local_light)

func _make_ui() -> void:
	super._make_ui()
	# Make it obvious which visual branch is installed during screenshot reviews.
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 0.9 // MKII"
