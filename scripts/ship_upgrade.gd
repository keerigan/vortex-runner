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

static func decorate(host: Node3D, ship_visual: Node3D, make_box: Callable, make_cylinder: Callable, make_mat: Callable) -> void:
	var graphite: Material = make_mat.call(Color(0.030, 0.036, 0.052), Color(0.004, 0.006, 0.012), 0.03, 0.96, 0.12)
	var titanium: Material = make_mat.call(Color(0.58, 0.64, 0.73), Color(0.020, 0.028, 0.045), 0.16, 0.76, 0.16)
	var white: Material = make_mat.call(Color(0.88, 0.91, 0.96), Color(0.035, 0.045, 0.065), 0.20, 0.48, 0.10)
	var red: Material = make_mat.call(Color(0.84, 0.045, 0.16), Color(0.56, 0.010, 0.06), 1.45, 0.62, 0.10)
	var cyan: Material = make_mat.call(Color(0.12, 0.94, 1.0), Color(0.0, 0.82, 1.0), 7.4, 0.10, 0.04)
	var glass: Material = make_mat.call(Color(0.015, 0.075, 0.12), Color(0.0, 0.16, 0.30), 1.3, 0.82, 0.04)
	var hot: Material = make_mat.call(Color(0.95, 0.98, 1.0), Color(0.05, 0.78, 1.0), 9.0, 0.08, 0.03)
	var amber: Material = make_mat.call(Color(1.0, 0.40, 0.05), Color(1.0, 0.16, 0.01), 4.2, 0.08, 0.06)

	# Long faceted fuselage: readable nose, cockpit and shoulder mass.
	_prism(ship_visual, Vector3(0.0, 0.08, -0.62), 0.72, 0.38, 2.95, graphite)
	_prism(ship_visual, Vector3(0.0, 0.25, -1.22), 0.50, 0.22, 1.45, white)
	_prism(ship_visual, Vector3(0.0, 0.37, -1.18), 0.34, 0.18, 0.92, glass)
	_prism(ship_visual, Vector3(0.0, 0.10, -2.05), 0.20, 0.14, 0.82, red)
	make_box.call(ship_visual, Vector3(0.0, 0.39, -1.75), Vector3(0.055, 0.035, 0.48), cyan, Vector3.ZERO)

	# Swept layered wings: dark structure, white armor, red undersurface and cyan edge light.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.70, 0.02, -0.10), 1.15, 0.18, 1.58, graphite, Vector3(0.0, side * -15.0, side * 19.0))
		_prism(ship_visual, Vector3(side * 1.18, 0.10, 0.04), 0.82, 0.12, 1.02, white, Vector3(0.0, side * -19.0, side * 28.0))
		_prism(ship_visual, Vector3(side * 1.50, 0.04, 0.18), 0.68, 0.10, 0.82, red, Vector3(0.0, side * -23.0, side * 34.0))
		_prism(ship_visual, Vector3(side * 1.83, 0.08, 0.34), 0.46, 0.08, 0.56, titanium, Vector3(0.0, side * -28.0, side * 40.0))
		make_box.call(ship_visual, Vector3(side * 1.36, 0.18, 0.02), Vector3(0.42, 0.035, 0.055), cyan, Vector3(0.0, side * -18.0, side * 31.0))
		make_box.call(ship_visual, Vector3(side * 1.98, 0.08, 0.40), Vector3(0.05, 0.035, 0.09), amber, Vector3.ZERO)

	# Twin engine pods. No oversized central glowing wheel.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.36, -0.05, 0.92), 0.34, 0.30, 0.82, graphite)
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.32), 0.18, 0.18, titanium, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.44), 0.125, 0.10, cyan, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.51), 0.075, 0.06, hot, Vector3(90.0, 0.0, 0.0))
	# Rear spine and stabilizers tie the engines into the hull.
	_prism(ship_visual, Vector3(0.0, 0.05, 0.76), 0.30, 0.18, 0.92, white)
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.56, 0.20, 0.62), 0.18, 0.42, 0.72, graphite, Vector3(side * -8.0, 0.0, side * 12.0))

	var key := SpotLight3D.new()
	key.position = Vector3(-1.0, 2.3, 2.8)
	key.rotation_degrees = Vector3(-31.0, -7.0, 0.0)
	key.light_color = Color(0.92, 0.95, 1.0)
	key.light_energy = 6.0
	key.spot_range = 9.0
	key.spot_angle = 50.0
	ship_visual.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 0.02, 1.38)
	rim.light_color = Color(0.0, 0.72, 1.0)
	rim.light_energy = 2.8
	rim.omni_range = 3.0
	ship_visual.add_child(rim)
