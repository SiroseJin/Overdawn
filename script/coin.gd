extends Area2D

class_name CoinItem

# ─── Coin ──────────────────────────────────────────────────────────────────────
# Collectible item that awards score when the player walks over it.
# Plays a pickup animation before freeing itself.
# ───────────────────────────────────────────────────────────────────────────────

@onready var animation_player = $AnimationPlayer

const SCORE_VALUE: int = 10

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# Award score to the player on contact, play the pickup animation, then despawn
func _on_body_entered(body):
	if Global.PlayerBody:
		Global.PlayerBody.gain_score(SCORE_VALUE)
		animation_player.play("pickup")
		await get_tree().create_timer(0.4).timeout
	queue_free()
