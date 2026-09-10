extends Node

static func decorate(host: Node3D, ship_visual: Node3D, make_box: Callable, make_cylinder: Callable, make_mat: Callable) -> void:
	var graphite: Material = make_mat.call(Color(0.055, 0.065, 0.09), Color(0.01, 0.015, 0.025), 0.08, 0.92, 0.15)
	var titanium: Material = make_mat.call(Color(0.58, 0.64, 0.72), Color(0.02, 0.025, 0.04), 0.18, 0.74, 0.16)
	var red: Material = make_mat.call(Color(0.66, 0.055, 0.16), Color(0.42, 0.01, 0.06), 1.25, 0.65, 0.14)
	var cyan: Material = make_mat.call(Color(0.08, 0.88, 1.0), Color(0.0, 0.74, 1.0), 7.0, 0.15, 0.06)
	var amber: Material = make_mat.call(Color(1.0, 0.38, 0.05), Color(1.0, 0.16, 0.01), 6.0, 0.1, 0.08)

	# Raised center spine, rear shoulder armor and layered wing roots.
	make_box.call(ship_visual, Vector3(0.0, 0.19, -0.42), Vector3(0.28, 0.10, 1.65), titanium, Vector3.ZERO)
	make_box.call(ship_visual, Vector3(0.0, 0.25, -0.78), Vector3(0.09, 0.055, 0.82), cyan, Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		make_box.call(ship_visual, Vector3(side * 0.72, 0.08, 0.34), Vector3(0.62, 0.13, 0.70), graphite, Vector3(0.0, 0.0, side * 17.0))
		make_box.call(ship_visual, Vector3(side * 1.34, 0.105, 0.35), Vector3(0.74, 0.08, 0.42), titanium, Vector3(0.0, 0.0, side * 23.0))
		make_box.call(ship_visual, Vector3(side * 1.88, 0.13, 0.52), Vector3(0.54, 0.06, 0.22), red, Vector3(0.0, 0.0, side * 29.0))
		make_box.call(ship_visual, Vector3(side * 2.17, 0.15, 0.66), Vector3(0.28, 0.045, 0.12), cyan, Vector3(0.0, 0.0, side * 31.0))

	# Compact, circular engine hardware. These should read as machinery, not two sticks.
	for x: float in [-0.34, 0.34]:
		make_cylinder.call(ship_visual, Vector3(x, -0.08, 1.29), 0.22, 0.19, graphite, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(x, -0.08, 1.42), 0.17, 0.12, titanium, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(x, -0.08, 1.51), 0.115, 0.08, cyan, Vector3(90.0, 0.0, 0.0))

	# Small warm navigation details break the all-cyan silhouette.
	make_box.call(ship_visual, Vector3(-2.23, 0.14, 0.68), Vector3(0.06, 0.05, 0.11), amber, Vector3.ZERO)
	make_box.call(ship_visual, Vector3(2.23, 0.14, 0.68), Vector3(0.06, 0.05, 0.11), amber, Vector3.ZERO)

	# Local lights follow the craft and reveal its surfaces in every corridor section.
	var key := SpotLight3D.new()
	key.position = Vector3(-1.8, 2.2, 3.1)
	key.rotation_degrees = Vector3(-31.0, -13.0, 0.0)
	key.light_color = Color(0.72, 0.82, 1.0)
	key.light_energy = 4.4
	key.spot_range = 9.0
	key.spot_angle = 44.0
	ship_visual.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, -0.10, 1.65)
	rim.light_color = Color(0.0, 0.72, 1.0)
	rim.light_energy = 3.0
	rim.omni_range = 3.3
	ship_visual.add_child(rim)
