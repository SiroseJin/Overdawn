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
	audio_bgm.play()
	# The lobby NPC's dialogue offers a Yes/No; picking Yes emits this Dialogic signal
	# (kept for compatibility; the choice is now a real prompt shown on `talked`).
	if Dialogic and not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)
	# Show the "Take the tutorial?" prompt when the lobby NPC's dialogue ends — this
	# fires whether the player read it or SKIPPED it (#11), so the offer isn't lost.
	var lobby_npc := get_node_or_null("LobbyNpc")
	if lobby_npc and not lobby_npc.talked.is_connected(_on_lobby_npc_talked):
		lobby_npc.talked.connect(_on_lobby_npc_talked)

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
		_fade_then_load("res://scene/Levels/Level1/stage1.tscn")

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Load the next scene (and its heavy audio) in the background during the fade
	# so the actual switch is instant instead of a stall on disk/audio reads.
	ResourceLoader.load_threaded_request(scene_path)
	scene_transition_anim.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	var packed: PackedScene
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(scene_path)
	else:
		packed = load(scene_path)
	get_tree().change_scene_to_packed(packed)
