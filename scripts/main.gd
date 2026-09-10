extends Node3D

const TUNNEL_SEGMENTS := 26
const SEGMENT_LENGTH := 4.0
const TUNNEL_RADIUS := 6.0
const OBSTACLE_COUNT := 18

var speed: float = 15.0
var max_speed: float = 42.0
var acceleration: float = 1.15
var score: float = 0.0
var alive: bool = true

var ship: CharacterBody3D
var ship_visual: MeshInstance3D
var camera: Camera3D
var tunnel_root: Node3D
var obstacle_root: Node3D
var ui_label: Label
var game_over_label: Label

var pointer_active: bool = false
var target_xy: Vector2 = Vector2.ZERO

func _ready() -> void:
	_make_world()
	_spawn_tunnel()
	_spawn_obstacles()

func _make_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.005, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.5)
	env.ambient_light_energy = 1.4
	env.glow_enabled = true
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -15, 0)
	light.light_energy = 1.6
	add_child(light)

	ship = CharacterBody3D.new()
	ship.name = "Ship"
	ship.position = Vector3(0, -1.0, 2.0)
	add_child(ship)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	collision.shape = sphere
	ship.add_child(collision)

	ship_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.35, 0.55, 2.2)
	ship_visual.mesh = mesh
	ship_visual.rotation_degrees = Vector3(-8, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.75, 1.0)
	mat.metallic = 0.65
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.25, 0.55)
	mat.emission_energy_multiplier = 2.5
	ship_visual.material_override = mat
	ship.add_child(ship_visual)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.2, 10.5)
	camera.rotation_degrees = Vector3(-10, 0, 0)
	camera.fov = 74.0
	add_child(camera)
	camera.current = true

	tunnel_root = Node3D.new()
	tunnel_root.name = "Tunnel"
	add_child(tunnel_root)

	obstacle_root = Node3D.new()
	obstacle_root.name = "Obstacles"
	add_child(obstacle_root)

	_make_ui()

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(28, 28)
	ui_label.add_theme_font_size_override("font_size", 34)
	ui_label.text = "SCORE  0"
	layer.add_child(ui_label)
	var hint := Label.new()
	hint.position = Vector2(28, 75)
	hint.add_theme_font_size_override("font_size", 22)
	hint.text = "Glisse pour piloter"
	layer.add_child(hint)
	game_over_label = Label.new()
	game_over_label.visible = false
	game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	game_over_label.position = Vector2(-220, -90)
	game_over_label.size = Vector2(440, 180)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 42)
	game_over_label.text = "CRASH !\nTouchez pour recommencer"
	layer.add_child(game_over_label)

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var seg := Node3D.new()
		seg.position.z = -float(i) * SEGMENT_LENGTH
		tunnel_root.add_child(seg)
		for j in 12:
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.22, SEGMENT_LENGTH * 0.82)
			bar.mesh = box
			var a: float = TAU * float(j) / 12.0
			bar.position = Vector3(cos(a) * TUNNEL_RADIUS, sin(a) * TUNNEL_RADIUS, 0.0)
			bar.rotation.z = a
			var m := StandardMaterial3D.new()
			var hue: float = fmod(float(i) * 0.04 + float(j) * 0.03, 1.0)
			var c := Color.from_hsv(hue, 0.8, 1.0)
			m.albedo_color = c * 0.35
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.0
			bar.material_override = m
			seg.add_child(bar)

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		_reset_obstacle(_create_obstacle(), -18.0 - float(i) * 11.0)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	area.monitorable = true
	obstacle_root.add_child(area)
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.8, 1.0)
	mesh_i.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.03, 0.01)
	mat.emission_energy_multiplier = 2.8
	mesh_i.material_override = mat
	area.add_child(mesh_i)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 1.2)
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(_on_obstacle_body_entered)
	return area

func _reset_obstacle(area: Area3D, zpos: float) -> void:
	var max_r: float = TUNNEL_RADIUS - 1.8
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(1.2, max_r)
	area.position = Vector3(cos(angle) * radius, sin(angle) * radius, zpos)
	area.rotation_degrees.z = randf_range(0.0, 360.0)
	var s: float = randf_range(0.7, 1.5)
	area.scale = Vector3(s, s, s)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	speed = minf(max_speed, speed + acceleration * delta)
	score += speed * delta
	ui_label.text = "SCORE  %06d   VIT  %02d" % [int(score), int(speed)]
	_update_ship(delta)
	_update_camera(delta)
	_update_tunnel(delta)
	_update_obstacles(delta)

func _update_ship(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_vec.y += 1.0
	if input_vec.length() > 1.0: input_vec = input_vec.normalized()
	var desired := Vector2(ship.position.x, ship.position.y)
	if input_vec.length() > 0.05:
		desired += input_vec * 8.0 * delta
	elif pointer_active:
		desired = target_xy
	var max_radius: float = TUNNEL_RADIUS - 1.0
	if desired.length() > max_radius: desired = desired.normalized() * max_radius
	var current := Vector2(ship.position.x, ship.position.y)
	var next_pos: Vector2 = current.lerp(desired, clampf(delta * 8.5, 0.0, 1.0))
	ship.position.x = next_pos.x
	ship.position.y = next_pos.y
	var bank: float = clampf((desired.x - current.x) * -8.0, -28.0, 28.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank, clampf(delta * 7.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, -8.0 + (desired.y - current.y) * 3.0, clampf(delta * 7.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target_pos := Vector3(ship.position.x * 0.18, 2.2 + ship.position.y * 0.10, 10.5)
	camera.position = camera.position.lerp(target_pos, clampf(delta * 2.5, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 74.0 + (speed - 15.0) * 0.35, clampf(delta * 2.0, 0.0, 1.0))

func _update_tunnel(delta: float) -> void:
	for seg in tunnel_root.get_children():
		seg.position.z += speed * delta
		seg.rotation.z += delta * (0.28 + speed * 0.004)
		if seg.position.z > 8.0:
			seg.position.z -= TUNNEL_SEGMENTS * SEGMENT_LENGTH

func _update_obstacles(delta: float) -> void:
	for area in obstacle_root.get_children():
		area.position.z += speed * delta
		area.rotation_degrees.z += 55.0 * delta
		if area.position.z > 8.0:
			_reset_obstacle(area, randf_range(-150.0, -105.0))

func _on_obstacle_body_entered(body: Node) -> void:
	if body == ship and alive:
		alive = false
		speed = 0.0
		game_over_label.visible = true
		ship_visual.rotation_degrees = Vector3(25, 0, 65)

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			get_tree().reload_current_scene()
		return
	if event is InputEventScreenTouch:
		pointer_active = event.pressed
		if event.pressed:
			_set_target_from_screen(event.position)
	elif event is InputEventScreenDrag:
		pointer_active = true
		_set_target_from_screen(event.position)
	elif event is InputEventMouseButton:
		pointer_active = event.pressed
		if event.pressed:
			_set_target_from_screen(event.position)
	elif event is InputEventMouseMotion and pointer_active:
		_set_target_from_screen(event.position)

func _set_target_from_screen(screen_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var nx: float = (screen_pos.x / viewport_size.x) * 2.0 - 1.0
	var ny: float = (screen_pos.y / viewport_size.y) * 2.0 - 1.0
	target_xy = Vector2(nx * 5.0, -ny * 7.0)
