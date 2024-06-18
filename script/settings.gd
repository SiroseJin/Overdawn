extends Control

# Define the resolutions
var resolutions = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768),
	Vector2(800, 600)
]

func _ready():
	pass

func _process(delta):
	pass

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
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
