extends "res://scripts/menu.gd"

# ---------------------------------------------------------------------------
# Optimisation layer (top of the chain, wired to main.tscn). Invisible and
# behaviour-preserving.
#
# The immediate-mode builders below allocate a brand new StandardMaterial3D on
# every corridor rebuild and every obstacle recycle. This layer memoises them:
# identical materials are created once and shared, which
#   * collapses the live material count (hundreds -> a few dozen), and
#   * removes the per-recycle allocation churn that causes GC hitches on mobile.
#
# Sharing is only safe because no cached material is ever mutated after
# creation. The whole project mutates a material in exactly three places - the
# ship build (_tame_ship clamps emission) and the two transparent effect
# materials (_flash, the shield bubble) - so the cache is bypassed there and
# those keep getting fresh, private instances. Every world / corridor / hazard
# material is written once, so the rendered image is byte-for-byte unchanged.
# ---------------------------------------------------------------------------

var _mat_cache: Dictionary = {}
var _cache_enabled := true

func _mat(color: Color, emission := Color.BLACK, energy := 0.0, metallic := 0.0, roughness := 0.28) -> StandardMaterial3D:
	if not _cache_enabled:
		return super._mat(color, emission, energy, metallic, roughness)
	var key := "%s|%s|%.4f|%.4f|%.4f" % [color, emission, energy, metallic, roughness]
	var cached: StandardMaterial3D = _mat_cache.get(key)
	if cached != null:
		return cached
	var created := super._mat(color, emission, energy, metallic, roughness)
	_mat_cache[key] = created
	return created

# --- Bypass the cache wherever the returned material is later mutated ---

func _build_ship() -> void:
	var prev := _cache_enabled
	_cache_enabled = false
	super._build_ship()
	_cache_enabled = prev

func _make_shield_bubble() -> void:
	var prev := _cache_enabled
	_cache_enabled = false
	super._make_shield_bubble()
	_cache_enabled = prev

func _flash(pos: Vector3, color: Color) -> void:
	var prev := _cache_enabled
	_cache_enabled = false
	super._flash(pos, color)
	_cache_enabled = prev
