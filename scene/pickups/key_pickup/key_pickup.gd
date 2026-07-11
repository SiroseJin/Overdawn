extends Area2D

# ─── Key Pickup ─────────────────────────────────────────────────────────────────
# Collectible key for lock-and-key puzzles. Collecting it records `key_id` in the
# ProgressionManager; a matching LockedDoor with the same id can then be opened.
# Detects the player via collision_mask = 2.
# ───────────────────────────────────────────────────────────────────────────────

@export var key_id: String = "stage1_key"
## Toast shown when the key is collected (a chance for a themed item name).
@export var obtained_message: String = "Key obtained"

@onready var tag: Label = $Tag

var _float_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_float()

func _start_float() -> void:
	var base_y := position.y
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(self, "position:y", base_y - 4.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", base_y, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	ProgressionManager.add_key(key_id)
	if body.has_method("show_toast"):
		body.show_toast(tr(obtained_message))
	_collect()

func _collect() -> void:
	Global.spawn_burst(global_position, Color(1, 0.9, 0.3), 16)   # golden key sparkle
	set_deferred("monitoring", false)
	if _float_tween:
		_float_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.5, 0.12)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
