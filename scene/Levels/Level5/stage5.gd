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
	Global.decorate_stage_portals()
	# Truth Shards are placed in the editor now (collectible.tscn instances you can drag).
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
	if n1:
		n1.npc_id = "stage5_intro"
		n1.repeat_timeline = "arif_rep"

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
		# Clearing the final gauntlet's quiz also pays out a bonus, not just the key.
		quiz.quiz_bonus_coins       = 30
		quiz.quiz_bonus_skill_point = true
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
		if not Global.all_required_npcs_done():
			if body.has_method("show_toast"):
				body.show_toast(tr("Someone here still needs to speak with you."))
			return
		_transitioning = true
		ProgressionManager.clear_stage("stage5")
		_fade_then_load("res://scene/Levels/Level6/stage6.tscn")

func _on_stage_4_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level4/stage4.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
