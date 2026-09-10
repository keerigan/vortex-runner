extends "res://scripts/visual_ship_hook.gd"

func _build_camera_canopy()->void:
	var shell:=Node3D.new(); shell.name="CameraCanopy"; add_child(shell)
	var roof:=_mat(Color(0.13,0.15,0.20),Color(0.02,0.025,0.05),0.16,0.72,0.24); var steel:=_mat(Color(0.42,0.46,0.55),Color(0.03,0.04,0.07),0.16,0.66,0.18); var cyan:=_mat(Color(0.12,0.88,1.0),Color(0,0.70,1),2.5,0.12,0.06)
	_box(shell,Vector3(0,2.42,5.2),Vector3(9.5,0.25,10.2),roof)
	for x:float in [-3.5,-1.75,0.0,1.75,3.5]: _box(shell,Vector3(x,2.15,5.1),Vector3(0.72,0.14,9.4),steel)
	for side:float in [-1.0,1.0]: _box(shell,Vector3(side*3.82,1.84,4.8),Vector3(0.055,0.05,7.0),cyan)

func _build_ship()->void:
	super._build_ship(); ship_visual.scale=Vector3(0.88,0.88,0.88)
	var white:=_mat(Color(0.92,0.94,1),Color(0.14,0.17,0.24),0.65,0.40,0.10); var steel:=_mat(Color(0.48,0.56,0.70),Color(0.04,0.07,0.12),0.32,0.72,0.13); var glass:=_mat(Color(0.035,0.15,0.24),Color(0,0.24,0.42),0.85,0.50,0.05); var cyan:=_mat(Color(0.10,0.95,1),Color(0,0.82,1),8,0.08,0.03)
	_box(ship_visual,Vector3(0,0.18,0.18),Vector3(0.62,0.18,1.65),white,Vector3(-4,0,0)); _box(ship_visual,Vector3(0,0.28,-0.48),Vector3(0.38,0.18,0.55),glass,Vector3(-8,0,0))
	for side:float in [-1.0,1.0]: _box(ship_visual,Vector3(side*0.58,0.10,0.28),Vector3(0.68,0.12,1.05),steel,Vector3(0,side*8,side*-8)); _box(ship_visual,Vector3(side*0.92,0.02,0.45),Vector3(0.72,0.08,0.48),white,Vector3(0,side*18,side*-12)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.22),0.18,0.22,white,Vector3(90,0,0)); _cylinder(ship_visual,Vector3(side*0.38,-0.02,1.37),0.115,0.12,cyan,Vector3(90,0,0))
	var key:=OmniLight3D.new(); key.position=Vector3(-0.8,1.8,2); key.light_color=Color(1,0.96,0.90); key.light_energy=8; key.omni_range=6; ship_visual.add_child(key)
	var fill:=OmniLight3D.new(); fill.position=Vector3(1.2,0.8,1.6); fill.light_color=Color(0.30,0.62,1); fill.light_energy=4.2; fill.omni_range=5; ship_visual.add_child(fill)

func _make_world()->void:
	super._make_world(); camera.position=Vector3(0.04,-0.18,7.85); camera.rotation_degrees=Vector3(-0.8,-0.25,0); camera.fov=64
	for child in get_children():
		if child is WorldEnvironment and child.environment: child.environment.ambient_light_color=Color(0.38,0.40,0.50); child.environment.ambient_light_energy=1.8

func _reset_obstacle(area:Area3D,z:float)->void:
	var visual:=area.get_child(0) as Node3D
	for child in visual.get_children(): child.queue_free()
	var graphite:=_mat(Color(0.075,0.085,0.11),Color(0.006,0.007,0.012),0.04,0.88,0.22)
	var armor:=_mat(Color(0.70,0.73,0.78),Color(0.035,0.040,0.055),0.22,0.48,0.18)
	var hazard:=_mat(Color(1.0,0.36,0.015),Color(1.0,0.10,0.0),5.5,0.12,0.04)
	var red:=_mat(Color(0.95,0.035,0.025),Color(1.0,0.0,0.0),4.0,0.12,0.04)
	var type:=randi_range(0,3)
	var size:=Vector3(1.2,1.0,0.65)
	if type==0:
		# Interceptor drone: compact body + swept shoulders + central warning eye.
		_box(visual,Vector3(0,0,0),Vector3(0.72,0.34,0.78),graphite)
		_box(visual,Vector3(0,0.24,0.08),Vector3(0.40,0.16,0.54),armor,Vector3(-12,0,0))
		for side:float in [-1.0,1.0]:
			_box(visual,Vector3(side*0.58,0,0.05),Vector3(0.70,0.14,0.46),armor,Vector3(0,side*16,side*-18))
			_box(visual,Vector3(side*0.82,-0.03,0.07),Vector3(0.30,0.09,0.36),graphite,Vector3(0,side*28,side*-20))
		_cylinder(visual,Vector3(0,0,0.46),0.16,0.13,red)
		size=Vector3(1.65,0.72,0.70)
	elif type==1:
		# Armoured diamond mine: four short vanes, no wheel silhouette.
		_box(visual,Vector3.ZERO,Vector3(0.86,0.86,0.62),graphite,Vector3(0,0,45))
		_box(visual,Vector3(0,0,0.34),Vector3(0.52,0.52,0.08),armor,Vector3(0,0,45))
		for a:float in [0,90]:
			_box(visual,Vector3.ZERO,Vector3(1.48,0.12,0.34),armor,Vector3(0,0,a+45))
			_box(visual,Vector3(0,0,0.30),Vector3(1.12,0.055,0.08),hazard,Vector3(0,0,a+45))
		_cylinder(visual,Vector3(0,0,0.42),0.13,0.10,red)
		size=Vector3(1.30,1.30,0.62)
	elif type==2:
		# Twin cargo cells: asymmetrical industrial debris with a clear gap in the silhouette.
		for side:float in [-1.0,1.0]:
			_box(visual,Vector3(side*0.46,side*0.12,0),Vector3(0.62,0.82,0.64),graphite,Vector3(0,0,side*8))
			_box(visual,Vector3(side*0.46,side*0.12,0.35),Vector3(0.44,0.52,0.08),armor,Vector3(0,0,side*8))
			_box(visual,Vector3(side*0.46,side*0.12,0.40),Vector3(0.08,0.42,0.06),hazard,Vector3(0,0,side*8))
		_box(visual,Vector3(0,0,0.03),Vector3(0.30,0.16,0.52),armor,Vector3(0,0,-18))
		size=Vector3(1.28,1.18,0.66)
	else:
		# Spear beacon: one directional hazard, slender but with a substantial mechanical head.
		_box(visual,Vector3(0,0,0),Vector3(0.34,1.52,0.56),graphite,Vector3(0,0,22))
		_box(visual,Vector3(0,0,0.32),Vector3(0.08,1.12,0.07),hazard,Vector3(0,0,22))
		_box(visual,Vector3(0,0.62,0.02),Vector3(0.72,0.32,0.58),armor,Vector3(0,0,22))
		_box(visual,Vector3(0,-0.62,0.02),Vector3(0.72,0.32,0.58),armor,Vector3(0,0,22))
		_cylinder(visual,Vector3(0,0.72,0.38),0.10,0.10,red)
		size=Vector3(0.82,1.62,0.62)
	var glow:=OmniLight3D.new(); glow.position=Vector3(0,0,0.6); glow.light_color=Color(1.0,0.16,0.03); glow.light_energy=1.7; glow.omni_range=2.1; visual.add_child(glow)
	var collision:=area.get_child(1) as CollisionShape3D; (collision.shape as BoxShape3D).size=size*0.66
	var idx:=area.get_index()
	if idx==0: area.position=Vector3(-1.15,-0.20,-20)
	elif idx==1: area.position=Vector3(1.25,0.35,-32)
	elif idx==2: area.position=Vector3(-0.60,-0.40,-45)
	else: area.position=Vector3(randf_range(-3.0,3.0),randf_range(-1.9,1.05),z)
	area.rotation_degrees.z=randf_range(-8,8)

func _update_camera(delta:float)->void:
	var target:=Vector3(0.04+ship.position.x*0.015,-0.18+ship.position.y*0.008,7.85); camera.position=camera.position.lerp(target,clampf(delta*1.5,0,1)); camera.fov=lerpf(camera.fov,64+(speed-13)*0.05,clampf(delta*1.2,0,1))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 2.5 // HAZARD PASS"
