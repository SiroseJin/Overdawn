extends Node2D

# ─── Stage 5 — The Final Test ───────────────────────────────────────────────────
# A gauntlet that gathers every mechanic — platforming, moving & falling
# platforms, all enemy types, a lock-and-key puzzle, pickups — before the boss.
# The must-do final quiz sits at the very end and gates the portal to Stage 6.
# Terrain is CollisionPolygon2D boxes so art can be dropped in later.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const PICKUP_SCENE := preload("res://scene/pickup.tscn")
const KEY_SCENE    := preload("res://scene/key_pickup.tscn")
const DOOR_SCENE   := preload("res://scene/locked_door.tscn")
const COIN_SCENE   := preload("res://scene/coin.tscn")
const TRADER       := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

const COIN_POSITIONS := [
	Vector2(300, 640), Vector2(1225, 548), Vector2(1400, 640),
	Vector2(2490, 448), Vector2(3300, 640), Vector2(3700, 640),
	Vector2(4300, 640),
]

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()
	_spawn_coins()
	_setup_pickups_and_puzzle()

func _apply_npc_skins() -> void:
	_skin("Npc1", "Trader_1")
	_skin("QuizNpc", "Trader_3")

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _configure_npcs() -> void:
	var n1 := get_node_or_null("Npc1")
	if n1: n1.npc_id = "stage5_intro"

	# The must-do final quiz at the end. Passing grants the key that opens the
	# gate to Stage 6 (the boss). Non-consuming so retries don't force a redo.
	var quiz := get_node_or_null("QuizNpc")
	if quiz:
		quiz.npc_id             = "stage5_bossgate"
		quiz.dialogue_timeline  = "s5bossgate"
		quiz.post_quiz_timeline = "s5bossgatepost"
		quiz.quiz_id            = "stage5_quiz"
		quiz.quiz_optional      = false
		quiz.quiz_grants_key    = "stage5_boss_key"

func _spawn_coins() -> void:
	for pos in COIN_POSITIONS:
		var c := COIN_SCENE.instantiate()
		c.position = pos
		add_child(c)

func _setup_pickups_and_puzzle() -> void:
	var spd: Node = PICKUP_SCENE.instantiate()
	spd.kind = Pickup.Kind.SPEED
	spd.position = Vector2(400, 640)
	add_child(spd)

	var hp: Node = PICKUP_SCENE.instantiate()
	hp.kind = Pickup.Kind.HEALTH
	hp.position = Vector2(3300, 640)
	add_child(hp)

	# Mid-level lock-and-key: key sits high on the climb, door blocks the way on.
	var key: Node = KEY_SCENE.instantiate()
	key.key_id = "stage5_key"
	key.position = Vector2(2490, 442)
	add_child(key)

	var puzzle_door: Node = DOOR_SCENE.instantiate()
	puzzle_door.required_key = "stage5_key"
	puzzle_door.position = Vector2(2740, 590)
	add_child(puzzle_door)

	# End gate: opens with the final-quiz key. Tall + non-consuming.
	var gate: Node = DOOR_SCENE.instantiate()
	gate.scale = Vector2(1.0, 1.4)
	gate.position = Vector2(4600, 536)
	gate.required_key = "stage5_boss_key"
	gate.consume_key  = false
	gate.locked_hint  = "The gate is sealed. Pass the final questions."
	add_child(gate)

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
