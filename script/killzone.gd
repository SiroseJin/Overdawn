extends Area2D

# ─── Kill Zone ─────────────────────────────────────────────────────────────────
# Boundary trigger placed around the stage edge.
# When any body enters it the game briefly slow-mos, then reloads the scene.
# ───────────────────────────────────────────────────────────────────────────────

@onready var timer = $Timer

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

func _on_body_entered(body):
	# Kill the body if it supports a die() method, and mark it dead
	if body.has_method("die"):
		body.die()
	if body.has("dead"):
		body.dead = true

	# Slow down time for a brief dramatic effect, then reload
	Engine.time_scale = 0.3
	timer.start()

func _on_timer_timeout():
	Engine.time_scale = 1
	get_tree().reload_current_scene()
