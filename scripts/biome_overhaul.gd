extends "res://scripts/final_visual.gd"

func _decorate_biome(section:Node3D,biome:int,index:int)->void:
	super._decorate_biome(section,biome,index)
	if biome==0:
		return
	if biome==1:
		# Reactor: unmistakable hot industrial sector with red bulkheads and floor heat strips.
		var black:=_mat(Color(0.035,0.025,0.025),Color(0.01,0.0,0.0),0.05,0.90,0.18)
		var red:=_mat(Color(0.48,0.055,0.025),Color(0.85,0.025,0.0),1.8,0.55,0.14)
		var amber:=_mat(Color(1.0,0.34,0.02),Color(1.0,0.12,0.0),5.5,0.10,0.04)
		var copper:=_mat(Color(0.38,0.20,0.10),Color(0.035,0.008,0.002),0.10,0.82,0.20)
		_box(section,Vector3(0,-3.08,0),Vector3(7.1,0.07,SECTION_LENGTH*0.94),black)
		for x:float in [-2.85,-1.9,1.9,2.85]: _box(section,Vector3(x,-3.00,0),Vector3(0.10,0.035,SECTION_LENGTH*0.90),amber)
		for side:float in [-1.0,1.0]:
			_box(section,Vector3(side*4.00,-0.35,0),Vector3(0.44,4.4,SECTION_LENGTH*0.90),red,Vector3(0,0,side*6))
			_cylinder(section,Vector3(side*3.62,-1.15,0),0.18,SECTION_LENGTH*0.90,copper,Vector3(90,0,0))
			_cylinder(section,Vector3(side*3.62,0.20,0),0.14,SECTION_LENGTH*0.90,copper,Vector3(90,0,0))
		if index%2==0:
			_box(section,Vector3(-3.85,0,-2.85),Vector3(0.42,5.2,0.28),red,Vector3(0,0,-6))
			_box(section,Vector3(3.85,0,-2.85),Vector3(0.42,5.2,0.28),red,Vector3(0,0,6))
			_box(section,Vector3(0,2.20,-2.85),Vector3(7.5,0.30,0.28),black)
			_box(section,Vector3(0,1.98,-2.82),Vector3(5.8,0.08,0.06),amber)
	elif biome==2:
		# Energy: luminous lattice / accelerator tunnel, very different from the base industrial corridor.
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
		# Laboratory: white clean-room shell, broad ceiling lights and pale floor plates.
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
		target_energy=1.55; target_fog_density=0.014
	elif biome==2:
		target_energy=1.35; target_fog_density=0.010
	elif biome==3:
		target_energy=2.35; target_fog_density=0.004
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.ambient_light_energy=lerpf(child.environment.ambient_light_energy,target_energy,clampf(delta*0.8,0,1))
			child.environment.fog_density=lerpf(child.environment.fog_density,target_fog_density,clampf(delta*0.8,0,1))

func _make_ui()->void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"): control.text="VORTEX // RUNNER 3.2 // BIOMES"
