extends Area2D

@onready var timer = $Timer

func _on_body_entered(body):
	if body.has_method("die"):
		body.die()
		set_dead(body)
	Engine.time_scale = 0.3
	timer.start()

func set_dead(body):
	if body.has("dead"):
		body.dead = true

func _on_timer_timeout():
	Engine.time_scale = 1
	get_tree().reload_current_scene()
