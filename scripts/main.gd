extends Node3D

const TUNNEL_SEGMENTS := 38
const SEGMENT_LENGTH := 3.8
const TUNNEL_RADIUS := 6.2
const OBSTACLE_COUNT := 10
const RIB_COUNT := 18
const JOYSTICK_RADIUS := 145.0
const JOYSTICK_DEADZONE := 0.20
const JOYSTICK_SPEED := 4.8

var speed: float = 13.0
var max_speed: float = 40.0
var acceleration: float = 0.72
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
	mesh.radial_segments = 16
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees.x = rx
	n.material_override = material
	parent.add_child(n)
	return n

func _sphere(parent: Node3D, pos: Vector3, radius: float, scale_y: float, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	n.mesh = mesh
	n.position = pos
	n.scale = Vector3(1.0, scale_y, 1.0)
	n.material_override = material
	parent.add_child(n)
	return n

func _make_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0008, 0.0012, 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.07, 0.11, 0.27)
	env.ambient_light_energy = 1.32
	env.glow_enabled = true
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28.0, -20.0, 0.0)
	key.light_color = Color(0.38, 0.61, 1.0)
	key.light_energy = 2.8
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 1.4, 3.7)
	rim.light_color = Color(0.0, 0.86, 1.0)
	rim.light_energy = 5.0
	rim.omni_range = 8.0
	add_child(rim)

	ship = CharacterBody3D.new()
	ship.name = "Ship"
	ship.position = Vector3(0.0, -1.15, 2.0)
	add_child(ship)

	# Fair collision: deliberately smaller than the visible craft.
	var core_collision := CollisionShape3D.new()
	var core_shape := CapsuleShape3D.new()
	core_shape.radius = 0.34
	core_shape.height = 1.25
	core_collision.shape = core_shape
	core_collision.rotation_degrees.x = 90.0
	ship.add_child(core_collision)

	ship_visual = Node3D.new()
	ship_visual.name = "ShipVisual"
	ship_visual.rotation_degrees.x = -8.0
	ship.add_child(ship_visual)
	_build_ship()

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 9.5)
	camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	camera.fov = 68.0
	add_child(camera)
	camera.current = true

	tunnel_root = Node3D.new(); tunnel_root.name = "Tunnel"; add_child(tunnel_root)
	streak_root = Node3D.new(); streak_root.name = "Streaks"; add_child(streak_root)
	scenery_root = Node3D.new(); scenery_root.name = "Scenery"; add_child(scenery_root)
	obstacle_root = Node3D.new(); obstacle_root.name = "Obstacles"; add_child(obstacle_root)
	_make_ui()

func _build_ship() -> void:
	var black := _mat(Color(0.008,0.014,0.032), Color(0,0.02,0.06), 0.8, 0.98, 0.11)
	var hull := _mat(Color(0.025,0.065,0.13), Color(0,0.05,0.14), 1.2, 0.93, 0.14)
	var armor := _mat(Color(0.07,0.24,0.38), Color(0,0.13,0.28), 2.0, 0.82, 0.16)
	var silver := _mat(Color(0.26,0.38,0.46), Color(0.02,0.08,0.12), 0.8, 0.85, 0.18)
	var cyan := _mat(Color(0.14,0.96,1.0), Color(0,0.82,1), 8.5, 0.32, 0.08)
	var glass := _mat(Color(0.002,0.014,0.04), Color(0,0.26,0.55), 3.0, 0.92, 0.04)
	var flame := _mat(Color(0.82,0.98,1), Color(0.02,0.78,1), 12.0, 0.0, 0.03)

	# Long central spear with layered armored shoulders.
	_box(ship_visual, Vector3(0,-0.03,-0.20), Vector3(0.72,0.30,3.15), black)
	_box(ship_visual, Vector3(0,0.02,-0.70), Vector3(0.56,0.34,1.80), hull)
	_box(ship_visual, Vector3(0,0.08,-1.72), Vector3(0.28,0.20,0.70), silver)
	_box(ship_visual, Vector3(0,0.08,-2.10), Vector3(0.12,0.11,0.38), cyan)

	# Curved-looking canopy built from a flattened sphere instead of a cube.
	_sphere(ship_visual, Vector3(0,0.25,-0.62), 0.42, 0.55, glass)
	_box(ship_visual, Vector3(0,0.24,-0.98), Vector3(0.34,0.08,0.54), cyan)

	# Layered swept wings: stronger silhouette and more depth.
	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side*0.72,-0.04,-0.03), Vector3(1.22,0.16,1.95), armor, side*16.0, 0.0, 3.0)
		_box(ship_visual, Vector3(side*1.34,-0.08,0.40), Vector3(1.10,0.11,1.52), hull, side*27.0)
		_box(ship_visual, Vector3(side*1.88,-0.10,0.88), Vector3(0.74,0.08,1.10), black, side*34.0)
		_box(ship_visual, Vector3(side*2.22,-0.07,1.18), Vector3(0.36,0.12,0.82), armor, side*39.0)
		# Bright leading edge and wing tip blade.
		_box(ship_visual, Vector3(side*1.52,0.01,0.46), Vector3(0.62,0.055,0.95), cyan, side*29.0)
		_box(ship_visual, Vector3(side*2.34,0.00,1.21), Vector3(0.10,0.24,0.74), cyan, side*42.0)
		# Small vertical fin.
		_box(ship_visual, Vector3(side*1.36,0.19,0.70), Vector3(0.12,0.42,0.58), silver, side*22.0, 0.0, side*8.0)

	# Luminous spine / technical vents.
	_box(ship_visual, Vector3(0,0.18,0.48), Vector3(0.11,0.07,1.06), cyan)
	for z: float in [0.05,0.38,0.71]:
		_box(ship_visual, Vector3(-0.29,0.12,z), Vector3(0.08,0.06,0.18), cyan)
		_box(ship_visual, Vector3(0.29,0.12,z), Vector3(0.08,0.06,0.18), cyan)

	# Twin engine pods, glowing cores and layered exhaust trails.
	for x: float in [-0.43,0.43]:
		_cylinder(ship_visual, Vector3(x,-0.10,1.24), 0.24, 0.78, black)
		_cylinder(ship_visual, Vector3(x,-0.10,1.56), 0.19, 0.26, silver)
		engines.append(_cylinder(ship_visual, Vector3(x,-0.10,1.82), 0.12, 0.62, flame))
		engine_trails.append(_box(ship_visual, Vector3(x,-0.10,2.80), Vector3(0.12,0.09,2.05), flame))
		engine_trails.append(_box(ship_visual, Vector3(x,-0.10,4.00), Vector3(0.045,0.035,2.90), cyan))

func _circle_points(radius: float, count: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		points.append(Vector2(cos(a), sin(a)) * radius)
	return points

func _make_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	ui_label = Label.new(); ui_label.position=Vector2(34,38); ui_label.add_theme_font_size_override("font_size",30); ui_label.modulate=Color(0.9,0.98,1,0.95); ui_label.text="000000   //   13"; layer.add_child(ui_label)
	var title := Label.new(); title.position=Vector2(34,77); title.add_theme_font_size_override("font_size",17); title.modulate=Color(0.18,0.78,1,0.85); title.text="VORTEX // RUNNER"; layer.add_child(title)
	var status := Label.new(); status.position=Vector2(34,106); status.add_theme_font_size_override("font_size",12); status.modulate=Color(0.27,0.68,0.9,0.62); status.text="FLIGHT CORE  ONLINE   •   VECTOR FIELD  STABLE"; layer.add_child(status)
	for x: float in [28.0, 1044.0]:
		var line := ColorRect.new(); line.position=Vector2(x,150); line.size=Vector2(2,260); line.color=Color(0.05,0.62,0.92,0.24); layer.add_child(line)
	game_over_label=Label.new(); game_over_label.visible=false; game_over_label.set_anchors_preset(Control.PRESET_CENTER); game_over_label.position=Vector2(-220,-100); game_over_label.size=Vector2(440,200); game_over_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; game_over_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; game_over_label.add_theme_font_size_override("font_size",40); game_over_label.modulate=Color(1,0.48,0.31,0.97); game_over_label.text="SIGNAL LOST\nTOUCHE POUR RELANCER"; layer.add_child(game_over_label)

	joystick_root=Control.new(); joystick_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; joystick_root.visible=false; layer.add_child(joystick_root)
	var outer:=Polygon2D.new(); outer.polygon=_circle_points(JOYSTICK_RADIUS); outer.color=Color(0.03,0.40,0.68,0.16); joystick_root.add_child(outer)
	var mid:=Polygon2D.new(); mid.polygon=_circle_points(JOYSTICK_RADIUS*0.72); mid.color=Color(0.01,0.035,0.075,0.48); joystick_root.add_child(mid)
	for a: float in [0.0,PI*0.5,PI,PI*1.5]:
		var tick:=Polygon2D.new(); tick.polygon=PackedVector2Array([Vector2(-14,-3),Vector2(14,-3),Vector2(14,3),Vector2(-14,3)]); tick.position=Vector2(cos(a),sin(a))*118; tick.rotation=a; tick.color=Color(0.12,0.84,1,0.58); joystick_root.add_child(tick)
	joystick_knob=Polygon2D.new(); joystick_knob.polygon=_circle_points(38); joystick_knob.color=Color(0.16,0.88,1,0.78); joystick_root.add_child(joystick_knob)

func _spawn_tunnel() -> void:
	for i in TUNNEL_SEGMENTS:
		var seg := Node3D.new()
		seg.position.z = -float(i) * SEGMENT_LENGTH
		seg.rotation.z = float(i) * 0.078
		seg.set_meta("index", i)
		tunnel_root.add_child(seg)

		# Spiral cage: varying radius and stronger structural ribs.
		var breathing_radius := TUNNEL_RADIUS + sin(float(i)*0.58)*0.32
		for j in RIB_COUNT:
			var a := TAU*float(j)/float(RIB_COUNT) + float(i)*0.032
			var major := j%3==0
			var thick := 0.25 if major else 0.065
			var hue := 0.52 + fmod(float(i)*0.011 + float(j)*0.004, 0.16)
			var c := Color.from_hsv(hue,0.82,1.0)
			_box(seg,Vector3(cos(a)*breathing_radius,sin(a)*breathing_radius,0),Vector3(thick,thick,SEGMENT_LENGTH*0.86),_mat(c*0.14,c,5.3 if major else 2.0),rad_to_deg(a))

		# Double segmented inner ring gives depth and a reactor-like tunnel.
		if i%2==0:
			for ring_radius: float in [5.18, 5.48]:
				for j in 12:
					var a := TAU*float(j)/12.0 + float(i)*0.045
					var c := Color(0.08,0.48,1.0) if i%6 else Color(0.62,0.08,1.0)
					var width := 1.28 if ring_radius < 5.3 else 0.74
					_box(seg,Vector3(cos(a)*ring_radius,sin(a)*ring_radius,-1.45),Vector3(width,0.065,0.075),_mat(c*0.16,c,3.9),rad_to_deg(a)+90)

		# Heavy portal sections break repetition.
		if i%8==0:
			var dark:=_mat(Color(0.012,0.026,0.060),Color(0,0.10,0.24),1.5,0.88)
			var portal:=_mat(Color(0.06,0.22,0.34),Color(0,0.54,0.92),3.2,0.65)
			for j in 8:
				var a:=TAU*float(j)/8.0
				_box(seg,Vector3(cos(a)*5.78,sin(a)*5.78,-0.65),Vector3(1.30,0.30,0.42),dark,rad_to_deg(a)+90)
				_box(seg,Vector3(cos(a)*5.48,sin(a)*5.48,-0.62),Vector3(0.62,0.08,0.16),portal,rad_to_deg(a)+90)

func _spawn_speed_streaks() -> void:
	var cyan:=_mat(Color(0.02,0.24,0.34),Color(0,0.56,0.88),3.2)
	var violet:=_mat(Color(0.08,0.03,0.22),Color(0.42,0.06,1.0),2.8)
	for i in 44:
		var streak:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(0.022,0.022,randf_range(1.5,5.8)); streak.mesh=mesh
		var a:=randf_range(0,TAU); var r:=randf_range(3.1,5.8); streak.position=Vector3(cos(a)*r,sin(a)*r,randf_range(-138,-6)); streak.material_override=violet if i%7==0 else cyan; streak_root.add_child(streak)

func _spawn_scenery() -> void:
	var blue:=_mat(Color(0.018,0.14,0.24),Color(0,0.44,0.78),2.4)
	var violet:=_mat(Color(0.10,0.02,0.23),Color(0.48,0.04,1),3.0)
	var amber:=_mat(Color(0.20,0.05,0.01),Color(1,0.22,0.01),3.8)
	for i in 28:
		var a:=randf_range(0,TAU); var r:=randf_range(4.5,5.9); var z:=randf_range(-145,-18)
		var mat:=amber if i%11==0 else (violet if i%4==0 else blue)
		_box(scenery_root,Vector3(cos(a)*r,sin(a)*r,z),Vector3(randf_range(0.05,0.16),randf_range(0.22,0.80),randf_range(0.6,2.2)),mat,randf_range(0,360),randf_range(-35,35))

func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		_reset_obstacle(_create_obstacle(), -62.0 - float(i)*23.0)

func _create_obstacle() -> Area3D:
	var area:=Area3D.new(); area.monitoring=true; obstacle_root.add_child(area)
	var visual:=Node3D.new(); visual.name="Visual"; area.add_child(visual)
	var collision:=CollisionShape3D.new(); collision.name="Collision"; collision.shape=BoxShape3D.new(); area.add_child(collision)
	area.body_entered.connect(_hit)
	return area

func _reset_obstacle(area: Area3D, z: float) -> void:
	var visual:=area.get_node("Visual") as Node3D
	for child in visual.get_children(): child.queue_free()
	var hot:=_mat(Color(0.48,0.045,0.012),Color(1,0.10,0.008),8.0,0.32,0.12)
	var amber:=_mat(Color(0.42,0.14,0.015),Color(1,0.44,0.015),6.0,0.34,0.14)
	var dark:=_mat(Color(0.035,0.018,0.025),Color(0.16,0.008,0),0.8,0.80,0.17)
	var t:=randi_range(0,3)
	var visual_size:=Vector3(1.5,1.5,0.8)
	var collision_size:=Vector3(0.82,0.82,0.72)

	if t==0:
		# Reactor mine. Collision only covers the actual core, not the decorative glow.
		_box(visual,Vector3.ZERO,Vector3(1.32,1.32,0.70),dark)
		for angle: float in [45.0,-45.0]: _box(visual,Vector3(0,0,0.42),Vector3(1.18,0.12,0.10),hot,angle)
		_cylinder(visual,Vector3(0,0,0.50),0.23,0.16,amber,90)
		visual_size=Vector3(1.45,1.45,0.78); collision_size=Vector3(0.78,0.78,0.68)
	elif t==1:
		visual_size=Vector3(3.1,0.66,0.80); collision_size=Vector3(2.50,0.38,0.68)
		_box(visual,Vector3.ZERO,visual_size,dark); _box(visual,Vector3(0,0.03,0.44),Vector3(2.72,0.10,0.09),hot)
		_box(visual,Vector3(-1.20,0,0),Vector3(0.21,1.02,0.34),amber); _box(visual,Vector3(1.20,0,0),Vector3(0.21,1.02,0.34),amber)
	elif t==2:
		visual_size=Vector3(0.66,3.1,0.80); collision_size=Vector3(0.38,2.50,0.68)
		_box(visual,Vector3.ZERO,visual_size,dark); _box(visual,Vector3(0.03,0,0.44),Vector3(0.10,2.72,0.09),hot)
		_box(visual,Vector3(0,-1.20,0),Vector3(1.02,0.21,0.34),amber); _box(visual,Vector3(0,1.20,0),Vector3(1.02,0.21,0.34),amber)
	else:
		visual_size=Vector3(2.35,2.35,0.74); collision_size=Vector3(1.55,1.55,0.62)
		for angle: float in [0.0,45.0,90.0,135.0]:
			_box(visual,Vector3.ZERO,Vector3(2.00,0.16,0.25),dark,angle)
			_box(visual,Vector3(0,0,0.20),Vector3(1.72,0.06,0.08),hot,angle)
		_cylinder(visual,Vector3(0,0,0.22),0.28,0.34,amber,90)

	var collision:=area.get_node("Collision") as CollisionShape3D
	(collision.shape as BoxShape3D).size=collision_size
	var maxr:=TUNNEL_RADIUS-maxf(visual_size.x,visual_size.y)*0.50-0.75
	var a:=randf_range(0,TAU); var r:=randf_range(1.4,maxf(1.55,maxr))
	area.position=Vector3(cos(a)*r,sin(a)*r,z)
	area.rotation_degrees.z=randf_range(0,360)

func _physics_process(delta: float) -> void:
	if not alive: return
	elapsed+=delta
	speed=minf(max_speed,speed+acceleration*delta)
	score+=speed*delta
	ui_label.text="%06d   //   %02d" % [int(score),int(speed)]
	_update_ship(delta)
	_update_camera(delta)
	_update_world(delta)
	_update_engines()

func _update_ship(delta: float) -> void:
	var input:=Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): input.x-=1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): input.x+=1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): input.y-=1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): input.y+=1
	if pointer_active:
		# Softer response curve: small thumb movements produce very small corrections.
		var strength:=joystick_vector.length()
		if strength>JOYSTICK_DEADZONE:
			var normalized_strength:=(strength-JOYSTICK_DEADZONE)/(1.0-JOYSTICK_DEADZONE)
			normalized_strength=pow(normalized_strength,1.65)
			input=joystick_vector.normalized()*normalized_strength
		else:
			input=Vector2.ZERO
	if input.length()>0.01:
		var move:=input*JOYSTICK_SPEED*delta
		ship.position.x+=move.x
		ship.position.y-=move.y
	var p:=Vector2(ship.position.x,ship.position.y)
	if p.length()>4.85:
		p=p.normalized()*4.85; ship.position.x=p.x; ship.position.y=p.y
	ship_visual.rotation_degrees.z=lerpf(ship_visual.rotation_degrees.z,clampf(-input.x*26,-30,30),clampf(delta*6.5,0,1))
	ship_visual.rotation_degrees.x=lerpf(ship_visual.rotation_degrees.x,clampf(-8+input.y*9,-16,5),clampf(delta*6,0,1))

func _update_camera(delta: float) -> void:
	var target:=Vector3(ship.position.x*0.075,1.98+ship.position.y*0.045,9.5)
	camera.position=camera.position.lerp(target,clampf(delta*1.8,0,1))
	camera.fov=lerpf(camera.fov,68+(speed-13)*0.40,clampf(delta*1.8,0,1))

func _update_world(delta: float) -> void:
	var spin:=0.16+speed*0.0042
	for child in tunnel_root.get_children():
		var seg:=child as Node3D
		var index:=int(seg.get_meta("index",0))
		seg.position.z+=speed*delta
		seg.rotation.z+=delta*spin
		# Subtle travelling wave makes the vortex feel alive instead of perfectly cylindrical.
		seg.position.x=sin(elapsed*0.65+float(index)*0.34)*0.34
		seg.position.y=cos(elapsed*0.52+float(index)*0.31)*0.24
		if seg.position.z>7.5: seg.position.z-=TUNNEL_SEGMENTS*SEGMENT_LENGTH
	for child in streak_root.get_children():
		var streak:=child as MeshInstance3D; streak.position.z+=speed*delta*1.48
		if streak.position.z>9: streak.position.z=randf_range(-138,-80)
	for child in scenery_root.get_children():
		var item:=child as Node3D; item.position.z+=speed*delta*0.91; item.rotation.z+=delta*0.38
		if item.position.z>10: item.position.z=randf_range(-148,-95)
	for child in obstacle_root.get_children():
		var area:=child as Area3D; area.position.z+=speed*delta; area.rotation_degrees.z+=(24+speed*0.40)*delta
		if area.position.z>8: _reset_obstacle(area,randf_range(-195,-145))

func _update_engines() -> void:
	var pulse:=0.90+sin(elapsed*21)*0.10+(speed-13)*0.012
	for engine in engines: engine.scale.z=pulse
	for trail in engine_trails:
		trail.scale.z=0.86+pulse*0.40
		trail.scale.x=0.88+sin(elapsed*19)*0.07

func _hit(body: Node) -> void:
	if body==ship and alive:
		alive=false; speed=0; game_over_label.visible=true; joystick_root.visible=false; ship_visual.rotation_degrees=Vector3(24,0,62)

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
	joystick_knob.position=offset
	joystick_vector=offset/JOYSTICK_RADIUS

func _end_joystick() -> void:
	pointer_active=false; joystick_vector=Vector2.ZERO; joystick_knob.position=Vector2.ZERO; joystick_root.visible=false
