extends Node

# ─── Score Manager ─────────────────────────────────────────────────────────────
# Tracks and displays the player's score.
# Each enemy / pickup type awards a different point value.
# ───────────────────────────────────────────────────────────────────────────────

@onready var score_label = $ScoreLabel

var score: int = 0

# ───────────────────────────────────────────────────────────────────────────────
# Score Helpers
# ───────────────────────────────────────────────────────────────────────────────

func _update_label():
	score_label.text = "Score: " + str(score)

func add_point_coin():
	score += 1
	_update_label()

func add_point_bat():
	score += 2
	_update_label()

func add_point_frog():
	score += 4
	_update_label()

func add_point_witch():
	score += 10
	_update_label()
