extends Area2D

class_name CollectorFireball

# ─── Collector Fireball ──────────────────────────────────────────────────────────
# Projectile fired by the Collector. Travels in a straight line toward the player's
# position at the moment of firing, rotating to match its travel angle. Deals a
# fixed burst of damage on contact.
#
# Muzzle grace: for the first split-second it can NOT detonate. The Collector spawns
# it from a marker tucked inside her own body, so without this it would explode the
# instant it appeared — right on the caster (or on a player meleeing her point-blank)
# instead of flying out. The grace lets it clear the muzzle first.
#
# Cleanup is a lifetime + distance cull (no VisibleOnScreenNotifier, which could fire
# a spurious "off screen" on the spawn frame and kill the shot at the muzzle).
# ────────────────────────────────────────────────────────────────────────────────

@export var speed: int = 240
## Despawn after this long, or once this far from the player — safety cleanup so
## missed shots don't linger off-screen forever.
@export var lifetime: float   = 6.0
@export var cull_distance: float = 1500.0

const ARM_TIME: float     = 0.10   # seconds before it's allowed to detonate
const DAMAGE_AMOUNT: int  = 40

var direction: Vector2 = Vector2.ZERO
var _age: float = 0.0

@onready var animated_sprite_2d = $AnimatedSprite2D

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _process(delta: float):
	_age += delta

	# Move along the firing direction each frame
	position += direction * speed * delta

	# Rotate the sprite to face the direction of travel
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2

	# Safety cleanup: too old, or flown well past the player.
	if _age >= lifetime:
		queue_free()
	elif is_instance_valid(Global.PlayerBody) \
			and global_position.distance_to(Global.PlayerBody.global_position) > cull_distance:
		queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# On contact with any area — deal damage if it belongs to the player
func _on_area_entered(area: Area2D):
	# Muzzle grace — ignore everything until the fireball has cleared the caster, so
	# it can't blow up on spawn (the reported "explodes the moment it's cast" bug).
	if _age < ARM_TIME:
		return
	if area.get_parent() is Player:
		area.get_parent().take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		Global.spawn_fx("splosion", global_position, 0.55)   # fiery impact
		queue_free()
