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
	# The base hull is intentionally medium graphite, not near-black: the player's craft
	# must keep a readable silhouette even between the corridor's neon light zones.
	var graphite: Material = make_mat.call(Color(0.12, 0.14, 0.20), Color(0.018, 0.025, 0.045), 0.18, 0.84, 0.16)
	var titanium: Material = make_mat.call(Color(0.66, 0.71, 0.80), Color(0.035, 0.045, 0.070), 0.30, 0.68, 0.14)
	var white: Material = make_mat.call(Color(0.92, 0.94, 0.98), Color(0.09, 0.11, 0.16), 0.55, 0.38, 0.09)
	var red: Material = make_mat.call(Color(0.88, 0.055, 0.16), Color(0.62, 0.012, 0.06), 1.65, 0.56, 0.09)
	var cyan: Material = make_mat.call(Color(0.12, 0.94, 1.0), Color(0.0, 0.82, 1.0), 7.4, 0.10, 0.04)
	var glass: Material = make_mat.call(Color(0.035, 0.16, 0.24), Color(0.0, 0.34, 0.56), 2.2, 0.70, 0.04)
	var hot: Material = make_mat.call(Color(0.95, 0.98, 1.0), Color(0.05, 0.78, 1.0), 9.0, 0.08, 0.03)
	var amber: Material = make_mat.call(Color(1.0, 0.40, 0.05), Color(1.0, 0.16, 0.01), 4.2, 0.08, 0.06)

	# Long faceted fuselage with a bright dorsal armor spine.
	_prism(ship_visual, Vector3(0.0, 0.08, -0.62), 0.72, 0.38, 2.95, graphite)
	_prism(ship_visual, Vector3(0.0, 0.27, -1.20), 0.54, 0.20, 1.52, white)
	_prism(ship_visual, Vector3(0.0, 0.40, -1.16), 0.35, 0.18, 0.96, glass)
	_prism(ship_visual, Vector3(0.0, 0.17, -0.18), 0.48, 0.12, 1.08, titanium)
	_prism(ship_visual, Vector3(0.0, 0.10, -2.05), 0.20, 0.14, 0.82, red)
	make_box.call(ship_visual, Vector3(0.0, 0.42, -1.73), Vector3(0.06, 0.04, 0.52), cyan, Vector3.ZERO)

	# Swept layered wings. The white/titanium top plates are deliberately broad so the
	# shape reads as a fighter instead of two black triangles around glowing engines.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.70, 0.02, -0.10), 1.15, 0.18, 1.58, graphite, Vector3(0.0, side * -15.0, side * 19.0))
		_prism(ship_visual, Vector3(side * 0.98, 0.16, -0.10), 0.88, 0.11, 1.20, titanium, Vector3(0.0, side * -17.0, side * 24.0))
		_prism(ship_visual, Vector3(side * 1.25, 0.19, 0.00), 0.72, 0.10, 0.94, white, Vector3(0.0, side * -20.0, side * 30.0))
		_prism(ship_visual, Vector3(side * 1.54, 0.06, 0.18), 0.62, 0.10, 0.78, red, Vector3(0.0, side * -23.0, side * 34.0))
		_prism(ship_visual, Vector3(side * 1.84, 0.10, 0.34), 0.44, 0.08, 0.54, titanium, Vector3(0.0, side * -28.0, side * 40.0))
		make_box.call(ship_visual, Vector3(side * 1.34, 0.23, -0.02), Vector3(0.46, 0.035, 0.055), cyan, Vector3(0.0, side * -18.0, side * 31.0))
		make_box.call(ship_visual, Vector3(side * 1.99, 0.10, 0.40), Vector3(0.05, 0.035, 0.09), amber, Vector3.ZERO)

	# Twin engine pods, integrated into light upper armor.
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.36, -0.05, 0.92), 0.34, 0.30, 0.82, graphite)
		_prism(ship_visual, Vector3(side * 0.36, 0.12, 0.92), 0.27, 0.10, 0.62, titanium)
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.32), 0.18, 0.18, white, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.44), 0.125, 0.10, cyan, Vector3(90.0, 0.0, 0.0))
		make_cylinder.call(ship_visual, Vector3(side * 0.36, -0.06, 1.51), 0.075, 0.06, hot, Vector3(90.0, 0.0, 0.0))
	_prism(ship_visual, Vector3(0.0, 0.09, 0.76), 0.32, 0.20, 0.92, white)
	for side: float in [-1.0, 1.0]:
		_prism(ship_visual, Vector3(side * 0.56, 0.22, 0.62), 0.18, 0.42, 0.72, titanium, Vector3(side * -8.0, 0.0, side * 12.0))

	# Neutral lighting is attached to the craft so gameplay lighting cannot swallow it.
	var key := SpotLight3D.new()
	key.position = Vector3(-0.8, 2.5, 2.6)
	key.rotation_degrees = Vector3(-34.0, -6.0, 0.0)
	key.light_color = Color(0.98, 0.98, 1.0)
	key.light_energy = 8.2
	key.spot_range = 9.5
	key.spot_angle = 55.0
	ship_visual.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.3, 1.0, 1.4)
	fill.light_color = Color(0.38, 0.62, 1.0)
	fill.light_energy = 4.0
	fill.omni_range = 4.0
	ship_visual.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 0.02, 1.38)
	rim.light_color = Color(0.0, 0.72, 1.0)
	rim.light_energy = 2.8
	rim.omni_range = 3.0
	ship_visual.add_child(rim)
