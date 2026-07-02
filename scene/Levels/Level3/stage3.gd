extends Node2D

# ─── Stage 3 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const DEBT_WALL := preload("res://scene/debt_wall.tscn")

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_setup_debt_wall()

# Gimmick: the Debt Wall creeps in from behind the whole level. Keep moving or it
# grinds you down — the debt always catches up.
func _setup_debt_wall() -> void:
	var wall := DEBT_WALL.instantiate()
	wall.position = Vector2(-320, 400)
	wall.speed = 45.0
	add_child(wall)

func _process(_delta: float) -> void:
	pass

func _on_stage_4_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level4/stage4.tscn")

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


func _on_stage_2_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level2/stage2.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
