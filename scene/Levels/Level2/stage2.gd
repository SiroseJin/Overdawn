extends Node2D

# ─── Stage 2 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const KEY_SCENE  := preload("res://scene/key_pickup.tscn")
const DOOR_SCENE := preload("res://scene/locked_door.tscn")
const BAIT_SCENE := preload("res://scene/bait_platform.tscn")
const COIN_SCENE := preload("res://scene/coin.tscn")
const TRADER     := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

# Gimmick: bait platforms — they glow gold and dangle a coin, then vanish the
# instant you trust them. Placed over solid floor so learning them is safe.
const BAIT_POSITIONS := [Vector2(600, 560), Vector2(1500, 560), Vector2(2600, 560)]

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_setup_puzzle()
	_setup_bait()

func _setup_bait() -> void:
	for pos in BAIT_POSITIONS:
		var bait := BAIT_SCENE.instantiate()
		bait.position = pos
		add_child(bait)
		var coin := COIN_SCENE.instantiate()
		coin.position = pos + Vector2(0, -30)   # the lure sitting on the trap
		add_child(coin)

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Npc1", "Trader_2")   # the spam-bot warner
	_skin("Npc2", "Trader_3")   # the phishing / near-win NPC
	_skin("Npc3", "Trader_1")   # Rafi, the insider dev
	_skin("Npc4", "Trader_2")   # the exit NPC

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

# ── Puzzle: Rafi's hidden backdoor key ──────────────────────────────────────────
# The exit is locked. Rafi (Npc3) tells you he hid a developer's key up high,
# where the platform usually dangles its bright "bonus" bait — so reaching it
# uses the double jump earned in Stage 1. Climb for the honest key, not the bait.
func _setup_puzzle() -> void:
	var key: Node = KEY_SCENE.instantiate()
	key.key_id = "stage2_key"
	key.obtained_message = "Backdoor key found"
	key.position = Vector2(4100, 392)   # atop the highest platform near the exit
	add_child(key)

	var door: Node = DOOR_SCENE.instantiate()
	door.required_key = "stage2_key"
	door.locked_hint = "Locked. The key is up where the 'bonus' hangs."
	door.position = Vector2(4620, 600)
	add_child(door)

func _on_stage_3_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		_transitioning = true
		ProgressionManager.clear_stage("stage2")
		_fade_then_load("res://scene/Levels/Level3/stage3.tscn")

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


func _on_stage_1_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		_fade_then_load("res://scene/Levels/Level1/stage1.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
