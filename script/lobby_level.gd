extends Node2D

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var player_camera = $Player/Camera2D

func _ready():
	player_camera.enabled = false
	SceneTransitionAnimation.get_parent().get_node("ColorRect").color.a = 255
	SceneTransitionAnimation.play("fade_out")
	Global.gameStarted = false

func _on_start_game_detection_body_entered(body):
	if body is Player:
		Global.gameStarted = true
		SceneTransitionAnimation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/stage.tscn")

func _process(delta):
	if !Global.playerAlive:
		await get_tree().create_timer(3.0).timeout
		Global.gameStarted = false
		SceneTransitionAnimation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/lobby_level.tscn")
		return
