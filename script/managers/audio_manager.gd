extends Node
## Central audio hub (autoload).
##
## Everything that makes a sound calls one of:
##   AudioManager.play_sfx("jump")        # gameplay one-shots  -> "sfx" bus
##   AudioManager.play_ui("click")        # menu / HUD one-shots -> "ui" bus
##   AudioManager.play_music("stage1")    # looping BGM          -> "bgm" bus (crossfaded)
##   AudioManager.play_ambience("city")   # looping background   -> "ambience" bus
##   AudioManager.start_loop("low_health")/ stop_loop("low_health")  # sustained sfx
##
## To re-skin a sound: just drop a new file over the matching path in res://audio/.
## The keys below never change, so no code edits are needed to swap audio.
##
## Volume is handled entirely by the audio buses (see default_bus_layout.tres):
##   Master -> { bgm -> ambience, sfx -> ui }
## so the Music slider governs music + ambience, and the SFX slider governs sfx + ui.

const MUSIC := {
	"main_menu":   "res://audio/music/main_menu.wav",
	"lobby":       "res://audio/music/lobby.ogg",
	"tutorial":    "res://audio/music/tutorial.wav",
	"stage1":      "res://audio/music/stage1.wav",
	"stage2":      "res://audio/music/stage2.ogg",
	"stage3":      "res://audio/music/stage3.wav",
	"stage4":      "res://audio/music/stage4.mp3",
	"stage5":      "res://audio/music/stage5.wav",
	"boss":        "res://audio/music/boss.ogg",
	"boss_phase2": "res://audio/music/boss_phase2.ogg",
	"arcade":      "res://audio/music/arcade.wav",
	"victory":     "res://audio/music/victory.wav",
	"game_over":   "res://audio/music/game_over.mp3",
}

const AMBIENCE := {
	"city":    "res://audio/ambience/city.wav",
	"dread":   "res://audio/ambience/dread.wav",
	"hopeful": "res://audio/ambience/hopeful.wav",
	"server":  "res://audio/ambience/server.wav",
}

const SFX := {
	# --- player ---
	"jump":            "res://audio/sfx/player/jump.wav",
	"double_jump":     "res://audio/sfx/player/double_jump.wav",
	"land":            "res://audio/sfx/player/land.wav",
	"melee":           "res://audio/sfx/player/melee.wav",
	"melee_hit":       "res://audio/sfx/player/melee_hit.wav",
	"arrow_shoot":     "res://audio/sfx/player/arrow_shoot.wav",
	"arrow_hit":       "res://audio/sfx/player/arrow_hit.wav",
	"no_arrows":       "res://audio/sfx/player/no_arrows.wav",
	"arrow_reload":    "res://audio/sfx/player/arrow_reload.wav",
	"hurt":            "res://audio/sfx/player/hurt.wav",
	"heal":            "res://audio/sfx/player/heal.wav",
	"level_up":        "res://audio/sfx/player/level_up.wav",
	"low_health":      "res://audio/sfx/player/low_health.wav",
	"death":           "res://audio/sfx/player/death.wav",
	"respawn":         "res://audio/sfx/player/respawn.wav",
	"firewall_up":     "res://audio/sfx/player/firewall_up.wav",
	"firewall_block":  "res://audio/sfx/player/firewall_block.ogg",
	"firewall_down":   "res://audio/sfx/player/firewall_down.wav",
	# --- enemy ---
	"alert":             "res://audio/sfx/enemy/alert.ogg",
	"adbot_attack":      "res://audio/sfx/enemy/adbot_attack.ogg",
	"adbot_death":       "res://audio/sfx/enemy/adbot_death.ogg",
	"buzzer_attack":     "res://audio/sfx/enemy/buzzer_attack.wav",
	"buzzer_death":      "res://audio/sfx/enemy/buzzer_death.ogg",
	"collector_attack":  "res://audio/sfx/enemy/collector_attack.ogg",
	"collector_death":   "res://audio/sfx/enemy/collector_death.ogg",
	"collector_fireball":"res://audio/sfx/enemy/collector_fireball.ogg",
	"fireball_impact":   "res://audio/sfx/enemy/fireball_impact.wav",
	"dealer_attack":     "res://audio/sfx/enemy/dealer_attack.ogg",
	"dealer_death":      "res://audio/sfx/enemy/dealer_death.ogg",
	"dealer_slow_orb":   "res://audio/sfx/enemy/dealer_slow_orb.ogg",
	"charge_coin":       "res://audio/sfx/enemy/charge_coin.ogg",
	"fake_coin_shot":    "res://audio/sfx/enemy/fake_coin.ogg",
	"enemy_hurt":        "res://audio/sfx/enemy/enemy_hurt.ogg",
	# --- boss ---
	"boss_intro":            "res://audio/sfx/boss/intro.ogg",
	"boss_bullet":           "res://audio/sfx/boss/bullet.ogg",
	"boss_bullet_impact":    "res://audio/sfx/boss/bullet_impact.wav",
	"boss_server_spawn":     "res://audio/sfx/boss/server_spawn.ogg",
	"boss_server_destroyed": "res://audio/sfx/boss/server_destroyed.ogg",
	"boss_telegraph":        "res://audio/sfx/boss/telegraph.ogg",
	"boss_hurt":             "res://audio/sfx/boss/hurt.ogg",
	"boss_phase":            "res://audio/sfx/boss/phase.ogg",
	"boss_death":            "res://audio/sfx/boss/death.ogg",
	# --- pickups ---
	"coin":           "res://audio/sfx/pickup/coin.wav",
	"fake_coin":      "res://audio/sfx/pickup/fake_coin.wav",
	"shard":          "res://audio/sfx/pickup/shard.wav",
	"shard_overflow": "res://audio/sfx/pickup/shard_overflow.wav",
	"key":            "res://audio/sfx/pickup/key.wav",
	"door_locked":    "res://audio/sfx/pickup/door_locked.wav",
	"door_open":      "res://audio/sfx/pickup/door_open.wav",
	"lore":           "res://audio/sfx/pickup/lore.wav",
	"health":         "res://audio/sfx/pickup/health.wav",
	# --- gimmicks ---
	"checkpoint":       "res://audio/sfx/gimmick/checkpoint.wav",
	"killzone":         "res://audio/sfx/gimmick/killzone.wav",
	"falling_platform": "res://audio/sfx/gimmick/falling_platform.ogg",
	"bait_platform":    "res://audio/sfx/gimmick/bait_platform.ogg",
	"debt_pop":         "res://audio/sfx/gimmick/debt_pop.ogg",
	# Sustained gimmick beds (played via attach_loop, one per gimmick instance).
	"rising_debt":      "res://audio/sfx/gimmick/rising_debt.mp3",
	"debt_wall":        "res://audio/sfx/gimmick/debt_wall.mp3",
	"pull_zone":        "res://audio/sfx/gimmick/pull_zone.ogg",
}

const UI := {
	"hover":            "res://audio/ui/hover.ogg",
	"click":            "res://audio/ui/click.ogg",
	"back":             "res://audio/ui/back.ogg",
	"menu_open":        "res://audio/ui/menu_open.ogg",
	"menu_close":       "res://audio/ui/menu_close.ogg",
	"tab":              "res://audio/ui/tab.ogg",
	"pause":            "res://audio/ui/pause.wav",
	"unpause":          "res://audio/ui/unpause.wav",
	"quest_accept":     "res://audio/ui/quest_accept.wav",
	"quest_progress":   "res://audio/ui/quest_progress.ogg",
	"quest_complete":   "res://audio/ui/quest_complete.wav",
	"badge":            "res://audio/ui/badge.wav",
	"toast":            "res://audio/ui/toast.ogg",
	"dialogue_advance": "res://audio/ui/dialogue_advance.ogg",
	"dialogue_blip":    "res://audio/ui/dialogue_blip.wav",
	"quiz_correct":     "res://audio/ui/quiz_correct.wav",
	"quiz_wrong":       "res://audio/ui/quiz_wrong.wav",
	"quiz_pass":        "res://audio/ui/quiz_pass.wav",
	"name_key":         "res://audio/ui/name_key.ogg",
	"save":             "res://audio/ui/save.ogg",
	"load":             "res://audio/ui/load.ogg",
	"transition":       "res://audio/ui/transition.wav",
	"exp_tick":         "res://audio/ui/exp_tick.ogg",
	"lore_unlock":      "res://audio/ui/lore_unlock.wav",
}

const SFX_VOICES := 14   # concurrent gameplay one-shots
const UI_VOICES  := 6    # concurrent UI one-shots
const MUSIC_FADE := 1.0  # crossfade seconds

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer          # whichever is currently the "front" track
var _ambi: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _ui_i := 0
var _loops := {}                              # key -> AudioStreamPlayer (sustained one-shots)
var _stream_cache := {}                       # path -> loaded AudioStream

var _current_music := ""
var _current_ambience := ""

# The single in-flight crossfade tween per channel. A new fade kills the previous one
# first so a stale tween's stop/-40 callback can't fire on a player the new track has
# since taken over (the intermittent mute after respawn: game_over -> stage reload).
var _music_tween: Tween
var _ambi_tween: Tween

func _kill_fade(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()

func _ready() -> void:
	# Audio must keep playing (and UI sounds must fire) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_a = _make_player(&"bgm")
	_music_b = _make_player(&"bgm")
	_music_active = _music_a
	_ambi = _make_player(&"ambience")

	for i in SFX_VOICES:
		_sfx_pool.append(_make_player(&"sfx"))
	for i in UI_VOICES:
		_ui_pool.append(_make_player(&"ui"))

	# Auto-wire hover + click to EVERY button in the game, present and future, from
	# this one place — no per-menu wiring, and new buttons get sound for free.
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		if not n.pressed.is_connected(_btn_click):
			n.pressed.connect(_btn_click)
		if not n.mouse_entered.is_connected(_btn_hover):
			n.mouse_entered.connect(_btn_hover)

func _btn_click() -> void:
	play_ui("click")

func _btn_hover() -> void:
	play_ui("hover")

func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

func _stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing audio file %s" % path)
		return null
	var s: AudioStream = load(path)
	_stream_cache[path] = s
	return s

func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamWAV:
		# WAVs import with loop disabled + loop_end = -1. Turning on LOOP_FORWARD without
		# a valid loop_end plays an empty [0, -1] region = dead silence, so set the loop
		# to span the whole sample explicitly.
		if on:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		else:
			stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = on
	elif stream is AudioStreamMP3:
		stream.loop = on

# ---------------------------------------------------------------- one-shots
func play_sfx(key: String, pitch_variation := 0.06) -> void:
	_play_pool(SFX, _sfx_pool, key, pitch_variation, false)

func play_ui(key: String) -> void:
	_play_pool(UI, _ui_pool, key, 0.0, true)

# Enemy "spotted you" sting. Rate-limited GLOBALLY so a room full of enemies all
# noticing at once plays a single alert, not a pile-up. Skipped in arcade mode,
# where enemies swarm constantly and the cue would be meaningless noise.
const ALERT_COOLDOWN_MS := 5000
var _alert_ms: int = -ALERT_COOLDOWN_MS - 1   # so the first alert always fires

# Returns TRUE only when the sting actually fired, so callers can hang other
# "it noticed you" reactions (the enemy spot-hop) off the same global cooldown
# instead of every enemy reacting at once.
func play_alert() -> bool:
	if Global.arcade_mode:
		return false
	var now := Time.get_ticks_msec()
	if now - _alert_ms < ALERT_COOLDOWN_MS:
		return false
	_alert_ms = now
	play_sfx("alert")
	return true

func _play_pool(lib: Dictionary, pool: Array, key: String, pitch_variation: float, is_ui: bool) -> void:
	if not lib.has(key):
		push_warning("AudioManager: unknown %s key '%s'" % ["ui" if is_ui else "sfx", key])
		return
	var stream := _stream(lib[key])
	if stream == null:
		return
	var p: AudioStreamPlayer
	if is_ui:
		p = pool[_ui_i]
		_ui_i = (_ui_i + 1) % pool.size()
	else:
		p = pool[_sfx_i]
		_sfx_i = (_sfx_i + 1) % pool.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation) if pitch_variation > 0.0 else 1.0
	p.play()

# ---------------------------------------------------------------- sustained loops (e.g. low_health)
func start_loop(key: String) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]) and _loops[key].playing:
		return
	if not SFX.has(key):
		return
	var stream := _stream(SFX[key])
	if stream == null:
		return
	_set_loop(stream, true)
	var p := _make_player(&"sfx")
	p.stream = stream
	p.play()
	_loops[key] = p

func stop_loop(key: String) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		_loops[key].stop()
		_loops[key].queue_free()
		_loops.erase(key)

# Attach a looping bed to a specific node (e.g. a gimmick). The player is a child of
# `host`, so it starts when the gimmick spawns and is freed automatically with it —
# ideal for per-instance loops (rising debt, pull zone, debt wall) that can exist in
# several copies at once. Returns the player so the caller can stop/tweak it.
func attach_loop(host: Node, key: String, volume_db := 0.0) -> AudioStreamPlayer:
	if not SFX.has(key):
		push_warning("AudioManager: unknown loop key '%s'" % key)
		return null
	var stream := _stream(SFX[key])
	if stream == null:
		return null
	_set_loop(stream, true)
	var p := AudioStreamPlayer.new()
	p.bus = &"sfx"
	p.stream = stream
	p.volume_db = volume_db
	host.add_child(p)
	p.play()
	return p

# ---------------------------------------------------------------- music (crossfade)
func play_music(key: String, fade := MUSIC_FADE) -> void:
	if key == _current_music and _music_active.playing:
		return
	if not MUSIC.has(key):
		push_warning("AudioManager: unknown music key '%s'" % key)
		return
	var stream := _stream(MUSIC[key])
	if stream == null:
		return
	_set_loop(stream, true)
	_current_music = key

	var incoming := _music_b if _music_active == _music_a else _music_a
	var outgoing := _music_active
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_music_active = incoming

	_kill_fade(_music_tween)
	var tw := create_tween().set_parallel(true)
	_music_tween = tw
	tw.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -40.0, fade)
		tw.chain().tween_callback(outgoing.stop)

func stop_music(fade := MUSIC_FADE) -> void:
	_current_music = ""
	if not _music_active.playing:
		return
	var p := _music_active
	_kill_fade(_music_tween)
	var tw := create_tween()
	_music_tween = tw
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.stop)

# ---------------------------------------------------------------- ambience
func play_ambience(key: String, fade := MUSIC_FADE) -> void:
	if key == _current_ambience and _ambi.playing:
		return
	if not AMBIENCE.has(key):
		push_warning("AudioManager: unknown ambience key '%s'" % key)
		return
	var stream := _stream(AMBIENCE[key])
	if stream == null:
		return
	_set_loop(stream, true)
	_current_ambience = key
	_ambi.stream = stream
	_ambi.volume_db = -40.0
	_ambi.play()
	_kill_fade(_ambi_tween)
	var tw := create_tween()
	_ambi_tween = tw
	tw.tween_property(_ambi, "volume_db", 0.0, fade)

func stop_ambience(fade := MUSIC_FADE) -> void:
	_current_ambience = ""
	if not _ambi.playing:
		return
	_kill_fade(_ambi_tween)
	var tw := create_tween()
	_ambi_tween = tw
	tw.tween_property(_ambi, "volume_db", -40.0, fade)
	tw.tween_callback(_ambi.stop)
