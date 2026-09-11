extends Node3D

func _save_frame(filename: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	var output := OS.get_environment("GITHUB_WORKSPACE")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://")
	var path := output.path_join(filename)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save visual review screenshot: %s" % err)
		return false
	print("VISUAL_REVIEW_SAVED=" + path)
	return true

func _capture_biome(game: Node, score_value: float, filename: String) -> bool:
	game.score = score_value
	var biome: int = int(game._current_biome())
	for section in game.corridor_root.get_children():
		game._rebuild_section_for_biome(section, biome, section.get_index())
	game.obstacle_root.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	return _save_frame(filename)

func _capture_obstacles(game: Node) -> bool:
	game.score = 0.0
	for section in game.corridor_root.get_children():
		game._rebuild_section_for_biome(section, 0, section.get_index())
	game.obstacle_root.visible = true
	var fixed_positions: Array[Vector3] = [Vector3(-1.55,-0.15,-8.5), Vector3(1.45,0.30,-12.5), Vector3(-0.25,-0.48,-16.5)]
	var count: int = mini(3, game.obstacle_root.get_child_count())
	for i in range(count):
		var area := game.obstacle_root.get_child(i) as Area3D
		area.set_meta("forced_hazard",i)
		game._reset_obstacle(area,fixed_positions[i].z)
		area.position = fixed_positions[i]
		area.rotation_degrees = Vector3.ZERO
	for i in range(count, game.obstacle_root.get_child_count()):
		game.obstacle_root.get_child(i).visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	return _save_frame("visual-review-obstacles.png")

func _capture_audio_menu(game: Node) -> bool:
	if game.music_panel == null:
		push_error("Audio menu unavailable in visual review")
		return false
	game.music_panel.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var ok := _save_frame("visual-review-audio-menu.png")
	game.music_panel.visible = false
	return ok

func _ready() -> void:
	var scene := load("res://main.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene for visual review")
		get_tree().quit(1)
		return
	var game := scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process_input(false)
	await get_tree().create_timer(0.35).timeout
	if not await _capture_biome(game, 0.0, "visual-review-industrial.png"):
		get_tree().quit(1); return
	if not await _capture_biome(game, 700.0, "visual-review-reactor.png"):
		get_tree().quit(1); return
	if not await _capture_biome(game, 1350.0, "visual-review-energy.png"):
		get_tree().quit(1); return
	if not await _capture_biome(game, 2000.0, "visual-review-lab.png"):
		get_tree().quit(1); return
	if not await _capture_obstacles(game):
		get_tree().quit(1); return
	if not await _capture_audio_menu(game):
		get_tree().quit(1); return
	if not _save_frame("visual-review.png"):
		get_tree().quit(1); return
	await get_tree().create_timer(0.25).timeout
	if not _save_frame("visual-review-close.png"):
		get_tree().quit(1); return
	get_tree().quit()
