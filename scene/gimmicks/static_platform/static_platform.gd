@tool
extends StaticBody2D

class_name StaticPlatform

# ─── Static Platform ────────────────────────────────────────────────────────────
# A plain solid ledge you can drop anywhere. It carries the same `skin` hook as the
# moving and falling platforms so a stage can dress all three from its own tileset
# instead of this one staying flat grey while the rest of the level is textured.
# ───────────────────────────────────────────────────────────────────────────────

const PlatformSkin = preload("res://scene/gimmicks/platform_skin.gd")
const _BASE_COLOR := Color(0.42, 0.47, 0.58, 1)   # the unskinned grey body

# ─── Skin ────────────────────────────────────────────────────────────────────────
# Set per stage so the platform matches that level's terrain tileset. Left empty it
# keeps the flat grey look. The bright top Edge keeps its colour either way.
@export_group("Skin")
## Tileset texture painted onto the platform body. Empty = flat colour.
@export var skin: Texture2D:
	set(v):
		skin = v
		_apply_skin()
## Tint multiplied over the skin (white = the texture's own colours).
@export var skin_tint: Color = Color.WHITE:
	set(v):
		skin_tint = v
		_apply_skin()

func _apply_skin() -> void:
	if not is_inside_tree():
		return
	PlatformSkin.apply(get_node_or_null("Visual") as Polygon2D, skin, skin_tint, _BASE_COLOR)

func _ready() -> void:
	_apply_skin()
