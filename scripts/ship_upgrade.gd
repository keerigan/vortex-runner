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
	var graphite: Material = make_mat.call(Color(0.032, 0.038, 0.055), Color(0.004, 0.006, 0.012), 0.03, 0.96, 0.12)
	var titanium: Material = make_mat.call(Color(0.64, 0.69, 0.77), Color(0.025, 0.03, 0.045), 0.18, 0.78, 0.14)
	var white: Material = make_mat.call(Color(0.86, 0.89, 0.94), Color(0.035, 0.04, 0.06), 0.20, 0.52, 0.12)
	var pink: Material = make_mat.call(Color(0.92, 0.07, 0.31), Color(0.74, 0.015, 0.18), 1.8, 0.60, 0.10)
	var cyan: Material = make_mat.call(Color(0.14, 0.94, 1.0), Color(0.0, 0.82, 1.0), 7.2, 0.12, 0.04)
	var glass: Material = make_mat.call(Color(0.02, 0.12, 0.20), Color(0.0, 0.32, 0.58), 2.4, 0.84, 0.04)
	var hot: Material = make_mat.call(Color(0.92, 0.96, 1.0), Color(0.08, 0.72, 1.0), 10.0, 0.08, 0.03)
	var amber: Material = make_mat.call(Color(1.0, 0.42, 0.06), Color(1.0, 0.18, 0.01), 4.8, 0.08, 0.06)

	# Narrow fuselage with layered white armor so the body reads before the engine.
	_prism(ship_visual, Vector3(0.0, 0.20, -0.82), 0.78, 0.48, 2.28, graphite)
	_prism(ship_visual, Vector3(0.0, 0.39, -1.18), 0.52, 0.26, 1.06, white)
	_sphere(ship_visual, Vector3(0.0, 0.49, -0.83), 0.31, glass, Vector3(0.76, 0.56, 1.18))
	_prism(ship_visual, Vector3(0.0, 0.25, -1.93), 0.22, 0.17, 0.72, pink)
	make_box.call(ship_visual, Vector3(0.0, 0.46, -1.57), Vector3(0.07, 0.042, 0.44), cyan, Vector3.ZERO)

	# Shorter, broader swept wings with white armor over pink structural panels.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.72, 0.10, -0.03), 1.08, 0.18, 1.30, graphite, Vector3(0.0, side * -14.0, side * 22.0))
		_prism(ship_visual, Vector3(side * 1.22, 0.13, 0.06), 0.84, 0.14, 0.88, pink, Vector3(0.0, side * -20.0, side * 31.0))
		_prism(ship_visual, Vector3(side * 1.34, 0.22, -0.04), 0.72, 0.08, 0.62, white, Vector3(0.0, side * -18.0, side * 31.0))
		_prism(ship_visual, Vector3(side * 1.70, 0.15, 0.18), 0.54, 0.09, 0.54, titanium, Vector3(0.0, side * -25.0, side * 38.0))
		make_box.call(ship_visual, Vector3(side * 1.38, 0.26, -0.03), Vector3(0.36, 0.042, 0.065), cyan, Vector3(0.0, side * -18.0, side * 32.0))
		make_box.call(ship_visual, Vector3(side * 1.88, 0.16, 0.31), Vector3(0.055, 0.042, 0.10), amber, Vector3.ZERO)

	# Smaller central turbine, now framed by visible rear bodywork rather than dominating the craft.
	_prism(ship_visual, Vector3(0.0, 0.06, 0.72), 0.74, 0.28, 0.78, graphite)
	make_cylinder.call(ship_visual, Vector3(0.0, -0.02, 1.10), 0.35, 0.18, graphite, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.02, 1.23), 0.28, 0.13, white, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.02, 1.33), 0.19, 0.09, cyan, Vector3(90.0, 0.0, 0.0))
	make_cylinder.call(ship_visual, Vector3(0.0, -0.02, 1.40), 0.095, 0.06, hot, Vector3(90.0, 0.0, 0.0))
	for spoke_angle: float in [0.0, 45.0, 90.0, 135.0]:
		make_box.call(ship_visual, Vector3(0.0, -0.018, 1.43), Vector3(0.42, 0.025, 0.025), titanium, Vector3(0.0, 0.0, spoke_angle))
	for side: float in [-1.0, 1.0]:
		make_cylinder.call(ship_visual, Vector3(side * 0.42, -0.07, 1.10), 0.12, 0.14, graphite, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.42, -0.07, 1.21), 0.072, 0.07, cyan, Vector3(90.0, 0.0, 0.0))

	_prism(ship_visual, Vector3(0.0, -0.02, 1.62), 0.16, 0.10, 0.38, hot)

	var key := SpotLight3D.new()
	key.position = Vector3(-1.2, 2.5, 3.0)
	key.rotation_degrees = Vector3(-33.0, -8.0, 0.0)
	key.light_color = Color(0.92, 0.94, 1.0)
	key.light_energy = 7.0
	key.spot_range = 10.0
	key.spot_angle = 48.0
	ship_visual.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 0.05, 1.28)
	rim.light_color = Color(0.0, 0.74, 1.0)
	rim.light_energy = 3.4
	rim.omni_range = 3.3
	ship_visual.add_child(rim)
