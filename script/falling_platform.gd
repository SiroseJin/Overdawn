extends AnimatableBody2D

class_name FallingPlatform

# ─── Falling Platform ───────────────────────────────────────────────────────────
# Stand on it and it shakes, then drops away — so the player must keep moving.
# After `respawn_time` it returns to its start. The Trigger area (mask 2) detects
# the player landing on top.
# ───────────────────────────────────────────────────────────────────────────────

@export var shake_time: float   = 0.5    # how long it shakes before dropping
@export var respawn_time: float = 3.0    # seconds before it returns

@onready var _col:     CollisionShape2D = $CollisionShape2D
@onready var _visual:  Polygon2D        = $Visual
@onready var _edge:    Polygon2D        = $Edge
@onready var _trigger: Area2D           = $Trigger

var _start: Vector2
var _triggered := false

func _ready() -> void:
	sync_to_physics = true
	_start = position
	_trigger.body_entered.connect(_on_trigger)

func _on_trigger(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
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
