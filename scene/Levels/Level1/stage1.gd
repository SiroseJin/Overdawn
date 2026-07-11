extends Node2D

# ─── Stage 1 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM
@onready var player_camera         = $Player/Camera2D
@onready var player                = $Player

const TRADER       := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()   # colour-coded portal beacons
	scene_transition_anim.play("fade_out")
	player_camera.enabled  = true
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()

# Assign story roles to the placed NPCs. Node names match their character names
# (Hendra, Sari, Ana, Bayu); the Dialogic display name comes from each timeline's
# speaker (see res://scene/<name>.dch).
func _configure_npcs() -> void:
	var intro := get_node_or_null("Hendra")
	if intro:
		intro.npc_id = "stage1_intro"
		intro.dialogue_timeline = "npc1timeline"

	# Sari: a teaching NPC partway through the stage
	var teach := get_node_or_null("Sari")
	if teach:
		teach.npc_id = "stage1_npc2"
		teach.dialogue_timeline = "npc2timeline"

	# Ana: a teaching NPC — the personal cost of gambling (her brother's story).
	# Optional lore now; the Firewall skill moved to Stage 3 so skills aren't all in S1.
	var skill_npc := get_node_or_null("Ana")
	if skill_npc:
		skill_npc.npc_id            = "stage1_ana"
		skill_npc.dialogue_timeline = "npc3timeline"

	# Bayu: the END-of-stage OPTIONAL quiz. After learning from the NPCs across
	# the stage, the player can choose to be quizzed here for a bonus — fully
	# skippable, and after the first intro it jumps straight to the Take offer.
	# (Set quiz_optional = false + quiz_grants_key to make a must-do gate instead.)
	var quiz_npc := get_node_or_null("Bayu")
	if quiz_npc:
		quiz_npc.npc_id             = "stage1_end_quiz"
		quiz_npc.dialogue_timeline  = "npc4timeline"
		quiz_npc.post_quiz_timeline = "s1endpost"
		quiz_npc.quiz_id            = "stage1_quiz"
		quiz_npc.quiz_optional      = true
		quiz_npc.quiz_bonus_coins   = 20
		quiz_npc.quiz_bonus_skill_point = true

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Hendra", "Trader_1")
	_skin("Sari", "Trader_2")
	_skin("Ana", "Trader_3")
	_skin("Bayu", "Trader_1")        # the Necromancer-foreshadowing NPC near the exit
	_skin("Gatekeeper", "Trader_2")  # the one who got out — grants key + double jump

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _on_stage_2_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		if not Global.all_required_npcs_done():
			if body.has_method("show_toast"):
				body.show_toast(tr("Someone here still needs to speak with you."))
			return
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
		_fade_then_load("res://scene/system/lobby_level.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
