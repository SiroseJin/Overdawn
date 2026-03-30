extends Node

# ─── SaveManager (Autoload) ──────────────────────────────────────────────────
# Handles reading and writing save files for up to MAX_SLOTS save slots.
# Screenshots are captured at save time, stored as base64 PNG inside the JSON,
# and decoded back to an ImageTexture when loading the slot UI.
# ─────────────────────────────────────────────────────────────────────────────

const MAX_SLOTS      : int    = 3
const SAVE_DIR       : String = "user://saves/"
const SAVE_PREFIX    : String = "save_slot_"
const SAVE_EXT       : String = ".json"
const THUMB_WIDTH    : int    = 160   # Thumbnail resolution stored in JSON
const THUMB_HEIGHT   : int    = 90

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func slot_label(slot: int) -> String:
	if not slot_exists(slot):
		return "Slot %d — Empty" % slot
	var data := _read_json(slot)
	if data.is_empty():
		return "Slot %d — Corrupted" % slot
	var ts         : String = data.get("timestamp", "??:??:??")
	var lvl        : String = "Level %s" % str(data.get("player_level", "?"))
	var scene_path : String = data.get("current_scene", "")
	var scene_name : String = scene_path.get_file().get_basename().capitalize()
	return "Slot %d — %s | %s | %s" % [slot, lvl, ts, scene_name]

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

func save_game(slot: int) -> void:
	_ensure_save_dir()
	var data := collect_save_data()
	data["timestamp"]  = _formatted_time()
	# Screenshot must be taken before writing — capture now, store as base64 PNG
	data["screenshot"] = await _capture_screenshot()
	_write_json(slot, data)
	print("[SaveManager] Saved to slot %d" % slot)

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

func _capture_screenshot() -> String:
	# Collect every CanvasLayer in the entire tree and hide them all
	var hidden : Array = []
	for node in get_tree().get_nodes_in_group(""):
		pass  # dummy — we use get_nodes_in_group below

	# Hide all CanvasLayers recursively from root
	_hide_canvas_layers(get_tree().root, hidden)

	# Wait two frames so the engine re-renders without any UI
	await get_tree().process_frame
	await get_tree().process_frame

	var vp    : Viewport = get_tree().root
	var image : Image    = vp.get_texture().get_image()
	image.resize(THUMB_WIDTH, THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var bytes := image.save_png_to_buffer()

	# Restore all hidden nodes
	for node in hidden:
		node.show()

	return Marshalls.raw_to_base64(bytes)

func _hide_canvas_layers(node: Node, hidden: Array) -> void:
	for child in node.get_children():
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
