extends Control

@onready var margin_container = $MarginContainer
@onready var option_container = $OptionContainer
@onready var audio_open = $AudioOpen
@onready var audio_close = $AudioClose

var resolutions = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768),
	Vector2(800, 600)
]

func _ready():
	audio_open.play()

func _on_resume_pressed():
	audio_close.play()
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	self.hide()

func _on_settings_pressed():
	audio_open.play()
	margin_container.hide()
	option_container.show()

func _on_lobby_pressed():
	audio_close.play()
	Global.PlayerBody.dead = true
	Global.PlayerBody.handle_death_animation()
	Global.playerAlive = false
	Engine.time_scale = 1
	self.hide()

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
	audio_close.play()
	margin_container.show()
	option_container.hide()
