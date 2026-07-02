extends Area2D

# ─── Boss Bullet ────────────────────────────────────────────────────────────────
# Simple bullet-hell projectile fired by the final boss. Flies in a straight
# line, damages the player on contact, and despawns after a short lifetime.
#
# Collision: layer 2 / mask 1. On its own layer (2) so the player's arrow raycast
# (which sweeps layer 1) ignores bullets; mask 1 so it still detects the player's
# hurtbox. Damage goes through Player.take_damage(), so an active Firewall (which
# guards take_damage) blocks bullets — the defensive skill matters here.
# ───────────────────────────────────────────────────────────────────────────────

@export var speed: float = 120.0
@export var damage: int  = 12

var direction: Vector2 = Vector2.ZERO
var _life: float = 5.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent is Player:
		parent.take_damage(damage)
		queue_free()

# Terrain (walls, floors, platforms — layer 1 physics bodies) blocks bullets,
# giving the player cover to hide behind.
func _on_body_entered(_body: Node) -> void:
	queue_free()
