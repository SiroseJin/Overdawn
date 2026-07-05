extends Control

# ─── Main Menu ────────────────────────────────────────────────────────────────

@onready var scene_transition_anim      = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_container = $SceneTransitionAnimation
@onready var audio_player  = $AudioStreamPlayer2D
@onready var audio_click   = $AudioClick
@onready var audio_hover   = $AudioHover
@onready var load_menu     = $LoadMenu
@onready var menu_ui       = $MenuUI

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
	# Fresh run: wipe carried-over progression (coins, skills, level/exp/health…)
	# so a new game never inherits stats from a previous playthrough this session.
	ProgressionManager.reset()
	get_tree().change_scene_to_file("res://scene/system/lobby_level.tscn")

func _on_load_pressed():
	audio_click.play()
	menu_ui.hide()
	# The LoadMenu builds its own slot rows (auto-save slot + manual slots).
	if load_menu.has_method("refresh"):
		load_menu.refresh()
	load_menu.show()

func _on_arcade_pressed():
	audio_click.play()
	Global.arcade_mode  = true
	Global.current_wave = 0
	get_tree().change_scene_to_file("res://scene/system/stage.tscn")

func _on_setting_pressed():
	audio_click.play()
	Global.settings_return_path = "res://scene/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scene/ui/settings.tscn")

func _on_debug_pressed():
	audio_click.play()
	Global.settings_return_path = "res://scene/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scene/ui/debug_settings.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	load_menu.hide()
	menu_ui.show()
