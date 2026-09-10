extends Node3D

const TUNNEL_SEGMENTS := 34
const SEGMENT_LENGTH := 4.0
const TUNNEL_RADIUS := 6.1
const OBSTACLE_COUNT := 11
const RIB_COUNT := 16

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
var engines: Array[MeshInstance3D] = []
var engine_trails: Array[MeshInstance3D] = []

var pointer_active: bool = false
var target_xy: Vector2 = Vector2.ZERO

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
	tunnel_root.name = "Tunnel"
	add_child(tunnel_root)

	streak_root = Node3D.new()
	streak_root.name = "SpeedStreaks"
	add_child(streak_root)

	obstacle_root = Node3D.new()
	obstacle_root.name = "Obstacles"
	add_child(obstacle_root)

	_make_ui()

func _build_ship() -> void:
	var hull := _mat(Color(0.025, 0.055, 0.11), Color(0.0, 0.03, 0.10), 1.2, 0.92, 0.17)
	var armor := _mat(Color(0.055, 0.19, 0.31), Color(0.0, 0.11, 0.22), 1.7, 0.78, 0.19)
	var cyan := _mat(Color(0.12, 0.92, 1.0), Color(0.0, 0.78, 1.0), 6.5, 0.38, 0.12)
	var glass := _mat(Color(0.008, 0.025, 0.06), Color(0.0, 0.18, 0.38), 1.8, 0.88, 0.08)
	var flame := _mat(Color(0.72, 0.95, 1.0), Color(0.04, 0.72, 1.0), 9.0, 0.0, 0.05)

	# Central arrow-shaped fuselage.
	_box(ship_visual, Vector3(0.0, -0.02, -0.10), Vector3(0.72, 0.32, 2.55), hull)
	_box(ship_visual, Vector3(0.0, 0.05, -1.28), Vector3(0.42, 0.22, 0.72), armor)
	_box(ship_visual, Vector3(0.0, 0.22, -0.36), Vector3(0.46, 0.23, 1.12), glass)

	# Layered swept wings for a much stronger silhouette in portrait view.
	_box(ship_visual, Vector3(-0.78, -0.04, 0.06), Vector3(1.34, 0.12, 1.68), armor, -13.0, 0.0, 2.0)
	_box(ship_visual, Vector3(0.78, -0.04, 0.06), Vector3(1.34, 0.12, 1.68), armor, 13.0, 0.0, 2.0)
	_box(ship_visual, Vector3(-1.42, -0.06, 0.56), Vector3(0.74, 0.09, 1.18), hull, -23.0)
	_box(ship_visual, Vector3(1.42, -0.06, 0.56), Vector3(0.74, 0.09, 1.18), hull, 23.0)
	_box(ship_visual, Vector3(-1.58, 0.00, 0.52), Vector3(0.44, 0.055, 0.72), cyan, -24.0)
	_box(ship_visual, Vector3(1.58, 0.00, 0.52), Vector3(0.44, 0.055, 0.72), cyan, 24.0)

	# Bright spine and nose details.
	_box(ship_visual, Vector3(0.0, 0.07, -1.54), Vector3(0.14, 0.09, 0.36), cyan)
	_box(ship_visual, Vector3(0.0, 0.17, 0.34), Vector3(0.10, 0.06, 0.72), cyan)

	# Twin engines plus long stylized trails.
	for x: float in [-0.36, 0.36]:
		_box(ship_visual, Vector3(x, -0.11, 1.18), Vector3(0.34, 0.28, 0.42), hull)
		engines.append(_box(ship_visual, Vector3(x, -0.11, 1.58), Vector3(0.20, 0.17, 0.66), flame))
		engine_trails.append(_box(ship_visual, Vector3(x, -0.11, 2.42), Vector3(0.10, 0.08, 1.70), flame))

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

	var marker := Label.new()
	marker.set_anchors_preset(Control.PRESET_CENTER)
	marker.position = Vector2(-42.0, 150.0)
	marker.size = Vector2(84.0, 36.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 18)
	marker.modulate = Color(0.2, 0.82, 1.0, 0.52)
	marker.text = "◇"
	layer.add_child(marker)

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

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var segment := Node3D.new()
		segment.position.z = -float(i) * SEGMENT_LENGTH
		segment.rotation.z = float(i) * 0.055
		tunnel_root.add_child(segment)

		# Outer structural rails.
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
			var hue: float = 0.53 + fmod(float(i) * 0.009 + float(j) * 0.006, 0.13)
			var color := Color.from_hsv(hue, 0.78, 1.0)
			var energy: float = 4.5 if major else 2.2
			rail.material_override = _mat(color * 0.16, color, energy)
			segment.add_child(rail)

		# Inner segmented energy ring: this creates the "vortex" depth instead of a wire cage.
		if i % 2 == 0:
			for j in 12:
				var ring_angle: float = TAU * float(j) / 12.0
				var ring_piece := MeshInstance3D.new()
				var ring_box := BoxMesh.new()
				ring_box.size = Vector3(1.55, 0.075, 0.075)
				ring_piece.mesh = ring_box
				ring_piece.position = Vector3(cos(ring_angle) * 5.15, sin(ring_angle) * 5.15, -1.55)
				ring_piece.rotation.z = ring_angle + PI * 0.5
				var ring_color := Color(0.10, 0.42, 1.0) if i % 6 else Color(0.62, 0.10, 1.0)
				ring_piece.material_override = _mat(ring_color * 0.18, ring_color, 3.4)
				segment.add_child(ring_piece)

func _spawn_speed_streaks() -> void:
	var streak_material := _mat(Color(0.03, 0.22, 0.32), Color(0.0, 0.50, 0.78), 2.8)
	for i in 24:
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, randf_range(1.4, 3.8))
		streak.mesh = box
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(3.4, 5.5)
		streak.position = Vector3(cos(angle) * radius, sin(angle) * radius, randf_range(-120.0, -6.0))
		streak.material_override = streak_material
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
	var shape := BoxShape3D.new()
	collision.shape = shape
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
	var obstacle_type: int = randi_range(0, 2)
	var size := Vector3(1.45, 1.45, 0.8)

	if obstacle_type == 0:
		# Reactor mine with bright cross-bracing.
		_box(visual, Vector3.ZERO, Vector3(1.25, 1.25, 0.70), dark)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(1.05, 0.11, 0.10), hot, 45.0)
		_box(visual, Vector3(0.0, 0.0, 0.42), Vector3(1.05, 0.11, 0.10), hot, -45.0)
		_box(visual, Vector3(0.0, 0.0, 0.50), Vector3(0.24, 0.24, 0.10), amber)
	elif obstacle_type == 1:
		# Horizontal energy pylon.
		size = Vector3(2.8, 0.62, 0.78)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.0, 0.03, 0.44), Vector3(2.45, 0.09, 0.09), hot)
		_box(visual, Vector3(-1.05, 0.0, 0.0), Vector3(0.18, 0.86, 0.30), amber)
		_box(visual, Vector3(1.05, 0.0, 0.0), Vector3(0.18, 0.86, 0.30), amber)
	else:
		# Vertical energy pylon.
		size = Vector3(0.62, 2.8, 0.78)
		_box(visual, Vector3.ZERO, size, dark)
		_box(visual, Vector3(0.03, 0.0, 0.44), Vector3(0.09, 2.45, 0.09), hot)
		_box(visual, Vector3(0.0, -1.05, 0.0), Vector3(0.86, 0.18, 0.30), amber)
		_box(visual, Vector3(0.0, 1.05, 0.0), Vector3(0.86, 0.18, 0.30), amber)

	var collision := area.get_child(1) as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = size * Vector3(0.92, 0.92, 1.0)

	var max_radius: float = TUNNEL_RADIUS - maxf(size.x, size.y) * 0.55 - 0.85
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(1.2, maxf(1.4, max_radius))
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

	var bank: float = clampf((desired.x - current.x) * -10.5, -34.0, 34.0)
	var pitch: float = clampf(-7.0 + (desired.y - current.y) * 3.2, -18.0, 8.0)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, bank, clampf(delta * 8.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, pitch, clampf(delta * 7.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target_position := Vector3(ship.position.x * 0.09, 2.15 + ship.position.y * 0.055, 11.0)
	camera.position = camera.position.lerp(target_position, clampf(delta * 2.2, 0.0, 1.0))
	var target_fov: float = 70.0 + (speed - 14.0) * 0.50
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 2.0, 0.0, 1.0))

func _update_world(delta: float) -> void:
	var tunnel_spin: float = 0.16 + speed * 0.0045
	for child in tunnel_root.get_children():
		var segment := child as Node3D
		segment.position.z += speed * delta
		segment.rotation.z += delta * tunnel_spin
		if segment.position.z > 8.0:
			segment.position.z -= TUNNEL_SEGMENTS * SEGMENT_LENGTH

	for child in streak_root.get_children():
		var streak := child as MeshInstance3D
		streak.position.z += speed * delta * 1.35
		if streak.position.z > 9.0:
			streak.position.z = randf_range(-120.0, -70.0)

	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (28.0 + speed * 0.52) * delta
		if area.position.z > 8.0:
			_reset_obstacle(area, randf_range(-180.0, -128.0))

func _update_engines() -> void:
	var pulse: float = 0.88 + sin(elapsed * 20.0) * 0.11 + (speed - 14.0) * 0.014
	for engine in engines:
		engine.scale.z = pulse
	for trail in engine_trails:
		trail.scale.z = 0.82 + pulse * 0.42
		trail.scale.x = 0.90 + sin(elapsed * 18.0) * 0.08

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
			_set_target(event.position)
	elif event is InputEventScreenDrag:
		pointer_active = true
		_set_target(event.position)
	elif event is InputEventMouseButton:
		pointer_active = event.pressed
		if event.pressed:
			_set_target(event.position)
	elif event is InputEventMouseMotion and pointer_active:
		_set_target(event.position)

func _set_target(screen_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var normalized_x: float = (screen_position.x / viewport_size.x) * 2.0 - 1.0
	var normalized_y: float = (screen_position.y / viewport_size.y) * 2.0 - 1.0
	target_xy = Vector2(normalized_x * 4.8, -normalized_y * 5.8)
