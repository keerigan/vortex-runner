extends "res://scripts/visual_ship_hook.gd"

func _build_camera_canopy()->void:
	var shell:=Node3D.new(); shell.name="CameraCanopy"; add_child(shell)
	var roof:=_mat(Color(0.13,0.15,0.20),Color(0.02,0.025,0.05),0.16,0.72,0.24)
	var steel:=_mat(Color(0.42,0.46,0.55),Color(0.03,0.04,0.07),0.16,0.66,0.18)
	var cyan:=_mat(Color(0.12,0.88,1.0),Color(0,0.70,1),2.5,0.12,0.06)
	_box(shell,Vector3(0,2.42,5.2),Vector3(9.5,0.25,10.2),roof)
	for x:float in [-3.5,-1.75,0.0,1.75,3.5]: _box(shell,Vector3(x,2.15,5.1),Vector3(0.72,0.14,9.4),steel)
	for side:float in [-1.0,1.0]: _box(shell,Vector3(side*3.82,1.84,4.8),Vector3(0.055,0.05,7.0),cyan)

func _add_ship_collisions()->void:
	# Fair, silhouette-following hitbox: narrow fuselage + two shallow wings.
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
		# Interceptor drone: actual mesh, restrained lights, fair multipart collision.
		_add_drone_mesh(visual,0.78,randf_range(-8.0,8.0))
		for side:float in [-1.0,1.0]:
			_cylinder(visual,Vector3(side*0.48,-0.05,0.47),0.105,0.09,graphite); _cylinder(visual,Vector3(side*0.48,-0.05,0.54),0.055,0.06,orange)
		_set_primary_box(area,Vector3(0.58,0.38,0.62),Vector3(0,0,0.02))
		_add_box_collision(area,Vector3(0.58,0.13,0.40),Vector3(-0.58,-0.02,0.02),Vector3(0,0,-4))
		_add_box_collision(area,Vector3(0.58,0.13,0.40),Vector3(0.58,-0.02,0.02),Vector3(0,0,4))
	elif type==1:
		# Dedicated mine asset: compact target with spherical collision slightly inside the spikes.
		_add_mine_mesh(visual,0.82,randf_range(-25.0,25.0))
		var collision:=area.get_child(1) as CollisionShape3D; var sphere:=SphereShape3D.new(); sphere.radius=0.62; collision.shape=sphere; collision.position=Vector3.ZERO; collision.rotation_degrees=Vector3.ZERO
	else:
		# Broken cargo module: asymmetrical hard-surface debris, with two independent hit volumes.
		_box(visual,Vector3(-0.30,0.12,0),Vector3(0.72,0.86,0.66),graphite,Vector3(0,0,-8)); _box(visual,Vector3(0.38,-0.12,0.02),Vector3(0.70,0.68,0.64),steel,Vector3(0,0,11))
		_box(visual,Vector3(-0.30,0.12,0.37),Vector3(0.46,0.54,0.07),pale,Vector3(0,0,-8)); _box(visual,Vector3(0.38,-0.12,0.38),Vector3(0.42,0.40,0.07),pale,Vector3(0,0,11)); _box(visual,Vector3(0.38,-0.12,0.43),Vector3(0.08,0.27,0.04),orange,Vector3(0,0,11)); _cylinder(visual,Vector3(-0.31,0.12,0.44),0.055,0.06,red)
		_set_primary_box(area,Vector3(0.62,0.72,0.56),Vector3(-0.30,0.12,0),Vector3(0,0,-8)); _add_box_collision(area,Vector3(0.60,0.56,0.54),Vector3(0.38,-0.12,0.02),Vector3(0,0,11))
	var glow:=OmniLight3D.new(); glow.position=Vector3(0,0,0.48); glow.light_color=Color(1.0,0.08,0.025); glow.light_energy=0.55; glow.omni_range=1.1; visual.add_child(glow)
	var idx:=area.get_index()
	if idx==0: area.position=Vector3(-1.10,-0.20,-21.0)
	elif idx==1: area.position=Vector3(1.15,0.24,-33.0)
	elif idx==2: area.position=Vector3(-0.45,-0.32,-45.0)
	else: area.position=Vector3(randf_range(-3.0,3.0),randf_range(-1.85,1.0),z)
	area.rotation_degrees.z=randf_range(-7.0,7.0)

func _update_camera(delta:float)->void:
	var target:=Vector3(0.04+ship.position.x*0.015,-0.18+ship.position.y*0.008,7.85); camera.position=camera.position.lerp(target,clampf(delta*1.5,0,1)); camera.fov=lerpf(camera.fov,64+(speed-13)*0.05,clampf(delta*1.2,0,1))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 3.0 // COLLISION PASS"
