extends Node

const CONFIG_PATH := "user://settings.cfg"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	# Audio
	var master_vol: float = config.get_value("audio", "master_volume", 1.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"), linear_to_db(master_vol))

	var bgm_idx := AudioServer.get_bus_index("bgm")
	if bgm_idx != -1:
		AudioServer.set_bus_volume_db(
			bgm_idx, linear_to_db(config.get_value("audio", "music_volume", 1.0)))

	var sfx_idx := AudioServer.get_bus_index("sfx")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(
			sfx_idx, linear_to_db(config.get_value("audio", "sfx_volume", 1.0)))

	# Display
	if config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync: bool = config.get_value("display", "vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	var res: Vector2i = config.get_value("display", "resolution", Vector2i(1280, 720))
	DisplayServer.window_set_size(res)

	# Locale
	TranslationServer.set_locale(config.get_value("app", "locale", "en"))

	# Gameplay
	Global.arcade_mode = config.get_value("game", "arcade_mode", false)

func save_settings() -> void:
	var config := ConfigFile.new()

	# Audio
	config.set_value("audio", "master_volume",
		db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))

	var bgm_idx := AudioServer.get_bus_index("bgm")
	if bgm_idx != -1:
		config.set_value("audio", "music_volume",
			db_to_linear(AudioServer.get_bus_volume_db(bgm_idx)))

	var sfx_idx := AudioServer.get_bus_index("sfx")
	if sfx_idx != -1:
		config.set_value("audio", "sfx_volume",
			db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))

	# Display
	config.set_value("display", "fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("display", "vsync",
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	config.set_value("display", "resolution", DisplayServer.window_get_size())

	# Locale
	config.set_value("app", "locale", TranslationServer.get_locale())

	# Gameplay
	config.set_value("game", "arcade_mode", Global.arcade_mode)

	config.save(CONFIG_PATH)
