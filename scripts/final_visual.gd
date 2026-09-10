extends "res://scripts/visual_ship_hook.gd"

func _build_camera_canopy() -> void:
	var shell := Node3D.new()
	shell.name = "CameraCanopy"
	add_child(shell)
	var roof := _mat(Color(0.105, 0.120, 0.165), Color(0.010, 0.014, 0.028), 0.10, 0.80, 0.22)
	var gunmetal := _mat(Color(0.075, 0.090, 0.125), Color(0.006, 0.008, 0.016), 0.05, 0.88, 0.20)
	var steel := _mat(Color(0.40, 0.44, 0.53), Color(0.020, 0.025, 0.045), 0.12, 0.70, 0.20)
	var pale := _mat(Color(0.66, 0.70, 0.78), Color(0.025, 0.035, 0.060), 0.14, 0.56, 0.18)
	var cyan := _mat(Color(0.12, 0.88, 1.0), Color(0.0, 0.70, 1.0), 2.8, 0.12, 0.06)
	_box(shell, Vector3(0.0, 2.42, 5.25), Vector3(9.5, 0.26, 10.2), roof)
	for x: float in [-3.65, -1.82, 0.0, 1.82, 3.65]:
		_box(shell, Vector3(x, 2.18, 5.15), Vector3(0.88, 0.13, 9.6), gunmetal)
	for x: float in [-3.20, -2.92, -2.64, 2.64, 2.92, 3.20]:
		_cylinder(shell, Vector3(x, 1.90, 5.15), 0.070, 8.7, steel, Vector3(90.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 3.82, 1.81, 4.8), Vector3(0.055, 0.045, 7.2), cyan)
		_box(shell, Vector3(side * 4.16, 1.48, 5.8), Vector3(0.22, 1.08, 3.0), steel, Vector3(0.0, 0.0, side * 12.0))
	for z: float in [1.0, 6.7]:
		_box(shell, Vector3(-3.55, 1.92, z), Vector3(1.35, 0.16, 0.28), pale)
		_box(shell, Vector3(3.55, 1.92, z), Vector3(1.35, 0.16, 0.28), pale)

func _build_ship() -> void:
	super._build_ship()
	ship_visual.scale = Vector3(0.76, 0.76, 0.76)
	var dark := _mat(Color(0.055, 0.070, 0.105), Color(0.010, 0.015, 0.028), 0.10, 0.88, 0.16)
	var white := _mat(Color(0.88, 0.91, 0.97), Color(0.08, 0.10, 0.15), 0.38, 0.42, 0.12)
	var cyan := _mat(Color(0.10, 0.94, 1.0), Color(0.0, 0.80, 1.0), 7.5, 0.10, 0.04)
	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side * 0.40, -0.04, 0.96), Vector3(0.30, 0.24, 0.62), dark, Vector3(0.0, side * 5.0, 0.0))
		_cylinder(ship_visual, Vector3(side * 0.40, -0.04, 1.27), 0.17, 0.18, white, Vector3(90.0, 0.0, 0.0))
		_cylinder(ship_visual, Vector3(side * 0.40, -0.04, 1.39), 0.105, 0.10, cyan, Vector3(90.0, 0.0, 0.0))
	_box(ship_visual, Vector3(0.0, 0.02, 1.08), Vector3(0.25, 0.22, 0.20), dark)
	# Dedicated neutral key/fill lights: the craft must remain readable between neon zones.
	var ship_key := OmniLight3D.new()
	ship_key.position = Vector3(-1.5, 1.9, 2.2)
	ship_key.light_color = Color(0.88, 0.92, 1.0)
	ship_key.light_energy = 6.2
	ship_key.omni_range = 6.0
	ship_visual.add_child(ship_key)
	var ship_fill := OmniLight3D.new()
	ship_fill.position = Vector3(1.5, 0.7, 1.8)
	ship_fill.light_color = Color(0.36, 0.62, 1.0)
	ship_fill.light_energy = 3.2
	ship_fill.omni_range = 4.8
	ship_visual.add_child(ship_fill)

func _make_world() -> void:
	super._make_world()
	camera.position = Vector3(0.06, -0.28, 8.15)
	camera.rotation_degrees = Vector3(-1.0, -0.35, -0.08)
	camera.fov = 66.0
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.ambient_light_color = Color(0.32, 0.34, 0.44)
			child.environment.ambient_light_energy = 1.65

func _reset_obstacle(area: Area3D, z: float) -> void:
	var visual := area.get_child(0) as Node3D
	for child in visual.get_children():
		child.queue_free()
	var frame := _mat(Color(0.12, 0.14, 0.18), Color(0.01, 0.012, 0.02), 0.08, 0.78, 0.20)
	var steel := _mat(Color(0.52, 0.56, 0.64), Color(0.035, 0.04, 0.06), 0.22, 0.52, 0.18)
	var hazard := _mat(Color(1.0, 0.48, 0.035), Color(1.0, 0.20, 0.01), 5.8, 0.16, 0.08)
	var red := _mat(Color(0.94, 0.08, 0.08), Color(1.0, 0.015, 0.01), 4.0, 0.18, 0.10)
	var cyan := _mat(Color(0.12, 0.90, 1.0), Color(0.0, 0.70, 1.0), 3.5, 0.12, 0.06)
	var type := randi_range(0, 3)
	var size := Vector3(1.0, 1.0, 0.7)
	if type == 0:
		# Armoured reactor/drone: circular silhouette with protective fins.
		_cylinder(visual, Vector3.ZERO, 0.72, 0.44, frame)
		_cylinder(visual, Vector3(0.0, 0.0, 0.26), 0.50, 0.48, steel)
		_cylinder(visual, Vector3(0.0, 0.0, 0.52), 0.23, 0.52, red)
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			_box(visual, Vector3(0.0, 0.0, 0.18), Vector3(1.72, 0.11, 0.18), frame, Vector3(0.0, 0.0, a))
		size = Vector3(1.45, 1.45, 0.72)
	elif type == 1:
		# Horizontal maintenance gate with hazard lamps and striped braces.
		size = Vector3(2.55, 0.58, 0.72)
		_box(visual, Vector3.ZERO, Vector3(3.05, 0.66, 0.76), frame)
		_box(visual, Vector3(0.0, 0.0, 0.40), Vector3(2.70, 0.10, 0.10), hazard)
		for x: float in [-1.12, -0.38, 0.38, 1.12]:
			_box(visual, Vector3(x, 0.0, 0.43), Vector3(0.24, 0.13, 0.11), steel, Vector3(0.0, 0.0, 28.0))
		for x: float in [-1.43, 1.43]:
			_cylinder(visual, Vector3(x, 0.0, 0.43), 0.10, 0.12, red)
	elif type == 2:
		# Vertical energy pylon with mechanical shoulders.
		size = Vector3(0.62, 2.55, 0.72)
		_box(visual, Vector3.ZERO, Vector3(0.68, 3.05, 0.76), frame)
		_box(visual, Vector3(0.0, 0.0, 0.40), Vector3(0.11, 2.68, 0.10), hazard)
		for y: float in [-1.15, -0.38, 0.38, 1.15]:
			_box(visual, Vector3(0.0, y, 0.42), Vector3(0.92, 0.15, 0.13), steel)
		for y: float in [-1.46, 1.46]:
			_cylinder(visual, Vector3(0.0, y, 0.43), 0.10, 0.12, red)
	else:
		# Compact rotating cross: recognizable gameplay hazard, not a random neon stick.
		size = Vector3(1.85, 1.85, 0.72)
		_cylinder(visual, Vector3.ZERO, 0.30, 0.55, steel)
		_cylinder(visual, Vector3(0.0, 0.0, 0.32), 0.16, 0.58, cyan)
		for a: float in [0.0, 90.0]:
			_box(visual, Vector3.ZERO, Vector3(2.30, 0.24, 0.52), frame, Vector3(0.0, 0.0, a))
			_box(visual, Vector3(0.0, 0.0, 0.30), Vector3(1.95, 0.065, 0.08), hazard, Vector3(0.0, 0.0, a))
	var collision := area.get_child(1) as CollisionShape3D
	(collision.shape as BoxShape3D).size = size * 0.72
	area.position = Vector3(randf_range(-3.30, 3.30), randf_range(-2.20, 1.35), z)
	area.rotation_degrees.z = randf_range(-18.0, 18.0) if type < 3 else randf_range(0.0, 45.0)

func _update_camera(delta: float) -> void:
	var target := Vector3(0.06 + ship.position.x * 0.018, -0.28 + ship.position.y * 0.010, 8.15)
	camera.position = camera.position.lerp(target, clampf(delta * 1.5, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 66.0 + (speed - 13.0) * 0.06, clampf(delta * 1.2, 0.0, 1.0))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 2.1 // HAZARDS"
