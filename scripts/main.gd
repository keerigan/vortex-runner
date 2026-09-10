extends Node3D

const TUNNEL_SEGMENTS := 34
const SEGMENT_LENGTH := 4.0
const TUNNEL_RADIUS := 6.1
const OBSTACLE_COUNT := 11
const RIB_COUNT := 16
const JOYSTICK_RADIUS := 105.0
const JOYSTICK_DEADZONE := 0.12

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
var streak_root: Node3D
var ui_label: Label
var game_over_label: Label
var joystick_root: Control
var joystick_base: Polygon2D
var joystick_knob: Polygon2D
var engines: Array[MeshInstance3D] = []
var engine_trails: Array[MeshInstance3D] = []
var pointer_active: bool = false
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO

func _ready() -> void:
	randomize()
	_make_world()
	_spawn_tunnel()
	_spawn_speed_streaks()
	_spawn_obstacles()

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, metallic: float = 0.0, roughness: float = 0.24) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rz: float = 0.0, ry: float = 0.0, rx: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(rx, ry, rz)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0015, 0.002, 0.008)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.09, 0.14, 0.30)
	environment.ambient_light_energy = 1.15
	environment.glow_enabled = true
	world_environment.environment = environment
	add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-30.0, -22.0, 0.0)
	key_light.light_color = Color(0.46, 0.67, 1.0)
	key_light.light_energy = 2.4
	add_child(key_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0.0, 1.8, 4.0)
	rim_light.light_color = Color(0.05, 0.85, 1.0)
	rim_light.light_energy = 4.0
	rim_light.omni_range = 7.0
	add_child(rim_light)
	ship = CharacterBody3D.new()
	ship.name = "Ship"
	ship.position = Vector3(0.0, -1.2, 2.0)
	add_child(ship)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	collision.shape = sphere
	ship.add_child(collision)
	ship_visual = Node3D.new()
	ship_visual.name = "ShipVisual"
	ship_visual.rotation_degrees.x = -7.0
	ship.add_child(ship_visual)
	_build_ship()
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.15, 11.0)
	camera.rotation_degrees = Vector3(-9.5, 0.0, 0.0)
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	tunnel_root = Node3D.new()
	add_child(tunnel_root)
	streak_root = Node3D.new()
	add_child(streak_root)
	obstacle_root = Node3D.new()
	add_child(obstacle_root)
	_make_ui()

func _build_ship() -> void:
	var hull := _mat(Color(0.025, 0.055, 0.11), Color(0.0, 0.03, 0.10), 1.2, 0.92, 0.17)
	var armor := _mat(Color(0.055, 0.19, 0.31), Color(0.0, 0.11, 0.22), 1.7, 0.78, 0.19)
	var cyan := _mat(Color(0.12, 0.92, 1.0), Color(0.0, 0.78, 1.0), 6.5, 0.38, 0.12)
	var glass := _mat(Color(0.008, 0.025, 0.06), Color(0.0, 0.18, 0.38), 1.8, 0.88, 0.08)
	var flame := _mat(Color(0.72, 0.95, 1.0), Color(0.04, 0.72, 1.0), 9.0, 0.0, 0.05)
	_box(ship_visual, Vector3(0.0, -0.02, -0.10), Vector3(0.72, 0.32, 2.55), hull)
	_box(ship_visual, Vector3(0.0, 0.05, -1.28), Vector3(0.42, 0.22, 0.72), armor)
	_box(ship_visual, Vector3(0.0, 0.22, -0.36), Vector3(0.46, 0.23, 1.12), glass)
	_box(ship_visual, Vector3(-0.78, -0.04, 0.06), Vector3(1.34, 0.12, 1.68), armor, -13.0, 0.0, 2.0)
	_box(ship_visual, Vector3(0.78, -0.04, 0.06), Vector3(1.34, 0.12, 1.68), armor, 13.0, 0.0, 2.0)
	_box(ship_visual, Vector3(-1.42, -0.06, 0.56), Vector3(0.74, 0.09, 1.18), hull, -23.0)
	_box(ship_visual, Vector3(1.42, -0.06, 0.56), Vector3(0.74, 0.09, 1.18), hull, 23.0)
	_box(ship_visual, Vector3(-1.58, 0.00, 0.52), Vector3(0.44, 0.055, 0.72), cyan, -24.0)
	_box(ship_visual, Vector3(1.58, 0.00, 0.52), Vector3(0.44, 0.055, 0.72), cyan, 24.0)
	_box(ship_visual, Vector3(0.0, 0.07, -1.54), Vector3(0.14, 0.09, 0.36), cyan)
	_box(ship_visual, Vector3(0.0, 0.17, 0.34), Vector3(0.10, 0.06, 0.72), cyan)
	for x: float in [-0.36, 0.36]:
		_box(ship_visual, Vector3(x, -0.11, 1.18), Vector3(0.34, 0.28, 0.42), hull)
		engines.append(_box(ship_visual, Vector3(x, -0.11, 1.58), Vector3(0.20, 0.17, 0.66), flame))
		engine_trails.append(_box(ship_visual, Vector3(x, -0.11, 2.42), Vector3(0.10, 0.08, 1.70), flame))

func _circle_points(radius: float, count: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(34.0, 40.0)
	ui_label.add_theme_font_size_override("font_size", 30)
	ui_label.modulate = Color(0.88, 0.97, 1.0, 0.96)
	ui_label.text = "000000   //   14"
	layer.add_child(ui_label)
	var title := Label.new()
	title.position = Vector2(34.0, 78.0)
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.22, 0.75, 1.0, 0.72)
	title.text = "VORTEX // RUNNER"
	layer.add_child(title)
	game_over_label = Label.new()
	game_over_label.visible = false
	game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	game_over_label.position = Vector2(-220.0, -100.0)
	game_over_label.size = Vector2(440.0, 200.0)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 40)
	game_over_label.modulate = Color(1.0, 0.55, 0.38, 0.96)
	game_over_label.text = "SIGNAL LOST\nTOUCHE POUR RELANCER"
	layer.add_child(game_over_label)
	joystick_root = Control.new()
	joystick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_root.visible = false
	layer.add_child(joystick_root)
	joystick_base = Polygon2D.new()
	joystick_base.polygon = _circle_points(JOYSTICK_RADIUS)
	joystick_base.color = Color(0.05, 0.45, 0.72, 0.22)
	joystick_root.add_child(joystick_base)
	var inner_ring := Polygon2D.new()
	inner_ring.polygon = _circle_points(JOYSTICK_RADIUS * 0.76)
	inner_ring.color = Color(0.01, 0.03, 0.07, 0.38)
	joystick_root.add_child(inner_ring)
	joystick_knob = Polygon2D.new()
	joystick_knob.polygon = _circle_points(42.0)
	joystick_knob.color = Color(0.18, 0.86, 1.0, 0.72)
	joystick_root.add_child(joystick_knob)

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var segment := Node3D.new()
		segment.position.z = -float(i) * SEGMENT_LENGTH
		segment.rotation.z = float(i) * 0.055
		tunnel_root.add_child(segment)
		for j in RIB_COUNT:
			var angle: float = TAU * float(j) / float(RIB_COUNT)
			var major: bool = j % 4 == 0
			var thickness: float = 0.22 if major else 0.075
			var rail := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(thickness, thickness, SEGMENT_LENGTH * 0.82)
			rail.mesh = box
			rail.position = Vector3(cos(angle) * TUNNEL_RADIUS, sin(angle) * TUNNEL_RADIUS, 0.0)
			rail.rotation.z = angle
			var color := Color.from_hsv(0.53 + fmod(float(i) * 0.009 + float(j) * 0.006, 0.13), 0.78, 1.0)
			rail.material_override = _mat(color * 0.16, color, 4.5 if major else 2.2)
			segment.add_child(rail)
		if i % 2 == 0:
			for j in 12:
				var angle := TAU * float(j) / 12.0
				var piece := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(1.55, 0.075, 0.075)
				piece.mesh = box
				piece.position = Vector3(cos(angle) * 5.15, sin(angle) * 5.15, -1.55)
				piece.rotation.z = angle + PI * 0.5
				var color := Color(0.10, 0.42, 1.0) if i % 6 else Color(0.62, 0.10, 1.0)
				piece.material_override = _mat(color * 0.18, color, 3.4)
				segment.add_child(piece)

func _spawn_speed_streaks() -> void:
	var material := _mat(Color(0.03, 0.22, 0.32), Color(0.0, 0.50, 0.78), 2.8)
	for i in 24:
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, randf_range(1.4, 3.8))
		streak.mesh = box
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(3.4, 5.5)
		streak.position = Vector3(cos(angle) * radius, sin(angle) * radius, randf_range(-120.0, -6.0))
		streak.material_override = material
		streak_root.add_child(streak)

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		_reset_obstacle(_create_obstacle(), -54.0 - float(i) * 20.0)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	obstacle_root.add_child(area)
	var visual := Node3D.new()
	visual.name = "Visual"
	area.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	area.add_child(collision)
	area.body_entered.connect(_hit)
	return area

func _reset_obstacle(area: Area3D, z_position: float) -> void:
	var visual := area.get_child(0) as Node3D
	for child in visual.get_children():
		child.queue_free()
	var hot := _mat(Color(0.42, 0.055, 0.018), Color(1.0, 0.16, 0.015), 6.5, 0.30, 0.16)
	var amber := _mat(Color(0.34, 0.13, 0.02), Color(1.0, 0.42, 0.02), 4.5, 0.30, 0.16)
	var dark := _mat(Color(0.045, 0.025, 0.025), Color(0.16, 0.015, 0.0), 0.8, 0.78, 0.20)
	var obstacle_type := randi_range(0, 2)
	var size := Vector3(1.45, 1.45, 0.8)
	if obstacle_type == 0:
		_box(visual, Vector3.ZERO, Vector3(1.25, 1.25, 0.70), dark)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(1.05, 0.11, 0.10), hot, 45.0)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(1.05, 0.11, 0.10), hot, -45.0)
		_box(visual, Vector3(0.0, 0.0, 0.50), Vector3(0.24, 0.24, 0.10), amber)
	elif obstacle_type == 1:
		size = Vector3(2.8, 0.62, 0.78)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.0, 0.03, 0.44), Vector3(2.45, 0.09, 0.09), hot)
		_box(visual, Vector3(-1.05, 0.0, 0.0), Vector3(0.18, 0.86, 0.30), amber)
		_box(visual, Vector3(1.05, 0.0, 0.0), Vector3(0.18, 0.86, 0.30), amber)
	else:
		size = Vector3(0.62, 2.8, 0.78)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.03, 0.0, 0.44), Vector3(0.09, 2.45, 0.09), hot)
		_box(visual, Vector3(0.0, -1.05, 0.0), Vector3(0.86, 0.18, 0.30), amber)
		_box(visual, Vector3(0.0, 1.05, 0.0), Vector3(0.86, 0.18, 0.30), amber)
	var collision := area.get_child(1) as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = size * Vector3(0.92, 0.92, 1.0)
	var max_radius := TUNNEL_RADIUS - maxf(size.x, size.y) * 0.55 - 0.85
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(1.2, maxf(1.4, max_radius))
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
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	if pointer_active:
		input_vector = joystick_vector
	if input_vector.length() > JOYSTICK_DEADZONE:
		var movement := input_vector.normalized() * minf(input_vector.length(), 1.0) * 7.2 * delta
		ship.position.x += movement.x
		ship.position.y -= movement.y
	var pos2 := Vector2(ship.position.x, ship.position.y)
	if pos2.length() > 5.0:
		pos2 = pos2.normalized() * 5.0
		ship.position.x = pos2.x
		ship.position.y = pos2.y
	var bank := clampf(-input_vector.x * 30.0, -34.0, 34.0)
	var pitch := clampf(-7.0 + input_vector.y * 11.0, -18.0, 8.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank, clampf(delta * 8.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, pitch, clampf(delta * 7.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	camera.position = camera.position.lerp(Vector3(ship.position.x * 0.09, 2.15 + ship.position.y * 0.055, 11.0), clampf(delta * 2.2, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 70.0 + (speed - 14.0) * 0.50, clampf(delta * 2.0, 0.0, 1.0))

func _update_world(delta: float) -> void:
	var tunnel_spin := 0.16 + speed * 0.0045
	for child in tunnel_root.get_children():
		var segment := child as Node3D
		segment.position.z += speed * delta
		segment.rotation.z += delta * tunnel_spin
		if segment.position.z > 8.0: segment.position.z -= TUNNEL_SEGMENTS * SEGMENT_LENGTH
	for child in streak_root.get_children():
		var streak := child as MeshInstance3D
		streak.position.z += speed * delta * 1.35
		if streak.position.z > 9.0: streak.position.z = randf_range(-120.0, -70.0)
	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (28.0 + speed * 0.52) * delta
		if area.position.z > 8.0: _reset_obstacle(area, randf_range(-180.0, -128.0))

func _update_engines() -> void:
	var pulse := 0.88 + sin(elapsed * 20.0) * 0.11 + (speed - 14.0) * 0.014
	for engine in engines: engine.scale.z = pulse
	for trail in engine_trails:
		trail.scale.z = 0.82 + pulse * 0.42
		trail.scale.x = 0.90 + sin(elapsed * 18.0) * 0.08

func _hit(body: Node) -> void:
	if body == ship and alive:
		alive = false
		speed = 0.0
		game_over_label.visible = true
		joystick_root.visible = false
		ship_visual.rotation_degrees = Vector3(24.0, 0.0, 62.0)

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
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

func _begin_joystick(screen_position: Vector2) -> void:
	pointer_active = true
	joystick_origin = screen_position
	joystick_vector = Vector2.ZERO
	joystick_root.position = joystick_origin
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = true

func _update_joystick(screen_position: Vector2) -> void:
	if not pointer_active:
		return
	var offset := screen_position - joystick_origin
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob.position = offset
	joystick_vector = offset / JOYSTICK_RADIUS

func _end_joystick() -> void:
	pointer_active = false
	joystick_vector = Vector2.ZERO
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = false
