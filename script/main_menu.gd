extends Control

# ─── Main Menu ────────────────────────────────────────────────────────────────

@onready var scene_transition_anim      = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_container = $SceneTransitionAnimation
@onready var audio_player  = $AudioStreamPlayer2D
@onready var audio_click   = $AudioClick
@onready var audio_hover   = $AudioHover
@onready var option_container = $OptionContainer
@onready var load_menu        = $LoadMenu
@onready var menu_ui          = $MenuUI

var resolutions: Array = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768),
	Vector2(800,  600),
]

func _ready():
	_handle_transition()
	audio_player.play()

func _handle_transition():
	scene_transition_container.show()
	scene_transition_anim.play("fade_out")
	await get_tree().create_timer(0.8).timeout
	scene_transition_container.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# Button signals
# ─────────────────────────────────────────────────────────────────────────────

func _on_start_pressed():
	audio_click.play()
	get_tree().change_scene_to_file("res://scene/lobby_level.tscn")

func _on_load_pressed():
	audio_click.play()
	menu_ui.hide()
	_refresh_load_menu()
	load_menu.show()

func _refresh_load_menu() -> void:
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		# Slot rows: Slot1Row/Save1, Slot1Row/Thumb1
		var btn   = load_menu.get_node_or_null("LoadMenuUI/LoadMenuSelect/Slot%dRow/Save%d" % [i, i])
		var thumb = load_menu.get_node_or_null("LoadMenuUI/LoadMenuSelect/Slot%dRow/Thumb%d" % [i, i])

		if btn == null:
			continue

		var exists : bool = SaveManager.slot_exists(i)
		btn.text     = SaveManager.slot_label(i)
		btn.disabled = not exists

		if thumb != null:
			thumb.texture = SaveManager.slot_thumbnail(i) if exists else null

		# Connect load signal once
		if not btn.pressed.is_connected(_on_load_slot_pressed.bind(i)):
			btn.pressed.connect(_on_load_slot_pressed.bind(i))

	# Connect Back once
	var back = load_menu.get_node_or_null("LoadMenuUI/LoadMenuSelect/Back")
	if back and not back.pressed.is_connected(_on_back_pressed):
		back.pressed.connect(_on_back_pressed)

func _on_load_slot_pressed(slot: int) -> void:
	SaveManager.load_game(slot)

func _on_arcade_pressed():
	audio_click.play()
	get_tree().change_scene_to_file("res://scene/stage.tscn")

func _on_setting_pressed():
	audio_click.play()
	menu_ui.hide()
	option_container.show()

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	option_container.hide()
	load_menu.hide()
	menu_ui.show()

# ─────────────────────────────────────────────────────────────────────────────
# Settings
# ─────────────────────────────────────────────────────────────────────────────

func _on_resolution_select_item_selected(index: int):
	var new_res = resolutions[index]
	DisplayServer.window_set_size(new_res)
	get_viewport().size = new_res

func _on_full_screen_toggle_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
