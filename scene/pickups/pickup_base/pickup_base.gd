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

# Sprites per kind — swap these in the inspector to re-skin the pickup. The correct
# one is applied automatically based on `kind`.
@export var health_texture: Texture2D = preload("res://art/pickups/health.png")
@export var speed_texture:  Texture2D = preload("res://art/pickups/speed.png")

@onready var visual: Sprite2D = $Visual
@onready var tag:    Label    = $Tag

var _float_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_appearance()
	# The "Tag" label is this pickup's caption — enroll it so it obeys the global
	# Object-labels toggle (drag/edit it in the editor like any other caption).
	Global.register_caption(tag)
	_start_float()

func _apply_appearance() -> void:
	var is_id := TranslationServer.get_locale().begins_with("id")
	match kind:
		Kind.HEALTH:
			visual.texture = health_texture
			tag.text = "Nyawa" if is_id else tr("Health")
		Kind.SPEED:
			visual.texture = speed_texture
			tag.text = "Kecepatan" if is_id else tr("Speed Boost")

# Colour used for the collect burst (the sprites carry their own art now).
func _kind_color() -> Color:
	return Color(0.3, 0.9, 0.45) if kind == Kind.HEALTH else Color(0.35, 0.8, 1.0)

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
	Global.spawn_burst(global_position, _kind_color(), 16)
	set_deferred("monitoring", false)
	if _float_tween:
		_float_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.5, 0.12)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
