extends Area2D

class_name CoinItem

@onready var animation_player = $AnimationPlayer
var score_manager

const score_value = 10

func _ready():
	var score_manager_path = "Player/CanvasLayer/HBoxContainer/ScoreManager"

func _on_body_entered(body):
	if Global.PlayerBody:
		Global.PlayerBody.gain_score(score_value)
		animation_player.play("pickup")
		await get_tree().create_timer(0.4).timeout
	self.queue_free()
