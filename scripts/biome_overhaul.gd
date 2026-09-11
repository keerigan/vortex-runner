extends "res://scripts/final_visual.gd"

func _reset_obstacle(area:Area3D,z:float)->void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	_clear_extra_collisions(area)
	var graphite:=_mat(Color(0.045,0.055,0.080),Color(0.004,0.006,0.012),0.04,0.90,0.16)
	var steel:=_mat(Color(0.40,0.47,0.58),Color(0.02,0.035,0.055),0.16,0.62,0.16)
	var pale:=_mat(Color(0.68,0.73,0.82),Color(0.04,0.055,0.08),0.20,0.45,0.14)
	var orange:=_mat(Color(1.0,0.30,0.015),Color(1.0,0.07,0.0),4.2,0.08,0.03)
	var cyan:=_mat(Color(0.10,0.90,1.0),Color(0.0,0.65,1.0),4.2,0.08,0.03)
	var forced:int=int(area.get_meta("forced_hazard",-1))
	var type:int=forced if forced>=0 else randi_range(0,2)
	if type==0:
		# Interceptor: wide fighter silhouette with three fair collision volumes.
		_add_drone_mesh(visual,0.78,randf_range(-7.0,7.0))
		for side:float in [-1.0,1.0]:
			_cylinder(visual,Vector3(side*0.48,-0.05,0.47),0.105,0.09,graphite)
			_cylinder(visual,Vector3(side*0.48,-0.05,0.54),0.055,0.06,orange)
		_set_primary_box(area,Vector3(0.56,0.36,0.60),Vector3(0,0,0.02))
		_add_box_collision(area,Vector3(0.54,0.12,0.38),Vector3(-0.56,-0.02,0.02),Vector3(0,0,-4))
		_add_box_collision(area,Vector3(0.54,0.12,0.38),Vector3(0.56,-0.02,0.02),Vector3(0,0,4))
	elif type==1:
		# Mine: dedicated mesh and forgiving spherical core hitbox inside the spikes.
		_add_mine_mesh(visual,0.78,randf_range(-24.0,24.0))
		var collision:=area.get_child(1) as CollisionShape3D
		var sphere:=SphereShape3D.new(); sphere.radius=0.58; collision.shape=sphere; collision.position=Vector3.ZERO; collision.rotation_degrees=Vector3.ZERO
		var warning:=OmniLight3D.new(); warning.position=Vector3(0,0,0.30); warning.light_color=Color(1.0,0.08,0.02); warning.light_energy=0.7; warning.omni_range=1.1; visual.add_child(warning)
	else:
		# Scout drone: same hard-surface family, narrower silhouette and cyan sensor.
		_add_drone_mesh(visual,0.62,randf_range(78.0,102.0))
		_cylinder(visual,Vector3(0,0,0.47),0.10,0.08,graphite)
		_cylinder(visual,Vector3(0,0,0.53),0.055,0.055,cyan)
		for y:float in [-0.38,0.38]: _box(visual,Vector3(0,y,0.05),Vector3(0.18,0.24,0.44),steel,Vector3(0,0,8 if y>0 else -8))
		_set_primary_box(area,Vector3(0.48,0.78,0.55),Vector3.ZERO)
		_add_box_collision(area,Vector3(0.72,0.16,0.36),Vector3(0,0,0.02))
	var idx:=area.get_index()
	if idx==0: area.position=Vector3(-1.10,-0.20,-21.0)
	elif idx==1: area.position=Vector3(1.15,0.24,-33.0)
	elif idx==2: area.position=Vector3(-0.45,-0.32,-45.0)
	else: area.position=Vector3(randf_range(-3.0,3.0),randf_range(-1.85,1.0),z)
	area.rotation_degrees.z=randf_range(-6.0,6.0)

func _decorate_biome(section:Node3D,biome:int,index:int)->void:
	super._decorate_biome(section,biome,index)
	if biome==0:
		return
	if biome==1:
		# Reactor: dark iron and copper, with red/orange used as warning accents rather than wall paint.
		var black:=_mat(Color(0.035,0.028,0.028),Color(0.01,0.002,0.0),0.05,0.90,0.18)
		var iron:=_mat(Color(0.16,0.095,0.075),Color(0.025,0.004,0.002),0.10,0.80,0.18)
		var red:=_mat(Color(0.40,0.045,0.025),Color(0.55,0.018,0.0),0.85,0.58,0.14)
		var amber:=_mat(Color(1.0,0.34,0.02),Color(1.0,0.12,0.0),4.2,0.10,0.04)
		var copper:=_mat(Color(0.36,0.19,0.10),Color(0.03,0.008,0.002),0.10,0.82,0.20)
		_box(section,Vector3(0,-3.08,0),Vector3(7.1,0.07,SECTION_LENGTH*0.94),black)
		for x:float in [-2.70,-2.35,2.35,2.70]: _box(section,Vector3(x,-3.00,0),Vector3(0.055,0.025,SECTION_LENGTH*0.88),amber)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*4.02,-0.35,0),Vector3(0.38,4.25,SECTION_LENGTH*0.88),iron,Vector3(0,0,side*6))
			_box(section,Vector3(side*3.80,0.72,0),Vector3(0.08,0.18,SECTION_LENGTH*0.82),red)
			_cylinder(section,Vector3(side*3.62,-1.15,0),0.18,SECTION_LENGTH*0.90,copper,Vector3(90,0,0))
			_cylinder(section,Vector3(side*3.62,0.20,0),0.14,SECTION_LENGTH*0.90,copper,Vector3(90,0,0))
		if index%2==0:
			_box(section,Vector3(-3.82,0,-2.85),Vector3(0.34,5.0,0.24),iron,Vector3(0,0,-6))
			_box(section,Vector3(3.82,0,-2.85),Vector3(0.34,5.0,0.24),iron,Vector3(0,0,6))
			_box(section,Vector3(0,2.20,-2.85),Vector3(7.35,0.28,0.24),black)
			_box(section,Vector3(0,1.98,-2.82),Vector3(4.8,0.06,0.05),amber)
	elif biome==2:
		# Energy: luminous lattice / accelerator tunnel.
		var deep:=_mat(Color(0.025,0.035,0.10),Color(0.0,0.01,0.05),0.12,0.72,0.16)
		var cyan:=_mat(Color(0.08,0.96,1.0),Color(0.0,0.85,1.0),7.0,0.06,0.03)
		var violet:=_mat(Color(0.72,0.12,1.0),Color(0.55,0.0,1.0),5.0,0.08,0.04)
		_box(section,Vector3(0,-3.06,0),Vector3(7.0,0.06,SECTION_LENGTH*0.94),deep)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*3.72,-0.20,0),Vector3(0.20,4.6,SECTION_LENGTH*0.92),deep,Vector3(0,0,side*10))
			for y:float in [-1.70,0.10,1.45]: _box(section,Vector3(side*3.48,y,0),Vector3(0.055,0.055,SECTION_LENGTH*0.94),cyan if y!=0.10 else violet)
		for x:float in [-2.6,-1.3,0.0,1.3,2.6]: _box(section,Vector3(x,2.02,0),Vector3(0.065,0.06,SECTION_LENGTH*0.88),cyan)
		if index%2==0:
			for side:float in [-1.0,1.0]: _box(section,Vector3(side*2.65,0,-2.75),Vector3(0.08,5.0,0.08),violet,Vector3(0,0,side*28))
			_box(section,Vector3(0,1.78,-2.75),Vector3(5.5,0.075,0.075),cyan)
	elif biome==3:
		# Laboratory: bright clean-room shell.
		var white:=_mat(Color(0.88,0.91,0.96),Color(0.10,0.12,0.16),0.42,0.28,0.12)
		var pale:=_mat(Color(0.65,0.72,0.82),Color(0.04,0.06,0.10),0.20,0.42,0.16)
		var dark:=_mat(Color(0.055,0.075,0.11),Color(0.005,0.008,0.016),0.04,0.80,0.18)
		var cool:=_mat(Color(0.78,0.96,1.0),Color(0.35,0.82,1.0),4.0,0.05,0.03)
		_box(section,Vector3(-2.95,-3.04,0),Vector3(2.5,0.065,SECTION_LENGTH*0.94),white)
		_box(section,Vector3(2.95,-3.04,0),Vector3(2.5,0.065,SECTION_LENGTH*0.94),white)
		_box(section,Vector3(0,-3.035,0),Vector3(2.1,0.07,SECTION_LENGTH*0.94),dark)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*4.02,-0.15,0),Vector3(0.62,4.7,SECTION_LENGTH*0.92),white)
			_box(section,Vector3(side*3.64,0.25,0),Vector3(0.10,3.5,SECTION_LENGTH*0.86),pale)
		_box(section,Vector3(0,2.18,0),Vector3(7.4,0.24,SECTION_LENGTH*0.92),white)
		for x:float in [-2.4,0.0,2.4]: _box(section,Vector3(x,2.02,0),Vector3(0.62,0.055,SECTION_LENGTH*0.78),cool)
		if index%3==0:
			for side:float in [-1.0,1.0]: _box(section,Vector3(side*3.62,-0.4,-2.70),Vector3(0.12,3.6,0.12),dark)

func _update_biome_environment(delta:float,biome:int)->void:
	super._update_biome_environment(delta,biome)
	var target_energy:=1.8
	var target_fog_density:=0.008
	if biome==1:
		target_energy=1.45; target_fog_density=0.012
	elif biome==2:
		target_energy=1.35; target_fog_density=0.010
	elif biome==3:
		target_energy=2.35; target_fog_density=0.004
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.ambient_light_energy=lerpf(child.environment.ambient_light_energy,target_energy,clampf(delta*0.8,0,1))
			child.environment.fog_density=lerpf(child.environment.fog_density,target_fog_density,clampf(delta*0.8,0,1))

# Keep all static canopy geometry out of the camera frustum. The previous canopy
# surrounded the camera and produced giant slabs/polygons across the top third.
func _build_camera_canopy()->void:
	pass

# Recycle geometry as soon as it has safely passed the ship. Nothing needs to
# travel all the way to the camera at z=7.85, where perspective made it explode
# in apparent size and caused near-camera clipping.
func _update_world(delta:float)->void:
	var biome:=_current_biome()
	_update_biome_environment(delta,biome)
	for child in corridor_root.get_children():
		var section:=child as Node3D
		section.position.z+=speed*delta
		if section.position.z>1.65:
			section.position.z-=SECTION_COUNT*SECTION_LENGTH
			var old_biome:=int(section.get_meta("biome",0))
			if old_biome!=biome:
				_rebuild_section_for_biome(section,biome,section.get_index())
	for child in streak_root.get_children():
		var streak:=child as Node3D
		streak.position.z+=speed*delta*1.25
		if streak.position.z>2.4:
			streak.position.z=randf_range(-120.0,-80.0)
	for child in obstacle_root.get_children():
		var area:=child as Area3D
		area.position.z+=speed*delta
		area.rotation_degrees.z+=(16.0+speed*0.20)*delta
		if area.position.z>2.2:
			_reset_obstacle(area,randf_range(-190.0,-140.0))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 3.4 // CLEAN VIEW"