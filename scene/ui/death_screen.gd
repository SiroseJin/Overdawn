extends Control

# ─── Death Screen ─────────────────────────────────────────────────────────────

@onready var main_panel:    Control = $MainPanel
@onready var load_panel:    Control = $LoadPanel
@onready var confirm_panel: Control = $ConfirmPanel
@onready var confirm_label: Label   = $ConfirmPanel/VBoxContainer/ConfirmLabel
@onready var checkpoint_button: Button = $MainPanel/VBoxContainer/CheckpointButton

var _pending_scene := ""

func show_screen() -> void:
	_refresh_load_slots()
	# Only offer "From Checkpoint" when there's a checkpoint to return to in this stage.
	checkpoint_button.visible = CheckpointManager.can_respawn()
	_show_only(main_panel)
	show()

func _show_only(panel: Control) -> void:
	for p: Control in [main_panel, load_panel, confirm_panel]:
		p.hide()
	panel.show()

func _refresh_load_slots() -> void:
	SaveManager.populate_slots(load_panel.get_node_or_null("VBoxContainer"), _do_load, false, ["LoadBackButton"])

# ─── Main panel ───────────────────────────────────────────────────────────────

func _on_retry_pressed() -> void:
	# From the beginning: restart the whole stage (progression as it stands is kept).
	Engine.time_scale = 1
	get_tree().reload_current_scene()

func _on_checkpoint_pressed() -> void:
	# From the last checkpoint: roll progression back to the checkpoint snapshot and
	# reload the stage with the player dropped there.
	Engine.time_scale = 1
	CheckpointManager.respawn()

func _on_load_pressed() -> void:
	_refresh_load_slots()
	_show_only(load_panel)

func _on_lobby_pressed() -> void:
	_pending_scene = "res://scene/system/lobby_level.tscn"
	confirm_label.text = tr("Unsaved progress will be lost!")
	_show_only(confirm_panel)

func _on_menu_pressed() -> void:
	_pending_scene = "res://scene/ui/main_menu.tscn"
	confirm_label.text = tr("Unsaved progress will be lost!")
	_show_only(confirm_panel)

# ─── Load panel ───────────────────────────────────────────────────────────────

# Legacy .tscn connections resolve here; rows are now built in _refresh_load_slots().
func _on_load_slot_1_pressed(): _do_load(1)
func _on_load_slot_2_pressed(): _do_load(2)
func _on_load_slot_3_pressed(): _do_load(3)

func _do_load(slot: int) -> void:
	if not SaveManager.slot_exists(slot):
		return
	Engine.time_scale = 1
	SaveManager.load_game(slot)

func _on_load_back_pressed() -> void:
	_show_only(main_panel)

# ─── Confirm panel ────────────────────────────────────────────────────────────

func _on_confirm_pressed() -> void:
	Engine.time_scale = 1
	get_tree().change_scene_to_file(_pending_scene)

func _on_cancel_pressed() -> void:
	_show_only(main_panel)

# Esc: from the load or confirm sub-panels, return to the main choices (#1). On the
# main panel it does nothing (there's no "resume" from death).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not main_panel.visible:
		_show_only(main_panel)
		get_viewport().set_input_as_handled()
