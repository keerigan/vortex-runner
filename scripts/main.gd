extends Node3D

const SECTION_COUNT := 24
const SECTION_LENGTH := 6.4
const CORRIDOR_HALF_WIDTH := 5.4
const CORRIDOR_HALF_HEIGHT := 5.0
const OBSTACLE_COUNT := 10
const JOYSTICK_RADIUS := 165.0
const JOYSTICK_DEADZONE := 0.24
const JOYSTICK_SPEED := 4.2

var speed: float = 13.0
var max_speed: float = 60.0
var acceleration: float = 0.62
var score: float = 0.0
var alive: bool = true
var elapsed: float = 0.0

var ship: CharacterBody3D
var ship_visual: Node3D
var camera: Camera3D
var corridor_root: Node3D
var obstacle_root: Node3D
var streak_root: Node3D
var ui_label: Label
var game_over_label: Label
var joystick_root: Control
var joystick_knob: Polygon2D
var engines: Array[MeshInstance3D] = []
var engine_trails: Array[MeshInstance3D] = []
var pointer_active: bool = false
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO

func _ready() -> void:
	randomize()
	_make_world()
	_spawn_corridor()
	_spawn_speed_streaks()
	_spawn_obstacles()

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, metallic: float = 0.0, roughness: float = 0.25) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rotation
	node.material_override = material
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3(90.0, 0.0, 0.0)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rotation
	node.material_override = material
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _make_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.001, 0.001, 0.006)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.09, 0.11, 0.22)
	environment.ambient_light_energy = 1.35
	environment.glow_enabled = true
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34.0, -18.0, 0.0)
	key_light.light_color = Color(0.48, 0.62, 1.0)
	key_light.light_energy = 2.6
	add_child(key_light)

	var cyan_light := OmniLight3D.new()
	cyan_light.position = Vector3(-2.8, 2.1, 3.8)
	cyan_light.light_color = Color(0.0, 0.72, 1.0)
	cyan_light.light_energy = 4.2
	cyan_light.omni_range = 8.0
	add_child(cyan_light)

	var violet_light := OmniLight3D.new()
	violet_light.position = Vector3(3.0, -0.8, 0.5)
	violet_light.light_color = Color(0.68, 0.16, 1.0)
	violet_light.light_energy = 3.4
	violet_light.omni_range = 7.0
	add_child(violet_light)

	ship = CharacterBody3D.new()
	ship.position = Vector3(0.0, -1.55, 2.0)
	add_child(ship)
	_add_ship_collisions()

	ship_visual = Node3D.new()
	ship_visual.rotation_degrees.x = -7.0
	ship.add_child(ship_visual)
	_build_ship()

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.7, 9.5)
	camera.rotation_degrees = Vector3(-10.5, 0.0, 0.0)
	camera.fov = 68.0
	add_child(camera)
	camera.current = true

	corridor_root = Node3D.new()
	add_child(corridor_root)
	obstacle_root = Node3D.new()
	add_child(obstacle_root)
	streak_root = Node3D.new()
	add_child(streak_root)
	_make_ui()

func _add_ship_collisions() -> void:
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(0.66, 0.38, 1.55)
	body_shape.shape = body_box
	body_shape.position = Vector3(0.0, 0.0, -0.2)
	ship.add_child(body_shape)

	for side: float in [-1.0, 1.0]:
		var wing_shape := CollisionShape3D.new()
		var wing_box := BoxShape3D.new()
		wing_box.size = Vector3(0.92, 0.16, 0.72)
		wing_shape.shape = wing_box
		wing_shape.position = Vector3(side * 0.72, -0.02, 0.26)
		wing_shape.rotation_degrees.z = side * 12.0
		ship.add_child(wing_shape)

func _build_ship() -> void:
	var hull := _mat(Color(0.025, 0.035, 0.07), Color(0.0, 0.02, 0.07), 0.8, 0.95, 0.14)
	var armor := _mat(Color(0.17, 0.055, 0.22), Color(0.15, 0.01, 0.20), 1.4, 0.82, 0.18)
	var armor_light := _mat(Color(0.33, 0.08, 0.39), Color(0.26, 0.02, 0.34), 1.6, 0.72, 0.20)
	var white_panel := _mat(Color(0.74, 0.80, 0.88), Color(0.05, 0.14, 0.20), 0.7, 0.62, 0.18)
	var cyan := _mat(Color(0.16, 0.92, 1.0), Color(0.0, 0.82, 1.0), 7.5, 0.25, 0.08)
	var glass := _mat(Color(0.008, 0.018, 0.05), Color(0.0, 0.18, 0.42), 2.4, 0.85, 0.05)
	var flame := _mat(Color(0.82, 0.97, 1.0), Color(0.02, 0.76, 1.0), 11.0, 0.0, 0.04)

	_box(ship_visual, Vector3(0.0, -0.02, -0.05), Vector3(0.72, 0.36, 2.65), hull)
	_box(ship_visual, Vector3(0.0, 0.12, -1.26), Vector3(0.44, 0.25, 0.72), armor)
	_sphere(ship_visual, Vector3(0.0, 0.22, -0.40), 0.34, glass)
	_box(ship_visual, Vector3(0.0, 0.08, -1.64), Vector3(0.16, 0.12, 0.38), cyan)

	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side * 0.72, -0.04, 0.04), Vector3(1.28, 0.14, 1.60), armor, Vector3(0.0, 0.0, side * 13.0))
		_box(ship_visual, Vector3(side * 1.30, -0.04, 0.44), Vector3(0.72, 0.11, 1.12), white_panel, Vector3(0.0, 0.0, side * 25.0))
		_box(ship_visual, Vector3(side * 1.65, -0.04, 0.72), Vector3(0.52, 0.08, 0.82), armor_light, Vector3(0.0, 0.0, side * 31.0))
		_box(ship_visual, Vector3(side * 1.54, 0.02, 0.47), Vector3(0.42, 0.055, 0.70), cyan, Vector3(0.0, 0.0, side * 25.0))
		_box(ship_visual, Vector3(side * 1.91, -0.01, 0.93), Vector3(0.11, 0.16, 0.54), cyan, Vector3(0.0, 0.0, side * 30.0))

	_box(ship_visual, Vector3(0.0, 0.14, 0.44), Vector3(0.08, 0.05, 0.72), cyan)

	for x: float in [-0.37, 0.37]:
		_cylinder(ship_visual, Vector3(x, -0.10, 1.30), 0.19, 0.44, hull)
		_cylinder(ship_visual, Vector3(x, -0.10, 1.62), 0.14, 0.26, white_panel)
		engines.append(_cylinder(ship_visual, Vector3(x, -0.10, 1.88), 0.10, 0.58, flame))
		engine_trails.append(_box(ship_visual, Vector3(x, -0.10, 2.88), Vector3(0.09, 0.07, 2.20), flame))
		engine_trails.append(_box(ship_visual, Vector3(x, -0.10, 3.72), Vector3(0.035, 0.03, 2.45), cyan))

func _spawn_corridor() -> void:
	for i in range(SECTION_COUNT):
		var section := Node3D.new()
		section.position.z = -float(i) * SECTION_LENGTH
		section.set_meta("index", i)
		corridor_root.add_child(section)
		_build_corridor_section(section, i)

func _build_corridor_section(section: Node3D, index: int) -> void:
	var floor_mat := _mat(Color(0.09, 0.07, 0.13), Color(0.08, 0.03, 0.14), 0.5, 0.72, 0.26)
	var wall_mat := _mat(Color(0.035, 0.035, 0.075), Color(0.02, 0.02, 0.08), 0.5, 0.82, 0.22)
	var panel_mat := _mat(Color(0.10, 0.08, 0.18), Color(0.08, 0.025, 0.16), 0.7, 0.76, 0.24)
	var dark_mat := _mat(Color(0.012, 0.012, 0.025), Color.BLACK, 0.0, 0.9, 0.20)
	var cyan := _mat(Color(0.15, 0.90, 1.0), Color(0.0, 0.82, 1.0), 7.0, 0.25, 0.10)
	var violet := _mat(Color(0.45, 0.12, 0.78), Color(0.56, 0.08, 1.0), 4.0, 0.28, 0.12)
	var pipe_mat := _mat(Color(0.15, 0.16, 0.22), Color(0.03, 0.04, 0.08), 0.4, 0.78, 0.22)

	# Floor with a dark central racing channel and raised side platforms.
	_box(section, Vector3(0.0, -CORRIDOR_HALF_HEIGHT, 0.0), Vector3(10.8, 0.35, SECTION_LENGTH), floor_mat)
	_box(section, Vector3(0.0, -4.78, 0.0), Vector3(2.1, 0.08, SECTION_LENGTH * 0.96), dark_mat)
	_box(section, Vector3(-3.75, -4.68, 0.0), Vector3(2.0, 0.22, SECTION_LENGTH * 0.94), panel_mat)
	_box(section, Vector3(3.75, -4.68, 0.0), Vector3(2.0, 0.22, SECTION_LENGTH * 0.94), panel_mat)

	# Side walls: layered blocks rather than a flat tube.
	for side: float in [-1.0, 1.0]:
		_box(section, Vector3(side * 5.25, -0.35, 0.0), Vector3(0.36, 9.2, SECTION_LENGTH), wall_mat)
		_box(section, Vector3(side * 4.88, -3.40, 0.0), Vector3(0.58, 2.0, SECTION_LENGTH * 0.88), panel_mat, Vector3(0.0, 0.0, side * 12.0))
		_box(section, Vector3(side * 4.88, 3.20, 0.0), Vector3(0.52, 2.2, SECTION_LENGTH * 0.88), panel_mat, Vector3(0.0, 0.0, side * -12.0))

		# Machinery cabinets and ribs inspired by the reference screenshot.
		if index % 2 == 0:
			for k in range(2):
				var z_pos := -1.55 + float(k) * 3.1
				_box(section, Vector3(side * 4.48, -3.45, z_pos), Vector3(0.62, 1.05, 1.25), wall_mat)
				_box(section, Vector3(side * 4.12, -3.10, z_pos), Vector3(0.18, 0.42, 0.74), cyan if (index + k) % 4 == 0 else violet)

		# Long cyan guide rails along both walls.
		_box(section, Vector3(side * 4.98, 1.55, 0.0), Vector3(0.10, 0.10, SECTION_LENGTH * 0.96), cyan)
		_box(section, Vector3(side * 4.84, -1.35, 0.0), Vector3(0.07, 0.07, SECTION_LENGTH * 0.96), cyan)

	# Ceiling structure and pipes.
	_box(section, Vector3(0.0, CORRIDOR_HALF_HEIGHT, 0.0), Vector3(10.8, 0.34, SECTION_LENGTH), wall_mat)
	_box(section, Vector3(0.0, 4.70, 0.0), Vector3(5.2, 0.14, SECTION_LENGTH * 0.95), dark_mat)
	for pipe_x: float in [-2.4, -2.0, 2.0, 2.4]:
		_cylinder(section, Vector3(pipe_x, 4.53, 0.0), 0.10, SECTION_LENGTH * 0.94, pipe_mat, Vector3(90.0, 0.0, 0.0))

	# Repeated structural arch. Gives a strong tunnel silhouette.
	if index % 3 == 0:
		_box(section, Vector3(-4.35, 0.0, -2.8), Vector3(0.32, 8.6, 0.34), panel_mat, Vector3(0.0, 0.0, -8.0))
		_box(section, Vector3(4.35, 0.0, -2.8), Vector3(0.32, 8.6, 0.34), panel_mat, Vector3(0.0, 0.0, 8.0))
		_box(section, Vector3(0.0, 4.05, -2.8), Vector3(8.0, 0.30, 0.34), panel_mat)
		_box(section, Vector3(0.0, 3.82, -2.60), Vector3(7.4, 0.07, 0.08), cyan)

	# Accent pools of purple light made with emissive geometry.
	if index % 4 == 1:
		_box(section, Vector3(3.85, -4.48, -1.8), Vector3(1.4, 0.05, 2.2), violet)
	if index % 4 == 3:
		_box(section, Vector3(-3.85, -4.48, 1.4), Vector3(1.4, 0.05, 2.2), violet)

func _spawn_speed_streaks() -> void:
	var material := _mat(Color(0.03, 0.24, 0.34), Color(0.0, 0.56, 0.85), 3.5)
	for i in range(42):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.022, 0.022, randf_range(1.2, 4.2))
		streak.mesh = mesh
		streak.position = Vector3(randf_range(-4.4, 4.4), randf_range(-3.8, 4.0), randf_range(-140.0, -8.0))
		streak.material_override = material
		streak_root.add_child(streak)

func _spawn_obstacles() -> void:
	for i in range(OBSTACLE_COUNT):
		var area := _create_obstacle()
		_reset_obstacle(area, -52.0 - float(i) * 22.0)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	obstacle_root.add_child(area)
	var visual := Node3D.new()
	visual.name = "Visual"
	area.add_child(visual)
	var collisions := Node3D.new()
	collisions.name = "Collisions"
	area.add_child(collisions)
	area.body_entered.connect(_hit)
	return area

func _add_obstacle_collision(parent: Node3D, pos: Vector3, size: Vector3, rotation_z: float = 0.0) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	collision.rotation_degrees.z = rotation_z
	parent.add_child(collision)

func _reset_obstacle(area: Area3D, z_position: float) -> void:
	var visual := area.get_node("Visual") as Node3D
	var collisions := area.get_node("Collisions") as Node3D
	for child in visual.get_children():
		child.queue_free()
	for child in collisions.get_children():
		child.queue_free()

	var dark := _mat(Color(0.035, 0.02, 0.03), Color(0.10, 0.01, 0.02), 0.5, 0.78, 0.20)
	var hot := _mat(Color(0.58, 0.06, 0.025), Color(1.0, 0.12, 0.02), 7.5, 0.25, 0.12)
	var amber := _mat(Color(0.42, 0.17, 0.02), Color(1.0, 0.42, 0.02), 5.2, 0.25, 0.12)
	var white := _mat(Color(0.72, 0.76, 0.80), Color(0.12, 0.08, 0.06), 0.8, 0.55, 0.18)
	var obstacle_type := randi_range(0, 3)

	if obstacle_type == 0:
		# Compact reactor wheel.
		_cylinder(visual, Vector3.ZERO, 0.78, 0.64, dark)
		_cylinder(visual, Vector3(0.0, 0.0, 0.36), 0.48, 0.10, white)
		_sphere(visual, Vector3(0.0, 0.0, 0.48), 0.20, hot)
		_add_obstacle_collision(collisions, Vector3.ZERO, Vector3(1.10, 1.10, 0.62))
	elif obstacle_type == 1:
		# Horizontal barricade with real gaps around it.
		_box(visual, Vector3.ZERO, Vector3(2.85, 0.46, 0.72), dark)
		_box(visual, Vector3(0.0, 0.04, 0.40), Vector3(2.55, 0.08, 0.08), hot)
		_box(visual, Vector3(-1.12, 0.0, 0.0), Vector3(0.18, 0.82, 0.30), amber)
		_box(visual, Vector3(1.12, 0.0, 0.0), Vector3(0.18, 0.82, 0.30), amber)
		_add_obstacle_collision(collisions, Vector3.ZERO, Vector3(2.55, 0.35, 0.65))
	elif obstacle_type == 2:
		# Vertical barricade.
		_box(visual, Vector3.ZERO, Vector3(0.46, 2.85, 0.72), dark)
		_box(visual, Vector3(0.04, 0.0, 0.40), Vector3(0.08, 2.55, 0.08), hot)
		_box(visual, Vector3(0.0, -1.12, 0.0), Vector3(0.82, 0.18, 0.30), amber)
		_box(visual, Vector3(0.0, 1.12, 0.0), Vector3(0.82, 0.18, 0.30), amber)
		_add_obstacle_collision(collisions, Vector3.ZERO, Vector3(0.35, 2.55, 0.65))
	else:
		# Spinning four-arm drone. Collision follows each arm, not a giant bounding box.
		_sphere(visual, Vector3.ZERO, 0.28, amber)
		for angle: float in [0.0, 90.0, 180.0, 270.0]:
			_box(visual, Vector3.ZERO, Vector3(1.80, 0.18, 0.24), dark, Vector3(0.0, 0.0, angle))
			_box(visual, Vector3.ZERO, Vector3(1.55, 0.06, 0.08), hot, Vector3(0.0, 0.0, angle))
			_add_obstacle_collision(collisions, Vector3.ZERO, Vector3(1.55, 0.12, 0.52), angle)

	var angle := randf_range(0.0, TAU)
	var radius := randf_range(0.7, 3.45)
	area.position = Vector3(cos(angle) * radius, sin(angle) * radius - 0.3, z_position)
	area.rotation_degrees.z = randf_range(0.0, 360.0)

func _circle_points(radius: float, count: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(34.0, 40.0)
	ui_label.add_theme_font_size_override("font_size", 30)
	ui_label.text = "000000   //   013"
	layer.add_child(ui_label)
	var title := Label.new()
	title.position = Vector2(34.0, 78.0)
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.20, 0.76, 1.0, 0.78)
	title.text = "VORTEX // RUNNER  0.5"
	layer.add_child(title)
	var status := Label.new()
	status.position = Vector2(34.0, 106.0)
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color(0.30, 0.68, 0.90, 0.56)
	status.text = "FLIGHT CORE ONLINE   •   CORRIDOR LINK ACTIVE"
	layer.add_child(status)
	game_over_label = Label.new()
	game_over_label.visible = false
	game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	game_over_label.position = Vector2(-220.0, -100.0)
	game_over_label.size = Vector2(440.0, 200.0)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 40)
	game_over_label.modulate = Color(1.0, 0.52, 0.34, 0.96)
	game_over_label.text = "SIGNAL LOST\nTOUCHE POUR RELANCER"
	layer.add_child(game_over_label)

	joystick_root = Control.new()
	joystick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_root.visible = false
	layer.add_child(joystick_root)
	var base := Polygon2D.new()
	base.polygon = _circle_points(JOYSTICK_RADIUS)
	base.color = Color(0.04, 0.34, 0.58, 0.18)
	joystick_root.add_child(base)
	var inner := Polygon2D.new()
	inner.polygon = _circle_points(JOYSTICK_RADIUS * 0.72)
	inner.color = Color(0.01, 0.02, 0.05, 0.44)
	joystick_root.add_child(inner)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var tick := Polygon2D.new()
		tick.polygon = PackedVector2Array([Vector2(-12.0, -3.0), Vector2(12.0, -3.0), Vector2(12.0, 3.0), Vector2(-12.0, 3.0)])
		tick.position = Vector2(cos(angle), sin(angle)) * 132.0
		tick.rotation = angle
		tick.color = Color(0.16, 0.82, 1.0, 0.56)
		joystick_root.add_child(tick)
	joystick_knob = Polygon2D.new()
	joystick_knob.polygon = _circle_points(43.0)
	joystick_knob.color = Color(0.18, 0.86, 1.0, 0.78)
	joystick_root.add_child(joystick_knob)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	elapsed += delta
	var dynamic_acceleration := acceleration
	if speed > 40.0:
		dynamic_acceleration = 0.34
	if speed > 52.0:
		dynamic_acceleration = 0.18
	speed = minf(max_speed, speed + dynamic_acceleration * delta)
	score += speed * delta
	ui_label.text = "%06d   //   %03d" % [int(score), int(speed)]
	_update_ship(delta)
	_update_camera(delta)
	_update_world(delta)
	_update_engines()

func _update_ship(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	if pointer_active:
		input_vector = joystick_vector

	if input_vector.length() > JOYSTICK_DEADZONE:
		var normalized_strength := clampf((input_vector.length() - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE), 0.0, 1.0)
		var curved_strength := pow(normalized_strength, 1.65)
		var direction := input_vector.normalized()
		var movement := direction * curved_strength * JOYSTICK_SPEED * delta
		ship.position.x += movement.x
		ship.position.y -= movement.y

	ship.position.x = clampf(ship.position.x, -4.25, 4.25)
	ship.position.y = clampf(ship.position.y, -4.00, 3.85)

	var bank_target := clampf(-input_vector.x * 28.0, -32.0, 32.0)
	var pitch_target := clampf(-7.0 + input_vector.y * 10.0, -17.0, 7.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank_target, clampf(delta * 7.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, pitch_target, clampf(delta * 6.5, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target := Vector3(ship.position.x * 0.08, 1.7 + ship.position.y * 0.045, 9.5)
	camera.position = camera.position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
	var speed_ratio := (speed - 13.0) / (max_speed - 13.0)
	camera.fov = lerpf(camera.fov, 68.0 + speed_ratio * 15.0, clampf(delta * 1.8, 0.0, 1.0))

func _update_world(delta: float) -> void:
	for child in corridor_root.get_children():
		var section := child as Node3D
		section.position.z += speed * delta
		if section.position.z > 9.0:
			section.position.z -= SECTION_COUNT * SECTION_LENGTH

	for child in streak_root.get_children():
		var streak := child as MeshInstance3D
		streak.position.z += speed * delta * 1.45
		if streak.position.z > 9.0:
			streak.position.z = randf_range(-145.0, -85.0)

	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (18.0 + speed * 0.36) * delta
		if area.position.z > 8.0:
			_reset_obstacle(area, randf_range(-185.0, -128.0))

func _update_engines() -> void:
	var pulse := 0.90 + sin(elapsed * 20.0) * 0.10 + (speed - 13.0) * 0.010
	for engine in engines:
		engine.scale.z = pulse
	for trail in engine_trails:
		trail.scale.z = 0.80 + pulse * 0.48
		trail.scale.x = 0.90 + sin(elapsed * 17.0) * 0.07

func _hit(body: Node) -> void:
	if body == ship and alive:
		alive = false
		speed = 0.0
		game_over_label.visible = true
		joystick_root.visible = false
		ship_visual.rotation_degrees = Vector3(24.0, 0.0, 62.0)

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		if event is InputEventScreenTouch and event.pressed:
			get_tree().reload_current_scene()
		elif event is InputEventMouseButton and event.pressed:
			get_tree().reload_current_scene()
		elif event is InputEventKey and event.pressed:
			get_tree().reload_current_scene()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_joystick(event.position)
		else:
			_end_joystick()
	elif event is InputEventScreenDrag:
		_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			_begin_joystick(event.position)
		else:
			_end_joystick()
	elif event is InputEventMouseMotion and pointer_active:
		_update_joystick(event.position)

func _begin_joystick(position: Vector2) -> void:
	pointer_active = true
	joystick_origin = position
	joystick_vector = Vector2.ZERO
	joystick_root.position = position
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = true

func _update_joystick(position: Vector2) -> void:
	if not pointer_active:
		return
	var offset := position - joystick_origin
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob.position = offset
	joystick_vector = offset / JOYSTICK_RADIUS

func _end_joystick() -> void:
	pointer_active = false
	joystick_vector = Vector2.ZERO
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = false
