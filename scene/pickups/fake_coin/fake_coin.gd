extends Area2D

# ─── Fake Coin — the rigged jackpot ─────────────────────────────────────────────
# A "coin" that looks like free money. Grab it and the machine rolls: every
# outcome is a loss, you just don't know which one until you've already taken it.
# That's the whole gamble — the house always wins, the only question is how.
#   0 SLOW    — your speed is throttled for a while
#   1 DAMAGE  — a straight hit to your health
#   2 REVERSE — left/right controls get flipped ("rigged")
#   3 ROBBED  — some of your real coins are skimmed off
# ────────────────────────────────────────────────────────────────────────────────

const SLOW_FACTOR    := 0.7    # 30% slow
const SLOW_DURATION  := 3.0
const DAMAGE         := 12
const REVERSE_DURATION := 4.0
const ROB_AMOUNT     := 15      # coins skimmed (clamped to what you have)

enum { SLOW, DAMAGE_HIT, REVERSE, ROBBED }

var _collected := false

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body is CharacterBody2D:
		return
	# Needs to be the player (the one who can actually be punished).
	if not body.has_method("slow_down"):
		return

	_collected = true
	Global.spawn_burst(global_position, Color(1, 0.25, 0.2), 16)   # rigged — angry red pop
	$AnimationPlayer.play("pickup")

	_roll_effect(body)


# Pick one rigged outcome at random and apply it.
func _roll_effect(body: Node2D) -> void:
	match randi() % 4:
		SLOW:
			if body.has_method("apply_slow"):
				body.apply_slow(SLOW_FACTOR, SLOW_DURATION)
			else:
				body.slow_down(SLOW_FACTOR)
			_toast(body, "Rigged coin! You're slowed.")
		DAMAGE_HIT:
			if body.has_method("take_damage"):
				body.take_damage(DAMAGE)
			_toast(body, "Rigged coin! It bites — you lose health.")
		REVERSE:
			if body.has_method("reverse_controls"):
				body.reverse_controls(REVERSE_DURATION)
			_toast(body, "Rigged coin! Your controls are scrambled.")
		ROBBED:
			var take: int = min(ProgressionManager.coins, ROB_AMOUNT)
			if take > 0:
				ProgressionManager.spend_coins(take)
				_toast(body, "Rigged coin! The house skimmed %d coins." % take)
			else:
				_toast(body, "Rigged coin! Nothing left to skim.")


func _toast(body: Node2D, text: String) -> void:
	if is_instance_valid(body) and body.has_method("show_toast"):
		body.show_toast(tr(text))
