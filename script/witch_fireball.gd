extends Area2D

class_name WitchFireball

# ─── Witch Fireball ────────────────────────────────────────────────────────────
# Projectile fired by the Witch enemy. Travels in a straight line toward the
# player's position at the moment of firing. Rotates to match its travel angle.
# Deals a fixed burst of damage on contact and frees itself off-screen.
# ───────────────────────────────────────────────────────────────────────────────

@export var speed: int = 240
var direction: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d = $AnimatedSprite2D

const DAMAGE_AMOUNT: int = 40

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _process(delta: float):
	# Move along the firing direction each frame
	position += direction * speed * delta

	# Rotate the sprite to face the direction of travel
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# On contact with any area — deal damage if it belongs to the player
func _on_area_entered(area: Area2D):
	if area.get_parent() is Player:
		area.get_parent().take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		queue_free()

# Clean up when the fireball leaves the visible screen area
func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
