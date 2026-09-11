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
	# Force corridor sections to recycle immediately so the requested biome is visible.
	for section in game.corridor_root.get_children():
		section.position.z = 10.0
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
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
	# Keep legacy names for the existing review workflow / quick comparison.
	if not _save_frame("visual-review.png"):
		get_tree().quit(1); return
	await get_tree().create_timer(1.0).timeout
	if not _save_frame("visual-review-close.png"):
		get_tree().quit(1); return
	get_tree().quit()
