extends Control

# ─── Death Screen ─────────────────────────────────────────────────────────────

@onready var main_panel:    Control = $MainPanel
@onready var load_panel:    Control = $LoadPanel
@onready var confirm_panel: Control = $ConfirmPanel
@onready var confirm_label: Label   = $ConfirmPanel/VBoxContainer/ConfirmLabel

var _pending_scene := ""

func show_screen() -> void:
	_refresh_load_slots()
	_show_only(main_panel)
	show()

func _show_only(panel: Control) -> void:
	for p: Control in [main_panel, load_panel, confirm_panel]:
		p.hide()
	panel.show()

func _refresh_load_slots() -> void:
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var label := SaveManager.slot_label(i)
		var btn: Button      = load_panel.get_node_or_null("VBoxContainer/Slot%dRow/LoadSlot%d" % [i, i]) as Button
		var thumb: TextureRect = load_panel.get_node_or_null("VBoxContainer/Slot%dRow/Thumb%d" % [i, i]) as TextureRect
		if btn:
			btn.text     = label
			btn.disabled = not SaveManager.slot_exists(i)
		if thumb:
			thumb.texture = SaveManager.slot_thumbnail(i) if SaveManager.slot_exists(i) else null

# ─── Main panel ───────────────────────────────────────────────────────────────

func _on_retry_pressed() -> void:
	Engine.time_scale = 1
	get_tree().reload_current_scene()

func _on_load_pressed() -> void:
	_refresh_load_slots()
	_show_only(load_panel)

func _on_lobby_pressed() -> void:
	_pending_scene = "res://scene/lobby_level.tscn"
	confirm_label.text = tr("Unsaved progress will be lost!")
	_show_only(confirm_panel)

func _on_menu_pressed() -> void:
	_pending_scene = "res://scene/main_menu.tscn"
	confirm_label.text = tr("Unsaved progress will be lost!")
	_show_only(confirm_panel)

# ─── Load panel ───────────────────────────────────────────────────────────────

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
