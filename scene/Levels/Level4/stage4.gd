extends Node2D

# ─── Stage 4 — Inside the Machine ───────────────────────────────────────────────
# The gambling platform's interior. Heaviest regular stage: introduces witches
# and a necromancer mini-boss before the Stage 5 core. Terrain is flat ground at
# three heights joined by clean slopes, split by two chasms crossed on platforms.
#   Ground1: high flat @560 -> slope -> low flat @650   (gap 1600-1900)
#   Ground2: low flat  @650 -> slope -> high flat @520  (gap 3100-3400)
#   Ground3: high flat @520 -> slope -> low flat @620
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const TRADER        := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()
	# Truth Shards are placed in the editor now (collectible.tscn instances you can drag).
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()

# Give each placed NPC a distinct trader look.
func _apply_npc_skins() -> void:
	_skin("Vino", "Trader_2")     # intro — inside the machine
	_skin("Mega", "Trader_1")     # the algorithm learns you
	_skin("Guntur", "Trader_3")   # the debt trap
	_skin("Laras", "Trader_2")    # end quiz — the core ahead

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _configure_npcs() -> void:
	# Vino (first NPC): must-talk. Speaking to him now unlocks Firewall AND brings up the
	# bridge platform (MovingPlatform1, dormant until then) so you can cross the first gap
	# — moved here from Mega so the shield comes from the very first NPC you meet (#14).
	var n1 := get_node_or_null("Vino")
	if n1:
		n1.npc_id = "stage4_vino"
		n1.unlocks_skill = "firewall"
		n1.repeat_timeline = "vino_rep"
		if not n1.talked.is_connected(_on_bridge_npc_talked):
			n1.talked.connect(_on_bridge_npc_talked)
	# Mega: now a normal lore NPC (the algorithm-learns-you beat).
	var n2 := get_node_or_null("Mega")
	if n2:
		n2.npc_id = "stage4_mega"
		n2.repeat_timeline = "mega_rep"
	var n3 := get_node_or_null("Guntur")
	if n3:
		n3.npc_id = "stage4_guntur"
		n3.repeat_timeline = "guntur_rep"

	# Laras (end): optional quiz for a bonus, distinct post-quiz line.
	var n4 := get_node_or_null("Laras")
	if n4:
		n4.npc_id             = "stage4_end_quiz"
		n4.quiz_id            = "stage4_quiz"
		n4.quiz_optional      = true
		n4.quiz_bonus_coins   = 25
		n4.quiz_bonus_skill_point = true
		n4.post_quiz_timeline = "s4laraspost"

# Bring up the dormant bridge platform once the first NPC (Vino) has been spoken to.
func _on_bridge_npc_talked(_npc_id: String) -> void:
	var plat := get_node_or_null("MovingPlatform1")
	if plat and plat.has_method("activate"):
		plat.activate()

# ─── Transitions ─────────────────────────────────────────────────────────────────

func _on_stage_5_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		if not Global.all_required_npcs_done():
			if body.has_method("show_toast"):
				body.show_toast(tr("Someone here still needs to speak with you."))
			return
		_transitioning = true
		ProgressionManager.clear_stage("stage4")
		_fade_then_load("res://scene/Levels/Level5/stage5.tscn")

func _on_stage_3_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level3/stage3.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
