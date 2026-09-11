extends "res://scripts/juice.gd"

# ---------------------------------------------------------------------------
# Collision overhaul (top of the chain, wired to main.tscn).
#
# The old test asked, every frame, "is the ship inside this small collision box
# right now?". At speed a hazard jumps past the ship's depth between two frames
# so the answer was "no" on every frame it mattered, and the internal boxes were
# smaller than the meshes you see - hence hazards you clearly touched doing
# nothing.
#
# This replaces it with a SWEPT plane-crossing test. The ship sits at a fixed
# depth; each frame we detect the exact moment a hazard crosses that depth and
# test the ship against the hazard's real on-screen silhouette (its visual AABB,
# oriented with the hazard's spin). A crossing can never be skipped, whatever the
# speed, and the footprint matches what the player sees - so you die exactly when
# the shape touches you. The per-obstacle Area monitoring is turned off so this
# is the single, predictable source of collisions.
# ---------------------------------------------------------------------------

# Ship half-size added to each hazard silhouette. Sized to the visible hull so
# a hazard that overlaps the ship on screen actually kills.
const SHIP_PAD_X := 0.42
const SHIP_PAD_Y := 0.26
# Depth half-window: the ship and hazard both have thickness, so a hazard counts
# while its body overlaps the ship's depth, not only at the exact centre plane.
const Z_OVERLAP := 0.80

func _reset_obstacle(area: Area3D, z: float) -> void:
	super._reset_obstacle(area, z)
	area.monitoring = false          # this layer decides collisions, not body_entered
	var fp := _visual_footprint(area)
	area.set_meta("fpx", fp.x)
	area.set_meta("fpy", fp.y)
	area.set_meta("pz", area.position.z)

# Half-extents (x, y) of everything drawn for the hazard, in its local frame -
# i.e. the silhouette the player actually sees and aims at.
func _visual_footprint(area: Area3D) -> Vector2:
	var fpx := 0.30
	var fpy := 0.30
	var visual := area.get_child(0) as Node3D
	if visual:
		for child in visual.get_children():
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				var aabb := mi.get_aabb()
				var t := mi.transform
				for i in range(8):
					var corner := aabb.position + Vector3(
						aabb.size.x * float(i & 1),
						aabb.size.y * float((i >> 1) & 1),
						aabb.size.z * float((i >> 2) & 1))
					var p: Vector3 = t * corner
					fpx = maxf(fpx, absf(p.x))
					fpy = maxf(fpy, absf(p.y))
	return Vector2(fpx, fpy)

func _check_hits() -> void:
	if not alive:
		return
	var sp := ship.global_position
	for child in obstacle_root.get_children():
		var area := child as Area3D
		var znow := area.position.z
		var zprev := float(area.get_meta("pz", znow))
		area.set_meta("pz", znow)
		# Hit while the hazard body overlaps the ship's depth, OR on the exact
		# frame it sweeps past (the safety net against high-speed frame skips).
		if absf(znow - sp.z) < Z_OVERLAP or (zprev < sp.z and znow >= sp.z):
			var fpx := float(area.get_meta("fpx", 0.6)) + SHIP_PAD_X * hit_pad_scale
			var fpy := float(area.get_meta("fpy", 0.6)) + SHIP_PAD_Y * hit_pad_scale
			var ang := deg_to_rad(area.rotation_degrees.z)
			var ca := cos(-ang)
			var sa := sin(-ang)
			var rx := area.position.x - sp.x
			var ry := area.position.y - sp.y
			var lx := rx * ca - ry * sa
			var ly := rx * sa + ry * ca
			if absf(lx) < fpx and absf(ly) < fpy:
				_hit(ship)
				return
