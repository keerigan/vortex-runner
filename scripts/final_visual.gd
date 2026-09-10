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

	# Keep the near roof readable instead of producing a featureless black cap.
	_box(shell, Vector3(0.0, 2.42, 5.25), Vector3(9.5, 0.26, 10.2), roof)
	for x: float in [-3.65, -1.82, 0.0, 1.82, 3.65]:
		_box(shell, Vector3(x, 2.18, 5.15), Vector3(0.88, 0.13, 9.6), gunmetal)
	# Long cable trays and pipes converge naturally with perspective.
	for x: float in [-3.20, -2.92, -2.64, 2.64, 2.92, 3.20]:
		_cylinder(shell, Vector3(x, 1.90, 5.15), 0.070, 8.7, steel, Vector3(90.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 3.82, 1.81, 4.8), Vector3(0.055, 0.045, 7.2), cyan)
		_box(shell, Vector3(side * 4.16, 1.48, 5.8), Vector3(0.22, 1.08, 3.0), steel, Vector3(0.0, 0.0, side * 12.0))
	# Sparse structural collars close to camera give scale without ladder bars.
	for z: float in [1.0, 6.7]:
		_box(shell, Vector3(-3.55, 1.92, z), Vector3(1.35, 0.16, 0.28), pale)
		_box(shell, Vector3(3.55, 1.92, z), Vector3(1.35, 0.16, 0.28), pale)

func _build_ship() -> void:
	super._build_ship()
	ship_visual.scale = Vector3(0.76, 0.76, 0.76)
	# Twin rear nacelles make the craft read as a fighter rather than a single glowing wheel.
	var dark := _mat(Color(0.025, 0.032, 0.050), Color(0.004, 0.006, 0.012), 0.03, 0.94, 0.12)
	var white := _mat(Color(0.84, 0.88, 0.94), Color(0.03, 0.04, 0.06), 0.18, 0.54, 0.12)
	var cyan := _mat(Color(0.10, 0.94, 1.0), Color(0.0, 0.80, 1.0), 7.5, 0.10, 0.04)
	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side * 0.40, -0.04, 0.96), Vector3(0.30, 0.24, 0.62), dark, Vector3(0.0, side * 5.0, 0.0))
		_cylinder(ship_visual, Vector3(side * 0.40, -0.04, 1.27), 0.17, 0.18, white, Vector3(90.0, 0.0, 0.0))
		_cylinder(ship_visual, Vector3(side * 0.40, -0.04, 1.39), 0.105, 0.10, cyan, Vector3(90.0, 0.0, 0.0))
	# Dark rear bridge de-emphasizes the old central turbine while preserving its detail.
	_box(ship_visual, Vector3(0.0, 0.02, 1.08), Vector3(0.25, 0.22, 0.20), dark)

func _make_world() -> void:
	super._make_world()
	camera.position = Vector3(0.06, -0.28, 8.15)
	camera.rotation_degrees = Vector3(-1.0, -0.35, -0.08)
	camera.fov = 66.0

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
					control.text = "VORTEX // RUNNER 2.0 // REVIEW"
