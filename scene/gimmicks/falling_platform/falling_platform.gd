@tool
extends AnimatableBody2D

class_name FallingPlatform

# ─── Falling Platform ───────────────────────────────────────────────────────────
# Stand on it and it shakes, then drops away — so the player must keep moving.
# After `respawn_time` it returns to its start. The Trigger area (mask 2) detects
# the player landing on top.
# ───────────────────────────────────────────────────────────────────────────────

@export var shake_time: float   = 0.5    # how long it shakes before dropping
@export var respawn_time: float = 3.0    # seconds before it returns

# ─── Skin ────────────────────────────────────────────────────────────────────────
# Set per stage so the platform matches that level's terrain tileset. Left empty it
# keeps the flat orange look. The bright top Edge keeps its colour either way, so a
# falling platform still reads as one before you trust it with your weight.
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

const PlatformSkin = preload("res://scene/gimmicks/platform_skin.gd")
const _BASE_COLOR := Color(0.85, 0.45, 0.2, 1)   # the unskinned orange body

@onready var _col:     CollisionShape2D = $CollisionShape2D
@onready var _visual:  Polygon2D        = $Visual
@onready var _edge:    Polygon2D        = $Edge
@onready var _trigger: Area2D           = $Trigger

var _start: Vector2
var _triggered := false

func _apply_skin() -> void:
	if not is_inside_tree():
		return
	PlatformSkin.apply(get_node_or_null("Visual") as Polygon2D, skin, skin_tint, _BASE_COLOR)

func _ready() -> void:
	_apply_skin()
	if Engine.is_editor_hint():
		return          # editor: just show the skin, no physics/signal wiring
	sync_to_physics = true
	_start = position
	_trigger.body_entered.connect(_on_trigger)

func _on_trigger(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	AudioManager.play_sfx("falling_platform")
	_run()

func _run() -> void:
	# Shake in place as a warning
	var shake := create_tween()
	var reps := int(shake_time / 0.1)
	for i in reps:
		shake.tween_property(self, "position:x", _start.x + 2.0, 0.05)
		shake.tween_property(self, "position:x", _start.x - 2.0, 0.05)
	await shake.finished
	position.x = _start.x

	# Drop away: remove support and sink the visual
	_col.set_deferred("disabled", true)
	var fall := create_tween()
	fall.tween_property(self, "position:y", _start.y + 320.0, 0.7).set_ease(Tween.EASE_IN)
	await fall.finished
	_set_visible(false)

	# Respawn back at the start
	await get_tree().create_timer(respawn_time).timeout
	position = _start
	_set_visible(true)
	_col.set_deferred("disabled", false)
	_triggered = false

func _set_visible(v: bool) -> void:
	_visual.visible = v
	_edge.visible = v
