extends Node2D

# ─── Stage 3 — The Debt Tower (vertical parkour) ────────────────────────────────
# A tall, narrow Jump-King-style climb: small staggered ledges, precise arced
# double-jumps, and a long fall cascades you back down the tower. The stage's
# gimmick — the Debt — is re-themed here as a slow flood rising from the bottom:
# climb steadily or keep falling and it drags you under. The mandatory key waits
# at the summit and opens the gate to Stage 4.
# ───────────────────────────────────────────────────────────────────────────────

@onready var scene_transition_anim: AnimationPlayer    = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM

const TRADER     := "res://art/Free-City-Trader-Character-Sprite-Sheets-Pixel-Art/"

var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()
	CollectibleManager.populate(self, "stage3")   # UC-004 Truth Shards   # colour-coded portal beacons
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	_apply_npc_skins()
	_configure_npcs()

# Distinct look + stable id per NPC. Damar (network guide), Rina (who the Collector
# was), Toni (saw her, found her weakness), Sinta (the casino ahead).
func _apply_npc_skins() -> void:
	_skin("Damar", "Trader_1")
	_skin("Rina", "Trader_3")
	_skin("Toni", "Trader_2")
	_skin("Sinta", "Trader_1")

func _skin(npc_name: String, trader: String) -> void:
	var npc := get_node_or_null(npc_name)
	if npc and npc.has_method("set_appearance"):
		npc.set_appearance(
			load(TRADER + trader + "/Idle.png"),
			load(TRADER + trader + "/Dialogue.png"))

func _configure_npcs() -> void:
	var repeats := {"Damar": "damar_rep", "Rina": "rina_rep", "Toni": "toni_rep"}
	for pair in [["Damar", "stage3_damar"], ["Rina", "stage3_rina"],
			["Toni", "stage3_toni"], ["Sinta", "stage3_sinta"]]:
		var n := get_node_or_null(pair[0])
		if n:
			n.npc_id = pair[1]
			if repeats.has(pair[0]):
				n.repeat_timeline = repeats[pair[0]]
	# Sinta hosts the OPTIONAL end-of-stage quiz — themed on this layer's rising debt.
	var sinta := get_node_or_null("Sinta")
	if sinta:
		sinta.quiz_id                = "stage3_quiz"
		sinta.quiz_optional          = true
		sinta.quiz_bonus_coins       = 20
		sinta.quiz_bonus_skill_point = true
		sinta.post_quiz_timeline     = "s3sintapost"

# ─── Transitions ─────────────────────────────────────────────────────────────────

func _on_stage_4_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning:
		if not Global.all_required_npcs_done():
			if body.has_method("show_toast"):
				body.show_toast(tr("Someone here still needs to speak with you."))
			return
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


func _on_stage_2_portal_body_entered(body):
	if body is Player and not _transitioning:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level2/stage2.tscn")

func _on_deathzone_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not _transitioning:
		body.die()
