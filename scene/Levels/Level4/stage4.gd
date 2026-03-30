extends Node2D

# ─── Stage 4 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer2D = $AudioBGM

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()

func _process(_delta: float) -> void:
	if not Global.playerAlive and not _transitioning:
		_transitioning = true
		await get_tree().create_timer(3.0).timeout
		_fade_then_load("res://scene/lobby_level.tscn")

func _on_stage_5_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level5/stage5.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	scene_transition_anim.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(scene_path)


func _on_stage_3_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level3/stage3.tscn")
