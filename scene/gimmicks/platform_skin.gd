@tool
extends RefCounted

# ─── Platform Skin ──────────────────────────────────────────────────────────────
# Used via `const PlatformSkin = preload(...)` rather than a global class_name, so
# it resolves immediately without waiting for an editor rescan of the class cache.
# Shared helper that paints a tileset texture onto a platform's Polygon2D so the
# gimmick platforms match whatever stage they're standing in (Stage 2's sci-fi
# panels, Stage 3's industrial slabs, ...). Kept here so the moving and falling
# platforms skin themselves identically instead of each rolling their own.
#
# HORIZONTALLY the UV is fitted to a WHOLE number of tiles, so a tile is never
# sliced off mid-way at the edge — the texture stretches by a few percent instead,
# which is invisible next to a hard cut-off.
#
# VERTICALLY it maps 1 polygon pixel to 1 texture pixel, measured from the top of
# the tile. Slab tiles (Stage 3's are 32x32 images whose slab only fills the top
# 16px) then render at their true height instead of being squashed whole into the
# platform — that squash left the slab half-height over a transparent gap.
#
# Leave `skin` empty and the platform keeps its flat colour-coded look.
# ───────────────────────────────────────────────────────────────────────────────

static func apply(visual: Polygon2D, skin: Texture2D, tint: Color, base: Color) -> void:
	if visual == null:
		return
	visual.texture = skin
	if skin == null:
		visual.color = base          # no skin — back to the flat gimmick colour
		return
	visual.color          = tint
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.uv             = _fit_uv(visual.polygon, skin.get_size())

# Map the polygon onto a whole number of tile repeats.
static func _fit_uv(poly: PackedVector2Array, tile: Vector2) -> PackedVector2Array:
	var uv := PackedVector2Array()
	if poly.is_empty() or tile.x <= 0.0 or tile.y <= 0.0:
		return uv
	var r := _bounds(poly)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return uv
	# X: nearest whole tile count (at least one). Y: 1:1 pixels from the tile's top.
	var span := Vector2(tile.x * maxf(1.0, roundf(r.size.x / tile.x)), r.size.y)
	for p in poly:
		uv.append(Vector2((p.x - r.position.x) / r.size.x * span.x,
						  (p.y - r.position.y) / r.size.y * span.y))
	return uv

static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r
