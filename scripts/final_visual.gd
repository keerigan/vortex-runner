extends "res://scripts/visual_ship_hook.gd"

const BIOME_LENGTH := 650.0

func _build_camera_canopy()->void:
	var shell:=Node3D.new(); shell.name="CameraCanopy"; add_child(shell)
	var roof:=_mat(Color(0.13,0.15,0.20),Color(0.02,0.025,0.05),0.16,0.72,0.24)
	var steel:=_mat(Color(0.42,0.46,0.55),Color(0.03,0.04,0.07),0.16,0.66,0.18)
	var cyan:=_mat(Color(0.12,0.88,1.0),Color(0,0.70,1),2.5,0.12,0.06)
	_box(shell,Vector3(0,2.42,5.2),Vector3(9.5,0.25,10.2),roof)
	for x:float in [-3.5,-1.75,0.0,1.75,3.5]: _box(shell,Vector3(x,2.15,5.1),Vector3(0.72,0.14,9.4),steel)
	for side:float in [-1.0,1.0]: _box(shell,Vector3(side*3.82,1.84,4.8),Vector3(0.055,0.05,7.0),cyan)

func _add_ship_collisions()->void:
	var body:=CollisionShape3D.new(); var body_shape:=BoxShape3D.new(); body_shape.size=Vector3(0.38,0.20,1.12); body.shape=body_shape; body.position=Vector3(0,0.02,0.08); ship.add_child(body)
	for side:float in [-1.0,1.0]:
		var wing:=CollisionShape3D.new(); var wing_shape:=BoxShape3D.new(); wing_shape.size=Vector3(0.50,0.075,0.46); wing.shape=wing_shape; wing.position=Vector3(side*0.55,-0.015,0.30); wing.rotation_degrees.z=side*9.0; ship.add_child(wing)

func _build_ship()->void:
	super._build_ship(); ship_visual.scale=Vector3(0.88,0.88,0.88)
	var white:=_mat(Color(0.92,0.94,1),Color(0.14,0.17,0.24),0.65,0.40,0.10)
	var steel:=_mat(Color(0.48,0.56,0.70),Color(0.04,0.07,0.12),0.32,0.72,0.13)
	var glass:=_mat(Color(0.035,0.15,0.24),Color(0,0.24,0.42),0.85,0.50,0.05)
	var cyan:=_mat(Color(0.10,0.95,1),Color(0,0.82,1),8,0.08,0.03)
	_box(ship_visual,Vector3(0,0.18,0.18),Vector3(0.62,0.18,1.65),white,Vector3(-4,0,0)); _box(ship_visual,Vector3(0,0.28,-0.48),Vector3(0.38,0.18,0.55),glass,Vector3(-8,0,0))
	for side:float in [-1.0,1.0]:
		_box(ship_visual,Vector3(side*0.58,0.10,0.28),Vector3(0.68,0.12,1.05),steel,Vector3(0,side*8,side*-8)); _box(ship_visual,Vector3(side*0.92,0.02,0.45),Vector3(0.72,0.08,0.48),white,Vector3(0,side*18,side*-12)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.22),0.18,0.22,white,Vector3(90,0,0)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.37),0.115,0.12,cyan,Vector3(90,0,0))
	var key:=OmniLight3D.new(); key.position=Vector3(-0.8,1.8,2); key.light_color=Color(1,0.96,0.90); key.light_energy=8; key.omni_range=6; ship_visual.add_child(key)
	var fill:=OmniLight3D.new(); fill.position=Vector3(1.2,0.8,1.6); fill.light_color=Color(0.30,0.62,1); fill.light_energy=4.2; fill.omni_range=5; ship_visual.add_child(fill)

func _make_world()->void:
	super._make_world(); camera.position=Vector3(0.04,-0.18,7.85); camera.rotation_degrees=Vector3(-0.8,-0.25,0); camera.fov=64
	for child in get_children():
		if child is WorldEnvironment and child.environment: child.environment.ambient_light_color=Color(0.38,0.40,0.50); child.environment.ambient_light_energy=1.8

func _add_drone_mesh(visual:Node3D,scale_value:float,roll:float)->void:
	var mesh:=load("res://assets/hazard_drone.obj") as Mesh
	if mesh:
		var model:=MeshInstance3D.new(); model.mesh=mesh; model.scale=Vector3(scale_value,scale_value,scale_value); model.rotation_degrees.z=roll; visual.add_child(model)

func _add_mine_mesh(visual:Node3D,scale_value:float,roll:float)->void:
	var mesh:=load("res://assets/hazard_mine.obj") as Mesh
	if mesh:
		var model:=MeshInstance3D.new(); model.mesh=mesh; model.scale=Vector3(scale_value,scale_value,scale_value); model.rotation_degrees=Vector3(roll*0.35,roll,roll*0.65); visual.add_child(model)

func _clear_extra_collisions(area:Area3D)->void:
	for i in range(area.get_child_count()-1,1,-1):
		var child:=area.get_child(i)
		if child is CollisionShape3D: child.free()

func _set_primary_box(area:Area3D,size:Vector3,pos:=Vector3.ZERO,rot:=Vector3.ZERO)->void:
	var collision:=area.get_child(1) as CollisionShape3D
	var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; collision.position=pos; collision.rotation_degrees=rot

func _add_box_collision(area:Area3D,size:Vector3,pos:Vector3,rot:=Vector3.ZERO)->void:
	var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; collision.position=pos; collision.rotation_degrees=rot; area.add_child(collision)

func _reset_obstacle(area:Area3D,z:float)->void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	_clear_extra_collisions(area)
	var graphite:=_mat(Color(0.055,0.065,0.09),Color(0.004,0.006,0.012),0.04,0.90,0.16)
	var steel:=_mat(Color(0.42,0.48,0.58),Color(0.025,0.035,0.055),0.15,0.58,0.18)
	var pale:=_mat(Color(0.66,0.70,0.78),Color(0.04,0.05,0.08),0.20,0.48,0.16)
	var orange:=_mat(Color(1.0,0.30,0.012),Color(1.0,0.055,0.0),3.8,0.10,0.03)
	var red:=_mat(Color(1.0,0.035,0.02),Color(1.0,0.0,0.0),3.5,0.10,0.03)
	var type:=randi_range(0,2)
	if type==0:
		_add_drone_mesh(visual,0.78,randf_range(-8.0,8.0))
		for side:float in [-1.0,1.0]:
			_cylinder(visual,Vector3(side*0.48,-0.05,0.47),0.105,0.09,graphite); _cylinder(visual,Vector3(side*0.48,-0.05,0.54),0.055,0.06,orange)
		_set_primary_box(area,Vector3(0.58,0.38,0.62),Vector3(0,0,0.02))
		_add_box_collision(area,Vector3(0.58,0.13,0.40),Vector3(-0.58,-0.02,0.02),Vector3(0,0,-4))
		_add_box_collision(area,Vector3(0.58,0.13,0.40),Vector3(0.58,-0.02,0.02),Vector3(0,0,4))
	elif type==1:
		_add_mine_mesh(visual,0.82,randf_range(-25.0,25.0))
		var collision:=area.get_child(1) as CollisionShape3D; var sphere:=SphereShape3D.new(); sphere.radius=0.62; collision.shape=sphere; collision.position=Vector3.ZERO; collision.rotation_degrees=Vector3.ZERO
	else:
		_box(visual,Vector3(-0.30,0.12,0),Vector3(0.72,0.86,0.66),graphite,Vector3(0,0,-8)); _box(visual,Vector3(0.38,-0.12,0.02),Vector3(0.70,0.68,0.64),steel,Vector3(0,0,11))
		_box(visual,Vector3(-0.30,0.12,0.37),Vector3(0.46,0.54,0.07),pale,Vector3(0,0,-8)); _box(visual,Vector3(0.38,-0.12,0.38),Vector3(0.42,0.40,0.07),pale,Vector3(0,0,11)); _box(visual,Vector3(0.38,-0.12,0.43),Vector3(0.08,0.27,0.04),orange,Vector3(0,0,11)); _cylinder(visual,Vector3(-0.31,0.12,0.44),0.055,0.06,red)
		_set_primary_box(area,Vector3(0.62,0.72,0.56),Vector3(-0.30,0.12,0),Vector3(0,0,-8)); _add_box_collision(area,Vector3(0.60,0.56,0.54),Vector3(0.38,-0.12,0.02),Vector3(0,0,11))
	var glow:=OmniLight3D.new(); glow.position=Vector3(0,0,0.48); glow.light_color=Color(1.0,0.08,0.025); glow.light_energy=0.55; glow.omni_range=1.1; visual.add_child(glow)
	var idx:=area.get_index()
	if idx==0: area.position=Vector3(-1.10,-0.20,-21.0)
	elif idx==1: area.position=Vector3(1.15,0.24,-33.0)
	elif idx==2: area.position=Vector3(-0.45,-0.32,-45.0)
	else: area.position=Vector3(randf_range(-3.3,3.3),randf_range(-2.3,1.2),z)
	area.rotation_degrees.z=randf_range(-7.0,7.0)

func _current_biome()->int:
	return int(floor(score / BIOME_LENGTH)) % 6

func _build_corridor_section(section:Node3D,index:int)->void:
	super._build_corridor_section(section,index)
	section.set_meta("biome",0)
	_decorate_biome(section,0,index)

func _rebuild_section_for_biome(section:Node3D,biome:int,serial:int)->void:
	for child in section.get_children(): child.free()
	super._build_corridor_section(section,serial)
	_decorate_biome(section,biome,serial)
	section.set_meta("biome",biome)

func _decorate_biome(section:Node3D,biome:int,index:int)->void:
	if biome==0:
		return
	if biome==1:
		# Reactor sector: hot pipes, heavy red/orange warning bands and warm pools of light.
		var hot:=_mat(Color(0.95,0.20,0.025),Color(1.0,0.07,0.0),3.8,0.18,0.06)
		var pipe:=_mat(Color(0.24,0.18,0.16),Color(0.03,0.008,0.004),0.10,0.82,0.24)
		var dark:=_mat(Color(0.08,0.045,0.045),Color(0.015,0.002,0.002),0.06,0.88,0.18)
		for side:float in [-1.0,1.0]:
			for y:float in [-1.85,-0.65,0.55]: _cylinder(section,Vector3(side*4.05,y,0),0.11,SECTION_LENGTH*0.90,pipe,Vector3(90,0,0))
			_box(section,Vector3(side*4.30,1.15,0),Vector3(0.09,0.12,SECTION_LENGTH*0.85),hot)
		for z:float in [-2.4,2.4]: _box(section,Vector3(0,-3.02,z),Vector3(7.2,0.055,0.30),dark)
		if index%3==0:
			var light:=OmniLight3D.new(); light.position=Vector3(0,-0.4,-1.2); light.light_color=Color(1.0,0.16,0.04); light.light_energy=3.2; light.omni_range=5.2; section.add_child(light)
	elif biome==2:
		# Energy sector: cooler, cleaner geometry with violet/cyan energy rails and open visual rhythm.
		var cyan:=_mat(Color(0.18,0.90,1.0),Color(0.0,0.72,1.0),4.4,0.12,0.05)
		var violet:=_mat(Color(0.46,0.18,0.76),Color(0.58,0.08,1.0),3.0,0.18,0.08)
		var shell:=_mat(Color(0.11,0.13,0.22),Color(0.01,0.015,0.04),0.10,0.68,0.20)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*3.80,-0.35,0),Vector3(0.16,4.1,SECTION_LENGTH*0.90),shell,Vector3(0,0,side*8))
			_box(section,Vector3(side*3.58,0.55,0),Vector3(0.065,0.08,SECTION_LENGTH*0.95),cyan)
			_box(section,Vector3(side*3.42,-1.45,0),Vector3(0.055,0.06,SECTION_LENGTH*0.82),violet)
		for x:float in [-2.4,0.0,2.4]: _box(section,Vector3(x,1.65,0),Vector3(0.10,0.08,SECTION_LENGTH*0.78),cyan)
		if index%3==1:
			var light:=OmniLight3D.new(); light.position=Vector3(0,0.15,-0.8); light.light_color=Color(0.35,0.18,1.0); light.light_energy=3.0; light.omni_range=5.6; section.add_child(light)
	elif biome==3:
		# Lab sector: bright white hard-surface panels, cool lighting and reduced visual noise.
		var white:=_mat(Color(0.72,0.76,0.84),Color(0.05,0.07,0.11),0.28,0.36,0.16)
		var lightmat:=_mat(Color(0.72,0.94,1.0),Color(0.35,0.80,1.0),2.2,0.10,0.04)
		var seam:=_mat(Color(0.08,0.11,0.16),Color(0.005,0.008,0.016),0.04,0.82,0.18)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*4.42,-0.45,0),Vector3(0.34,4.65,SECTION_LENGTH*0.92),white)
			_box(section,Vector3(side*4.20,0.92,0),Vector3(0.045,0.07,SECTION_LENGTH*0.88),lightmat)
		for x:float in [-2.8,0.0,2.8]: _box(section,Vector3(x,2.00,0),Vector3(1.25,0.12,SECTION_LENGTH*0.88),white)
		for x:float in [-1.40,1.40]: _box(section,Vector3(x,-3.03,0),Vector3(0.035,0.025,SECTION_LENGTH*0.92),seam)
		if index%4==0:
			var light:=OmniLight3D.new(); light.position=Vector3(0,0.8,-0.5); light.light_color=Color(0.72,0.88,1.0); light.light_energy=3.6; light.omni_range=6.2; section.add_child(light)
	elif biome==4:
		# Cryo sector: frozen tunnel - pale blue ice, frosted panels and angled crystal shards.
		var ice:=_mat(Color(0.62,0.82,0.95),Color(0.10,0.30,0.52),0.9,0.10,0.06)
		var frost:=_mat(Color(0.80,0.90,0.98),Color(0.20,0.36,0.50),0.5,0.20,0.10)
		var deep:=_mat(Color(0.10,0.20,0.34),Color(0.02,0.05,0.10),0.10,0.62,0.20)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*4.30,-0.35,0),Vector3(0.22,4.3,SECTION_LENGTH*0.90),deep,Vector3(0,0,side*6))
			_box(section,Vector3(side*3.98,0.85,0),Vector3(0.06,0.10,SECTION_LENGTH*0.92),ice)
			# Crystal shards jutting from the walls at a few points along the section.
			for z:float in [-2.2,0.0,2.2]:
				_box(section,Vector3(side*3.75,-1.9,z),Vector3(0.16,0.9,0.16),frost,Vector3(side*18,0,side*24))
		for x:float in [-2.6,0.0,2.6]: _box(section,Vector3(x,2.02,0),Vector3(0.5,0.5,0.5),ice,Vector3(45,45,0))
		for x:float in [-1.4,1.4]: _box(section,Vector3(x,-3.02,0),Vector3(0.05,0.03,SECTION_LENGTH*0.9),ice)
		if index%3==0:
			var light:=OmniLight3D.new(); light.position=Vector3(0,0.4,-1.0); light.light_color=Color(0.45,0.78,1.0); light.light_energy=3.0; light.omni_range=5.8; section.add_child(light)
	else:
		# Toxic sector: acid-green haze, hazard bands and dripping green pipes.
		var toxic:=_mat(Color(0.45,0.85,0.10),Color(0.30,0.90,0.0),3.6,0.14,0.08)
		var pipe:=_mat(Color(0.20,0.26,0.14),Color(0.02,0.04,0.005),0.10,0.80,0.22)
		var warn:=_mat(Color(0.85,0.80,0.10),Color(0.9,0.75,0.0),2.6,0.16,0.10)
		for side:float in [-1.0,1.0]:
			for y:float in [-1.75,-0.55,0.65]: _cylinder(section,Vector3(side*4.02,y,0),0.10,SECTION_LENGTH*0.90,pipe,Vector3(90,0,0))
			_box(section,Vector3(side*4.26,1.05,0),Vector3(0.08,0.12,SECTION_LENGTH*0.85),toxic)
			_box(section,Vector3(side*3.72,-1.15,0),Vector3(0.05,0.06,SECTION_LENGTH*0.82),toxic)
		for z:float in [-2.4,0.0,2.4]: _box(section,Vector3(0,2.02,z),Vector3(6.6,0.12,0.5),warn,Vector3(0,0,0))
		for x:float in [-1.4,1.4]: _box(section,Vector3(x,-3.02,0),Vector3(0.06,0.04,SECTION_LENGTH*0.9),toxic)
		if index%3==1:
			var light:=OmniLight3D.new(); light.position=Vector3(0,-0.3,-1.0); light.light_color=Color(0.45,0.95,0.10); light.light_energy=3.0; light.omni_range=5.6; section.add_child(light)

func _update_biome_environment(delta:float,biome:int)->void:
	var target_ambient:=Color(0.38,0.40,0.50)
	var target_fog:=Color(0.16,0.10,0.24)
	if biome==1:
		target_ambient=Color(0.42,0.22,0.20); target_fog=Color(0.30,0.07,0.035)
	elif biome==2:
		target_ambient=Color(0.24,0.28,0.48); target_fog=Color(0.12,0.08,0.34)
	elif biome==3:
		target_ambient=Color(0.52,0.56,0.68); target_fog=Color(0.22,0.30,0.42)
	elif biome==4:
		target_ambient=Color(0.40,0.52,0.66); target_fog=Color(0.16,0.34,0.52)
	elif biome==5:
		target_ambient=Color(0.34,0.46,0.18); target_fog=Color(0.20,0.40,0.04)
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.ambient_light_color=child.environment.ambient_light_color.lerp(target_ambient,clampf(delta*0.7,0,1))
			child.environment.fog_light_color=child.environment.fog_light_color.lerp(target_fog,clampf(delta*0.7,0,1))

func _update_world(delta:float)->void:
	var biome:=_current_biome()
	_update_biome_environment(delta,biome)
	for child in corridor_root.get_children():
		var section:=child as Node3D
		section.position.z+=speed*delta
		if section.position.z>9.0:
			section.position.z-=SECTION_COUNT*SECTION_LENGTH
			var old_biome:=int(section.get_meta("biome",0))
			if old_biome!=biome:
				_rebuild_section_for_biome(section,biome,section.get_index())
	for child in streak_root.get_children():
		var streak:=child as Node3D; streak.position.z+=speed*delta*1.25
		if streak.position.z>8.0: streak.position.z=randf_range(-120.0,-80.0)
	for child in obstacle_root.get_children():
		var area:=child as Area3D; area.position.z+=speed*delta; area.rotation_degrees.z+=(16.0+speed*0.20)*delta
		if area.position.z>7.0: _reset_obstacle(area,randf_range(-190.0,-140.0))

func _update_camera(delta:float)->void:
	var target:=Vector3(0.04+ship.position.x*0.015,-0.18+ship.position.y*0.008,7.85); camera.position=camera.position.lerp(target,clampf(delta*1.5,0,1)); camera.fov=lerpf(camera.fov,64+(speed-13)*0.05,clampf(delta*1.2,0,1))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 3.1 // SECTORS"
