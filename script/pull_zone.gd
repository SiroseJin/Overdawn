extends Area2D

class_name PullZone

# ─── Pull Zone (Stage 4 gimmick) ────────────────────────────────────────────────
# An invisible current the machine runs through the floor. While the player is
# inside, it constantly drags them in `pull` — usually back the way they came, or
# toward danger. You can still move, but you're always fighting the current. The
# algorithm never stops nudging you back in.
# ───────────────────────────────────────────────────────────────────────────────

@export var pull: Vector2 = Vector2(-90, 0)   # velocity added while inside

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and "external_push" in body:
		body.external_push = pull

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and "external_push" in body:
		body.external_push = Vector2.ZERO

# If the zone is removed (e.g. a boss phase ends) while the player is still inside,
# body_exited won't fire — so clear our pull here so they aren't dragged forever.
func _exit_tree() -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p) and "external_push" in p and p.external_push == pull:
		p.external_push = Vector2.ZERO
