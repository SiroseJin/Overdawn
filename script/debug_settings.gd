extends Control

# ─── Debug Settings ───────────────────────────────────────────────────────────

@onready var _vbox              = $ColorRect/MarginContainer/VBoxContainer
@onready var _arcade_toggle     = $ColorRect/MarginContainer/VBoxContainer/ArcadeModeToggle
@onready var _hp_spin           = $ColorRect/MarginContainer/VBoxContainer/HPRow/CurrentHPSpin
@onready var _hp_max_spin       = $ColorRect/MarginContainer/VBoxContainer/HPRow/MaxHPSpin
@onready var _apply_hp_btn      = $ColorRect/MarginContainer/VBoxContainer/HPRow/ApplyHP
@onready var _level_spin        = $ColorRect/MarginContainer/VBoxContainer/LevelRow/LevelSpin
@onready var _apply_level_btn   = $ColorRect/MarginContainer/VBoxContainer/LevelRow/ApplyLevel
@onready var _dead_test_btn     = $ColorRect/MarginContainer/VBoxContainer/DeadTest

func _ready() -> void:
	_arcade_toggle.button_pressed = Global.arcade_mode

	var has_player := Global.PlayerBody != null and is_instance_valid(Global.PlayerBody)
	if has_player:
		_hp_spin.value     = Global.PlayerBody.health
		_hp_max_spin.value = Global.PlayerBody.health_max
		_level_spin.value  = Global.PlayerBody.level
	else:
		_hp_spin.editable       = false
		_hp_max_spin.editable   = false
		_apply_hp_btn.disabled  = true
		_level_spin.editable    = false
		_apply_level_btn.disabled = true
		_dead_test_btn.disabled = true
		for node in [_hp_spin, _hp_max_spin, _apply_hp_btn, _level_spin, _apply_level_btn, _dead_test_btn]:
			node.modulate.a = 0.4

# ─── Arcade Mode ──────────────────────────────────────────────────────────────

func _on_arcade_mode_toggle_toggled(toggled_on: bool) -> void:
	Global.arcade_mode = toggled_on
	SettingsManager.save_settings()

# ─── Stage Selector ───────────────────────────────────────────────────────────

func _on_lobby_pressed()   -> void: _go("res://scene/lobby_level.tscn")
func _on_stage1_pressed()  -> void: _go("res://scene/Levels/Level1/stage1.tscn")
func _on_stage2_pressed()  -> void: _go("res://scene/Levels/Level2/stage2.tscn")
func _on_stage3_pressed()  -> void: _go("res://scene/Levels/Level3/stage3.tscn")
func _on_stage4_pressed()  -> void: _go("res://scene/Levels/Level4/stage4.tscn")
func _on_stage5_pressed()  -> void: _go("res://scene/Levels/Level5/stage5.tscn")
func _on_stage6_pressed()  -> void: _go("res://scene/Levels/Level6/stage6.tscn")

func _go(path: String) -> void:
	Engine.time_scale = 1
	# Teleporting can skip a stage's skill-unlock NPC; grant everything so later
	# stages that need those skills stay clearable.
	ProgressionManager.unlock_all()
	get_tree().change_scene_to_file(path)

# ─── HP Editor ────────────────────────────────────────────────────────────────

func _on_apply_hp_pressed() -> void:
	if Global.PlayerBody == null or not is_instance_valid(Global.PlayerBody):
		return
	var new_max := int(_hp_max_spin.value)
	var new_hp  := clampi(int(_hp_spin.value), 0, new_max)
	Global.PlayerBody.health_max = new_max
	Global.PlayerBody.health     = new_hp
	Global.PlayerBody.update_health_bar()

# ─── Level Editor ─────────────────────────────────────────────────────────────

func _on_apply_level_pressed() -> void:
	if Global.PlayerBody == null or not is_instance_valid(Global.PlayerBody):
		return
	var target_level := int(_level_spin.value)
	Global.PlayerBody.level = target_level
	Global.PlayerBody.exp   = 0
	Global.PlayerBody.exp_to_next_level = int(10 * pow(1.1, target_level - 1))
	Global.PlayerBody.update_exp_lvl_label()

# ─── Dead Test ────────────────────────────────────────────────────────────────

func _on_dead_test_pressed() -> void:
	if Global.PlayerBody == null or not is_instance_valid(Global.PlayerBody):
		return
	# Hide pause menu so it doesn't reappear when this overlay closes
	var pause_menu = get_parent().get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.hide()
	# Unpause so death animation timers can run
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	hide()
	Global.PlayerBody.die()

# ─── Back ─────────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()
