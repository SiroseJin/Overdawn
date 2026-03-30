extends Control

# ─── Pause Menu ───────────────────────────────────────────────────────────────

var margin_container : Node
var option_container : Node
var save_menu        : Node
var load_menu        : Node
var audio_open       : Node
var audio_close      : Node

var resolutions: Array = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768),
	Vector2(800,  600),
]

func _ready():
	margin_container = get_node_or_null("MarginContainer")
	option_container = get_node_or_null("OptionContainer")
	save_menu        = get_node_or_null("SaveMenu")
	load_menu        = get_node_or_null("LoadMenu")
	audio_open       = get_node_or_null("AudioOpen")
	audio_close      = get_node_or_null("AudioClose")

	for pair in [
		["MarginContainer", margin_container],
		["OptionContainer", option_container],
		["SaveMenu",        save_menu],
		["LoadMenu",        load_menu],
		["AudioOpen",       audio_open],
		["AudioClose",      audio_close],
	]:
		if pair[1] == null:
			push_warning("PauseMenu: node '%s' not found." % pair[0])

	if audio_open:
		audio_open.play()
	_refresh_slot_labels()

# ─────────────────────────────────────────────────────────────────────────────

func _refresh_slot_labels() -> void:
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var label : String = SaveManager.slot_label(i)

		if save_menu:
			var btn = save_menu.get_node_or_null("VBoxContainer/SaveSlot%d" % i)
			if btn:
				btn.text = label

		if load_menu:
			var btn   = load_menu.get_node_or_null("VBoxContainer/Slot%dRow/LoadSlot%d" % [i, i])
			var thumb = load_menu.get_node_or_null("VBoxContainer/Slot%dRow/Thumb%d" % [i, i])
			if btn:
				btn.text     = label
				btn.disabled = not SaveManager.slot_exists(i)
			if thumb:
				thumb.texture = SaveManager.slot_thumbnail(i) if SaveManager.slot_exists(i) else null

func _show_only(container: Node) -> void:
	for c in [margin_container, option_container, save_menu, load_menu]:
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
	_show_only(option_container)

func _on_lobby_pressed():
	if audio_close: audio_close.play()
	Global.PlayerBody.dead = true
	Global.PlayerBody.handle_death_animation()
	Global.playerAlive = false
	Engine.time_scale  = 1
	hide()

func _on_quit_pressed():
	get_tree().quit()

# ─────────────────────────────────────────────────────────────────────────────
# Save slots — save_game is now async (captures screenshot)
# ─────────────────────────────────────────────────────────────────────────────

func _on_save_slot_1_pressed(): _do_save(1)
func _on_save_slot_2_pressed(): _do_save(2)
func _on_save_slot_3_pressed(): _do_save(3)

func _do_save(slot: int) -> void:
	# save_game is async — await it so screenshot is captured before refresh
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
	hide()
	SaveManager.load_game(slot)

func _on_back_pressed():
	if audio_close: audio_close.play()
	_show_only(margin_container)

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
