extends Node2D

# ─── Tutorial Stage ──────────────────────────────────────────────────────────────
# A short, safe practice level reached from the lobby NPC. Every skill is available
# here (Global.tutorial_mode) WITHOUT unlocking anything in the real save. Teaches,
# left-to-right: movement, dash, firewall, platforms, items, enemies. The exit portal
# returns to the lobby.
# ────────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

var _transitioning := false

# Tutorial signs are hidden until the player walks near them (keeps the screen clean).
var _sign_labels: Array[Label] = []
const SIGN_REVEAL_RANGE := 120.0   # how close (px, horizontal) the player must be

func _ready() -> void:
	Global.gameStarted   = true
	Global.tutorial_mode = true    # hand out every skill for teaching (save untouched)
	Global.arcade_mode   = false
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_localize_signs()
	_place_exit_portal_fx()
	# The Player's _ready builds its skill HUD BEFORE tutorial_mode is set (child readies
	# first), so it only shows Arrows. Refresh once we're set so every skill bar appears.
	call_deferred("_refresh_player_skill_ui")

func _refresh_player_skill_ui() -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p):
		if p.has_method("refresh_stats_from_skills"): p.refresh_stats_from_skills()
		if p.has_method("_refresh_skill_huds"):        p._refresh_skill_huds()

# A looping portal beacon on the exit that leads back to the lobby (green = safe/home).
func _place_exit_portal_fx() -> void:
	var cs := $LobbyPortal/CollisionShape2D
	var fx := Global.spawn_fx("portal", cs.global_position, 1.3, Color(0.5, 1.0, 0.75), true)
	if fx:
		fx.z_index = -1   # behind the player as they step through

# Collect every tutorial sign for the proximity-reveal system, and — ONLY when the
# game locale is Indonesian — overwrite each with its ID text. In English we keep
# whatever text is authored on the label in the .tscn, so editing signs in the editor
# just works (no need to also touch this script). To add a sign: give it a node name
# here with its Indonesian translation.
func _localize_signs() -> void:
	var id_text := {
		"L_move":  "GERAK:  A / D",
		"L_jump":  "LOMPAT:  SPACE",
		"L_2jump": "tekan space dua kali di udara = LOMPAT GANDA",
		"L_dash":  "DASH:  SHIFT   -   dash melewati jurang  >>",
		"L_fire":  "Klik-Kiri serang, E untuk panah",
		"L_tab":   "Tekan TAB untuk upgrade skill",
		"L_plat":  "PLATFORM:\n1. padat\n2. bergerak\n3. jatuh (jangan berlama-lama)",
		"L_item":  "ITEM - cukup jalan ke arahnya",
		"L_fake":  "KOIN PALSU = jebakan",
		"L_key":   "KUNCI membuka PINTU",
		"L_enemy": "FIREWALL:  Q\npasang tameng, menahan tembakan",
		"L_dashatk": "SERANGAN DASH: Shift, lalu\nKlik Kiri/Kanan saat dash",
		"L_enemy2": "Klik Kanan: Serangan berat",
		"L_npc":   "TANDA !  (empat di depan menunjukkan tiap warna):\nPUTIH = cerita    HIJAU = kuis / hadiah\nKUNING = info gimmick / musuh    MERAH = wajib diajak bicara",
		"L_exit":  "KELUAR ke Lobby",
		# platform name-tags (children of the platforms, shown just below them)
		"PitStatic/solid":    "Padat",
		"PitMoving/moving":   "Bergerak",
		"PitFalling/falling": "Jatuh",
	}
	for key in id_text:
		var lbl := get_node_or_null(key) as Label
		if lbl:
			lbl.set_meta("en_text", lbl.text)       # remember the .tscn English original
			lbl.set_meta("id_text", id_text[key])
			lbl.visible = false          # revealed by _process when the player is near
			_sign_labels.append(lbl)
	add_to_group("localized")
	on_locale_changed()

# Re-apply sign language — at load and whenever the language is switched live (#7).
func on_locale_changed() -> void:
	var id := TranslationServer.get_locale().begins_with("id")
	for lbl in _sign_labels:
		if is_instance_valid(lbl) and lbl.has_meta("id_text"):
			lbl.text = str(lbl.get_meta("id_text")) if id else str(lbl.get_meta("en_text"))

# Reveal each sign only while the player is standing near it — declutters the level.
func _process(_delta: float) -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var px: float = Global.PlayerBody.global_position.x
	for lbl in _sign_labels:
		if not is_instance_valid(lbl):
			continue
		var cx: float = lbl.global_position.x + lbl.size.x * 0.5
		lbl.visible = absf(px - cx) < SIGN_REVEAL_RANGE

func _exit_tree() -> void:
	# Whatever route leaves the tutorial (portal, death-retry-to-menu, etc.), make sure
	# the free-skills flag never leaks into the real game.
	Global.tutorial_mode = false

func _on_lobby_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.tutorial_mode = false
		_fade_then_load("res://scene/system/lobby_level.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)
