extends "res://scripts/readability.gd"

# ---------------------------------------------------------------------------
# Obstacle pattern director (top of the chain, wired to main.tscn).
#
# The hazards used to be single objects scattered at random, so dodging felt
# aimless. This layer replaces the random placement with readable, telegraphed
# rhythms - horizontal / vertical slaloms, smooth waves, diagonal sweeps and
# gap walls. Each recycled obstacle simply takes the next slot of the current
# pattern, positioned a fixed spacing ahead of a frontier cursor that rides the
# world, so a pattern reads cleanly no matter when its obstacles recycle.
#
# It only overrides the obstacle POSITION (after super builds the visual,
# collision, aura and records the curve base): spacing tightens with difficulty,
# and the reachable extremes are still threatened so camping stays punished.
# ---------------------------------------------------------------------------

var _frontier_z := -55.0
var _pattern: Array = []
var _pattern_i := 0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if started and alive:
		_frontier_z += speed * delta

func _reset_obstacle(area: Area3D, z: float) -> void:
	super._reset_obstacle(area, z)
	var p := _next_placement()
	area.position = p
	area.set_meta("base_x", p.x)
	area.set_meta("base_y", p.y)

func _next_placement() -> Vector3:
	var slot := _next_slot()
	var spacing := lerpf(20.0, 13.0, _difficulty())
	_frontier_z = clampf(_frontier_z - spacing, -235.0, -55.0)
	return Vector3(slot.x, slot.y, _frontier_z)

func _next_slot() -> Vector2:
	if _pattern_i >= _pattern.size():
		_pattern = _make_pattern()
		_pattern_i = 0
	var slot: Vector2 = _pattern[_pattern_i]
	_pattern_i += 1
	return slot

# Each pattern is a sequence of (x, y) slots for consecutive obstacles. Y stays
# inside the reachable band; obstacles near y=-1.9 / 0.9 still threaten a ship
# parked at the very top or bottom (collision padding reaches ~0.5 further).
func _make_pattern() -> Array:
	var pts: Array = []
	match randi() % 6:
		0: # horizontal slalom - weave left/right
			for i in range(5):
				pts.append(Vector2(-2.4 if i % 2 == 0 else 2.4, randf_range(-1.3, 0.5)))
		1: # vertical slalom - weave up/down
			for i in range(5):
				pts.append(Vector2(randf_range(-2.2, 2.2), -1.9 if i % 2 == 0 else 0.9))
		2: # smooth wave
			for i in range(6):
				pts.append(Vector2(sin(float(i) * 0.9) * 2.6, cos(float(i) * 0.7) * 0.9 - 0.4))
		3: # diagonal sweep across the tunnel
			var dir := 1.0 if randf() < 0.5 else -1.0
			for i in range(5):
				var t := float(i) / 4.0
				pts.append(Vector2(lerpf(-2.6, 2.6, t) * dir, lerpf(-1.7, 0.8, t)))
		4: # gap wall - two of three lanes blocked, thread the open one
			var lanes := [-2.4, 0.0, 2.4]
			var gap: float = lanes[randi() % lanes.size()]
			for lane in lanes:
				if lane != gap:
					pts.append(Vector2(lane, randf_range(-1.2, 0.4)))
		_: # breather - a couple of loose hazards
			for i in range(2):
				pts.append(Vector2(randf_range(-2.6, 2.6), randf_range(-2.0, 1.0)))
	return pts
