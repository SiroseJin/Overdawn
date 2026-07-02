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
	lobby_camera.enabled = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()

func _process(_delta: float) -> void:
	pass

# ─── Signals ──────────────────────────────────────────────────────────────────

func _on_start_game_detection_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		_fade_then_load("res://scene/stage.tscn")

func _on_stage_1_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
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
