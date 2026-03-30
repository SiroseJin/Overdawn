extends Area2D

class_name NecroSlowOrb

# ─── Necromancer Slow Orb ──────────────────────────────────────────────────────
# Projectile fired by the Necromancer. On hitting the player it deals a small
# burst of damage and spawns a NecroDotField at the impact point, which slows
# the player and ticks damage over its lifetime.
# ───────────────────────────────────────────────────────────────────────────────

@export var speed: int = 150
var direction: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d = $AnimatedSprite2D

@export var necro_dot_field_scene: PackedScene = preload("res://scene/dot_field.tscn")

const DAMAGE_AMOUNT: int = 5

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _process(delta: float):
	position += direction * speed * delta

	# Rotate the sprite to align with the travel direction
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D):
	if area.get_parent() is Player:
		area.get_parent().take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		summon_necro_dot_field()
		queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Dot Field
# ───────────────────────────────────────────────────────────────────────────────

# Instantiate the persistent damage field at this orb's impact position
func summon_necro_dot_field():
	if !necro_dot_field_scene:
		return
	var dot_field          = necro_dot_field_scene.instantiate()
	dot_field.position     = position
	get_parent().add_child(dot_field)

# Clean up when the orb leaves the visible screen area
func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
