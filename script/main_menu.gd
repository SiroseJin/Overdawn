extends Control

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_animation = $SceneTransitionAnimation

func _ready():
	SceneTransitionAnimation.play("fade_out")
	await get_tree().create_timer(1.0).timeout
	scene_transition_animation.hide()

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scene/lobby_level.tscn")

func _on_arcade_pressed():
	get_tree().change_scene_to_file("res://scene/stage.tscn")

func _on_setting_pressed():
	get_tree().change_scene_to_file("res://scene/settings.tscn")

func _on_quit_pressed():
	get_tree().quit()


