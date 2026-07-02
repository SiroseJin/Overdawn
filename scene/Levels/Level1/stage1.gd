extends Node2D

# ─── Stage 1 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM
@onready var player_camera         = $Player/Camera2D
@onready var player                = $Player

const PICKUP_SCENE := preload("res://scene/pickup.tscn")
const KEY_SCENE    := preload("res://scene/key_pickup.tscn")
const DOOR_SCENE   := preload("res://scene/locked_door.tscn")
const NPC_SCENE    := preload("res://scene/npc1.tscn")
const COIN_SCENE   := preload("res://scene/coin.tscn")
const TRADER       := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

# Coins scattered along the path (ground-reachable in Stage 1)
const COIN_POSITIONS := [
	Vector2(300, 640), Vector2(520, 640), Vector2(860, 640),
	Vector2(1350, 640), Vector2(1720, 640), Vector2(2120, 640),
	Vector2(2520, 640), Vector2(2760, 640),
]

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	player_camera.enabled  = true
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()
	_spawn_coins()
	_setup_progression_demo()

# Assign story roles to the placed NPCs.
func _configure_npcs() -> void:
	var intro := get_node_or_null("Npc1")
	if intro:
		intro.npc_id = "stage1_intro"
		intro.dialogue_timeline = "npc1timeline"

	# Npc2: a teaching NPC partway through the stage
	var teach := get_node_or_null("Npc2")
	if teach:
		teach.npc_id = "stage1_npc2"
		teach.dialogue_timeline = "npc2timeline"

	# Npc3 unlocks the Firewall defensive skill
	var skill_npc := get_node_or_null("Npc3")
	if skill_npc:
		skill_npc.npc_id            = "stage1_firewall_npc"
		skill_npc.dialogue_timeline = "npc3timeline"
		skill_npc.unlocks_skill     = "firewall"

	# Npc4: the END-of-stage OPTIONAL quiz. After learning from the NPCs across
	# the stage, the player can choose to be quizzed here for a bonus — fully
	# skippable, and after the first intro it jumps straight to the Take offer.
	# (Set quiz_optional = false + quiz_grants_key to make a must-do gate instead.)
	var quiz_npc := get_node_or_null("Npc4")
	if quiz_npc:
		quiz_npc.npc_id             = "stage1_end_quiz"
		quiz_npc.dialogue_timeline  = "npc4timeline"
		quiz_npc.post_quiz_timeline = "s1endpost"
		quiz_npc.quiz_id            = "stage1_quiz"
		quiz_npc.quiz_optional      = true
		quiz_npc.quiz_bonus_coins   = 20
		quiz_npc.quiz_bonus_skill_point = true

func _spawn_coins() -> void:
	for pos in COIN_POSITIONS:
		var c := COIN_SCENE.instantiate()
		c.position = pos
		add_child(c)

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Npc1", "Trader_1")
	_skin("Npc2", "Trader_2")
	_skin("Npc3", "Trader_3")
	_skin("Npc4", "Trader_1")   # the Witch-foreshadowing NPC near the exit

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

# ── Foundation systems demo ────────────────────────────────────────────────────
# Drops collectibles + a story-driven lock-and-key gate into the existing layout
# via code so the level scene file stays untouched. Move/replace these by placing
# the same prefab scenes (pickup.tscn, locked_door.tscn, npc1.tscn) in the editor.
#
# Narrative gate: the exit is locked. The only key comes from the gatekeeper NPC,
# whose dialogue also grants the double jump ("a second chance"). Because the door
# can't open without that key, the player can never enter Stage 2 — which needs
# the double jump — unequipped for it.
func _setup_progression_demo() -> void:
	# "Lucky Streak" — a temporary high that wears off, early before the enemies
	var spd: Node = PICKUP_SCENE.instantiate()
	spd.kind = Pickup.Kind.SPEED
	spd.position = Vector2(700, 645)
	add_child(spd)

	# "Lifeline" — support that pulls you back up, after the enemy cluster
	var hp: Node = PICKUP_SCENE.instantiate()
	hp.kind = Pickup.Kind.HEALTH
	hp.position = Vector2(1900, 645)
	add_child(hp)

	# The gatekeeper: someone who got out. Finishing their story is the ONLY way
	# to receive the key AND the double-jump ("second chance") skill.
	var gate := NPC_SCENE.instantiate()
	gate.position = Vector2(2850, 671)
	gate.dialogue_timeline = "s1gatekeepertimeline"
	gate.npc_id = "stage1_gatekeeper"
	gate.unlocks_skill = "double_jump"
	gate.grants_key = "stage1_key"
	gate.idle_texture = load(TRADER + "Trader_2/Idle.png")
	gate.dialogue_texture = load(TRADER + "Trader_2/Dialogue.png")
	add_child(gate)

	# The locked exit. Opens only with the gatekeeper's key.
	var door: Node = DOOR_SCENE.instantiate()
	door.required_key = "stage1_key"
	door.position = Vector2(2980, 600)
	add_child(door)

func _process(_delta: float) -> void:
	pass

func _on_stage_2_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		ProgressionManager.clear_stage("stage1")
		_fade_then_load("res://scene/Levels/Level2/stage2.tscn")

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

func _on_lobby_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/lobby_level.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
