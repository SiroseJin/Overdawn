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
const YESNO_PROMPT := preload("res://scene/actors/npc/yes_no_prompt.tscn")
const NPC_GUIDE    := preload("res://scene/system/vfx/npc_guide.gd")
const HELP_GROUP   := "guide_to"

var _transitioning := false
var _help_accepted := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()
	# Truth Shards are placed in the editor now (collectible.tscn instances you can drag).
	scene_transition_anim.play("fade_out")
	AudioManager.play_music("stage5")
	AudioManager.play_ambience("hopeful")
	_apply_npc_skins()
	_configure_npcs()
	_spawn_help_guide()

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
		# After Arif's maze warning, offer help (a Yes/No prompt shown on `talked`).
		if not n1.talked.is_connected(_on_arif_talked):
			n1.talked.connect(_on_arif_talked)

	# Reaching / talking to the Warden clears the green guide-line to her.
	var warden := get_node_or_null("Warden")
	if warden and not warden.talked.is_connected(_on_warden_talked):
		warden.talked.connect(_on_warden_talked)

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

# ─── Arif's help offer ─────────────────────────────────────────────────────────────
# A world-space guide line that lights up green toward the Warden once the player
# accepts Arif's offer of help.
func _spawn_help_guide() -> void:
	if has_node("WardenGuide"):
		return
	var g := Node2D.new()
	g.set_script(NPC_GUIDE)
	g.name = "WardenGuide"
	add_child(g)

# After Arif's dialogue, offer help. Re-offered each talk until the player accepts.
func _on_arif_talked(_npc_id: String) -> void:
	if _help_accepted or _transitioning:
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var prompt := YESNO_PROMPT.instantiate()
	layer.add_child(prompt)
	prompt.answered.connect(func(yes: bool):
		layer.queue_free()
		if yes:
			_help_accepted = true
			var warden := get_node_or_null("Warden")
			if warden and not warden.is_in_group(HELP_GROUP):
				warden.add_to_group(HELP_GROUP)
			_arif_toast("Follow the glow — the Warden holds the key you'll need.",
						"Ikuti cahayanya — Warden menyimpan kunci yang kamu butuhkan.")
		else:
			_arif_toast("Then trust your own footing. Good luck out there.",
						"Kalau begitu percayai pijakanmu sendiri. Semoga berhasil di luar sana."))

# Reaching the Warden clears the guide line.
func _on_warden_talked(_npc_id: String) -> void:
	var warden := get_node_or_null("Warden")
	if warden and warden.is_in_group(HELP_GROUP):
		warden.remove_from_group(HELP_GROUP)

func _arif_toast(en: String, id_txt: String) -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p) and p.has_method("show_toast"):
		var id := TranslationServer.get_locale().begins_with("id")
		p.show_toast("Arif: " + (id_txt if id else en))

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
