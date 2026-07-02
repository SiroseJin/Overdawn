extends Control

# ─── Pause Menu ───────────────────────────────────────────────────────────────

var margin_container : Node
var save_menu        : Node
var load_menu        : Node
var confirm_panel    : Node
var audio_open       : Node
var audio_close      : Node

func _ready():
	margin_container = get_node_or_null("MarginContainer")
	save_menu        = get_node_or_null("SaveMenu")
	load_menu        = get_node_or_null("LoadMenu")
	confirm_panel    = get_node_or_null("ConfirmPanel")
	audio_open       = get_node_or_null("AudioOpen")
	audio_close      = get_node_or_null("AudioClose")

	if audio_open:
		audio_open.play()
	_refresh_slot_labels()

# ─────────────────────────────────────────────────────────────────────────────

func _refresh_slot_labels() -> void:
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var label : String = SaveManager.slot_label(i)

		if save_menu:
			var btn: Button = save_menu.get_node_or_null("VBoxContainer/SaveSlot%d" % i) as Button
			if btn:
				btn.text = label

		if load_menu:
			var btn:   Button      = load_menu.get_node_or_null("VBoxContainer/Slot%dRow/LoadSlot%d" % [i, i]) as Button
			var thumb: TextureRect = load_menu.get_node_or_null("VBoxContainer/Slot%dRow/Thumb%d" % [i, i]) as TextureRect
			if btn:
				btn.text     = label
				btn.disabled = not SaveManager.slot_exists(i)
			if thumb:
				thumb.texture = SaveManager.slot_thumbnail(i) if SaveManager.slot_exists(i) else null

func _show_only(container: Node) -> void:
	for c in [margin_container, save_menu, load_menu, confirm_panel]:
		if c:
			c.hide()
	if container:
		container.show()

# ─────────────────────────────────────────────────────────────────────────────
# Main buttons
# ─────────────────────────────────────────────────────────────────────────────

func _on_resume_pressed():
	if audio_close: audio_close.play()
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	hide()

func _on_save_pressed():
	if audio_open: audio_open.play()
	_refresh_slot_labels()
	_show_only(save_menu)

func _on_load_pressed():
	if audio_open: audio_open.play()
	_refresh_slot_labels()
	_show_only(load_menu)

func _on_settings_pressed():
	if audio_open: audio_open.play()
	if get_parent().get_node_or_null("SettingsOverlay"):
		return
	var settings: Node = (load("res://scene/settings.tscn") as PackedScene).instantiate()
	settings.name = "SettingsOverlay"
	get_parent().add_child(settings)
	hide()
	settings.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_debug_pressed():
	if audio_open: audio_open.play()
	var debug: Node = (load("res://scene/debug_settings.tscn") as PackedScene).instantiate()
	debug.name = "DebugOverlay"
	get_parent().add_child(debug)
	hide()
	debug.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_main_menu_pressed():
	if audio_open: audio_open.play()
	_show_only(confirm_panel)

func _on_confirm_pressed():
	if audio_close: audio_close.play()
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_cancel_pressed():
	if audio_close: audio_close.play()
	_show_only(margin_container)

func _on_quit_pressed():
	get_tree().quit()

# ─────────────────────────────────────────────────────────────────────────────
# Save slots
# ─────────────────────────────────────────────────────────────────────────────

func _on_save_slot_1_pressed(): _do_save(1)
func _on_save_slot_2_pressed(): _do_save(2)
func _on_save_slot_3_pressed(): _do_save(3)

func _do_save(slot: int) -> void:
	await SaveManager.save_game(slot)
	if audio_close: audio_close.play()
	_refresh_slot_labels()
	_show_only(margin_container)

# ─────────────────────────────────────────────────────────────────────────────
# Load slots
# ─────────────────────────────────────────────────────────────────────────────

func _on_load_slot_1_pressed(): _do_load(1)
func _on_load_slot_2_pressed(): _do_load(2)
func _on_load_slot_3_pressed(): _do_load(3)

func _do_load(slot: int) -> void:
	if not SaveManager.slot_exists(slot):
		return
	if audio_close: audio_close.play()
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	hide()
	SaveManager.load_game(slot)

func _on_back_pressed():
	if audio_close: audio_close.play()
	_show_only(margin_container)
