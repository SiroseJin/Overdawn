extends Area2D

# ─── Arrow ─────────────────────────────────────────────────────────────────────
# Player projectile fired toward the mouse cursor.
# Deals a fixed amount of damage to the first damageable non-player target it
# hits, then frees itself. Also frees itself when it leaves the screen.
# ───────────────────────────────────────────────────────────────────────────────

var speed: int         = 270
var direction: Vector2 = Vector2.ZERO

const DAMAGE_AMOUNT: int = 15

var _spent := false   # guards against applying damage / freeing twice

@onready var sprite_2d = $Sprite2D

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

# Movement + hit detection run in _physics_process so the swept raycast stays in
# sync with the physics step. The raycast is continuous, so a fast arrow can't
# tunnel past a thin/small enemy hitbox between frames (the old _process + thin
# SegmentShape2D + area_entered approach missed hits this way).
func _physics_process(delta: float):
	if _spent:
		return

	var move := direction * speed * delta

	# Sweep the path ahead. Layer 1 holds walls/floors AND enemy hitboxes;
	# collide_with_areas lets the ray catch the (Area2D) hitboxes too.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + move + direction * 4.0)
	query.exclude             = [self]
	query.collision_mask      = 1
	query.collide_with_areas  = true
	query.collide_with_bodies = true

	var hit := space.intersect_ray(query)
	if hit:
		var target := _damageable_from(hit.collider)
		if target != null and not target is Player:
			_hit(target)
			return
		elif target == null and hit.collider is PhysicsBody2D:
			# Solid geometry (walls, floors, platforms) → stop here
			_spent = true
			queue_free()
			return
		# else: a non-damageable Area2D (pickups, the player's own hitbox) → pass
		# through and keep flying

	position += move

	if direction.length() > 0:
		rotation = direction.angle() + PI / 2

# Resolve the damageable node behind a collider (the collider itself, or its
# parent when the collider is a child HitBox area).
func _damageable_from(collider: Object) -> Node:
	if collider == null:
		return null
	if collider.has_method("take_damage"):
		return collider
	var parent = collider.get_parent()
	if parent and parent.has_method("take_damage"):
		return parent
	return null

func _hit(target: Node) -> void:
	if _spent:
		return
	_spent = true
	target.take_damage(DAMAGE_AMOUNT)
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# Backup detection in case an overlap registers before the swept ray does.
func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and not parent is Player:
		_hit(parent)

# Auto-destroy when the arrow flies off-screen
func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
