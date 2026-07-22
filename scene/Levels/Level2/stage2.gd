extends Node2D

# ─── Stage 2 ──────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const TRADER     := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()
	# Truth Shards are placed in the editor now (collectible.tscn instances you can drag).
	scene_transition_anim.play("fade_out")
	AudioManager.play_music("stage2")
	AudioManager.play_ambience("city")
	_apply_npc_skins()
	_configure_npcs()

# Give each NPC a stable id so the game remembers who's been spoken to.
func _configure_npcs() -> void:
	# Each non-quiz NPC gets a shorter repeat line for return visits.
	var repeats := {"Nadia": "nadia_rep", "Eko": "eko_rep", "Yani": "yani_rep"}
	for pair in [["Nadia", "stage2_nadia"], ["Eko", "stage2_eko"],
			["Rafi", "stage2_rafi"], ["Yani", "stage2_yani"]]:
		var n := get_node_or_null(pair[0])
		if n:
			n.npc_id = pair[1]
			if repeats.has(pair[0]):
				n.repeat_timeline = repeats[pair[0]]
	# Yani is the must-talk gate NPC: speaking to her hands over the key that opens the
	# exit door — no key to hunt for.
	var yani := get_node_or_null("Yani")
	if yani:
		yani.grants_key    = "stage2_key"
	# Nadia (first NPC) teaches DASH right away — Stage 1 is now a pure walk-and-talk
	# tutorial and every skill is earned from the FIRST NPC of the stage built around it
	# (dash here, double jump from Damar in Stage 3, firewall in Stage 4). She also hands
	# out a minor, easy OPTIONAL side quest — pass Rafi's quiz (#13).
	var nadia := get_node_or_null("Nadia")
	if nadia:
		nadia.unlocks_skill    = "dash"
		nadia.quest_id         = "q_s2_quiz_whiz"
		nadia.quest_giver_name = "Nadia"
	# Rafi hosts the OPTIONAL end-of-stage quiz — themed on this layer's bait platforms.
	var rafi := get_node_or_null("Rafi")
	if rafi:
		rafi.quiz_id                = "stage2_quiz"
		rafi.quiz_optional          = true
		rafi.quiz_bonus_coins       = 20
		rafi.quiz_bonus_skill_point = true
		rafi.post_quiz_timeline     = "s2rafipost"

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
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)


func _on_stage_1_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		Global.gameStarted = true
		_fade_then_load("res://scene/Levels/Level1/stage1.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
