extends Area2D

# ─── Kill Zone ─────────────────────────────────────────────────────────────────
# Boundary trigger placed around the stage edge.
# When any body enters it the game briefly slow-mos, then reloads the scene.
# ───────────────────────────────────────────────────────────────────────────────


func _on_body_entered(body):
	if body.has_method("die"):
		AudioManager.play_sfx("killzone")
		body.die()
