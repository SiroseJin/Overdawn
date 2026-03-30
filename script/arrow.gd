extends Area2D

# ─── Arrow ─────────────────────────────────────────────────────────────────────
# Player projectile fired toward the mouse cursor.
# Deals a fixed amount of damage to the first damageable non-player target it
# hits, then frees itself. Also frees itself when it leaves the screen.
# ───────────────────────────────────────────────────────────────────────────────

var speed: int         = 270
var direction: Vector2 = Vector2.ZERO

const DAMAGE_AMOUNT: int = 15

@onready var sprite_2d = $Sprite2D

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

# Hit any area that belongs to a damageable node — ignore the player itself
func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent.has_method("take_damage") and not parent is Player:
		parent.take_damage(DAMAGE_AMOUNT)
		queue_free()

# Auto-destroy when the arrow flies off-screen
func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
