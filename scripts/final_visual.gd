extends "res://scripts/visual_ship_hook.gd"

func _build_camera_canopy() -> void:
	# Keep the portrait frame enclosed without stacking horizontal bars across the image.
	var shell := Node3D.new()
	shell.name = "CameraCanopy"
	add_child(shell)
	var dark := _mat(Color(0.024, 0.029, 0.043), Color(0.004, 0.005, 0.012), 0.03, 0.90, 0.20)
	var gunmetal := _mat(Color(0.085, 0.100, 0.135), Color(0.006, 0.008, 0.015), 0.05, 0.86, 0.20)
	var steel := _mat(Color(0.34, 0.38, 0.46), Color(0.018, 0.022, 0.038), 0.10, 0.72, 0.19)
	var cyan := _mat(Color(0.12, 0.88, 1.0), Color(0.0, 0.72, 1.0), 3.0, 0.12, 0.06)

	# Continuous dark roof with long recessed channels: perspective lines, not a ladder.
	_box(shell, Vector3(0.0, 2.20, 5.0), Vector3(9.4, 0.34, 10.8), dark)
	for x: float in [-3.55, -1.80, 0.0, 1.80, 3.55]:
		_box(shell, Vector3(x, 1.96, 5.0), Vector3(1.02, 0.15, 10.0), gunmetal)

	# Pipe bundles run into the vanishing point like the target corridor ceiling.
	for x: float in [-3.12, -2.86, -2.60, 2.60, 2.86, 3.12]:
		_cylinder(shell, Vector3(x, 1.66, 5.0), 0.075, 9.0, steel, Vector3(90.0, 0.0, 0.0))

	# Two thin luminous rails provide the signature cyan ceiling lines.
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 3.78, 1.58, 4.6), Vector3(0.060, 0.050, 7.6), cyan)
		# Angled structural shoulder at the edge, leaving the central view open.
		_box(shell, Vector3(side * 4.12, 1.22, 5.8), Vector3(0.20, 1.15, 3.0), steel, Vector3(0.0, 0.0, side * 12.0))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 1.9 // CANDIDATE"
