extends Node2D

# ─── Lobby Level ───────────────────────────────────────────────────────────────
# Hub scene. Walking into the start trigger goes to Stage 1.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var lobby_camera:          Camera2D            = $Camera2D
@onready var audio_bgm:             AudioStreamPlayer2D = $AudioBGM

var _transitioning := false

func _ready() -> void:
	Global.gameStarted   = false
	Global.playerAlive   = true
	lobby_camera.enabled = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()

func _process(_delta: float) -> void:
	if not Global.playerAlive and not _transitioning:
		_transitioning = true
		await get_tree().create_timer(3.0).timeout
		_fade_then_load("res://scene/lobby_level.tscn")

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

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	scene_transition_anim.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(scene_path)
