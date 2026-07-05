extends Area2D

class_name NecroDotField

# ─── Necro Dot Field ───────────────────────────────────────────────────────────
# A persistent area-of-effect hazard spawned by the Necromancer's slow orb.
# While the player stands inside it they are slowed and take periodic damage.
# The field lasts 6 seconds before despawning.
# ───────────────────────────────────────────────────────────────────────────────

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var damage_timer: Timer  = $DamageTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

const DAMAGE_AMOUNT: int  = 1
const SLOW_FACTOR: float  = 0.6   # Player speed is multiplied by this while inside

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	# Start the despawn countdown immediately on spawn
	_start_lifetime()

# Begin a 6-second countdown then free this node
func _start_lifetime():
	await get_tree().create_timer(6.0).timeout
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# Slow the player and tick 5 pulses of damage (1.2 s apart) while they are inside
func _on_area_entered(area: Area2D):
	if not area.get_parent() is Player:
		return

	var player = area.get_parent()
	player.slow_down(SLOW_FACTOR)

	# Deal damage 5 times over ~6 seconds while the player remains in the field
	for i in range(5):
		player.take_damage(DAMAGE_AMOUNT)
		await get_tree().create_timer(1.2).timeout

# Restore player speed when they leave the field
func _on_area_exited(area: Area2D):
	if area.get_parent() is Player:
		area.get_parent().restore_speed()

# Clean up if the field drifts off-screen (shouldn't normally happen)
func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
