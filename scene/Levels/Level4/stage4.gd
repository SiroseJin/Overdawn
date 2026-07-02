extends Node2D

# ─── Stage 4 — Inside the Machine ───────────────────────────────────────────────
# The gambling platform's interior. Heaviest regular stage: introduces witches
# and a necromancer mini-boss before the Stage 5 core. Terrain is authored as
# CollisionPolygon2D boxes so art can be dropped in later.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const PICKUP_SCENE  := preload("res://scene/pickup.tscn")
const KEY_SCENE     := preload("res://scene/key_pickup.tscn")
const DOOR_SCENE    := preload("res://scene/locked_door.tscn")
const COIN_SCENE    := preload("res://scene/coin.tscn")
const MOVING_PLAT   := preload("res://scene/moving_platform.tscn")
const FALLING_PLAT  := preload("res://scene/falling_platform.tscn")
const PULL_ZONE     := preload("res://scene/pull_zone.tscn")
const TRADER        := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

const COIN_POSITIONS := [
	Vector2(300, 640), Vector2(560, 470), Vector2(1300, 640),
	Vector2(1640, 470), Vector2(2350, 640), Vector2(2640, 458),
	Vector2(3500, 640), Vector2(3790, 470), Vector2(4140, 528),
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
	_setup_learning_platforms()
	_setup_pull_zones()

# Gimmick: pull zones — the machine's current. Walking through one drags you back
# the way you came, so you have to fight the pull the whole time.
func _setup_pull_zones() -> void:
	for x in [1500, 2600, 3800]:
		var pz := PULL_ZONE.instantiate()
		pz.position = Vector2(x, 600)
		pz.pull = Vector2(-95, 0)
		add_child(pz)

# Introduce the moving + falling platforms here (over solid ground, so failing is
# harmless) so the player learns them before they matter in Stage 5 and the boss.
func _setup_learning_platforms() -> void:
	# Vertical moving lift up to a bonus coin
	var mp := MOVING_PLAT.instantiate()
	mp.position = Vector2(1700, 640)
	mp.travel = Vector2(0, -120)
	add_child(mp)
	var c1 := COIN_SCENE.instantiate()
	c1.position = Vector2(1700, 504)
	add_child(c1)

	# A falling stepping-stone over the floor — grab the coin before it drops
	var fp := FALLING_PLAT.instantiate()
	fp.position = Vector2(3620, 560)
	add_child(fp)
	var c2 := COIN_SCENE.instantiate()
	c2.position = Vector2(3620, 520)
	add_child(c2)

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Npc1", "Trader_2")
	_skin("Npc2", "Trader_1")
	_skin("Npc3", "Trader_3")
	_skin("Npc4", "Trader_2")

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _configure_npcs() -> void:
	var n1 := get_node_or_null("Npc1")
	if n1: n1.npc_id = "stage4_npc1"
	var n2 := get_node_or_null("Npc2")
	if n2: n2.npc_id = "stage4_npc2"
	var n3 := get_node_or_null("Npc3")
	if n3: n3.npc_id = "stage4_npc3"

	# Npc4 (end): optional quiz for a bonus, distinct post-quiz line.
	var n4 := get_node_or_null("Npc4")
	if n4:
		n4.npc_id             = "stage4_end_quiz"
		n4.quiz_id            = "stage4_quiz"
		n4.quiz_optional      = true
		n4.quiz_bonus_coins   = 25
		n4.quiz_bonus_skill_point = true

func _spawn_coins() -> void:
	for pos in COIN_POSITIONS:
		var c := COIN_SCENE.instantiate()
		c.position = pos
		add_child(c)

# Pickups + the lock-and-key puzzle: the key sits high on Platform6 (needs the
# double jump), and the locked door guards the route to the exit.
func _setup_pickups_and_puzzle() -> void:
	var spd: Node = PICKUP_SCENE.instantiate()
	spd.kind = Pickup.Kind.SPEED
	spd.position = Vector2(650, 640)
	add_child(spd)

	var hp: Node = PICKUP_SCENE.instantiate()
	hp.kind = Pickup.Kind.HEALTH
	hp.position = Vector2(3300, 640)
	add_child(hp)

	# Key on the high platform (Platform6, top y=470)
	var key: Node = KEY_SCENE.instantiate()
	key.key_id = "stage4_key"
	key.position = Vector2(2640, 452)
	add_child(key)

	# Locked door before the exit NPC + portal
	var door: Node = DOOR_SCENE.instantiate()
	door.required_key = "stage4_key"
	door.position = Vector2(4460, 600)
	add_child(door)

# ─── Transitions ─────────────────────────────────────────────────────────────────

func _on_stage_5_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		ProgressionManager.clear_stage("stage4")
		_fade_then_load("res://scene/Levels/Level5/stage5.tscn")

func _on_stage_3_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level3/stage3.tscn")

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
