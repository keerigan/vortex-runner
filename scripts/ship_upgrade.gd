extends Node

static func _prism(parent: Node3D, pos: Vector3, width: float, height: float, length: float, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-width * 0.5, -height * 0.5, -length * 0.5)
	var b := Vector3(width * 0.5, -height * 0.5, -length * 0.5)
	var c := Vector3(0.0, height * 0.5, -length * 0.5)
	var d := Vector3(-width * 0.5, -height * 0.5, length * 0.5)
	var e := Vector3(width * 0.5, -height * 0.5, length * 0.5)
	var f := Vector3(0.0, height * 0.5, length * 0.5)
	for v in [a,c,b,d,e,f,a,d,f,a,f,c,b,c,f,b,f,e,a,b,e,a,e,d]:
		st.set_material(material)
		st.add_vertex(v)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.position = pos
	node.rotation_degrees = rot
	parent.add_child(node)
	return node

static func _sphere(parent: Node3D, pos: Vector3, radius: float, material: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = material
	parent.add_child(node)
	return node

static func decorate(host: Node3D, ship_visual: Node3D, make_box: Callable, make_cylinder: Callable, make_mat: Callable) -> void:
	var graphite: Material = make_mat.call(Color(0.035, 0.040, 0.060), Color(0.004, 0.006, 0.012), 0.03, 0.96, 0.12)
	var titanium: Material = make_mat.call(Color(0.72, 0.76, 0.82), Color(0.035, 0.04, 0.055), 0.18, 0.76, 0.12)
	var pink: Material = make_mat.call(Color(0.92, 0.08, 0.33), Color(0.74, 0.015, 0.18), 1.9, 0.60, 0.10)
	var cyan: Material = make_mat.call(Color(0.14, 0.94, 1.0), Color(0.0, 0.82, 1.0), 8.0, 0.12, 0.04)
	var glass: Material = make_mat.call(Color(0.02, 0.12, 0.20), Color(0.0, 0.32, 0.58), 2.8, 0.84, 0.04)
	var hot: Material = make_mat.call(Color(0.92, 0.96, 1.0), Color(0.08, 0.72, 1.0), 11.0, 0.08, 0.03)
	var amber: Material = make_mat.call(Color(1.0, 0.42, 0.06), Color(1.0, 0.18, 0.01), 5.0, 0.08, 0.06)

	# Compact arrowhead fuselage. The visual center is intentionally raised and bright.
	_prism(ship_visual, Vector3(0.0, 0.20, -0.82), 0.86, 0.50, 2.25, graphite)
	_prism(ship_visual, Vector3(0.0, 0.40, -1.20), 0.54, 0.28, 1.10, titanium)
	_sphere(ship_visual, Vector3(0.0, 0.50, -0.82), 0.34, glass, Vector3(0.78, 0.58, 1.18))
	_prism(ship_visual, Vector3(0.0, 0.25, -1.95), 0.22, 0.18, 0.74, pink)
	make_box.call(ship_visual, Vector3(0.0, 0.48, -1.58), Vector3(0.075, 0.045, 0.46), cyan, Vector3.ZERO)

	# Swept delta wings, closer to the reference craft than the previous long cross shape.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.78, 0.10, -0.02), 1.20, 0.18, 1.36, graphite, Vector3(0.0, side * -14.0, side * 22.0))
		_prism(ship_visual, Vector3(side * 1.38, 0.14, 0.10), 0.95, 0.14, 0.92, pink, Vector3(0.0, side * -20.0, side * 33.0))
		_prism(ship_visual, Vector3(side * 1.86, 0.16, 0.21), 0.62, 0.09, 0.58, titanium, Vector3(0.0, side * -25.0, side * 39.0))
		make_box.call(ship_visual, Vector3(side * 1.44, 0.23, -0.02), Vector3(0.52, 0.045, 0.075), cyan, Vector3(0.0, side * -18.0, side * 34.0))
		make_box.call(ship_visual, Vector3(side * 2.07, 0.16, 0.35), Vector3(0.06, 0.045, 0.12), amber, Vector3.ZERO)

	# One large rear turbine is the focal point; two compact auxiliaries sit beside it.
	make_cylinder.call(ship_visual, Vector3(0.0, -0.03, 1.14), 0.46, 0.20, graphite, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.03, 1.28), 0.36, 0.14, titanium, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.03, 1.39), 0.25, 0.10, cyan, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.03, 1.47), 0.13, 0.07, hot, Vector3(90.0, 0.0, 0.0))
	for spoke_angle: float in [0.0, 45.0, 90.0, 135.0]:
		make_box.call(ship_visual, Vector3(0.0, -0.025, 1.51), Vector3(0.57, 0.035, 0.035), titanium, Vector3(0.0, 0.0, spoke_angle))
	for side: float in [-1.0, 1.0]:
		make_cylinder.call(ship_visual, Vector3(side * 0.48, -0.08, 1.18), 0.14, 0.16, graphite, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.48, -0.08, 1.30), 0.085, 0.08, cyan, Vector3(90.0, 0.0, 0.0))

	# Short exhaust glow only; no long cyan sticks.
	_prism(ship_visual, Vector3(0.0, -0.03, 1.72), 0.20, 0.12, 0.46, hot)

	var key := SpotLight3D.new()
	key.position = Vector3(-1.2, 2.5, 3.0)
	key.rotation_degrees = Vector3(-33.0, -8.0, 0.0)
	key.light_color = Color(0.88, 0.91, 1.0)
	key.light_energy = 7.2
	key.spot_range = 10.0
	key.spot_angle = 48.0
	ship_visual.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 0.05, 1.36)
	rim.light_color = Color(0.0, 0.74, 1.0)
	rim.light_energy = 3.8
	rim.omni_range = 3.6
	ship_visual.add_child(rim)
