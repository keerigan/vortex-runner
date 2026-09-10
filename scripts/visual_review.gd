extends Node3D

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
	await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	var output := OS.get_environment("GITHUB_WORKSPACE")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://")
	var path := output.path_join("visual-review.png")
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save visual review screenshot: %s" % err)
		get_tree().quit(1)
		return
	print("VISUAL_REVIEW_SAVED=" + path)
	get_tree().quit()
