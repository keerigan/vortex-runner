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
# 2. CONTENT - a new hazard, the ROTATING GIRDER: a wide bar (instead of the
#    compact drone / mine / crate) that spins across the tunnel, so you must
#    read its angle and thread the short side. It reuses the existing swept
#    silhouette collision (collisions.gd) by refreshing the visual footprint
#    after we swap the mesh, and the existing spin / curve bookkeeping, so no
#    movement code changes. It only appears once the run is warmed up.
# ---------------------------------------------------------------------------

const GIRDER_MIN_SCORE := 220.0
const GIRDER_CHANCE := 0.22
const GIRDER_HALF_W := 1.24

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
	# Keep the position/spin/lane super just set; only swap the shape sometimes.
	if score > GIRDER_MIN_SCORE and randf() < GIRDER_CHANCE:
		_make_girder(area)

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
