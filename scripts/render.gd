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
var _flash_pool: Array = []
var _flash_tweens: Array = []
var _flash_next := 0

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

# --- 1. MultiMesh batching ---

func _build_corridor_section(section: Node3D, index: int) -> void:
	super._build_corridor_section(section, index)
	_batch_section(section)

func _rebuild_section_for_biome(section: Node3D, biome: int, serial: int) -> void:
	super._rebuild_section_for_biome(section, biome, serial)
	_batch_section(section)

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
