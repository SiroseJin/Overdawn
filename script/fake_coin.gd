extends Area2D

const DEBUFF_DURATION := 3.0
const SLOW_FACTOR := 0.7

var _collected := false

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("slow_down"):
		return

	_collected = true

	body.slow_down(SLOW_FACTOR)
	_start_restore_timer(body)

	$AnimationPlayer.play("pickup")


func _start_restore_timer(body: Node2D) -> void:
	var timer := get_tree().create_timer(DEBUFF_DURATION)
	timer.timeout.connect(func():
		if is_instance_valid(body) and body.has_method("restore_speed"):
			body.restore_speed()
	)
