extends Node3D

const SECTION_COUNT := 22
const SECTION_LENGTH := 7.0
const OBSTACLE_COUNT := 9
const JOYSTICK_RADIUS := 180.0
const JOYSTICK_DEADZONE := 0.20
const JOYSTICK_SPEED := 4.6

var speed := 13.0
var max_speed := 60.0
var acceleration := 0.54
var score := 0.0
var alive := true
var elapsed := 0.0

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
var pointer_active := false
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO

func _ready() -> void:
	randomize()
	_make_world()
	_spawn_corridor()
	_spawn_streaks()
	_spawn_obstacles()

func _mat(color: Color, emission := Color.BLACK, energy := 0.0, metallic := 0.0, roughness := 0.28) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = material
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, rot := Vector3(90, 0, 0)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = material
	parent.add_child(node)
	return node

func _make_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.004, 0.006, 0.014)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.24, 0.34)
	environment.ambient_light_energy = 1.15
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18, 0.15, 0.28)
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.014
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -20, 0)
	key.light_color = Color(0.64, 0.72, 1.0)
	key.light_energy = 2.0
	key.shadow_enabled = false   # perf: shadows are costly in gl_compatibility, barely read on a scrolling tunnel
	add_child(key)

	# Fixed light zones: geometry moving through them gives much richer shading.
	for i in range(4):
		var light := OmniLight3D.new()
		light.position = Vector3(-2.7 if i % 2 == 0 else 2.7, -0.2 + float(i % 3) * 0.8, -8.0 - float(i) * 18.0)
		light.light_color = Color(0.05, 0.75, 1.0) if i % 2 == 0 else Color(0.65, 0.18, 1.0)
		light.light_energy = 3.2
		light.omni_range = 10.0
		add_child(light)

	ship = CharacterBody3D.new()
	ship.position = Vector3(0.0, -1.65, 0.6)
	add_child(ship)
	_add_ship_collisions()

	ship_visual = Node3D.new()
	ship_visual.rotation_degrees.x = -4.0
	ship.add_child(ship_visual)
	_build_ship()

	camera = Camera3D.new()
	camera.position = Vector3(0.0, -0.15, 8.0)
	camera.rotation_degrees = Vector3(-1.5, 0.0, 0.0)
	camera.fov = 64.0
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
	var body := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(0.44, 0.25, 1.05)
	body.shape = body_box
	body.position = Vector3(0.0, 0.0, -0.16)
	ship.add_child(body)
	for side: float in [-1.0, 1.0]:
		var wing := CollisionShape3D.new()
		var wing_box := BoxShape3D.new()
		wing_box.size = Vector3(0.56, 0.10, 0.45)
		wing.shape = wing_box
		wing.position = Vector3(side * 0.58, -0.02, 0.18)
		wing.rotation_degrees.z = side * 9.0
		ship.add_child(wing)

func _build_ship() -> void:
	var fighter_mesh := load("res://assets/ship.obj") as Mesh
	if fighter_mesh:
		var fighter := MeshInstance3D.new()
		fighter.mesh = fighter_mesh
		fighter.scale = Vector3(0.68, 0.68, 0.68)
		fighter.position = Vector3(0.0, 0.02, -0.05)
		ship_visual.add_child(fighter)
	else:
		push_error("Unable to load dedicated fighter mesh")

	var dark := _mat(Color(0.035, 0.045, 0.075), Color.BLACK, 0.0, 0.92, 0.16)
	var metal := _mat(Color(0.62, 0.67, 0.76), Color(0.02, 0.03, 0.05), 0.25, 0.68, 0.18)
	var flame := _mat(Color(0.78, 0.96, 1.0), Color(0.01, 0.72, 1.0), 10.0, 0.0, 0.04)
	for x: float in [-0.30, 0.30]:
		_cylinder(ship_visual, Vector3(x, -0.08, 0.94), 0.14, 0.30, dark)
		_cylinder(ship_visual, Vector3(x, -0.08, 1.16), 0.11, 0.18, metal)
		engines.append(_cylinder(ship_visual, Vector3(x, -0.08, 1.34), 0.075, 0.22, flame))
		engine_trails.append(_box(ship_visual, Vector3(x, -0.08, 1.64), Vector3(0.055, 0.045, 0.42), flame))

func _spawn_corridor() -> void:
	for i in range(SECTION_COUNT):
		var section := Node3D.new()
		section.position.z = -float(i) * SECTION_LENGTH
		corridor_root.add_child(section)
		_build_corridor_section(section, i)

func _build_corridor_section(section: Node3D, index: int) -> void:
	# Neutral industrial materials. Violet is now lighting/accent, not the whole world.
	var floor := _mat(Color(0.32, 0.31, 0.38), Color(0.025, 0.02, 0.04), 0.15, 0.46, 0.32)
	var floor_panel := _mat(Color(0.45, 0.45, 0.52), Color(0.03, 0.025, 0.05), 0.20, 0.42, 0.26)
	var wall := _mat(Color(0.10, 0.11, 0.15), Color(0.012, 0.012, 0.022), 0.12, 0.74, 0.26)
	var armor := _mat(Color(0.24, 0.25, 0.31), Color(0.02, 0.02, 0.035), 0.18, 0.68, 0.22)
	var pale := _mat(Color(0.56, 0.58, 0.64), Color(0.03, 0.03, 0.05), 0.16, 0.50, 0.25)
	var dark := _mat(Color(0.015, 0.018, 0.028), Color.BLACK, 0.0, 0.82, 0.28)
	var cyan := _mat(Color(0.20, 0.92, 1.0), Color(0.0, 0.82, 1.0), 6.0, 0.18, 0.08)
	var violet := _mat(Color(0.52, 0.18, 0.72), Color(0.54, 0.10, 0.90), 2.6, 0.25, 0.12)
	var pipe := _mat(Color(0.20, 0.22, 0.28), Color(0.01, 0.015, 0.025), 0.10, 0.82, 0.20)

	# Floor planes and seams.
	_box(section, Vector3(0, -3.45, 0), Vector3(10.0, 0.34, SECTION_LENGTH), floor)
	_box(section, Vector3(0, -3.24, 0), Vector3(1.35, 0.06, SECTION_LENGTH * 0.98), dark)
	_box(section, Vector3(-3.05, -3.23, 0), Vector3(3.1, 0.055, SECTION_LENGTH * 0.93), floor_panel)
	_box(section, Vector3(3.05, -3.23, 0), Vector3(3.1, 0.055, SECTION_LENGTH * 0.93), floor_panel)
	for lane_x: float in [-4.35, -1.55, 1.55, 4.35]:
		_box(section, Vector3(lane_x, -3.17, 0), Vector3(0.045, 0.025, SECTION_LENGTH * 0.9), dark)

	# Dense side architecture.
	for side: float in [-1.0, 1.0]:
		_box(section, Vector3(side * 4.75, -0.55, 0), Vector3(0.46, 5.8, SECTION_LENGTH), wall)
		_box(section, Vector3(side * 4.40, 1.85, 0), Vector3(0.95, 1.35, SECTION_LENGTH * 0.96), armor, Vector3(0, 0, side * -18))
		_box(section, Vector3(side * 4.22, -2.38, 0), Vector3(0.78, 1.22, SECTION_LENGTH * 0.92), pale, Vector3(0, 0, side * 10))

		# Repeating machinery banks.
		for k in range(3):
			var z := -2.15 + float(k) * 2.15
			_box(section, Vector3(side * 4.04, -1.95, z), Vector3(0.62, 0.92, 0.95), armor)
			_cylinder(section, Vector3(side * 3.68, -1.85, z), 0.26, 0.42, pale, Vector3(0, 0, 90))
			_box(section, Vector3(side * 3.53, -1.84, z), Vector3(0.06, 0.32, 0.54), cyan if (index + k) % 3 == 0 else violet)

		# Light rails inspired by target image.
		_box(section, Vector3(side * 4.48, 0.95, 0), Vector3(0.085, 0.10, SECTION_LENGTH * 0.98), cyan)
		_box(section, Vector3(side * 4.08, -2.82, 0), Vector3(0.055, 0.055, SECTION_LENGTH * 0.92), violet)

	# Bring the roof down and fill the portrait top with visible structure.
	_box(section, Vector3(0, 2.55, 0), Vector3(9.7, 0.30, SECTION_LENGTH), wall)
	_box(section, Vector3(0, 2.33, 0), Vector3(6.8, 0.12, SECTION_LENGTH * 0.96), armor)
	for x: float in [-3.15, -2.72, 2.72, 3.15]:
		_cylinder(section, Vector3(x, 2.05, 0), 0.095, SECTION_LENGTH * 0.96, pipe, Vector3(90, 0, 0))

	# Heavy portal every other segment.
	if index % 2 == 0:
		_box(section, Vector3(-4.34, -0.15, -2.9), Vector3(0.34, 5.4, 0.46), pale, Vector3(0, 0, -7))
		_box(section, Vector3(4.34, -0.15, -2.9), Vector3(0.34, 5.4, 0.46), pale, Vector3(0, 0, 7))
		_box(section, Vector3(0, 2.18, -2.9), Vector3(8.35, 0.30, 0.46), pale)
		_box(section, Vector3(0, 1.96, -2.63), Vector3(7.7, 0.085, 0.09), cyan)

	# Large turbine/generator, closer to the target reference than tiny neon blocks.
	if index % 4 == 0:
		var side := -1.0 if index % 8 == 0 else 1.0
		_cylinder(section, Vector3(side * 3.68, -1.20, -0.55), 0.90, 0.34, armor, Vector3(0, 0, 90))
		_cylinder(section, Vector3(side * 3.48, -1.20, -0.55), 0.68, 0.38, pale, Vector3(0, 0, 90))
		_cylinder(section, Vector3(side * 3.26, -1.20, -0.55), 0.49, 0.42, cyan, Vector3(0, 0, 90))
		_cylinder(section, Vector3(side * 3.02, -1.20, -0.55), 0.24, 0.46, dark, Vector3(0, 0, 90))

func _spawn_streaks() -> void:
	var streak_mat := _mat(Color(0.10, 0.34, 0.43), Color(0.0, 0.35, 0.55), 1.8)
	for i in range(12):
		var x := randf_range(-4.0, 4.0)
		var y := randf_range(-2.5, 1.8)
		_box(streak_root, Vector3(x, y, randf_range(-115, -12)), Vector3(0.02, 0.02, randf_range(0.5, 1.3)), streak_mat)

func _spawn_obstacles() -> void:
	for i in range(OBSTACLE_COUNT):
		_reset_obstacle(_create_obstacle(), -52.0 - float(i) * 24.0)

func _create_obstacle() -> Area3D:
	var area := Area3D.new()
	area.monitoring = true
	obstacle_root.add_child(area)
	var visual := Node3D.new()
	area.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	area.add_child(collision)
	area.body_entered.connect(_hit)
	return area

func _reset_obstacle(area: Area3D, z: float) -> void:
	var visual := area.get_child(0) as Node3D
	for child in visual.get_children():
		child.queue_free()
	var hot := _mat(Color(0.90, 0.32, 0.05), Color(1.0, 0.28, 0.02), 6.5, 0.25, 0.12)
	var pale := _mat(Color(0.62, 0.66, 0.72), Color(0.03, 0.04, 0.06), 0.2, 0.65, 0.20)
	var dark := _mat(Color(0.035, 0.04, 0.055), Color.BLACK, 0.0, 0.78, 0.22)
	var type := randi_range(0, 2)
	var size := Vector3(1.0, 1.0, 0.6)
	if type == 0:
		_cylinder(visual, Vector3.ZERO, 0.66, 0.46, dark)
		_cylinder(visual, Vector3(0, 0, 0.30), 0.48, 0.50, pale)
		_cylinder(visual, Vector3(0, 0, 0.56), 0.20, 0.54, hot)
	elif type == 1:
		size = Vector3(2.35, 0.42, 0.60)
		_box(visual, Vector3.ZERO, Vector3(2.8, 0.62, 0.72), dark)
		_box(visual, Vector3(0, 0, 0.42), Vector3(2.42, 0.10, 0.09), hot)
	else:
		size = Vector3(0.42, 2.35, 0.60)
		_box(visual, Vector3.ZERO, Vector3(0.62, 2.8, 0.72), dark)
		_box(visual, Vector3(0, 0, 0.42), Vector3(0.10, 2.42, 0.09), hot)
	var collision := area.get_child(1) as CollisionShape3D
	(collision.shape as BoxShape3D).size = size * 0.72
	area.position = Vector3(randf_range(-3.45, 3.45), randf_range(-2.35, 1.5), z)
	area.rotation_degrees.z = randf_range(0, 360)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(24, 28)
	ui_label.add_theme_font_size_override("font_size", 34)
	layer.add_child(ui_label)
	var title := Label.new()
	title.position = Vector2(24, 65)
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.35, 0.78, 1.0, 0.72)
	title.text = "VORTEX // RUNNER 0.8"
	layer.add_child(title)
	game_over_label = Label.new()
	game_over_label.visible = false
	game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	game_over_label.position = Vector2(-220, -100)
	game_over_label.size = Vector2(440, 200)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 38)
	game_over_label.text = "SIGNAL LOST\nTOUCHE POUR RELANCER"
	layer.add_child(game_over_label)
	joystick_root = Control.new()
	joystick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_root.visible = false
	layer.add_child(joystick_root)
	var base := Polygon2D.new()
	base.polygon = _circle_points(JOYSTICK_RADIUS)
	base.color = Color(0.05, 0.42, 0.70, 0.18)
	joystick_root.add_child(base)
	joystick_knob = Polygon2D.new()
	joystick_knob.polygon = _circle_points(46)
	joystick_knob.color = Color(0.18, 0.86, 1.0, 0.76)
	joystick_root.add_child(joystick_knob)

func _circle_points(radius: float, count := 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _physics_process(delta: float) -> void:
	if not alive:
		return
	elapsed += delta
	var accel := acceleration
	if speed > 40:
		accel *= 0.62
	if speed > 52:
		accel *= 0.48
	speed = minf(max_speed, speed + accel * delta)
	score += speed * delta
	ui_label.text = "%06d  //  %03d" % [int(score), int(speed)]
	_update_ship(delta)
	_update_camera(delta)
	_update_world(delta)
	_update_engines()

func _update_ship(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input.y += 1
	if pointer_active:
		input = joystick_vector
	if input.length() > JOYSTICK_DEADZONE:
		var strength := (input.length() - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE)
		strength = pow(clampf(strength, 0.0, 1.0), 1.45)
		var move := input.normalized() * strength * JOYSTICK_SPEED * delta
		ship.position.x += move.x
		ship.position.y -= move.y
	ship.position.x = clampf(ship.position.x, -3.55, 3.55)
	ship.position.y = clampf(ship.position.y, -2.2, 1.35)
	ship_visual.rotation_degrees.z = lerpf(ship_visual.rotation_degrees.z, -input.x * 22.0, clampf(delta * 7.0, 0.0, 1.0))
	ship_visual.rotation_degrees.x = lerpf(ship_visual.rotation_degrees.x, -4.0 + input.y * 7.0, clampf(delta * 6.0, 0.0, 1.0))

func _update_camera(delta: float) -> void:
	var target := Vector3(ship.position.x * 0.06, -0.15 + ship.position.y * 0.025, 8.0)
	camera.position = camera.position.lerp(target, clampf(delta * 1.8, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 64.0 + (speed - 13.0) * 0.10, clampf(delta * 1.4, 0.0, 1.0))

func _update_world(delta: float) -> void:
	for child in corridor_root.get_children():
		var section := child as Node3D
		section.position.z += speed * delta
		if section.position.z > 9.0:
			section.position.z -= SECTION_COUNT * SECTION_LENGTH
	for child in streak_root.get_children():
		var streak := child as Node3D
		streak.position.z += speed * delta * 1.25
		if streak.position.z > 8.0:
			streak.position.z = randf_range(-120.0, -80.0)
	for child in obstacle_root.get_children():
		var area := child as Area3D
		area.position.z += speed * delta
		area.rotation_degrees.z += (16.0 + speed * 0.20) * delta
		if area.position.z > 7.0:
			_reset_obstacle(area, randf_range(-190.0, -140.0))

func _update_engines() -> void:
	var pulse := 0.92 + sin(elapsed * 20.0) * 0.07 + (speed - 13.0) * 0.006
	for engine in engines:
		engine.scale.z = pulse
	for trail in engine_trails:
		trail.scale.z = 0.88 + pulse * 0.18

func _hit(body: Node) -> void:
	if body == ship and alive:
		alive = false
		speed = 0.0
		game_over_label.visible = true
		joystick_root.visible = false
		ship_visual.rotation_degrees = Vector3(20, 0, 55)

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

func _begin_joystick(pos: Vector2) -> void:
	pointer_active = true
	joystick_origin = pos
	joystick_vector = Vector2.ZERO
	joystick_root.position = pos
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = true

func _update_joystick(pos: Vector2) -> void:
	if not pointer_active:
		return
	var offset := pos - joystick_origin
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob.position = offset
	joystick_vector = offset / JOYSTICK_RADIUS

func _end_joystick() -> void:
	pointer_active = false
	joystick_vector = Vector2.ZERO
	joystick_knob.position = Vector2.ZERO
	joystick_root.visible = false
