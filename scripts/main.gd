extends Node3D

const SECTION_COUNT := 22
const SECTION_LENGTH := 7.0
const CORRIDOR_HALF_WIDTH := 5.2
const CORRIDOR_HALF_HEIGHT := 3.7
const OBSTACLE_COUNT := 9
const JOYSTICK_RADIUS := 180.0
const JOYSTICK_DEADZONE := 0.26
const JOYSTICK_SPEED := 3.7

var speed := 13.0
var max_speed := 60.0
var acceleration := 0.62
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

func _mat(color: Color, emission := Color.BLACK, energy := 0.0, metallic := 0.0, roughness := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=color; m.metallic=metallic; m.roughness=roughness
	if energy>0.0: m.emission_enabled=true; m.emission=emission; m.emission_energy_multiplier=energy
	return m
func _box(parent:Node3D,pos:Vector3,size:Vector3,material:Material,rot:=Vector3.ZERO)->MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; n.mesh=mesh; n.position=pos; n.rotation_degrees=rot; n.material_override=material; parent.add_child(n); return n
func _cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,material:Material,rot:=Vector3(90,0,0))->MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=18; n.mesh=mesh; n.position=pos; n.rotation_degrees=rot; n.material_override=material; parent.add_child(n); return n
func _sphere(parent:Node3D,pos:Vector3,radius:float,material:Material)->MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2.0; mesh.radial_segments=18; mesh.rings=10; n.mesh=mesh; n.position=pos; n.material_override=material; parent.add_child(n); return n

func _make_world()->void:
	var we:=WorldEnvironment.new(); var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color(0.004,0.003,0.012); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(0.18,0.13,0.30); env.ambient_light_energy=2.0; env.glow_enabled=true; we.environment=env; add_child(we)
	var key:=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-28,-22,0); key.light_color=Color(0.55,0.66,1); key.light_energy=3.3; add_child(key)
	var cyan_light:=OmniLight3D.new(); cyan_light.position=Vector3(-3,0.2,2); cyan_light.light_color=Color(0,0.8,1); cyan_light.light_energy=5.2; cyan_light.omni_range=10; add_child(cyan_light)
	var violet_light:=OmniLight3D.new(); violet_light.position=Vector3(3,-1.8,0.5); violet_light.light_color=Color(0.72,0.18,1); violet_light.light_energy=5; violet_light.omni_range=9; add_child(violet_light)
	ship=CharacterBody3D.new(); ship.position=Vector3(0,-1.45,1.4); add_child(ship); _add_ship_collisions()
	ship_visual=Node3D.new(); ship_visual.rotation_degrees.x=-5; ship.add_child(ship_visual); _build_ship()
	camera=Camera3D.new(); camera.position=Vector3(0,0.45,7.2); camera.rotation_degrees=Vector3(-4,0,0); camera.fov=76; add_child(camera); camera.current=true
	corridor_root=Node3D.new(); add_child(corridor_root); obstacle_root=Node3D.new(); add_child(obstacle_root); streak_root=Node3D.new(); add_child(streak_root); _make_ui()

func _add_ship_collisions()->void:
	var body:=CollisionShape3D.new(); var body_box:=BoxShape3D.new(); body_box.size=Vector3(0.55,0.30,1.25); body.shape=body_box; body.position=Vector3(0,0,-0.18); ship.add_child(body)
	for side:float in [-1.0,1.0]:
		var wing:=CollisionShape3D.new(); var wing_box:=BoxShape3D.new(); wing_box.size=Vector3(0.72,0.12,0.55); wing.shape=wing_box; wing.position=Vector3(side*0.72,-0.02,0.20); wing.rotation_degrees.z=side*10; ship.add_child(wing)

func _build_ship()->void:
	var hull:=_mat(Color(0.035,0.045,0.085),Color(0.01,0.02,0.08),0.8,0.95,0.13); var magenta:=_mat(Color(0.48,0.055,0.28),Color(0.55,0.02,0.28),2.1,0.72,0.16); var red:=_mat(Color(0.78,0.10,0.25),Color(0.70,0.03,0.18),2.2,0.65,0.14); var white:=_mat(Color(0.75,0.83,0.94),Color(0.10,0.18,0.30),0.9,0.55,0.16); var cyan:=_mat(Color(0.15,0.94,1),Color(0,0.85,1),8,0.2,0.07); var glass:=_mat(Color(0.01,0.025,0.07),Color(0,0.30,0.62),3,0.85,0.04); var flame:=_mat(Color(0.82,0.98,1),Color(0.02,0.78,1),12,0,0.03)
	_box(ship_visual,Vector3(0,0,-0.12),Vector3(0.68,0.34,2.45),hull); _box(ship_visual,Vector3(0,0.11,-1.15),Vector3(0.42,0.24,0.72),red); _sphere(ship_visual,Vector3(0,0.23,-0.40),0.34,glass); _box(ship_visual,Vector3(0,0.10,-1.55),Vector3(0.15,0.10,0.32),cyan)
	for side:float in [-1.0,1.0]:
		_box(ship_visual,Vector3(side*0.72,-0.03,0.08),Vector3(1.28,0.14,1.48),magenta,Vector3(0,0,side*12)); _box(ship_visual,Vector3(side*1.30,-0.02,0.42),Vector3(0.82,0.10,0.92),red,Vector3(0,0,side*27)); _box(ship_visual,Vector3(side*1.68,-0.01,0.58),Vector3(0.58,0.07,0.58),white,Vector3(0,0,side*35)); _box(ship_visual,Vector3(side*1.50,0.03,0.36),Vector3(0.40,0.05,0.58),cyan,Vector3(0,0,side*27))
	for x:float in [-0.36,0.36]:
		_cylinder(ship_visual,Vector3(x,-0.10,1.22),0.19,0.40,hull); _cylinder(ship_visual,Vector3(x,-0.10,1.52),0.15,0.24,white); engines.append(_cylinder(ship_visual,Vector3(x,-0.10,1.76),0.11,0.42,flame)); engine_trails.append(_box(ship_visual,Vector3(x,-0.10,2.25),Vector3(0.10,0.07,0.78),flame))

func _spawn_corridor()->void:
	for i in range(SECTION_COUNT):
		var section:=Node3D.new(); section.position.z=-float(i)*SECTION_LENGTH; corridor_root.add_child(section); _build_corridor_section(section,i)
func _build_corridor_section(section:Node3D,index:int)->void:
	var floor:=_mat(Color(0.18,0.13,0.23),Color(0.14,0.05,0.24),1,0.55,0.28); var lit:=_mat(Color(0.25,0.15,0.34),Color(0.35,0.08,0.50),1.8,0.42,0.22); var wall:=_mat(Color(0.07,0.065,0.13),Color(0.05,0.025,0.12),0.8,0.8,0.22); var panel:=_mat(Color(0.18,0.11,0.29),Color(0.18,0.04,0.34),1.2,0.65,0.22); var dark:=_mat(Color(0.012,0.012,0.025)); var cyan:=_mat(Color(0.20,0.96,1),Color(0,0.9,1),8.5); var violet:=_mat(Color(0.66,0.18,0.92),Color(0.65,0.08,1),5); var metal:=_mat(Color(0.18,0.19,0.25),Color(0.04,0.04,0.09),0.5,0.82,0.2)
	_box(section,Vector3(0,-3.7,0),Vector3(10.4,0.42,SECTION_LENGTH),floor); _box(section,Vector3(0,-3.45,0),Vector3(1.65,0.10,SECTION_LENGTH*0.96),dark); _box(section,Vector3(-3.15,-3.42,0),Vector3(3,0.10,SECTION_LENGTH*0.94),lit); _box(section,Vector3(3.15,-3.42,0),Vector3(3,0.10,SECTION_LENGTH*0.94),lit)
	for side:float in [-1.0,1.0]:
		_box(section,Vector3(side*4.95,-0.8,0),Vector3(0.50,5.7,SECTION_LENGTH),wall); _box(section,Vector3(side*4.45,2.35,0),Vector3(1.35,1.55,SECTION_LENGTH*0.98),panel,Vector3(0,0,side*-22)); _box(section,Vector3(side*4.42,-2.75,0),Vector3(0.85,1.25,SECTION_LENGTH*0.92),panel,Vector3(0,0,side*13))
		for k in range(2):
			var z:float=-1.65+float(k)*3.3; _box(section,Vector3(side*4.25,-2.25,z),Vector3(0.72,1.18,1.25),metal); _cylinder(section,Vector3(side*3.83,-2.05,z),0.32,0.48,metal,Vector3(0,0,90)); _box(section,Vector3(side*3.72,-1.95,z),Vector3(0.10,0.46,0.70),cyan if (index+k)%4==0 else violet)
		_box(section,Vector3(side*4.72,0.95,0),Vector3(0.10,0.11,SECTION_LENGTH*0.97),cyan); _box(section,Vector3(side*4.50,-2.95,0),Vector3(0.08,0.08,SECTION_LENGTH*0.94),violet)
	_box(section,Vector3(0,3.55,0),Vector3(10.2,0.34,SECTION_LENGTH),wall)
	for x:float in [-3.2,-2.75,2.75,3.2]: _cylinder(section,Vector3(x,3.12,0),0.10,SECTION_LENGTH*0.94,metal,Vector3(90,0,0))
	if index%2==0:
		_box(section,Vector3(-4.55,0,-2.85),Vector3(0.38,6.8,0.48),metal,Vector3(0,0,-7)); _box(section,Vector3(4.55,0,-2.85),Vector3(0.38,6.8,0.48),metal,Vector3(0,0,7)); _box(section,Vector3(0,3.05,-2.85),Vector3(8.8,0.34,0.48),metal); _box(section,Vector3(0,2.82,-2.58),Vector3(7.9,0.10,0.10),cyan)
	if index%4==0:
		var side:float=-1.0 if index%8==0 else 1.0; _cylinder(section,Vector3(side*3.95,-1.45,-0.8),0.82,0.34,metal,Vector3(0,0,90)); _cylinder(section,Vector3(side*3.72,-1.45,-0.8),0.58,0.40,cyan,Vector3(0,0,90)); _cylinder(section,Vector3(side*3.48,-1.45,-0.8),0.32,0.44,dark,Vector3(0,0,90))

func _spawn_streaks()->void:
	var cyan:=_mat(Color(0.08,0.45,0.62),Color(0,0.55,0.9),2.5)
	for i in range(18):
		var a:=randf_range(0,TAU); var r:=randf_range(3.6,5); var streak:=_box(streak_root,Vector3(cos(a)*r,sin(a)*2.6,randf_range(-120,-10)),Vector3(0.025,0.025,randf_range(0.6,1.8)),cyan); streak.rotation.z=a
func _spawn_obstacles()->void:
	for i in range(OBSTACLE_COUNT): _reset_obstacle(_create_obstacle(),-48-float(i)*23)
func _create_obstacle()->Area3D:
	var area:=Area3D.new(); area.monitoring=true; obstacle_root.add_child(area); var visual:=Node3D.new(); area.add_child(visual); var collision:=CollisionShape3D.new(); collision.shape=BoxShape3D.new(); area.add_child(collision); area.body_entered.connect(_hit); return area
func _reset_obstacle(area:Area3D,z:float)->void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	var hot:=_mat(Color(0.72,0.20,0.03),Color(1,0.28,0.02),8); var white:=_mat(Color(0.72,0.82,0.92),Color(0.12,0.20,0.30),0.8); var dark:=_mat(Color(0.04,0.045,0.075),Color(0.03,0.02,0.08),0.6); var type:=randi_range(0,2); var size:=Vector3(1.1,1.1,0.65)
	if type==0: _cylinder(visual,Vector3.ZERO,0.62,0.42,dark); _cylinder(visual,Vector3(0,0,0.28),0.43,0.48,white); _cylinder(visual,Vector3(0,0,0.52),0.20,0.52,hot)
	elif type==1: size=Vector3(2.55,0.46,0.65); _box(visual,Vector3.ZERO,Vector3(2.9,0.62,0.72),dark); _box(visual,Vector3(0,0,0.42),Vector3(2.5,0.11,0.10),hot)
	else: size=Vector3(0.46,2.55,0.65); _box(visual,Vector3.ZERO,Vector3(0.62,2.9,0.72),dark); _box(visual,Vector3(0,0,0.42),Vector3(0.11,2.5,0.10),hot)
	var collision:=area.get_child(1) as CollisionShape3D; (collision.shape as BoxShape3D).size=size*0.78; area.position=Vector3(randf_range(-3.5,3.5),randf_range(-2.5,2),z); area.rotation_degrees.z=randf_range(0,360)

func _make_ui()->void:
	var layer:=CanvasLayer.new(); add_child(layer); ui_label=Label.new(); ui_label.position=Vector2(24,28); ui_label.add_theme_font_size_override("font_size",28); layer.add_child(ui_label); var title:=Label.new(); title.position=Vector2(24,65); title.add_theme_font_size_override("font_size",14); title.modulate=Color(0.2,0.7,1,0.75); title.text="VORTEX // RUNNER 0.6"; layer.add_child(title); game_over_label=Label.new(); game_over_label.visible=false; game_over_label.set_anchors_preset(Control.PRESET_CENTER); game_over_label.position=Vector2(-220,-100); game_over_label.size=Vector2(440,200); game_over_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; game_over_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; game_over_label.add_theme_font_size_override("font_size",38); game_over_label.text="SIGNAL LOST\nTOUCHE POUR RELANCER"; layer.add_child(game_over_label); joystick_root=Control.new(); joystick_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; joystick_root.visible=false; layer.add_child(joystick_root); var base:=Polygon2D.new(); base.polygon=_circle_points(JOYSTICK_RADIUS); base.color=Color(0.05,0.42,0.70,0.18); joystick_root.add_child(base); joystick_knob=Polygon2D.new(); joystick_knob.polygon=_circle_points(46); joystick_knob.color=Color(0.18,0.86,1,0.76); joystick_root.add_child(joystick_knob)
func _circle_points(radius:float,count:=40)->PackedVector2Array:
	var points:=PackedVector2Array()
	for i in range(count): var a:=TAU*float(i)/float(count); points.append(Vector2(cos(a),sin(a))*radius)
	return points

func _physics_process(delta:float)->void:
	if not alive:return
	elapsed+=delta; var accel:=acceleration
	if speed>40:accel*=0.62
	if speed>52:accel*=0.48
	speed=minf(max_speed,speed+accel*delta); score+=speed*delta; ui_label.text="%06d  //  %03d"%[int(score),int(speed)]; _update_ship(delta); _update_camera(delta); _update_world(delta); _update_engines()
func _update_ship(delta:float)->void:
	var input:=Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):input.x-=1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):input.x+=1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):input.y-=1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):input.y+=1
	if pointer_active:input=joystick_vector
	if input.length()>JOYSTICK_DEADZONE:
		var strength:=(input.length()-JOYSTICK_DEADZONE)/(1-JOYSTICK_DEADZONE); strength=pow(clampf(strength,0,1),1.75); var move:=input.normalized()*strength*JOYSTICK_SPEED*delta; ship.position.x+=move.x; ship.position.y-=move.y
	ship.position.x=clampf(ship.position.x,-3.85,3.85); ship.position.y=clampf(ship.position.y,-2.65,2); ship_visual.rotation_degrees.z=lerpf(ship_visual.rotation_degrees.z,-input.x*24,clampf(delta*7,0,1)); ship_visual.rotation_degrees.x=lerpf(ship_visual.rotation_degrees.x,-5+input.y*8,clampf(delta*6,0,1))
func _update_camera(delta:float)->void:
	camera.position=camera.position.lerp(Vector3(ship.position.x*0.08,0.45+ship.position.y*0.04,7.2),clampf(delta*2,0,1)); camera.fov=lerpf(camera.fov,76+(speed-13)*0.18,clampf(delta*1.5,0,1))
func _update_world(delta:float)->void:
	for child in corridor_root.get_children(): var section:=child as Node3D; section.position.z+=speed*delta; 
	for child in corridor_root.get_children():
		var section:=child as Node3D
		if section.position.z>8:section.position.z-=SECTION_COUNT*SECTION_LENGTH
	for child in streak_root.get_children():
		var streak:=child as Node3D; streak.position.z+=speed*delta*1.3
		if streak.position.z>8:streak.position.z=randf_range(-125,-85)
	for child in obstacle_root.get_children():
		var area:=child as Area3D; area.position.z+=speed*delta; area.rotation_degrees.z+=(18+speed*0.25)*delta
		if area.position.z>7:_reset_obstacle(area,randf_range(-185,-135))
func _update_engines()->void:
	var pulse:=0.9+sin(elapsed*20)*0.08+(speed-13)*0.008
	for engine in engines:engine.scale.z=pulse
	for trail in engine_trails:trail.scale.z=0.85+pulse*0.22
func _hit(body:Node)->void:
	if body==ship and alive:alive=false; speed=0; game_over_label.visible=true; joystick_root.visible=false; ship_visual.rotation_degrees=Vector3(22,0,58)
func _unhandled_input(event:InputEvent)->void:
	if not alive:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):get_tree().reload_current_scene()
		return
	if event is InputEventScreenTouch:
		if event.pressed:_begin_joystick(event.position)
		else:_end_joystick()
	elif event is InputEventScreenDrag:_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:_begin_joystick(event.position)
		else:_end_joystick()
	elif event is InputEventMouseMotion and pointer_active:_update_joystick(event.position)
func _begin_joystick(pos:Vector2)->void:pointer_active=true; joystick_origin=pos; joystick_vector=Vector2.ZERO; joystick_root.position=pos; joystick_knob.position=Vector2.ZERO; joystick_root.visible=true
func _update_joystick(pos:Vector2)->void:
	if not pointer_active:return
	var offset:=pos-joystick_origin
	if offset.length()>JOYSTICK_RADIUS:offset=offset.normalized()*JOYSTICK_RADIUS
	joystick_knob.position=offset; joystick_vector=offset/JOYSTICK_RADIUS
func _end_joystick()->void:pointer_active=false; joystick_vector=Vector2.ZERO; joystick_knob.position=Vector2.ZERO; joystick_root.visible=false
