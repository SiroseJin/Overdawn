extends Node2D

# ─── Lobby Level ───────────────────────────────────────────────────────────────
# Hub scene. Walking into the start trigger goes to Stage 1.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var lobby_camera:          Camera2D            = $Camera2D
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

var _transitioning := false

func _ready() -> void:
	Global.gameStarted   = false
	Global.playerAlive   = true
	Global.tutorial_mode = false   # returning from the tutorial re-locks the skills
	lobby_camera.enabled = true
	scene_transition_anim.play("fade_out")
	AudioManager.play_music("lobby")
	_place_portal_beacons()
	Global.warm_dialogic()   # build the dialogue layout now, so the first NPC talk is instant
	# The lobby NPC's dialogue offers a Yes/No; picking Yes emits this Dialogic signal
	# (kept for compatibility; the choice is now a real prompt shown on `talked`).
	if Dialogic and not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)
	# Show the "Take the tutorial?" prompt when the lobby NPC's dialogue ends — this
	# fires whether the player read it or SKIPPED it (#11), so the offer isn't lost.
	var lobby_npc := get_node_or_null("LobbyNpc")
	if lobby_npc and not lobby_npc.talked.is_connected(_on_lobby_npc_talked):
		lobby_npc.talked.connect(_on_lobby_npc_talked)

# ─── Portal beacons ─────────────────────────────────────────────────────────────
# A looping beacon on each lobby exit so both read as portals at a glance, colour-
# coded by where they lead: cyan for the Stage 1 story run (matching that stage's
# portal tint elsewhere), gold for the Arcade arena. The beacon is placed from the
# portal's collision shape when it has one, so dragging a portal in the editor moves
# its beacon with it — no coordinates duplicated here.
# name -> [beacon tint, English tag, Indonesian tag]
const _PORTAL_BEACONS := {
	"Stage1Portal": [Color(0.45, 0.85, 1.0), "To Stage 1", "Ke Stage 1"],
	"ArcadePortal": [Color(1.0, 0.78, 0.35), "To Arcade",  "Ke Arkade"],
}

func _place_portal_beacons() -> void:
	for portal_name in _PORTAL_BEACONS:
		var portal := get_node_or_null(portal_name) as Node2D
		if portal == null:
			continue
		var at: Vector2 = portal.global_position
		var cs := portal.get_node_or_null("CollisionShape2D")
		if cs is Node2D:
			at = (cs as Node2D).global_position
		var info: Array = _PORTAL_BEACONS[portal_name]
		Global.add_portal_caption(portal, str(info[1]), str(info[2]))
		var fx := Global.spawn_fx("portal", at, 1.2, info[0], true)
		if fx == null:
			continue
		# The stages hide their backdrop in a ParallaxBackground (a CanvasLayer), so a
		# z_index of -1 still draws above it. The lobby's BackGroundSprite is a plain
		# Node2D at z 0, so -1 buried the beacon underneath the floor. Stay at z 0 and
		# get "behind the player" from tree order instead.
		fx.z_index = 0
		var player := get_node_or_null("Player")
		if player:
			move_child(fx, player.get_index())

const TUTORIAL_PROMPT := preload("res://scene/actors/npc/tutorial_prompt.tscn")

func _on_lobby_npc_talked(_npc_id: String) -> void:
	if _transitioning:
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var prompt := TUTORIAL_PROMPT.instantiate()
	layer.add_child(prompt)
	prompt.answered.connect(func(take: bool):
		layer.queue_free()
		if take and not _transitioning:
			_transitioning = true
			Global.tutorial_mode = true
			_fade_then_load("res://scene/Levels/Tutorial/tutorial.tscn"))

func _on_dialogic_signal(arg: Variant) -> void:
	if arg == "goto_tutorial" and not _transitioning:
		_transitioning = true
		Global.tutorial_mode = true
		_fade_then_load("res://scene/Levels/Tutorial/tutorial.tscn")

func _process(_delta: float) -> void:
	pass

# ─── Signals ──────────────────────────────────────────────────────────────────

func _on_start_game_detection_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		_fade_then_load("res://scene/system/stage.tscn")

func _on_stage_1_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		Global.arcade_mode = false   # story run — don't inherit arcade's full skill kit
		_fade_then_load("res://scene/Levels/Level1/stage1.tscn")

func _on_arcade_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		Global.arcade_mode = true
		# The arcade is the wave arena, not Stage 1 — this handler was a copy of the
		# Stage 1 one and sent arcade runs into the story level.
		_fade_then_load("res://scene/system/stage.tscn")

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)
