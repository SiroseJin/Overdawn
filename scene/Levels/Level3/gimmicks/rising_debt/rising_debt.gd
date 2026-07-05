extends Area2D

class_name RisingDebt

# ─── Rising Debt (Stage 3 gimmick) ──────────────────────────────────────────────
# A slow flood of debt that creeps upward. Stay above it; fall too far / too often
# and it catches you (chip damage that respects the player's i-frames). It pauses
# while the player is in a conversation, so talking to a rest-ledge NPC is always
# safe. Place it so its top edge sits just below the floor and it rises from there.
# Scale the node horizontally to make the flood wider/narrower.
# ───────────────────────────────────────────────────────────────────────────────

@export var rise_speed: float = 6.0   # px/s — how fast the debt floods upward
@export var damage: int      = 12     # chip damage per hit

func _process(delta: float) -> void:
	var p = Global.PlayerBody
	# Freeze the debt while the player is talking so conversations are safe.
	var talking: bool = is_instance_valid(p) and p.conversation_safe
	if not talking:
		position.y -= rise_speed * delta
	if is_instance_valid(p) and p.can_take_damage and overlaps_body(p):
		p.take_damage(damage)
