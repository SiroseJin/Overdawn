extends Control

# ─── Main Menu ────────────────────────────────────────────────────────────────

@onready var scene_transition_anim      = $SceneTransitionAnimation/AnimationPlayer
@onready var scene_transition_container = $SceneTransitionAnimation
@onready var load_menu     = $LoadMenu
@onready var menu_ui       = $MenuUI

func _ready():
	_handle_transition()
	AudioManager.stop_ambience()
	AudioManager.play_music("main_menu")
	var cont := $MenuUI/MenuSelect.get_node_or_null("Continue")
	if cont:
		cont.disabled = not SaveManager.has_any_save()

func _handle_transition():
	scene_transition_container.show()
	scene_transition_anim.play("fade_out")
	await get_tree().create_timer(0.8).timeout
	scene_transition_container.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# Button signals
# ─────────────────────────────────────────────────────────────────────────────

const NAME_ENTRY := preload("res://scene/ui/name_entry.tscn")
const DIFFICULTY_SELECT := preload("res://scene/ui/difficulty_select.tscn")

func _on_start_pressed():
	# New Game asks for a name first so each save is uniquely the player's (#15).
	var prompt := NAME_ENTRY.instantiate()
	add_child(prompt)
	prompt.submitted.connect(func(player_name: String):
		# Then a difficulty choice, which is persisted with the save.
		var diff := DIFFICULTY_SELECT.instantiate()
		add_child(diff)
		diff.chosen.connect(func(difficulty: int):
			# Fresh STORY run: leave arcade mode (which hands out the full skill kit) and wipe
			# carried-over progression so a new game never inherits buffs/stats. Then stamp
			# the chosen name (reset() defaults it to "Player") and difficulty.
			Global.arcade_mode = false
			ProgressionManager.reset()
			ProgressionManager.player_name = player_name
			Difficulty.set_difficulty(difficulty)
			get_tree().change_scene_to_file("res://scene/system/lobby_level.tscn")))

func _on_continue_pressed():
	# Jump straight back into the most recent save (auto-save included).
	var s := SaveManager.latest_slot()
	if s >= 0:
		SaveManager.load_game(s)
	# No save yet → do nothing (the button is greyed out in _ready).

func _on_load_pressed():
	menu_ui.hide()
	# The LoadMenu builds its own slot rows (auto-save slot + manual slots).
	if load_menu.has_method("refresh"):
		load_menu.refresh()
	load_menu.show()

func _on_arcade_pressed():
	Global.arcade_mode  = true
	Global.current_wave = 0
	get_tree().change_scene_to_file("res://scene/system/stage.tscn")

func _on_progress_pressed():
	Global.settings_return_path = "res://scene/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scene/ui/progress_menu.tscn")

func _on_setting_pressed():
	Global.settings_return_path = "res://scene/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scene/ui/settings.tscn")

func _on_debug_pressed():
	Global.settings_return_path = "res://scene/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scene/ui/debug_settings.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	load_menu.hide()
	menu_ui.show()
