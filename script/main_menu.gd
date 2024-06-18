extends Control

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_animation = $SceneTransitionAnimation
@onready var audio_player = $AudioStreamPlayer2D
@onready var audio_click = $AudioClick
@onready var audio_hover = $AudioHover

func _ready():
	handle_transition()
	handle_bgm()

func handle_transition():
	scene_transition_animation.show()
	SceneTransitionAnimation.play("fade_out")
	await get_tree().create_timer(1.0).timeout
	scene_transition_animation.queue_free()

func handle_bgm():
	audio_player.play()

func _on_start_pressed():
	audio_click.play()
	get_tree().change_scene_to_file("res://scene/lobby_level.tscn")

func _on_arcade_pressed():
	audio_click.play()
	get_tree().change_scene_to_file("res://scene/stage.tscn")

func _on_setting_pressed():
	audio_click.play()
	get_tree().change_scene_to_file("res://scene/settings.tscn")

func _on_quit_pressed():
	get_tree().quit()
