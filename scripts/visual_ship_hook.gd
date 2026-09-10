extends "res://scripts/visual_overhaul.gd"

func _build_ship() -> void:
	super._build_ship()
	var upgrade = load("res://scripts/ship_upgrade.gd")
	if upgrade:
		upgrade.decorate(self, ship_visual, Callable(self, "_box"), Callable(self, "_cylinder"), Callable(self, "_mat"))

func _make_ui() -> void:
	super._make_ui()
	for child in get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Label and control.text.begins_with("VORTEX // RUNNER"):
					control.text = "VORTEX // RUNNER 1.0 // REVIEW"
