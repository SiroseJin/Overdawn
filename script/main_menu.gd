extends Control

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_animation = $SceneTransitionAnimation
@onready var audio_player = $AudioStreamPlayer2D
@onready var audio_click = $AudioClick
@onready var audio_hover = $AudioHover
@onready var option_container = $OptionContainer
@onready var menu_ui = $MenuUI

var resolutions = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768),
	Vector2(800, 600)
]

func _ready():
	handle_transition()
	handle_bgm()

func handle_transition():
	scene_transition_animation.show()
	SceneTransitionAnimation.play("fade_out")
	await get_tree().create_timer(0.8).timeout
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
	menu_ui.hide()
	option_container.show()

func _on_quit_pressed():
	get_tree().quit()

func _on_resolution_select_item_selected(index):
	var new_resolution = resolutions[index]
	DisplayServer.window_set_size(new_resolution)
	get_viewport().size = new_resolution

func _on_full_screen_toggle_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed():
	option_container.hide()
	menu_ui.show()
