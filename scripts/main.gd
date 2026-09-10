extends Node3D

const TUNNEL_SEGMENTS := 32
const SEGMENT_LENGTH := 4.0
const TUNNEL_RADIUS := 6.0
const OBSTACLE_COUNT := 12

var speed: float = 14.0
var max_speed: float = 42.0
var acceleration: float = 0.85
var score: float = 0.0
var alive: bool = true
var elapsed: float = 0.0

var ship: CharacterBody3D
var ship_visual: Node3D
var camera: Camera3D
var tunnel_root: Node3D
var obstacle_root: Node3D
var ui_label: Label
var game_over_label: Label
var engines: Array[MeshInstance3D] = []

var pointer_active: bool = false
var target_xy: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	_make_world()
	_spawn_tunnel()
	_spawn_obstacles()

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.22
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rz: float = 0.0, ry: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0.0, ry, rz)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.002, 0.003, 0.012)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.20, 0.42)
	environment.ambient_light_energy = 1.15
	environment.glow_enabled = true
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, -18.0, 0.0)
	light.light_color = Color(0.55, 0.72, 1.0)
	light.light_energy = 2.0
	add_child(light)

	ship = CharacterBody3D.new()
	ship.position = Vector3(0.0, -1.15, 2.0)
	add_child(ship)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	collision.shape = sphere
	ship.add_child(collision)

	ship_visual = Node3D.new()
	ship_visual.rotation_degrees.x = -6.0
	ship.add_child(ship_visual)
	_build_ship()

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 10.8)
	camera.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
	camera.fov = 72.0
	add_child(camera)
	camera.current = true

	tunnel_root = Node3D.new()
	add_child(tunnel_root)
	obstacle_root = Node3D.new()
	add_child(obstacle_root)
	_make_ui()

func _build_ship() -> void:
	var hull := _mat(Color(0.035, 0.09, 0.16), Color(0.0, 0.06, 0.16), 1.2, 0.9)
	var panel := _mat(Color(0.10, 0.32, 0.48), Color(0.0, 0.12, 0.22), 1.4, 0.75)
	var cyan := _mat(Color(0.10, 0.9, 1.0), Color(0.0, 0.75, 1.0), 5.0, 0.35)
	var glass := _mat(Color(0.015, 0.04, 0.09), Color(0.0, 0.12, 0.25), 1.2, 0.8)
	var flame := _mat(Color(0.7, 0.95, 1.0), Color(0.05, 0.75, 1.0), 7.0)

	_box(ship_visual, Vector3(0.0, 0.0, 0.0), Vector3(0.82, 0.34, 2.65), hull)
	_box(ship_visual, Vector3(0.0, 0.24, -0.25), Vector3(0.50, 0.25, 1.15), glass)
	_box(ship_visual, Vector3(-0.78, -0.03, 0.12), Vector3(1.20, 0.12, 1.75), panel, -12.0)
	_box(ship_visual, Vector3(0.78, -0.03, 0.12), Vector3(1.20, 0.12, 1.75), panel, 12.0)
	_box(ship_visual, Vector3(-1.42, -0.04, 0.56), Vector3(0.62, 0.08, 1.0), hull, -20.0)
	_box(ship_visual, Vector3(1.42, -0.04, 0.56), Vector3(0.62, 0.08, 1.0), hull, 20.0)
	_box(ship_visual, Vector3(-1.35, 0.01, 0.43), Vector3(0.46, 0.05, 0.60), cyan, -20.0)
	_box(ship_visual, Vector3(1.35, 0.01, 0.43), Vector3(0.46, 0.05, 0.60), cyan, 20.0)
	_box(ship_visual, Vector3(0.0, 0.02, -1.28), Vector3(0.24, 0.12, 0.42), cyan)

	for x: float in [-0.34, 0.34]:
		_box(ship_visual, Vector3(x, -0.10, 1.28), Vector3(0.30, 0.24, 0.35), hull)
		engines.append(_box(ship_visual, Vector3(x, -0.10, 1.75), Vector3(0.18, 0.14, 1.15), flame))

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	ui_label = Label.new()
	ui_label.position = Vector2(34.0, 42.0)
	ui_label.add_theme_font_size_override("font_size", 30)
	ui_label.text = "000000"
	layer.add_child(ui_label)

	var title := Label.new()
	title.position = Vector2(34.0, 78.0)
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.35, 0.8, 1.0, 0.75)
	title.text = "VORTEX // RUNNER"
	layer.add_child(title)

	game_over_label = Label.new()
	game_over_label.visible = false
	game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	game_over_label.position = Vector2(-220.0, -90.0)
	game_over_label.size = Vector2(440.0, 180.0)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 40)
	game_over_label.text = "SIGNAL LOST\nTOUCHE POUR RELANCER"
	layer.add_child(game_over_label)

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var segment := Node3D.new()
		segment.position.z = -float(i) * SEGMENT_LENGTH
		segment.rotation.z = float(i) * 0.045
		tunnel_root.add_child(segment)

		for j in 16:
			var angle: float = TAU * float(j) / 16.0
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			var thickness: float = 0.10 if j % 2 else 0.18
			box.size = Vector3(thickness, thickness, SEGMENT_LENGTH * 0.78)
			bar.mesh = box
			bar.position = Vector3(cos(angle) * TUNNEL_RADIUS, sin(angle) * TUNNEL_RADIUS, 0.0)
			bar.rotation.z = angle
			var phase: float = fmod(float(i) * 0.018 + float(j) * 0.008, 1.0)
			var color := Color.from_hsv(0.52 + phase * 0.16, 0.82, 1.0)
			var energy: float = 2.5 if j % 2 else 4.0
			bar.material_override = _mat(color * 0.18, color, energy)
			segment.add_child(bar)

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		_reset_obstacle(_create_obstacle(), -48.0 - float(i) * 19.0)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	obstacle_root.add_child(area)

	var visual := Node3D.new()
	visual.name = "Visual"
	area.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_hit)
	return area

func _reset_obstacle(area: Area3D, z_position: float) -> void:
	var visual := area.get_child(0) as Node3D
	for child in visual.get_children():
		child.queue_free()

	var hot := _mat(Color(0.38, 0.06, 0.025), Color(1.0, 0.12, 0.015), 5.0, 0.35)
	var dark := _mat(Color(0.06, 0.025, 0.025), Color(0.22, 0.01, 0.0), 1.0, 0.75)
	var obstacle_type: int = randi_range(0, 2)
	var size := Vector3(1.45, 1.45, 0.8)

	if obstacle_type == 0:
		_box(visual, Vector3.ZERO, Vector3(1.35, 1.35, 0.72), dark)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(0.92, 0.12, 0.12), hot)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(0.12, 0.92, 0.12), hot)
	elif obstacle_type == 1:
		size = Vector3(2.5, 0.58, 0.75)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.0, 0.05, 0.42), Vector3(2.2, 0.10, 0.10), hot)
	else:
		size = Vector3(0.58, 2.5, 0.75)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.05, 0.0, 0.42), Vector3(0.10, 2.2, 0.10), hot)

	var collision := area.get_child(1) as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = size
	var max_radius: float = TUNNEL_RADIUS - maxf(size.x, size.y) * 0.55 - 0.9
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(1.0, maxf(1.2, max_radius))
	area.position = Vector3(cos(angle) * radius, sin(angle) * radius, z_position)
	area.rotation_degrees.z = randf_range(0.0, 360.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return

	elapsed += delta
	speed = minf(max_speed, speed + acceleration * delta)
	score += speed * delta
	ui_label.text = "%06d   //   %02d" % [int(score), int(speed)]
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

	var desired := Vector2(ship.position.x, ship.position.y)
	if input_vector.length() > 0.05:
		desired += input_vector.normalized() * 8.0 * delta
	elif pointer_active:
		desired = target_xy

	if desired.length() > 5.0:
		desired = desired.normalized() * 5.0

	var current := Vector2(ship.position.x, ship.position.y)
	var next_position: Vector2 = current.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	ship.position.x = next_position.x
	ship.position.y = next_position.y
	var bank: float = clampf((desired.x - current.x) * -10.0, -34.0, 34.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank, clampf(delta * 8.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target_position := Vector3(ship.position.x * 0.10, 2.0 + ship.position.y * 0.06, 10.8)
	camera.position = camera.position.lerp(target_position, clampf(delta * 2.2, 0.0, 1.0))
	var target_fov: float = 72.0 + (speed - 14.0) * 0.44
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 2.0, 0.0, 1.0))

func _update_world(delta: float) -> void:
	for child in tunnel_root.get_children():
		var segment := child as Node3D
		segment.position.z += speed * delta
		segment.rotation.z += delta * (0.18 + speed * 0.004)
		if segment.position.z > 8.0:
			segment.position.z -= TUNNEL_SEGMENTS * SEGMENT_LENGTH

	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (30.0 + speed * 0.5) * delta
		if area.position.z > 8.0:
			_reset_obstacle(area, randf_range(-175.0, -125.0))

func _update_engines() -> void:
	var pulse: float = 0.85 + sin(elapsed * 20.0) * 0.10 + (speed - 14.0) * 0.014
	for engine in engines:
		engine.scale.z = pulse

func _hit(body: Node) -> void:
	if body == ship and alive:
		alive = false
		speed = 0.0
		game_over_label.visible = true
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
		pointer_active = event.pressed
		if event.pressed:
			_target(event.position)
	elif event is InputEventScreenDrag:
		pointer_active = true
		_target(event.position)
	elif event is InputEventMouseButton:
		pointer_active = event.pressed
		if event.pressed:
			_target(event.position)
	elif event is InputEventMouseMotion and pointer_active:
		_target(event.position)

func _target(position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var normalized_x: float = position.x / viewport_size.x * 2.0 - 1.0
	var normalized_y: float = position.y / viewport_size.y * 2.0 - 1.0
	target_xy = Vector2(normalized_x * 5.0, -normalized_y * 7.0)
