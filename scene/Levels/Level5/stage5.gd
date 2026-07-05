extends Node2D

# ─── Stage 5 — The Final Test ───────────────────────────────────────────────────
# A gauntlet that gathers every mechanic — platforming, moving & falling
# platforms, all enemy types, a lock-and-key puzzle, pickups — before the boss.
# The must-do final quiz sits at the very end and gates the portal to Stage 6.
# Terrain is CollisionPolygon2D boxes so art can be dropped in later.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const TRADER       := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()

func _apply_npc_skins() -> void:
	_skin("Arif", "Trader_1")
	_skin("Wira", "Trader_3")

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _configure_npcs() -> void:
	var n1 := get_node_or_null("Arif")
	if n1: n1.npc_id = "stage5_intro"

	# The must-do final quiz at the end (Wira). Passing grants the key that opens
	# the gate to Stage 6 (the boss). Non-consuming so retries don't force a redo.
	var quiz := get_node_or_null("Wira")
	if quiz:
		quiz.npc_id             = "stage5_bossgate"
		quiz.dialogue_timeline  = "s5bossgate"
		quiz.post_quiz_timeline = "s5bossgatepost"
		quiz.quiz_id            = "stage5_quiz"
		quiz.quiz_optional      = false
		quiz.quiz_grants_key    = "stage5_boss_key"
		# Talking to Wira reveals the two hidden lifts by the exit.
		quiz.talked.connect(_reveal_hidden_lifts)

# The lifts (Lift2, Lift3) start dormant (hidden + non-solid) and only appear once
# the player has spoken to Wira.
func _reveal_hidden_lifts(_npc_id: String) -> void:
	for lift_name in ["Lift2", "Lift3"]:
		var lift := get_node_or_null(lift_name)
		if lift and lift.has_method("activate"):
			lift.activate()

# ─── Transitions ─────────────────────────────────────────────────────────────────

func _on_stage_6_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		ProgressionManager.clear_stage("stage5")
		_fade_then_load("res://scene/Levels/Level6/stage6.tscn")

func _on_stage_4_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level4/stage4.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	ResourceLoader.load_threaded_request(scene_path)
	scene_transition_anim.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	var packed: PackedScene
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(scene_path)
	else:
		packed = load(scene_path)
	get_tree().change_scene_to_packed(packed)

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
