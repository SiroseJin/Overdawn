extends Node2D

# ─── Stage 2 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const TRADER     := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()   # colour-coded portal beacons
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()

# Give each NPC a stable id so the game remembers who's been spoken to.
func _configure_npcs() -> void:
	for pair in [["Nadia", "stage2_nadia"], ["Eko", "stage2_eko"],
			["Rafi", "stage2_rafi"], ["Yani", "stage2_yani"]]:
		var n := get_node_or_null(pair[0])
		if n: n.npc_id = pair[1]
	# Yani is the must-talk gate NPC: speaking to her unlocks Double Jump AND hands
	# over the key that opens the exit door — no key to hunt for.
	var yani := get_node_or_null("Yani")
	if yani:
		yani.unlocks_skill = "double_jump"
		yani.grants_key    = "stage2_key"

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Nadia", "Trader_2")  # spam-bot / surface-web warner
	_skin("Eko", "Trader_3")    # the phishing / near-win NPC
	_skin("Rafi", "Trader_1")   # the insider dev who hid the key
	_skin("Yani", "Trader_2")   # the exit NPC (warns of the Collector)

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _on_stage_3_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		if not Global.all_required_npcs_done():
			if body.has_method("show_toast"):
				body.show_toast(tr("Someone here still needs to speak with you."))
			return
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
