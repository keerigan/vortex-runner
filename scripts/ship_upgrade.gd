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
	var graphite: Material = make_mat.call(Color(0.045, 0.055, 0.078), Color(0.008, 0.012, 0.022), 0.05, 0.94, 0.14)
	var titanium: Material = make_mat.call(Color(0.64, 0.69, 0.77), Color(0.025, 0.03, 0.045), 0.20, 0.78, 0.14)
	var red: Material = make_mat.call(Color(0.74, 0.045, 0.13), Color(0.48, 0.008, 0.035), 1.35, 0.70, 0.12)
	var cyan: Material = make_mat.call(Color(0.10, 0.90, 1.0), Color(0.0, 0.76, 1.0), 7.4, 0.15, 0.05)
	var glass: Material = make_mat.call(Color(0.025, 0.10, 0.16), Color(0.0, 0.24, 0.42), 2.2, 0.82, 0.05)
	var amber: Material = make_mat.call(Color(1.0, 0.38, 0.05), Color(1.0, 0.16, 0.01), 5.5, 0.1, 0.08)

	# A strongly faceted fuselage placed above the imported base mesh.
	_prism(ship_visual, Vector3(0.0, 0.20, -0.70), 0.78, 0.44, 2.55, graphite)
	_prism(ship_visual, Vector3(0.0, 0.39, -1.05), 0.52, 0.28, 1.34, titanium)
	_prism(ship_visual, Vector3(0.0, 0.51, -0.84), 0.38, 0.24, 0.96, glass)
	_prism(ship_visual, Vector3(0.0, 0.31, -2.02), 0.28, 0.22, 0.72, red)
	make_box.call(ship_visual, Vector3(0.0, 0.49, -1.72), Vector3(0.07, 0.05, 0.58), cyan, Vector3.ZERO)

	# Swept blade wings: narrower roots, thick enough to catch light, sharply angled tips.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.86, 0.11, 0.05), 1.35, 0.20, 1.55, graphite, Vector3(0.0, side * -9.0, side * 17.0))
		_prism(ship_visual, Vector3(side * 1.58, 0.13, 0.34), 1.05, 0.16, 1.02, red, Vector3(0.0, side * -12.0, side * 25.0))
		_prism(ship_visual, Vector3(side * 2.13, 0.15, 0.52), 0.72, 0.11, 0.62, titanium, Vector3(0.0, side * -16.0, side * 32.0))
		make_box.call(ship_visual, Vector3(side * 1.56, 0.22, 0.13), Vector3(0.48, 0.045, 0.10), cyan, Vector3(0.0, side * -9.0, side * 25.0))
		make_box.call(ship_visual, Vector3(side * 2.36, 0.17, 0.68), Vector3(0.08, 0.055, 0.18), amber, Vector3.ZERO)

	# Engine cluster with mechanical rings and a central red heat glow.
	for x: float in [-0.34, 0.34]:
		make_cylinder.call(ship_visual, Vector3(x, -0.07, 1.22), 0.24, 0.22, graphite, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(x, -0.07, 1.36), 0.19, 0.10, titanium, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(x, -0.07, 1.44), 0.13, 0.075, cyan, Vector3(90.0, 0.0, 0.0))
	make_box.call(ship_visual, Vector3(0.0, -0.03, 1.16), Vector3(0.16, 0.10, 0.36), red, Vector3.ZERO)

	# Strong local lighting so the craft never returns to a black silhouette.
	var key := SpotLight3D.new()
	key.position = Vector3(-1.3, 2.7, 3.2)
	key.rotation_degrees = Vector3(-34.0, -10.0, 0.0)
	key.light_color = Color(0.80, 0.86, 1.0)
	key.light_energy = 6.5
	key.spot_range = 10.0
	key.spot_angle = 50.0
	ship_visual.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 0.12, 1.45)
	rim.light_color = Color(0.0, 0.72, 1.0)
	rim.light_energy = 3.4
	rim.omni_range = 3.5
	ship_visual.add_child(rim)
