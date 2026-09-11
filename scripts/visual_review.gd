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

func _capture(game: Node, score_value: float, filename: String) -> bool:
	game.score = score_value
	var biome := game._current_biome()
	for section in game.corridor_root.get_children():
		game._rebuild_section_for_biome(section, biome, section.get_index())
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	return _save_frame(filename)

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
	await get_tree().create_timer(0.7).timeout
	if not await _capture(game, 0.0, "visual-review-industrial.png"):
		get_tree().quit(1); return
	if not await _capture(game, 700.0, "visual-review-reactor.png"):
		get_tree().quit(1); return
	if not await _capture(game, 1350.0, "visual-review-energy.png"):
		get_tree().quit(1); return
	if not await _capture(game, 2000.0, "visual-review-lab.png"):
		get_tree().quit(1); return
	if not _save_frame("visual-review.png"):
		get_tree().quit(1); return
	await get_tree().create_timer(1.0).timeout
	if not _save_frame("visual-review-close.png"):
		get_tree().quit(1); return
	get_tree().quit()
