extends Node

# ─── SaveManager (Autoload) ──────────────────────────────────────────────────
# Handles reading and writing save files for up to MAX_SLOTS save slots.
# Screenshots are captured at save time, stored as base64 PNG inside the JSON,
# and decoded back to an ImageTexture when loading the slot UI.
# ─────────────────────────────────────────────────────────────────────────────

const MAX_SLOTS      : int    = 5     # manual save slots (1..MAX_SLOTS)
const AUTO_SLOT      : int    = 0     # dedicated auto-save slot (shown at the top)
const AUTOSAVE_INTERVAL : float = 300.0   # auto-save every 5 minutes of play
const SAVE_DIR       : String = "user://saves/"
const SAVE_PREFIX    : String = "save_slot_"
const SAVE_EXT       : String = ".json"
const THUMB_WIDTH    : int    = 160   # Thumbnail resolution stored in JSON
const THUMB_HEIGHT   : int    = 90

var _autosave_accum : float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func is_auto(slot: int) -> bool:
	return slot == AUTO_SLOT

# Manual slots only.
func manual_slots() -> Array:
	return range(1, MAX_SLOTS + 1)

# Every slot to list in the UI: the auto-save slot first, then the manual slots.
func all_slots() -> Array:
	var list := [AUTO_SLOT]
	list.append_array(manual_slots())
	return list

func _slot_name(slot: int) -> String:
	return "Auto-Save" if is_auto(slot) else "Slot %d" % slot

# ─── Slot-list UI builder (shared by every save/load menu) ────────────────────────
# Rebuilds `container`'s slot rows from all_slots() — the auto-save slot first, then
# the manual slots — so adding/removing slots is data-driven and no menu hardcodes
# rows. Old hardcoded rows are removed at runtime; nodes named in `keep` (e.g. the
# Back button) are preserved. `on_pressed` is called with the slot int on click.
const _SLOT_FONT := "res://art/Fonts/skeleboom.ttf"

func populate_slots(container: Node, on_pressed: Callable, save_mode: bool = false, keep: Array = ["Back"]) -> void:
	if container == null:
		return
	for c in container.get_children():
		if String(c.name) in keep:
			continue
		container.remove_child(c)
		c.queue_free()

	var font: Font = load(_SLOT_FONT)
	var index := 0
	for slot in all_slots():
		var exists: bool = slot_exists(slot)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(120, 68)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if exists:
			thumb.texture = slot_thumbnail(slot)
		row.add_child(thumb)

		var btn := Button.new()
		# Fixed width so every row matches (the parent CenterContainer sizes the list
		# to content, so EXPAND_FILL wouldn't stretch here).
		btn.custom_minimum_size = Vector2(300, 0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font:
			btn.add_theme_font_override("font", font)
		btn.text = slot_label(slot)
		btn.disabled = is_auto(slot) if save_mode else (not exists)
		var s: int = slot
		btn.pressed.connect(func(): on_pressed.call(s))
		row.add_child(btn)

		container.add_child(row)
		container.move_child(row, index)
		index += 1

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func slot_label(slot: int) -> String:
	var label_name := _slot_name(slot)
	if not slot_exists(slot):
		return "%s — Empty" % label_name
	var data := _read_json(slot)
	if data.is_empty():
		return "%s — Corrupted" % label_name
	var ts         : String = data.get("timestamp", "??:??:??")
	var lvl        : String = "Level %s" % str(data.get("player_level", "?"))
	var scene_path : String = data.get("current_scene", "")
	var scene_name : String = scene_path.get_file().get_basename().capitalize()
	if data.get("arcade_mode", false):
		scene_name = "Arcade — Wave %d" % int(data.get("current_wave", 0))
	return "%s — %s | %s | %s" % [label_name, lvl, ts, scene_name]

## Returns an ImageTexture thumbnail for the slot, or null if none exists.
func slot_thumbnail(slot: int) -> ImageTexture:
	if not slot_exists(slot):
		return null
	var data := _read_json(slot)
	var b64 : String = data.get("screenshot", "")
	if b64 == "":
		return null
	var bytes  := Marshalls.base64_to_raw(b64)
	var image  := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func save_game(slot: int, capture_shot: bool = true, hide_ui: bool = true) -> void:
	_ensure_save_dir()
	var data := collect_save_data()
	data["timestamp"]  = _formatted_time()
	# Screenshot must be taken before writing — capture now, store as base64 PNG.
	# `hide_ui` off = grab the current frame instantly (HUD included, no flicker) so
	# auto-saves can still get a thumbnail while the game is live.
	if capture_shot:
		data["screenshot"] = await _capture_screenshot(hide_ui)
	else:
		data["screenshot"] = ""
	_write_json(slot, data)
	print("[SaveManager] Saved to slot %d" % slot)

# ─────────────────────────────────────────────────────────────────────────────
# Auto-save — fires on stage entry (stages call autosave()) and every 5 minutes.
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _in_gameplay():
		_autosave_accum = 0.0
		return
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		autosave()

# Write the dedicated auto-save slot (no screenshot, so no flicker). Safe to call
# from anywhere — it no-ops outside of live gameplay.
func autosave() -> void:
	if not _in_gameplay():
		return
	_autosave_accum = 0.0
	# Capture a thumbnail, but WITHOUT hiding the HUD (that would flicker mid-play).
	save_game(AUTO_SLOT, true, false)
	print("[SaveManager] Auto-saved")

# Stage-entry auto-save: wait out the fade-in first so the thumbnail isn't a black
# screen. Stages call this (fire-and-forget) from their _ready.
func autosave_on_enter() -> void:
	# Fire a "stage_entered" event first (synchronously) so quests/badges reset their
	# per-stage trackers, e.g. the no-hit challenge, before the player can be hit.
	var scn := get_tree().current_scene
	if scn:
		ProgressionManager.notify("stage_entered", {"stage_id": String(scn.name).to_lower()})
	await get_tree().create_timer(0.7).timeout
	autosave()

func _in_gameplay() -> bool:
	return Global.gameStarted \
		and get_tree().current_scene != null \
		and is_instance_valid(Global.PlayerBody) \
		and Global.playerAlive

func load_game(slot: int) -> bool:
	if not slot_exists(slot):
		push_warning("[SaveManager] Slot %d is empty." % slot)
		return false
	var data := _read_json(slot)
	if data.is_empty():
		push_error("[SaveManager] Slot %d could not be parsed." % slot)
		return false
	apply_save_data(data)
	print("[SaveManager] Loaded slot %d" % slot)
	return true

func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] Deleted slot %d" % slot)

# ─────────────────────────────────────────────────────────────────────────────
# Screenshot capture
# ─────────────────────────────────────────────────────────────────────────────

func _capture_screenshot(hide_ui: bool = true) -> String:
	# Optionally hide every CanvasLayer (HUD/menus) for a clean shot. Auto-saves pass
	# hide_ui=false so the grab is instant (no 2-frame UI-hide flicker during play).
	var hidden : Array = []
	# This runs from the PAUSE MENU (Save), where the game is paused via
	# Engine.time_scale = 0. The two frame-waits below only resume while the main loop
	# advances at normal speed; at time_scale 0 they can stall — and since hiding the
	# UI also hides the pause menu itself (it lives under the same CanvasLayer), a stall
	# leaves the HUD + pause menu hidden with no way to click Resume = a frozen, grey
	# screen (grey on stages whose only backdrop is the parallax). Force real time for
	# the duration so the capture always completes and the UI is guaranteed restored.
	var prev_scale := Engine.time_scale
	if hide_ui:
		if prev_scale == 0.0:
			Engine.time_scale = 1.0
		_hide_canvas_layers(get_tree().root, hidden)
		# Wait two frames so the engine re-renders without any UI.
		await get_tree().process_frame
		await get_tree().process_frame

	var vp    : Viewport = get_tree().root
	var image : Image    = vp.get_texture().get_image()

	# Restore the hidden UI and the previous (paused) time scale IMMEDIATELY after the
	# grab — before the resize/encode below, which could error out. If restore ran after
	# and something threw, the HUD would be left invisible for the rest of play.
	for node in hidden:
		node.show()
	Engine.time_scale = prev_scale

	image.resize(THUMB_WIDTH, THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var bytes := image.save_png_to_buffer()
	return Marshalls.raw_to_base64(bytes)

func _hide_canvas_layers(node: Node, hidden: Array) -> void:
	for child in node.get_children():
		# ParallaxBackground is a CanvasLayer, but it's the world backdrop, not UI.
		# Never hide it: it belongs in the thumbnail, and on stages whose only visible
		# backdrop IS the parallax, leaving it hidden turns the screen fully grey.
		if child is ParallaxBackground:
			continue
		if child is CanvasLayer and child.visible:
			child.hide()
			hidden.append(child)
		else:
			_hide_canvas_layers(child, hidden)

# ─────────────────────────────────────────────────────────────────────────────
# Collect
# ─────────────────────────────────────────────────────────────────────────────

func collect_save_data() -> Dictionary:
	var data := {}

	data["current_scene"] = get_tree().current_scene.scene_file_path
	data["current_wave"]  = Global.current_wave
	data["player_alive"]  = Global.playerAlive
	data["arcade_mode"]   = Global.arcade_mode
	data["progression"]   = ProgressionManager.to_dict()

	if is_instance_valid(Global.PlayerBody):
		var p := Global.PlayerBody
		data["player_position"]    = { "x": p.global_position.x, "y": p.global_position.y }
		data["player_health"]      = p.health
		data["player_health_max"]  = p.health_max
		data["player_level"]       = p.level
		data["player_exp"]         = p.exp
		data["player_exp_to_next"] = p.exp_to_next_level
		data["player_strength"]    = p.strength
		data["player_score"]       = p.score
		data["player_arrows"]      = p.arrows_held
		data["player_max_arrows"]  = p.max_arrows

	return data

# ─────────────────────────────────────────────────────────────────────────────
# Apply
# ─────────────────────────────────────────────────────────────────────────────

func apply_save_data(data: Dictionary) -> void:
	# Set these before the scene loads so _ready() in stage.gd / player.gd can read them
	Global.arcade_mode  = data.get("arcade_mode", false)
	# stage.gd increments current_wave before spawning, so pre-set to saved-1
	Global.current_wave = max(0, int(data.get("current_wave", 1)) - 1)
	ProgressionManager.from_dict(data.get("progression", {}))

	var scene_path : String = data.get("current_scene", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		call_deferred("_restore_player_state", data)
	else:
		_restore_player_state(data)

func _restore_player_state(data: Dictionary) -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	Global.playerAlive  = data.get("player_alive", true)
	Global.current_wave = data.get("current_wave", 0)
	Global.arcade_mode  = data.get("arcade_mode", false)

	if not is_instance_valid(Global.PlayerBody):
		push_warning("[SaveManager] PlayerBody not valid after load.")
		return

	var p := Global.PlayerBody

	if data.has("player_position"):
		var pos : Dictionary = data["player_position"]
		p.global_position    = Vector2(pos["x"], pos["y"])

	p.health_max        = data.get("player_health_max",  100)
	p.health            = data.get("player_health",      100)
	p.health            = min(p.health, p.health_max)
	p.update_health_bar()

	p.level             = data.get("player_level",        1)
	p.exp               = data.get("player_exp",          0)
	p.exp_to_next_level = data.get("player_exp_to_next", 10)
	p.update_exp_lvl_label()

	p.strength    = data.get("player_strength", 11)
	p.score       = data.get("player_score",     0)
	p.update_score_label()

	p.max_arrows  = data.get("player_max_arrows", 2)
	p.arrows_held = data.get("player_arrows",     2)
	p.update_arrow_cd()

# ─────────────────────────────────────────────────────────────────────────────
# Private helpers
# ─────────────────────────────────────────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _write_json(slot: int, data: Dictionary) -> void:
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open %s for writing." % _slot_path(slot))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _read_json(slot: int) -> Dictionary:
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	return json.data as Dictionary

func _formatted_time() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [t["hour"], t["minute"], t["second"]]
