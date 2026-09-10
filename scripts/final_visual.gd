extends "res://scripts/visual_ship_hook.gd"

func _build_camera_canopy() -> void:
	var shell:=Node3D.new(); shell.name="CameraCanopy"; add_child(shell)
	var roof:=_mat(Color(0.13,0.15,0.20),Color(0.02,0.025,0.05),0.16,0.72,0.24)
	var steel:=_mat(Color(0.42,0.46,0.55),Color(0.03,0.04,0.07),0.16,0.66,0.18)
	var cyan:=_mat(Color(0.12,0.88,1.0),Color(0.0,0.70,1.0),2.5,0.12,0.06)
	_box(shell,Vector3(0,2.42,5.2),Vector3(9.5,0.25,10.2),roof)
	for x: float in [-3.5,-1.75,0.0,1.75,3.5]: _box(shell,Vector3(x,2.15,5.1),Vector3(0.72,0.14,9.4),steel)
	for side: float in [-1.0,1.0]: _box(shell,Vector3(side*3.82,1.84,4.8),Vector3(0.055,0.05,7.0),cyan)

func _build_ship() -> void:
	super._build_ship(); ship_visual.scale=Vector3(0.88,0.88,0.88)
	var white:=_mat(Color(0.92,0.94,1.0),Color(0.14,0.17,0.24),0.65,0.40,0.10)
	var steel:=_mat(Color(0.48,0.56,0.70),Color(0.04,0.07,0.12),0.32,0.72,0.13)
	var glass:=_mat(Color(0.035,0.15,0.24),Color(0.0,0.24,0.42),0.85,0.50,0.05)
	var cyan:=_mat(Color(0.10,0.95,1.0),Color(0.0,0.82,1.0),8.0,0.08,0.03)
	_box(ship_visual,Vector3(0,0.18,0.18),Vector3(0.62,0.18,1.65),white,Vector3(-4,0,0)); _box(ship_visual,Vector3(0,0.28,-0.48),Vector3(0.38,0.18,0.55),glass,Vector3(-8,0,0))
	for side: float in [-1.0,1.0]:
		_box(ship_visual,Vector3(side*0.58,0.10,0.28),Vector3(0.68,0.12,1.05),steel,Vector3(0,side*8,side*-8)); _box(ship_visual,Vector3(side*0.92,0.02,0.45),Vector3(0.72,0.08,0.48),white,Vector3(0,side*18,side*-12)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.22),0.18,0.22,white,Vector3(90,0,0)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.37),0.115,0.12,cyan,Vector3(90,0,0))
	var key:=OmniLight3D.new(); key.position=Vector3(-0.8,1.8,2.0); key.light_color=Color(1.0,0.96,0.90); key.light_energy=8.0; key.omni_range=6.0; ship_visual.add_child(key)
	var fill:=OmniLight3D.new(); fill.position=Vector3(1.2,0.8,1.6); fill.light_color=Color(0.30,0.62,1.0); fill.light_energy=4.2; fill.omni_range=5.0; ship_visual.add_child(fill)

func _make_world()->void:
	super._make_world(); camera.position=Vector3(0.04,-0.18,7.85); camera.rotation_degrees=Vector3(-0.8,-0.25,0); camera.fov=64.0
	for child in get_children():
		if child is WorldEnvironment and child.environment: child.environment.ambient_light_color=Color(0.38,0.40,0.50); child.environment.ambient_light_energy=1.8

func _reset_obstacle(area:Area3D,z:float)->void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	var metal:=_mat(Color(0.16,0.18,0.23),Color(0.01,0.012,0.02),0.08,0.78,0.24)
	var pale:=_mat(Color(0.62,0.66,0.72),Color(0.035,0.04,0.055),0.20,0.50,0.18)
	var yellow:=_mat(Color(1.0,0.58,0.025),Color(1.0,0.25,0.0),4.8,0.16,0.05)
	var red:=_mat(Color(0.95,0.05,0.035),Color(1.0,0.015,0.0),3.5,0.18,0.05)
	var type:=randi_range(0,3); var size:=Vector3(1,1,0.65)
	if type==0:
		# Suspended cargo pod: compact, readable, no giant wheel.
		_box(visual,Vector3.ZERO,Vector3(1.55,1.05,0.72),metal)
		_box(visual,Vector3(0,0,0.39),Vector3(1.18,0.72,0.08),pale)
		for x:float in [-0.52,0.52]: _box(visual,Vector3(x,0,0.46),Vector3(0.12,0.88,0.09),yellow,Vector3(0,0,22*x))
		for y:float in [-0.42,0.42]: _cylinder(visual,Vector3(0,y,0.48),0.095,0.10,red)
		size=Vector3(1.42,0.95,0.7)
	elif type==1:
		# Ceiling gate: two mechanical arms leave a clear opening below.
		_box(visual,Vector3(0,1.15,0),Vector3(4.7,0.42,0.62),metal)
		for x:float in [-1.75,1.75]:
			_box(visual,Vector3(x,0.38,0),Vector3(0.38,1.75,0.62),pale)
			_box(visual,Vector3(x,0.38,0.36),Vector3(0.12,1.42,0.08),yellow)
			_cylinder(visual,Vector3(x,-0.47,0.38),0.12,0.10,red)
		size=Vector3(4.25,2.15,0.7)
	elif type==2:
		# Side clamp: heavy machinery intrudes from one wall; opposite side stays readable.
		var side:float=-1.0 if randf()<0.5 else 1.0
		_box(visual,Vector3(side*1.45,0,0),Vector3(2.65,0.70,0.68),metal)
		_box(visual,Vector3(side*0.32,0,0.38),Vector3(0.18,0.56,0.09),yellow)
		_box(visual,Vector3(side*1.15,0,0.38),Vector3(0.72,0.12,0.09),pale)
		_cylinder(visual,Vector3(side*0.18,0,0.44),0.13,0.11,red)
		size=Vector3(2.7,0.72,0.7)
	else:
		# Split blast door: two chunky panels with a central escape gap.
		for side:float in [-1.0,1.0]:
			_box(visual,Vector3(side*1.30,0,0),Vector3(1.55,2.75,0.68),metal)
			_box(visual,Vector3(side*0.58,0,0.38),Vector3(0.10,2.25,0.09),yellow)
			for y:float in [-0.92,0.92]: _cylinder(visual,Vector3(side*0.55,y,0.44),0.10,0.10,red)
		size=Vector3(3.95,2.6,0.7)
	var collision:=area.get_child(1) as CollisionShape3D; (collision.shape as BoxShape3D).size=size*0.66
	var idx:=area.get_index()
	if idx==0: area.position=Vector3(-1.35,-0.35,-20.0)
	elif idx==1: area.position=Vector3(0,0.25,-31.0)
	elif idx==2: area.position=Vector3(1.1,-0.15,-43.0)
	else: area.position=Vector3(randf_range(-2.8,2.8),randf_range(-1.75,0.9),z)
	area.rotation_degrees.z=randf_range(-5.0,5.0)

func _update_camera(delta:float)->void:
	var target:=Vector3(0.04+ship.position.x*0.015,-0.18+ship.position.y*0.008,7.85); camera.position=camera.position.lerp(target,clampf(delta*1.5,0,1)); camera.fov=lerpf(camera.fov,64.0+(speed-13.0)*0.05,clampf(delta*1.2,0,1))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 2.3 // GATES"
