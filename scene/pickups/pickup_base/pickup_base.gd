extends Area2D
class_name Pickup

# ─── Pickup ─────────────────────────────────────────────────────────────────────
# Reusable collectible. Drop an instance into a level and pick its `kind` in the
# inspector. Walking the player into it applies the effect and the node frees
# itself with a small pop. Detects the player via collision_mask = 2.
# ───────────────────────────────────────────────────────────────────────────────

enum Kind { HEALTH, SPEED }

@export var kind: Kind            = Kind.HEALTH
@export var heal_amount: int      = 25     # HEALTH: HP restored
@export var speed_multiplier: float = 1.6  # SPEED: walk-speed factor while active
@export var speed_duration: float = 5.0    # SPEED: seconds the boost lasts

@onready var visual: Polygon2D = $Visual
@onready var tag:    Label     = $Tag

var _float_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_appearance()
	_start_float()

func _apply_appearance() -> void:
	match kind:
		Kind.HEALTH:
			visual.color = Color(0.3, 0.9, 0.45)
			tag.text = tr("Health")
		Kind.SPEED:
			visual.color = Color(0.35, 0.8, 1.0)
			tag.text = tr("Speed Boost")

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

	match kind:
		Kind.HEALTH:
			if body.has_method("heal_player"):
				body.heal_player(heal_amount)
			if body.has_method("show_toast"):
				body.show_toast(tr("Health") + " +%d" % heal_amount)
		Kind.SPEED:
			if body.has_method("apply_speed_boost"):
				body.apply_speed_boost(speed_multiplier, speed_duration)
			if body.has_method("show_toast"):
				body.show_toast(tr("Speed Boost!"))

	_collect()

func _collect() -> void:
	set_deferred("monitoring", false)
	if _float_tween:
		_float_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.5, 0.12)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
