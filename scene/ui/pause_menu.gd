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
	if save_menu:
		SaveManager.populate_slots(save_menu.get_node_or_null("VBoxContainer"), _do_save, true)
	if load_menu:
		SaveManager.populate_slots(load_menu.get_node_or_null("VBoxContainer"), _do_load, false)

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
	# Unfreeze FIRST and guard the player ref: if PlayerBody were invalid, the old
	# order threw here and left time_scale at 0 = permanently frozen/unplayable.
	Engine.time_scale = 1
	Dialogic.paused = false
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.is_game_paused = false
	_ensure_backgrounds_visible()
	hide()

# Safety net against the "grey screen" bug: a ParallaxBackground is the world backdrop
# and must never stay hidden. If anything (e.g. an interrupted screenshot capture) ever
# leaves one hidden, un-hide every ParallaxBackground in the scene on resume so we never
# come back to an empty grey screen on parallax-only stages.
func _ensure_backgrounds_visible() -> void:
	var scene := get_tree().current_scene
	if scene:
		_show_parallax(scene)

func _show_parallax(node: Node) -> void:
	for child in node.get_children():
		if child is ParallaxBackground:
			child.visible = true
		else:
			_show_parallax(child)

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
	var settings: Node = (load("res://scene/ui/settings.tscn") as PackedScene).instantiate()
	settings.name = "SettingsOverlay"
	get_parent().add_child(settings)
	hide()
	settings.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_progress_pressed():
	if audio_open: audio_open.play()
	if get_parent().get_node_or_null("ProgressOverlay"):
		return
	var pm: Node = (load("res://scene/ui/progress_menu.tscn") as PackedScene).instantiate()
	pm.name = "ProgressOverlay"
	get_parent().add_child(pm)
	hide()
	pm.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_quests_pressed():
	if audio_open: audio_open.play()
	if get_parent().get_node_or_null("QuestOverlay"):
		return
	var qm: Node = (load("res://scene/ui/quest_menu.tscn") as PackedScene).instantiate()
	qm.name = "QuestOverlay"
	get_parent().add_child(qm)
	hide()
	qm.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_guide_pressed():
	if audio_open: audio_open.play()
	if get_parent().get_node_or_null("CodexOverlay"):
		return
	var cm: Node = (load("res://scene/ui/codex_menu.tscn") as PackedScene).instantiate()
	cm.name = "CodexOverlay"
	get_parent().add_child(cm)
	hide()
	cm.tree_exited.connect(func():
		if is_instance_valid(self):
			show()
	)

func _on_debug_pressed():
	if audio_open: audio_open.play()
	var debug: Node = (load("res://scene/ui/debug_settings.tscn") as PackedScene).instantiate()
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
	get_tree().change_scene_to_file("res://scene/ui/main_menu.tscn")

func _on_cancel_pressed():
	if audio_close: audio_close.play()
	_show_only(margin_container)

func _on_quit_pressed():
	get_tree().quit()

# ─────────────────────────────────────────────────────────────────────────────
# Save slots
# ─────────────────────────────────────────────────────────────────────────────

# Legacy .tscn connections resolve here; rows are now built in _refresh_slot_labels().
func _on_save_slot_1_pressed(): _do_save(1)
func _on_save_slot_2_pressed(): _do_save(2)
func _on_save_slot_3_pressed(): _do_save(3)
func _on_load_slot_1_pressed(): _do_load(1)
func _on_load_slot_2_pressed(): _do_load(2)
func _on_load_slot_3_pressed(): _do_load(3)

func _do_save(slot: int) -> void:
	await SaveManager.save_game(slot)
	if audio_close: audio_close.play()
	_refresh_slot_labels()
	_show_only(margin_container)

# ─────────────────────────────────────────────────────────────────────────────
# Load slots
# ─────────────────────────────────────────────────────────────────────────────

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

# Esc: from a sub-panel (save/load/confirm) go back to the main list; from the main
# list, resume the game — same as the buttons, just on the key (#1).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if margin_container and margin_container.visible:
		_on_resume_pressed()
	else:
		_show_only(margin_container)
	get_viewport().set_input_as_handled()
