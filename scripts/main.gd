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
var scenery_root: Node3D
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
	_spawn_tunnel()
	_spawn_speed_streaks()
	_spawn_scenery()
	_spawn_obstacles()

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, metallic: float = 0.0, roughness: float = 0.24) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rz: float = 0.0, ry: float = 0.0, rx: float = 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees = Vector3(rx, ry, rz)
	n.material_override = material
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, rx: float = 90.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees.x = rx
	n.material_override = material
	parent.add_child(n)
	return n

func _make_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.001, 0.0015, 0.007)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.12, 0.28)
	env.ambient_light_energy = 1.25
	env.glow_enabled = true
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -22, 0)
	key.light_color = Color(0.40, 0.62, 1.0)
	key.light_energy = 2.5
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 1.6, 4.0)
	rim.light_color = Color(0.0, 0.82, 1.0)
	rim.light_energy = 4.5
	rim.omni_range = 7.5
	add_child(rim)
	ship = CharacterBody3D.new()
	ship.position = Vector3(0, -1.2, 2)
	add_child(ship)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	collision.shape = sphere
	ship.add_child(collision)
	ship_visual = Node3D.new()
	ship_visual.rotation_degrees.x = -7
	ship.add_child(ship_visual)
	_build_ship()
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.15, 11)
	camera.rotation_degrees = Vector3(-9.5, 0, 0)
	camera.fov = 70
	add_child(camera)
	camera.current = true
	tunnel_root = Node3D.new(); add_child(tunnel_root)
	streak_root = Node3D.new(); add_child(streak_root)
	scenery_root = Node3D.new(); add_child(scenery_root)
	obstacle_root = Node3D.new(); add_child(obstacle_root)
	_make_ui()

func _build_ship() -> void:
	var hull := _mat(Color(0.018,0.035,0.075), Color(0,0.03,0.10), 1.0, 0.95, 0.15)
	var armor := _mat(Color(0.055,0.18,0.30), Color(0,0.12,0.24), 1.8, 0.80, 0.18)
	var armor2 := _mat(Color(0.12,0.26,0.38), Color(0,0.08,0.16), 1.0, 0.75, 0.22)
	var cyan := _mat(Color(0.10,0.92,1), Color(0,0.8,1), 7.0, 0.35, 0.10)
	var glass := _mat(Color(0.004,0.018,0.05), Color(0,0.20,0.46), 2.2, 0.9, 0.06)
	var flame := _mat(Color(0.72,0.96,1), Color(0.03,0.74,1), 10.0, 0, 0.04)
	# Layered fuselage, cockpit and armored nose.
	_box(ship_visual, Vector3(0,-0.02,-0.05), Vector3(0.76,0.34,2.75), hull)
	_box(ship_visual, Vector3(0,0.07,-1.28), Vector3(0.50,0.25,0.78), armor)
	_box(ship_visual, Vector3(0,0.25,-0.42), Vector3(0.48,0.25,1.12), glass)
	_box(ship_visual, Vector3(0,0.06,-1.68), Vector3(0.22,0.15,0.42), cyan)
	# Triple-layer swept wings.
	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side*0.78,-0.04,0.02), Vector3(1.36,0.13,1.78), armor, side*13)
		_box(ship_visual, Vector3(side*1.38,-0.06,0.48), Vector3(0.86,0.10,1.30), hull, side*23)
		_box(ship_visual, Vector3(side*1.72,-0.07,0.82), Vector3(0.54,0.08,0.92), armor2, side*30)
		_box(ship_visual, Vector3(side*1.57,0.00,0.50), Vector3(0.48,0.055,0.82), cyan, side*24)
		_box(ship_visual, Vector3(side*1.94,-0.02,1.00), Vector3(0.12,0.18,0.62), cyan, side*31)
	# Spine and small luminous technical details.
	_box(ship_visual, Vector3(0,0.17,0.35), Vector3(0.10,0.06,0.80), cyan)
	_box(ship_visual, Vector3(-0.30,0.12,0.58), Vector3(0.07,0.05,0.46), cyan)
	_box(ship_visual, Vector3(0.30,0.12,0.58), Vector3(0.07,0.05,0.46), cyan)
	# Engine nacelles, nozzles and layered trails.
	for x: float in [-0.38,0.38]:
		_box(ship_visual, Vector3(x,-0.11,1.20), Vector3(0.38,0.30,0.52), hull)
		_cylinder(ship_visual, Vector3(x,-0.11,1.55), 0.18, 0.32, armor)
		engines.append(_cylinder(ship_visual, Vector3(x,-0.11,1.80), 0.11, 0.62, flame))
		engine_trails.append(_box(ship_visual, Vector3(x,-0.11,2.70), Vector3(0.10,0.08,1.90), flame))
		engine_trails.append(_box(ship_visual, Vector3(x,-0.11,3.45), Vector3(0.045,0.035,2.20), cyan))

func _circle_points(radius: float, count: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := TAU*float(i)/float(count)
		points.append(Vector2(cos(a),sin(a))*radius)
	return points

func _make_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	ui_label = Label.new(); ui_label.position=Vector2(34,40); ui_label.add_theme_font_size_override("font_size",30); ui_label.text="000000   //   14"; layer.add_child(ui_label)
	var title := Label.new(); title.position=Vector2(34,78); title.add_theme_font_size_override("font_size",16); title.modulate=Color(0.22,0.75,1,0.72); title.text="VORTEX // RUNNER"; layer.add_child(title)
	var status := Label.new(); status.position=Vector2(34,106); status.add_theme_font_size_override("font_size",12); status.modulate=Color(0.25,0.65,0.85,0.55); status.text="FLIGHT CORE  ONLINE   •   VECTOR LOCK  ACTIVE"; layer.add_child(status)
	# Decorative HUD brackets.
	for x: float in [28.0, 1010.0]:
		var line := ColorRect.new(); line.position=Vector2(x,150); line.size=Vector2(2,210); line.color=Color(0.05,0.55,0.85,0.28); layer.add_child(line)
	game_over_label=Label.new(); game_over_label.visible=false; game_over_label.set_anchors_preset(Control.PRESET_CENTER); game_over_label.position=Vector2(-220,-100); game_over_label.size=Vector2(440,200); game_over_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; game_over_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; game_over_label.add_theme_font_size_override("font_size",40); game_over_label.modulate=Color(1,0.55,0.38,0.96); game_over_label.text="SIGNAL LOST\nTOUCHE POUR RELANCER"; layer.add_child(game_over_label)
	joystick_root=Control.new(); joystick_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; joystick_root.visible=false; layer.add_child(joystick_root)
	var base:=Polygon2D.new(); base.polygon=_circle_points(JOYSTICK_RADIUS); base.color=Color(0.05,0.45,0.72,0.20); joystick_root.add_child(base)
	var inner:=Polygon2D.new(); inner.polygon=_circle_points(JOYSTICK_RADIUS*0.76); inner.color=Color(0.01,0.03,0.07,0.42); joystick_root.add_child(inner)
	# Four sci-fi direction ticks around the floating stick.
	for a: float in [0.0,PI*0.5,PI,PI*1.5]:
		var tick:=Polygon2D.new(); tick.polygon=PackedVector2Array([Vector2(-12,-3),Vector2(12,-3),Vector2(12,3),Vector2(-12,3)]); tick.position=Vector2(cos(a),sin(a))*86; tick.rotation=a; tick.color=Color(0.15,0.82,1,0.55); joystick_root.add_child(tick)
	joystick_knob=Polygon2D.new(); joystick_knob.polygon=_circle_points(42); joystick_knob.color=Color(0.18,0.86,1,0.76); joystick_root.add_child(joystick_knob)

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var seg:=Node3D.new(); seg.position.z=-float(i)*SEGMENT_LENGTH; seg.rotation.z=float(i)*0.055; tunnel_root.add_child(seg)
		for j in RIB_COUNT:
			var a:=TAU*float(j)/float(RIB_COUNT); var major:=j%4==0; var thick:=0.22 if major else 0.07
			var color:=Color.from_hsv(0.53+fmod(float(i)*0.009+float(j)*0.006,0.13),0.78,1)
			_box(seg,Vector3(cos(a)*TUNNEL_RADIUS,sin(a)*TUNNEL_RADIUS,0),Vector3(thick,thick,SEGMENT_LENGTH*0.82),_mat(color*0.15,color,4.8 if major else 2.1),rad_to_deg(a))
		if i%2==0:
			for j in 12:
				var a:=TAU*float(j)/12.0; var c:=Color(0.10,0.42,1) if i%6 else Color(0.62,0.10,1)
				_box(seg,Vector3(cos(a)*5.15,sin(a)*5.15,-1.55),Vector3(1.55,0.075,0.075),_mat(c*0.18,c,3.5),rad_to_deg(a)+90)
		# Heavy gate ribs every few sections make the tunnel feel constructed.
		if i%7==0:
			var dark:=_mat(Color(0.015,0.03,0.06),Color(0,0.08,0.18),1.2,0.8)
			for j in 8:
				var a:=TAU*float(j)/8.0
				_box(seg,Vector3(cos(a)*5.72,sin(a)*5.72,-0.7),Vector3(1.25,0.24,0.34),dark,rad_to_deg(a)+90)

func _spawn_speed_streaks() -> void:
	var mat:=_mat(Color(0.03,0.22,0.32),Color(0,0.50,0.78),3.0)
	for i in 34:
		var streak:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(0.025,0.025,randf_range(1.4,4.8)); streak.mesh=mesh
		var a:=randf_range(0,TAU); var r:=randf_range(3.2,5.7); streak.position=Vector3(cos(a)*r,sin(a)*r,randf_range(-125,-6)); streak.material_override=mat; streak_root.add_child(streak)

func _spawn_scenery() -> void:
	# Floating luminous shards and distant warning beacons add parallax/detail.
	var blue:=_mat(Color(0.02,0.15,0.25),Color(0,0.42,0.75),2.2)
	var violet:=_mat(Color(0.12,0.03,0.24),Color(0.45,0.05,1),2.6)
	for i in 18:
		var a:=randf_range(0,TAU); var r:=randf_range(4.6,5.8); var z:=randf_range(-135,-15)
		var shard:=_box(scenery_root,Vector3(cos(a)*r,sin(a)*r,z),Vector3(randf_range(0.06,0.16),randf_range(0.25,0.75),randf_range(0.6,1.8)),blue if i%3 else violet,randf_range(0,360),randf_range(-30,30))
		shard.scale=Vector3.ONE

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT: _reset_obstacle(_create_obstacle(),-54-float(i)*20)

func _create_obstacle() -> Area3D:
	var area:=Area3D.new(); area.monitoring=true; obstacle_root.add_child(area)
	var visual:=Node3D.new(); area.add_child(visual)
	var collision:=CollisionShape3D.new(); collision.shape=BoxShape3D.new(); area.add_child(collision); area.body_entered.connect(_hit); return area

func _reset_obstacle(area: Area3D,z: float) -> void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	var hot:=_mat(Color(0.42,0.055,0.018),Color(1,0.16,0.015),7.0,0.3,0.14)
	var amber:=_mat(Color(0.34,0.13,0.02),Color(1,0.42,0.02),5.0,0.3,0.16)
	var dark:=_mat(Color(0.04,0.02,0.025),Color(0.16,0.015,0),0.8,0.78,0.2)
	var t:=randi_range(0,3); var size:=Vector3(1.45,1.45,0.8)
	if t==0:
		_box(visual,Vector3.ZERO,Vector3(1.28,1.28,0.72),dark); _box(visual,Vector3(0,0,0.42),Vector3(1.12,0.11,0.10),hot,45); _box(visual,Vector3(0,0,0.42),Vector3(1.12,0.11,0.10),hot,-45); _cylinder(visual,Vector3(0,0,0.5),0.20,0.14,amber,90)
	elif t==1:
		size=Vector3(3.0,0.64,0.78); _box(visual,Vector3.ZERO,size,dark); _box(visual,Vector3(0,0.03,0.44),Vector3(2.65,0.09,0.09),hot); _box(visual,Vector3(-1.18,0,0),Vector3(0.20,0.95,0.32),amber); _box(visual,Vector3(1.18,0,0),Vector3(0.20,0.95,0.32),amber)
	elif t==2:
		size=Vector3(0.64,3.0,0.78); _box(visual,Vector3.ZERO,size,dark); _box(visual,Vector3(0.03,0,0.44),Vector3(0.09,2.65,0.09),hot); _box(visual,Vector3(0,-1.18,0),Vector3(0.95,0.20,0.32),amber); _box(visual,Vector3(0,1.18,0),Vector3(0.95,0.20,0.32),amber)
	else:
		# Four-prong spinning hazard.
		size=Vector3(2.2,2.2,0.72)
		for a: float in [0,90,180,270]: _box(visual,Vector3.ZERO,Vector3(1.85,0.18,0.26),dark,a); _box(visual,Vector3.ZERO,Vector3(1.55,0.07,0.10),hot,a)
		_cylinder(visual,Vector3(0,0,0.18),0.25,0.30,amber,90)
	var collision:=area.get_child(1) as CollisionShape3D; (collision.shape as BoxShape3D).size=size*Vector3(0.90,0.90,1)
	var maxr:=TUNNEL_RADIUS-maxf(size.x,size.y)*0.55-0.85; var a:=randf_range(0,TAU); var r:=randf_range(1.2,maxf(1.4,maxr)); area.position=Vector3(cos(a)*r,sin(a)*r,z); area.rotation_degrees.z=randf_range(0,360)

func _physics_process(delta: float) -> void:
	if not alive: return
	elapsed+=delta; speed=minf(max_speed,speed+acceleration*delta); score+=speed*delta; ui_label.text="%06d   //   %02d"%[int(score),int(speed)]
	_update_ship(delta); _update_camera(delta); _update_world(delta); _update_engines()

func _update_ship(delta: float) -> void:
	var input:=Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): input.x-=1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): input.x+=1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): input.y-=1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): input.y+=1
	if pointer_active: input=joystick_vector
	if input.length()>JOYSTICK_DEADZONE:
		var move:=input.normalized()*minf(input.length(),1)*7.2*delta; ship.position.x+=move.x; ship.position.y-=move.y
	var p:=Vector2(ship.position.x,ship.position.y)
	if p.length()>5: p=p.normalized()*5; ship.position.x=p.x; ship.position.y=p.y
	ship_visual.rotation_degrees.z=lerpf(ship_visual.rotation_degrees.z,clampf(-input.x*30,-34,34),clampf(delta*8,0,1)); ship_visual.rotation_degrees.x=lerpf(ship_visual.rotation_degrees.x,clampf(-7+input.y*11,-18,8),clampf(delta*7,0,1))

func _update_camera(delta: float) -> void:
	camera.position=camera.position.lerp(Vector3(ship.position.x*0.09,2.15+ship.position.y*0.055,11),clampf(delta*2.2,0,1)); camera.fov=lerpf(camera.fov,70+(speed-14)*0.50,clampf(delta*2,0,1))

func _update_world(delta: float) -> void:
	var spin:=0.16+speed*0.0045
	for child in tunnel_root.get_children():
		var seg:=child as Node3D; seg.position.z+=speed*delta; seg.rotation.z+=delta*spin
		if seg.position.z>8: seg.position.z-=TUNNEL_SEGMENTS*SEGMENT_LENGTH
	for child in streak_root.get_children():
		var streak:=child as MeshInstance3D; streak.position.z+=speed*delta*1.4
		if streak.position.z>9: streak.position.z=randf_range(-125,-75)
	for child in scenery_root.get_children():
		var item:=child as Node3D; item.position.z+=speed*delta*0.92; item.rotation.z+=delta*0.4
		if item.position.z>10: item.position.z=randf_range(-140,-90)
	for child in obstacle_root.get_children():
		var area:=child as Area3D; area.position.z+=speed*delta; area.rotation_degrees.z+=(28+speed*0.52)*delta
		if area.position.z>8: _reset_obstacle(area,randf_range(-180,-128))

func _update_engines() -> void:
	var pulse:=0.88+sin(elapsed*20)*0.11+(speed-14)*0.014
	for engine in engines: engine.scale.z=pulse
	for trail in engine_trails: trail.scale.z=0.82+pulse*0.42; trail.scale.x=0.90+sin(elapsed*18)*0.08

func _hit(body: Node) -> void:
	if body==ship and alive: alive=false; speed=0; game_over_label.visible=true; joystick_root.visible=false; ship_visual.rotation_degrees=Vector3(24,0,62)

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed): get_tree().reload_current_scene()
		return
	if event is InputEventScreenTouch:
		if event.pressed: _begin_joystick(event.position)
		else: _end_joystick()
	elif event is InputEventScreenDrag: _update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.pressed: _begin_joystick(event.position)
		else: _end_joystick()
	elif event is InputEventMouseMotion and pointer_active: _update_joystick(event.position)

func _begin_joystick(pos: Vector2) -> void:
	pointer_active=true; joystick_origin=pos; joystick_vector=Vector2.ZERO; joystick_root.position=pos; joystick_knob.position=Vector2.ZERO; joystick_root.visible=true

func _update_joystick(pos: Vector2) -> void:
	if not pointer_active: return
	var offset:=pos-joystick_origin
	if offset.length()>JOYSTICK_RADIUS: offset=offset.normalized()*JOYSTICK_RADIUS
	joystick_knob.position=offset; joystick_vector=offset/JOYSTICK_RADIUS

func _end_joystick() -> void:
	pointer_active=false; joystick_vector=Vector2.ZERO; joystick_knob.position=Vector2.ZERO; joystick_root.visible=false
