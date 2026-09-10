extends Node3D

const TUNNEL_SEGMENTS := 28
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
var engine_left: MeshInstance3D
var engine_right: MeshInstance3D

var pointer_active: bool = false
var target_xy: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	_make_world()
	_spawn_tunnel()
	_spawn_obstacles()

func _make_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.004, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.28, 0.55)
	env.ambient_light_energy = 1.35
	env.glow_enabled = true
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -18, 0)
	light.light_energy = 1.8
	add_child(light)

	ship = CharacterBody3D.new()
	ship.name = "Ship"
	ship.position = Vector3(0, -1.1, 2.0)
	add_child(ship)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	collision.shape = sphere
	ship.add_child(collision)

	ship_visual = Node3D.new()
	ship_visual.name = "ShipVisual"
	ship_visual.rotation_degrees = Vector3(-7, 0, 0)
	ship.add_child(ship_visual)
	_build_ship_visual()

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.0, 10.8)
	camera.rotation_degrees = Vector3(-9, 0, 0)
	camera.fov = 72.0
	add_child(camera)
	camera.current = true

	tunnel_root = Node3D.new()
	tunnel_root.name = "Tunnel"
	add_child(tunnel_root)

	obstacle_root = Node3D.new()
	obstacle_root.name = "Obstacles"
	add_child(obstacle_root)

	_make_ui()

func _build_ship_visual() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.08, 0.34, 0.62)
	body_mat.metallic = 0.8
	body_mat.roughness = 0.2
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.0, 0.10, 0.26)
	body_mat.emission_energy_multiplier = 1.6

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.18, 0.9, 1.0)
	accent_mat.metallic = 0.45
	accent_mat.roughness = 0.16
	accent_mat.emission_enabled = true
	accent_mat.emission = Color(0.0, 0.55, 0.85)
	accent_mat.emission_energy_multiplier = 3.2

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.025, 0.04, 0.08)
	dark_mat.metallic = 0.9
	dark_mat.roughness = 0.18

	var engine_mat := StandardMaterial3D.new()
	engine_mat.albedo_color = Color(0.2, 0.8, 1.0)
	engine_mat.emission_enabled = true
	engine_mat.emission = Color(0.05, 0.65, 1.0)
	engine_mat.emission_energy_multiplier = 5.0

	_add_box(ship_visual, Vector3(0, 0, 0), Vector3(1.05, 0.38, 2.4), body_mat)
	_add_box(ship_visual, Vector3(0, 0.24, -0.15), Vector3(0.55, 0.24, 1.3), dark_mat)
	_add_box(ship_visual, Vector3(-0.92, -0.05, 0.15), Vector3(1.15, 0.16, 1.45), body_mat, -10.0)
	_add_box(ship_visual, Vector3(0.92, -0.05, 0.15), Vector3(1.15, 0.16, 1.45), body_mat, 10.0)
	_add_box(ship_visual, Vector3(-1.42, -0.05, 0.55), Vector3(0.45, 0.10, 0.75), accent_mat, -16.0)
	_add_box(ship_visual, Vector3(1.42, -0.05, 0.55), Vector3(0.45, 0.10, 0.75), accent_mat, 16.0)
	_add_box(ship_visual, Vector3(0, 0.02, -1.08), Vector3(0.38, 0.17, 0.35), accent_mat)

	engine_left = _add_box(ship_visual, Vector3(-0.38, -0.12, 1.36), Vector3(0.24, 0.18, 0.8), engine_mat)
	engine_right = _add_box(ship_visual, Vector3(0.38, -0.12, 1.36), Vector3(0.24, 0.18, 0.8), engine_mat)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, z_rotation: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation_degrees.z = z_rotation
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(28, 28)
	ui_label.add_theme_font_size_override("font_size", 34)
	ui_label.text = "SCORE  000000"
	layer.add_child(ui_label)

	var hint := Label.new()
	hint.position = Vector2(28, 76)
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
			box.size = Vector3(0.20, 0.20, SEGMENT_LENGTH * 0.84)
			bar.mesh = box
			var a: float = TAU * float(j) / 12.0
			bar.position = Vector3(cos(a) * TUNNEL_RADIUS, sin(a) * TUNNEL_RADIUS, 0.0)
			bar.rotation.z = a
			var m := StandardMaterial3D.new()
			var hue: float = fmod(float(i) * 0.034 + float(j) * 0.028, 1.0)
			var c := Color.from_hsv(hue, 0.82, 1.0)
			m.albedo_color = c * 0.28
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.2
			bar.material_override = m
			seg.add_child(bar)

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		var first_z: float = -42.0 - float(i) * 18.0
		_reset_obstacle(_create_obstacle(), first_z)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	area.monitorable = true
	obstacle_root.add_child(area)

	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	mesh_i.mesh = box
	area.add_child(mesh_i)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	cs.shape = shape
	area.add_child(cs)

	area.body_entered.connect(_on_obstacle_body_entered)
	return area

func _reset_obstacle(area: Area3D, zpos: float) -> void:
	var mesh_i := area.get_child(0) as MeshInstance3D
	var cs := area.get_child(1) as CollisionShape3D
	var box := mesh_i.mesh as BoxMesh
	var shape := cs.shape as BoxShape3D

	var obstacle_type: int = randi_range(0, 2)
	var obstacle_size := Vector3(1.5, 1.5, 1.0)
	if obstacle_type == 1:
		obstacle_size = Vector3(2.6, 0.65, 1.0)
	elif obstacle_type == 2:
		obstacle_size = Vector3(0.7, 2.5, 1.0)

	var difficulty: float = clampf(elapsed / 35.0, 0.0, 1.0)
	var scale_factor: float = randf_range(0.72, 0.95 + difficulty * 0.30)
	obstacle_size *= scale_factor
	box.size = obstacle_size
	shape.size = obstacle_size * Vector3(0.90, 0.90, 1.0)

	var mat := StandardMaterial3D.new()
	var hue: float = randf_range(0.96, 1.04)
	var c := Color.from_hsv(fmod(hue, 1.0), 0.92, 1.0)
	mat.albedo_color = c * 0.48
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 3.0
	mesh_i.material_override = mat

	var max_r: float = TUNNEL_RADIUS - maxf(obstacle_size.x, obstacle_size.y) * 0.55 - 0.8
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(1.0, maxf(1.2, max_r))
	area.position = Vector3(cos(angle) * radius, sin(angle) * radius, zpos)
	area.rotation_degrees.z = randf_range(0.0, 360.0)
	area.scale = Vector3.ONE

func _physics_process(delta: float) -> void:
	if not alive:
		return
	elapsed += delta
	speed = minf(max_speed, speed + acceleration * delta)
	score += speed * delta
	ui_label.text = "SCORE  %06d   VIT  %02d" % [int(score), int(speed)]
	_update_ship(delta)
	_update_camera(delta)
	_update_tunnel(delta)
	_update_obstacles(delta)
	_update_engines()

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
	if desired.length() > max_radius:
		desired = desired.normalized() * max_radius

	var current := Vector2(ship.position.x, ship.position.y)
	var next_pos: Vector2 = current.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	ship.position.x = next_pos.x
	ship.position.y = next_pos.y

	var bank: float = clampf((desired.x - current.x) * -9.5, -32.0, 32.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank, clampf(delta * 8.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, -7.0 + (desired.y - current.y) * 3.0, clampf(delta * 7.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target_pos := Vector3(ship.position.x * 0.12, 2.0 + ship.position.y * 0.07, 10.8)
	camera.position = camera.position.lerp(target_pos, clampf(delta * 2.2, 0.0, 1.0))
	var target_fov: float = 72.0 + (speed - 14.0) * 0.42
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 2.0, 0.0, 1.0))

func _update_tunnel(delta: float) -> void:
	var spin: float = 0.24 + speed * 0.0045
	for seg in tunnel_root.get_children():
		var segment := seg as Node3D
		segment.position.z += speed * delta
		segment.rotation.z += delta * spin
		if segment.position.z > 8.0:
			segment.position.z -= TUNNEL_SEGMENTS * SEGMENT_LENGTH

func _update_obstacles(delta: float) -> void:
	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (38.0 + speed * 0.7) * delta
		if area.position.z > 8.0:
			var difficulty: float = clampf(elapsed / 45.0, 0.0, 1.0)
			var far_z: float = randf_range(-165.0 + difficulty * 25.0, -120.0 + difficulty * 20.0)
			_reset_obstacle(area, far_z)

func _update_engines() -> void:
	var pulse: float = 0.85 + sin(elapsed * 16.0) * 0.12 + (speed - 14.0) * 0.012
	engine_left.scale.z = pulse
	engine_right.scale.z = pulse

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
	target_xy = Vector2(nx * 4.6, -ny * 5.6)
