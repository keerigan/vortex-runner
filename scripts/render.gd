extends "res://scripts/extras.gd"

# ---------------------------------------------------------------------------
# Render / content layer (top of the chain, wired to main.tscn).
#
# Two things:
#
# 1. PERF - MultiMesh batching of the corridor sections. The 22 corridor
#    sections are pooled (built once, scrolled and recycled), and each holds
#    dozens of MeshInstance3D built by loops (for side / for z / for x ...),
#    so the same (mesh, material) pair is drawn many times inside one section.
#    After a section is fully built we collapse every such repeat group into a
#    single MultiMeshInstance3D: identical rendering, far fewer nodes and draw
#    calls. Safe because the mesh cache (optimize.gd) and material cache make
#    identical geometry share the SAME resource instance, and the per-frame
#    code only ever touches section.position - never a section's mesh children.
#
# 2. CONTENT - new hazards: the ROTATING GIRDER (a wide bar you thread by the
#    short side) and the HOMING SEEKER (a red-eyed drone that drifts toward your
#    lane while it approaches). Both reuse the existing swept silhouette collision
#    (collisions.gd) by refreshing the visual footprint after swapping the mesh;
#    the seeker only nudges its lane meta, which the existing per-frame code
#    re-applies, so no movement code is duplicated.
#
# 3. PERF - a pooled hit-flash: _flash fires on every near-miss/pickup/shield
#    event and used to allocate+free a mesh+material+tween each time; now a fixed
#    ring of nodes is reused.
#
# 4. UX - the menu overlays (shop / missions / music) are made mutually exclusive.
# ---------------------------------------------------------------------------

const GIRDER_MIN_SCORE := 220.0
const GIRDER_CHANCE := 0.22
const GIRDER_HALF_W := 1.24

# Homing seeker hazard.
const SEEKER_MIN_SCORE := 140.0
const SEEKER_CHANCE := 0.18       # rolled after the girder slice (mutually exclusive)
const SEEKER_TRACK_X := 1.7       # units/s the seeker drifts toward the ship's x
const SEEKER_TRACK_Y := 1.15      # slower vertical tracking

# Flash-effect object pool.
const FLASH_POOL := 12
const SPEED_STREAKS_EXTRA := 34
var _flash_pool: Array = []
var _flash_tweens: Array = []
var _flash_next := 0
var _hud_marks: Array[ColorRect] = []
var _speed_bars: Array[ColorRect] = []

# Continue-for-coins on death.
const CONTINUE_BASE_COST := 60      # first continue; doubles each time in a run
const CONTINUE_MAX := 5
const CONTINUE_SECONDS := 30.0
var _continue_used := 0
var _continue_active := false
var _continue_deadline := 0
var _continue_cost := 0
var _continue_panel: Control
var _continue_timer_label: Label
var _continue_coins_label: Label
var _continue_bar: ProgressBar
var _continue_btn: Button

func _ready() -> void:
	super._ready()
	_build_flash_pool()
	_build_continue_panel()

# --- 0. Visual depth / readability polish ---

func _make_world() -> void:
	super._make_world()
	_retune_environment()
	_add_chase_lights()

func _build_ship() -> void:
	super._build_ship()
	_add_ship_detail_lights()

func _retune_environment() -> void:
	for child in get_children():
		if child is WorldEnvironment and child.environment:
			var env := child.environment as Environment
			env.ambient_light_color = Color(0.30, 0.32, 0.42)
			env.ambient_light_energy = 1.55
			env.fog_light_color = Color(0.12, 0.17, 0.28)
			env.fog_light_energy = 0.85
			env.fog_density = 0.010
			env.glow_intensity = 0.50
			env.glow_strength = 0.95
			env.glow_hdr_threshold = 1.18

func _add_chase_lights() -> void:
	var left := SpotLight3D.new()
	left.position = Vector3(-2.6, 1.0, 5.6)
	left.rotation_degrees = Vector3(-8.0, 18.0, 0.0)
	left.light_color = Color(0.16, 0.72, 1.0)
	left.light_energy = 3.2
	left.spot_range = 12.0
	left.spot_angle = 34.0
	left.shadow_enabled = false
	add_child(left)

	var right := SpotLight3D.new()
	right.position = Vector3(2.6, 0.45, 4.8)
	right.rotation_degrees = Vector3(-6.0, -18.0, 0.0)
	right.light_color = Color(1.0, 0.36, 0.12)
	right.light_energy = 1.7
	right.spot_range = 10.0
	right.spot_angle = 28.0
	right.shadow_enabled = false
	add_child(right)

func _add_ship_detail_lights() -> void:
	if ship_visual == null:
		return
	var cyan := _mat(Color(0.18, 0.92, 1.0), Color(0.0, 0.75, 1.0), 2.8, 0.06, 0.04)
	var amber := _mat(Color(1.0, 0.50, 0.10), Color(1.0, 0.20, 0.02), 2.5, 0.05, 0.05)
	var red := _mat(Color(1.0, 0.08, 0.12), Color(1.0, 0.0, 0.04), 2.8, 0.06, 0.05)
	_box(ship_visual, Vector3(0.0, 0.45, -1.60), Vector3(0.40, 0.035, 0.055), cyan)
	_box(ship_visual, Vector3(0.0, 0.26, 0.82), Vector3(0.28, 0.035, 0.060), amber)
	for side: float in [-1.0, 1.0]:
		_box(ship_visual, Vector3(side * 1.88, 0.12, 0.42), Vector3(0.055, 0.050, 0.13), red if side < 0.0 else cyan)
		_box(ship_visual, Vector3(side * 1.16, 0.24, -0.36), Vector3(0.36, 0.030, 0.050), cyan, Vector3(0.0, side * -18.0, side * 30.0))

func _spawn_streaks() -> void:
	super._spawn_streaks()
	var fast := _mat(Color(0.42, 0.90, 1.0), Color(0.06, 0.74, 1.0), 2.2, 0.0, 0.08)
	var warm := _mat(Color(1.0, 0.48, 0.16), Color(1.0, 0.16, 0.02), 1.6, 0.0, 0.08)
	for i in range(SPEED_STREAKS_EXTRA):
		var edge := -1.0 if i % 2 == 0 else 1.0
		var x := randf_range(2.0, 4.35) * edge if i < 22 else randf_range(-3.8, 3.8)
		var y := randf_range(-2.65, 1.65)
		var streak_length := randf_range(1.1, 3.6)
		var width := randf_range(0.018, 0.045)
		_box(streak_root, Vector3(x, y, randf_range(-135.0, -18.0)), Vector3(width, width, streak_length), fast if i % 5 != 0 else warm)

func _make_ui() -> void:
	super._make_ui()
	_layout_primary_hud()
	_add_hud_frame()
	_add_speed_edge_bars()

func _layout_primary_hud() -> void:
	if ui_label:
		ui_label.position = Vector2(36, 34)
		ui_label.add_theme_font_size_override("font_size", 30)
	if _best_label:
		_best_label.position = Vector2(38, 74)
		_best_label.add_theme_font_size_override("font_size", 20)
	if _chain_label:
		_chain_label.position = Vector2(38, 190)
		_chain_label.add_theme_font_size_override("font_size", 34)
	for i in range(_hp_pips.size()):
		var pip := _hp_pips[i] as ColorRect
		pip.position = Vector2(38 + i * 34, 108)
		pip.size = Vector2(26, 10)
	if _boost_bg:
		_boost_bg.position = Vector2(38, 136)
		_boost_bg.size = Vector2(BAR_W, 10)
	if _boost_fill:
		_boost_fill.position = Vector2(38, 136)
	if _od_label:
		_od_label.position = Vector2(256, 126)
		_od_label.add_theme_font_size_override("font_size", 22)
	if _shield_label:
		_shield_label.position = Vector2(-328, 244)
		_shield_label.add_theme_font_size_override("font_size", 24)
	if _hud_backdrop:
		_hud_backdrop.position = Vector2(24, 22)
		_hud_backdrop.size = Vector2(312, 142)

func _add_hud_frame() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	var frame := Control.new()
	frame.name = "HudFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	layer.move_child(frame, 0)

	var cyan := Color(0.18, 0.86, 1.0, 0.42)
	var amber := Color(1.0, 0.55, 0.12, 0.36)
	var dim := Color(0.26, 0.42, 0.62, 0.18)
	for sx: float in [0.0, 1.0]:
		for sy: float in [0.0, 1.0]:
			var top_left := sx == 0.0 and sy == 0.0
			var top_right := sx == 1.0 and sy == 0.0
			var x := 360.0 if top_left else (810.0 if top_right else (34.0 if sx == 0.0 else 1080.0 - 154.0))
			var y := 194.0 if top_left else (330.0 if top_right else (34.0 if sy == 0.0 else 1920.0 - 154.0))
			_add_hud_rect(frame, Vector2(x, y), Vector2(120, 4), cyan if sy == 0.0 else amber)
			_add_hud_rect(frame, Vector2(x, y), Vector2(4, 120), cyan if sx == 0.0 else amber)
	for y: float in [390.0, 1530.0]:
		_add_hud_rect(frame, Vector2(96.0, y), Vector2(888.0, 2.0), dim)
	for x: float in [260.0, 540.0, 820.0]:
		_add_hud_rect(frame, Vector2(x, 1516.0), Vector2(2.0, 30.0), dim)

func _add_hud_rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("base_color", color)
	parent.add_child(r)
	_hud_marks.append(r)

func _add_speed_edge_bars() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	for side: float in [0.0, 1.0]:
		for i in range(9):
			var bar := ColorRect.new()
			bar.position = Vector2(12.0 if side == 0.0 else 1080.0 - 24.0, 520.0 + float(i) * 74.0)
			bar.size = Vector2(12.0, 42.0)
			bar.color = Color(0.15, 0.82, 1.0, 0.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.set_meta("side", side)
			bar.set_meta("idx", i)
			layer.add_child(bar)
			layer.move_child(bar, 0)
			_speed_bars.append(bar)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.018, 0.035, 0.90)
	sb.border_color = Color(0.18, 0.86, 1.0, 0.58)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(42)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0.0, 8.0)
	return sb

# --- 1. MultiMesh batching ---

func _build_corridor_section(section: Node3D, index: int) -> void:
	super._build_corridor_section(section, index)
	_add_depth_gate(section, index)
	_add_runway_marks(section, index)
	_batch_section(section)

func _rebuild_section_for_biome(section: Node3D, biome: int, serial: int) -> void:
	super._rebuild_section_for_biome(section, biome, serial)
	_add_depth_gate(section, serial)
	_add_runway_marks(section, serial)
	_batch_section(section)

func _add_depth_gate(section: Node3D, index: int) -> void:
	var frame := _mat(Color(0.58, 0.62, 0.70), Color(0.05, 0.07, 0.10), 0.22, 0.62, 0.20)
	var shadow := _mat(Color(0.015, 0.020, 0.032), Color(0.0, 0.0, 0.0), 0.0, 0.88, 0.22)
	var cyan := _mat(Color(0.12, 0.92, 1.0), Color(0.0, 0.74, 1.0), 4.4, 0.10, 0.05)
	var amber := _mat(Color(1.0, 0.42, 0.08), Color(1.0, 0.18, 0.02), 3.5, 0.12, 0.06)
	for z: float in [-3.15, 0.0, 3.15]:
		if int(absf(z) * 10.0 + float(index)) % 2 == 0:
			for side: float in [-1.0, 1.0]:
				_box(section, Vector3(side * 4.12, -0.28, z), Vector3(0.18, 4.55, 0.16), frame, Vector3(0.0, 0.0, side * 5.0))
				_box(section, Vector3(side * 3.88, 1.20, z), Vector3(0.065, 0.70, 0.08), cyan if side < 0.0 else amber)
			_box(section, Vector3(0.0, 1.76, z), Vector3(7.35, 0.16, 0.16), frame)
			_box(section, Vector3(0.0, -2.98, z), Vector3(5.8, 0.055, 0.10), shadow)

func _add_runway_marks(section: Node3D, index: int) -> void:
	var lane := _mat(Color(0.20, 0.86, 1.0), Color(0.0, 0.58, 1.0), 2.8, 0.05, 0.05)
	var warning := _mat(Color(1.0, 0.58, 0.08), Color(1.0, 0.22, 0.0), 3.0, 0.08, 0.06)
	for z: float in [-2.45, -0.80, 0.85, 2.50]:
		var mat := warning if (index + int((z + 3.0) * 2.0)) % 5 == 0 else lane
		_box(section, Vector3(-0.62, -2.93, z), Vector3(0.30, 0.035, 0.16), mat)
		_box(section, Vector3(0.62, -2.93, z), Vector3(0.30, 0.035, 0.16), mat)

# Collapse repeated (mesh, material) MeshInstance3D children of a section into
# one MultiMeshInstance3D each. Singletons and lights are left untouched.
func _batch_section(section: Node3D) -> void:
	var groups: Dictionary = {}
	for child in section.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh == null:
				continue
			var mat := mi.material_override
			var key := "%d|%d" % [mi.mesh.get_instance_id(), mat.get_instance_id() if mat else 0]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(mi)
	for key in groups:
		var arr: Array = groups[key]
		if arr.size() < 2:
			continue
		var first: MeshInstance3D = arr[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = first.mesh
		mm.instance_count = arr.size()
		for i in range(arr.size()):
			var mi: MeshInstance3D = arr[i]
			mm.set_instance_transform(i, mi.transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = first.material_override
		section.add_child(mmi)
		for mi: MeshInstance3D in arr:
			mi.free()

# --- 2. Rotating girder hazard ---

func _reset_obstacle(area: Area3D, z: float) -> void:
	super._reset_obstacle(area, z)
	area.set_meta("homing", false)   # cleared unless this recycle becomes a seeker
	# Keep the position/spin/lane super just set; only swap the shape sometimes.
	# One roll partitions the slice: girder, then seeker, else the normal hazard.
	var r := randf()
	if score > GIRDER_MIN_SCORE and r < GIRDER_CHANCE:
		_make_girder(area)
	elif score > SEEKER_MIN_SCORE and r < GIRDER_CHANCE + SEEKER_CHANCE:
		_make_seeker(area)
	_add_hazard_telegraph(area)

func _make_girder(area: Area3D) -> void:
	var visual := area.get_child(0) as Node3D
	if visual == null:
		return
	for child in visual.get_children():
		child.free()
	_clear_extra_collisions(area)
	var body := _mat(Color(0.11, 0.12, 0.15), Color(0.02, 0.02, 0.03), 0.06, 0.85, 0.20)
	var warn := _mat(Color(1.0, 0.55, 0.02), Color(1.0, 0.34, 0.0), 4.2, 0.10, 0.06)
	# Central bar spanning the tunnel: the long axis you must avoid.
	_box(visual, Vector3(0.0, 0.0, 0.0), Vector3(GIRDER_HALF_W * 2.0, 0.34, 0.5), body)
	# Hazard stripes down the bar so its angle reads at a glance.
	for x: float in [-0.82, -0.28, 0.28, 0.82]:
		_box(visual, Vector3(x, 0.0, 0.27), Vector3(0.20, 0.30, 0.05), warn)
	# Bright end caps mark where the short side (the gap to thread) is.
	for s: float in [-1.0, 1.0]:
		_box(visual, Vector3(s * GIRDER_HALF_W, 0.0, 0.0), Vector3(0.16, 0.46, 0.5), warn)
	_set_primary_box(area, Vector3(GIRDER_HALF_W * 2.0, 0.34, 0.5), Vector3.ZERO)
	# The live collision test reads the visual silhouette, so refresh it.
	var fp := _visual_footprint(area)
	area.set_meta("fpx", fp.x)
	area.set_meta("fpy", fp.y)

# --- 3. Homing seeker hazard ---
# A compact drone with a red eye that drifts toward the ship's lane while it
# approaches, then locks in close so it can't chase you into a corner at point
# blank. It tracks slower than the ship steers, so it's a lead-your-dodge threat,
# not an unavoidable one. Only the base lane meta is nudged (in _update_world);
# the existing per-frame code re-applies it, so no movement code is duplicated.
func _make_seeker(area: Area3D) -> void:
	var visual := area.get_child(0) as Node3D
	if visual == null:
		return
	for child in visual.get_children():
		child.free()
	_clear_extra_collisions(area)
	var hull := _mat(Color(0.15, 0.05, 0.06), Color(0.06, 0.01, 0.01), 0.10, 0.72, 0.20)
	var eye := _mat(Color(1.0, 0.14, 0.08), Color(1.0, 0.0, 0.0), 6.0, 0.05, 0.05)
	_box(visual, Vector3(0.0, 0.0, 0.0), Vector3(0.5, 0.34, 0.5), hull)
	# Forward-facing red eye (toward the camera at +z) telegraphs "I'm tracking you".
	_box(visual, Vector3(0.0, 0.0, 0.30), Vector3(0.24, 0.24, 0.06), eye)
	# Angled fins either side.
	for s: float in [-1.0, 1.0]:
		_box(visual, Vector3(s * 0.42, 0.0, 0.0), Vector3(0.34, 0.07, 0.32), hull, Vector3(0.0, 0.0, s * 14.0))
	_set_primary_box(area, Vector3(0.6, 0.42, 0.5), Vector3.ZERO)
	var fp := _visual_footprint(area)
	area.set_meta("fpx", fp.x)
	area.set_meta("fpy", fp.y)
	area.set_meta("homing", true)

func _add_hazard_telegraph(area: Area3D) -> void:
	var visual := area.get_child(0) as Node3D
	if visual == null:
		return
	var hot := _mat(Color(1.0, 0.20, 0.06), Color(1.0, 0.03, 0.0), 4.5, 0.02, 0.04)
	var rim := _mat(Color(1.0, 0.62, 0.12), Color(1.0, 0.24, 0.02), 2.6, 0.04, 0.08)
	var fp := _visual_footprint(area)
	var radius := clampf(maxf(fp.x, fp.y) * 0.60 + 0.18, 0.42, 1.25)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.045
	torus.rings = 18
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = hot
	ring.position.z = 0.36
	ring.rotation_degrees.x = 90.0
	visual.add_child(ring)

	for x: float in [-radius, radius]:
		_box(visual, Vector3(x, 0.0, 0.39), Vector3(0.08, 0.20, 0.05), rim)
	for y: float in [-radius, radius]:
		_box(visual, Vector3(0.0, y, 0.39), Vector3(0.20, 0.08, 0.05), rim)

func _update_world(delta: float) -> void:
	super._update_world(delta)
	if not (started and alive):
		return
	for child in obstacle_root.get_children():
		var area := child as Area3D
		if not bool(area.get_meta("homing", false)):
			continue
		var az := area.position.z
		# Track only while approaching from a distance; lock once close (fair).
		if az < -4.0 and az > -70.0:
			var bx := float(area.get_meta("base_x", area.position.x))
			var by := float(area.get_meta("base_y", area.position.y))
			bx = move_toward(bx, ship.position.x, SEEKER_TRACK_X * delta)
			by = move_toward(by, ship.position.y, SEEKER_TRACK_Y * delta)
			area.set_meta("base_x", bx)
			area.set_meta("base_y", by)

# --- 4. Pooled hit flashes ---
# _flash fires on every near-miss (very frequent), pickup and shield event, and
# each call used to allocate a MeshInstance3D + material + tween then free them.
# Reuse a fixed ring of flash nodes instead: no steady allocation churn.
func _build_flash_pool() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	for i in range(FLASH_POOL):
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.metallic = 0.0
		mat.roughness = 0.1
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.visible = false
		add_child(m)
		_flash_pool.append(m)
		_flash_tweens.append(null)

func _flash(pos: Vector3, color: Color) -> void:
	if _flash_pool.is_empty():
		super._flash(pos, color)
		return
	var idx := _flash_next
	_flash_next = (_flash_next + 1) % _flash_pool.size()
	var m: MeshInstance3D = _flash_pool[idx]
	var mat: StandardMaterial3D = m.material_override
	var prev: Tween = _flash_tweens[idx]
	if prev != null and prev.is_valid():
		prev.kill()
	m.position = pos
	m.scale = Vector3.ONE
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	m.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(3.0, 3.0, 3.0), 0.35)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void: m.visible = false)
	_flash_tweens[idx] = tw

# --- 5. Continue for coins ---
# On death, if the player can afford it, offer a revive for coins with a 30 s
# countdown; if it runs out (or they pick MENU) the offer ends. The payout is
# banked in shop._hit at every death, so a revive UNDOES this death's payout
# (_last_payout) to avoid double-counting - the final death banks the full run.

func _build_continue_panel() -> void:
	var layer := _hud_layer()
	if layer == null:
		return
	var panel := _centered_panel(layer)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	_continue_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label("CONTINUER ?", 52, Color(1.0, 0.85, 0.3)))
	_continue_coins_label = _label("PIÈCES : 0", 34, Color(1.0, 0.82, 0.35))
	box.add_child(_continue_coins_label)
	_continue_timer_label = _label("30 s", 40, Color(0.9, 0.95, 1.0))
	box.add_child(_continue_timer_label)
	_continue_bar = ProgressBar.new()
	_continue_bar.min_value = 0.0
	_continue_bar.max_value = 100.0
	_continue_bar.value = 100.0
	_continue_bar.show_percentage = false
	_continue_bar.custom_minimum_size = Vector2(460, 22)
	box.add_child(_continue_bar)
	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(480, 110)
	_continue_btn.add_theme_font_size_override("font_size", 40)
	_continue_btn.pressed.connect(_do_continue)
	box.add_child(_continue_btn)
	var retry := Button.new()
	retry.text = "REJOUER"
	retry.custom_minimum_size = Vector2(340, 90)
	retry.add_theme_font_size_override("font_size", 34)
	retry.pressed.connect(_play_again)
	box.add_child(retry)
	var menu := Button.new()
	menu.text = "MENU"
	menu.custom_minimum_size = Vector2(300, 82)
	menu.add_theme_font_size_override("font_size", 30)
	menu.pressed.connect(_to_menu)
	box.add_child(menu)

func _next_continue_cost() -> int:
	return CONTINUE_BASE_COST * int(pow(2, _continue_used))

func _show_game_over() -> void:
	var cost := _next_continue_cost()
	# Spendable = banked coins minus the payout shop._hit just added for THIS death
	# (that payout is only real if the run truly ends here).
	if _continue_used < CONTINUE_MAX and _continue_panel != null and (coins - _last_payout) >= cost:
		_offer_continue(cost)
	else:
		super._show_game_over()

func _offer_continue(cost: int) -> void:
	_continue_active = true
	_continue_cost = cost
	_continue_deadline = Time.get_ticks_msec() + int(CONTINUE_SECONDS * 1000.0)
	if game_over_label:
		game_over_label.visible = false
	if _pause_button:
		_pause_button.visible = false
	if _continue_coins_label:
		# Spendable = banked coins minus this death's not-yet-final payout.
		_continue_coins_label.text = "PIÈCES : %d" % (coins - _last_payout)
	if _continue_btn:
		_continue_btn.text = "CONTINUER  -%d ⛁" % cost
	if _continue_bar:
		_continue_bar.value = 100.0
	if _continue_timer_label:
		_continue_timer_label.text = "%d s" % int(CONTINUE_SECONDS)
	_continue_panel.visible = true

func _process(delta: float) -> void:
	super._process(delta)
	_update_visual_pulse(delta)
	if not _continue_active:
		return
	var left := float(_continue_deadline - Time.get_ticks_msec()) / 1000.0
	if left <= 0.0:
		_end_continue_offer()
		_to_menu()
		return
	if _continue_timer_label:
		_continue_timer_label.text = "%d s" % int(ceil(left))
	if _continue_bar:
		_continue_bar.value = clampf(left / CONTINUE_SECONDS * 100.0, 0.0, 100.0)

func _update_visual_pulse(_delta: float) -> void:
	var speed_ratio := clampf((speed - 13.0) / maxf(max_speed - 13.0, 1.0), 0.0, 1.0)
	var active := started and alive
	var od := _overdrive_active()
	var t := float(Time.get_ticks_msec()) * 0.001
	var pulse := 0.70 + 0.30 * sin(t * (2.2 + speed_ratio * 3.0))
	for mark in _hud_marks:
		if mark == null:
			continue
		var base: Color = mark.get_meta("base_color", mark.color)
		var alpha := base.a * (0.55 if not active else 0.82 + speed_ratio * 0.35 + pulse * 0.18)
		if od:
			alpha = maxf(alpha, base.a * 1.35)
		mark.color = Color(base.r, base.g, base.b, clampf(alpha, 0.0, 0.86))
	for bar in _speed_bars:
		if bar == null:
			continue
		var idx := int(bar.get_meta("idx", 0))
		var side := float(bar.get_meta("side", 0.0))
		var phase := fmod(t * (1.8 + speed_ratio * 4.0) + float(idx) * 0.18 + side * 0.4, 1.0)
		var alpha := 0.0 if not active else clampf((1.0 - phase) * speed_ratio * 0.42, 0.0, 0.38)
		if od:
			alpha = maxf(alpha, 0.18 + (1.0 - phase) * 0.42)
		var col := Color(1.0, 0.72, 0.18, alpha) if od else Color(0.14, 0.84, 1.0, alpha)
		bar.color = col
		bar.position.y = 520.0 + float(idx) * 74.0 + phase * 42.0

func _end_continue_offer() -> void:
	_continue_active = false
	if _continue_panel:
		_continue_panel.visible = false

func _do_continue() -> void:
	if not _continue_active or coins - _last_payout < _continue_cost:
		return
	# Pay the cost, and undo this death's payout since the run isn't over.
	coins -= _continue_cost
	coins -= _last_payout
	if coins < 0:
		coins = 0
	_save_shop()
	_update_coin_labels()
	_continue_used += 1
	_end_continue_offer()
	_revive()

func _revive() -> void:
	alive = true
	speed = 13.0
	Engine.time_scale = 1.0
	hp = max_hp
	shield_charges = maxi(shield_charges, 1)
	_invuln_ms = Time.get_ticks_msec() + 2500
	if game_over_label:
		game_over_label.visible = false
	if ship_visual:
		ship_visual.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		ship_visual.visible = true
	if _pause_button:
		_pause_button.visible = true
	# Clear anything close so the player doesn't die again instantly.
	if obstacle_root:
		for child in obstacle_root.get_children():
			var area := child as Area3D
			if area.position.z > -30.0:
				_reset_obstacle(area, randf_range(-190.0, -140.0))
	_update_health_ui()

func _unhandled_input(event: InputEvent) -> void:
	# While the continue offer is up, swallow taps so the tap-to-restart handler
	# lower in the chain doesn't reload the scene behind the panel.
	if _continue_active:
		return
	super._unhandled_input(event)

# --- 6. Menu overlays are mutually exclusive ---
# Shop / Missions / Music panels each just set themselves visible, so they used
# to stack on top of each other. Opening one now closes the others first.

func _close_menu_overlays(keep: String) -> void:
	if keep != "shop" and _shop_panel:
		_shop_panel.visible = false
	if keep != "missions" and _mission_panel:
		_mission_panel.visible = false
	if keep != "music" and music_panel:
		music_panel.visible = false

func _open_shop() -> void:
	_close_menu_overlays("shop")
	super._open_shop()

func _open_missions() -> void:
	_close_menu_overlays("missions")
	super._open_missions()

func _toggle_music_panel() -> void:
	# Only clear the others when this action is about to OPEN the music panel.
	if music_panel and not music_panel.visible:
		_close_menu_overlays("music")
	super._toggle_music_panel()
