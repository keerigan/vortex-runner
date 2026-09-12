extends "res://scripts/patterns.gd"

# ---------------------------------------------------------------------------
# Game feel layer (top of the chain, wired to main.tscn).
#
#   * Crash impact: a short hit-stop (time scale dip) plus a decaying screen
#     shake, so dying reads as a real impact instead of an instant stop.
#   * Near-miss reward: when a hazard sweeps close past the ship without hitting,
#     it grants a small spark, a whoosh, a chip of shake and a combo tick - so
#     threading a gap tightly feels good and feeds the score chain. This turns
#     the new obstacle patterns into something satisfying to cut through.
#
# Shake uses the camera's frustum offsets (h/v_offset), which don't fight the
# position/rotation lerp the lower camera layers run every frame.
# ---------------------------------------------------------------------------

var _shake := 0.0
var _whoosh: AudioStreamWAV

func _ready() -> void:
	Engine.time_scale = 1.0   # clear any hit-stop left over across a scene reload
	super._ready()
	_whoosh = _make_tone(1350.0, 520.0, 0.14, 0.26)

func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - delta * 2.6)
		var amp := _shake * 0.5
		camera.h_offset = randf_range(-amp, amp)
		camera.v_offset = randf_range(-amp, amp)
	elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if started and alive:
		_check_near_miss()

func _hit(body: Node) -> void:
	var was_alive := alive
	super._hit(body)
	if was_alive and not alive:
		_shake = 1.5
		_hit_stop()

func _hit_stop() -> void:
	Engine.time_scale = 0.12
	# ignore_time_scale so the timer still fires in real time while frozen
	var timer := get_tree().create_timer(0.13, true, false, true)
	timer.timeout.connect(_end_hit_stop)

func _end_hit_stop() -> void:
	Engine.time_scale = 1.0

# A hazard that crosses the ship's depth within a close-but-not-hitting ring
# counts once as a near miss (flag reset when it recycles far ahead again).
func _check_near_miss() -> void:
	var sp := ship.global_position
	for child in obstacle_root.get_children():
		var area := child as Area3D
		# Swept detection (like the collision layer): catch the exact frame the
		# hazard crosses the ship's depth, so near misses still register during
		# Overdrive when hazards jump >1 unit between frames.
		var znow := area.position.z
		var zprev := float(area.get_meta("nm_pz", znow))
		area.set_meta("nm_pz", znow)
		if bool(area.get_meta("nm_done", false)):
			if znow < sp.z - 3.0:
				area.set_meta("nm_done", false)
			continue
		var crossed := zprev < sp.z and znow >= sp.z
		if crossed or absf(znow - sp.z) < 0.6:
			var dx := area.position.x - sp.x
			var dy := area.position.y - sp.y
			var d := sqrt(dx * dx + dy * dy)
			if d > 0.78 and d < 1.6:
				area.set_meta("nm_done", true)
				_near_miss(area.position)

func _near_miss(pos: Vector3) -> void:
	chain = mini(CHAIN_MAX, chain + 1)
	chain_timer = CHAIN_WINDOW
	bonus_points += 20
	_shake = maxf(_shake, 0.3)
	_play_fx(_whoosh)
	_flash(pos, Color(0.5, 0.9, 1.0))
