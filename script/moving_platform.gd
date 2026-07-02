extends AnimatableBody2D

class_name MovingPlatform

# ─── Moving Platform ────────────────────────────────────────────────────────────
# Rides back and forth between its start and start+travel, carrying the player.
# AnimatableBody2D + a physics-mode tween so standing bodies are moved with it.
# Set `travel` to a horizontal or vertical offset in the inspector.
# ───────────────────────────────────────────────────────────────────────────────

@export var travel: Vector2   = Vector2(200, 0)  # offset from start to far end
@export var duration: float   = 2.0              # seconds for one leg
@export var wait: float       = 0.3              # pause at each end

func _ready() -> void:
	sync_to_physics = true
	var start := position
	var t := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(self, "position", start + travel, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(wait)
	t.tween_property(self, "position", start, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(wait)
