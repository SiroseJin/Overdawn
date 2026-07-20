extends Area2D

# ─── Fake Coin — the rigged jackpot ─────────────────────────────────────────────
# A "coin" that looks like free money. Grab it and the machine rolls: every
# outcome is a loss, you just don't know which one until you've already taken it.
# That's the whole gamble — the house always wins, the only question is how.
#   0 SLOW    — your speed is throttled for a while
#   1 DAMAGE  — a straight hit to your health
#   2 REVERSE — left/right controls get flipped ("rigged")
#   3 ROBBED  — some of your real coins are skimmed off
#   4 EXP_DRAIN — chips 1 EXP off your progress toward the next level
# ────────────────────────────────────────────────────────────────────────────────

const SLOW_FACTOR    := 0.7    # 30% slow
const SLOW_DURATION  := 3.0
const DAMAGE         := 12
const REVERSE_DURATION := 4.0
const ROB_AMOUNT     := 15      # coins skimmed (clamped to what you have)
const EXP_DRAIN_AMOUNT := 1     # EXP chipped off

enum { SLOW, DAMAGE_HIT, REVERSE, ROBBED, EXP_DRAIN }

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
	AudioManager.play_sfx("fake_coin")   # sweet chime that curdles — the false jackpot
	Global.spawn_burst(global_position, Color(1, 0.25, 0.2), 16)   # rigged — angry red pop
	$AnimationPlayer.play("pickup")

	_roll_effect(body)


# Pick one rigged outcome at random and apply it.
func _roll_effect(body: Node2D) -> void:
	match randi() % 5:
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
		EXP_DRAIN:
			if body.has_method("lose_exp"):
				body.lose_exp(EXP_DRAIN_AMOUNT)
			_toast(body, "Rigged coin! It drained %d EXP." % EXP_DRAIN_AMOUNT)


func _toast(body: Node2D, text: String) -> void:
	if is_instance_valid(body) and body.has_method("show_toast"):
		body.show_toast(tr(text))
