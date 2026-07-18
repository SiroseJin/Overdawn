extends Node

# ─── Badge Manager (Autoload) — achievements (UC-009, Deploy/PBL) ──────────────────
# Listens to the ProgressionManager.game_event hub and awards badges when the player
# hits real milestones (clear a stage, pass every quiz, collect every shard, a no-hit
# run, level thresholds, finish a quest, beat the House). Awards persist through
# ProgressionManager (SaveManager) and fire juice: a gold burst + chime + toast.
# ──────────────────────────────────────────────────────────────────────────────────

# id -> localized name/desc for the badge grid + unlock toast.
const BADGES := {
	"first_steps":   {"en": "First Steps",       "id": "Langkah Pertama",
		"en_d": "Clear Stage 1.",                 "id_d": "Selesaikan Stage 1."},
	"halfway_out":   {"en": "Halfway Out",       "id": "Setengah Jalan",
		"en_d": "Clear Stage 3.",                 "id_d": "Selesaikan Stage 3."},
	"the_way_out":   {"en": "The Way Out",       "id": "Jalan Keluar",
		"en_d": "Clear Stage 5.",                 "id_d": "Selesaikan Stage 5."},
	"overdawn":      {"en": "Overdawn",          "id": "Fajar Menyingsing",
		"en_d": "Beat the House. Break the machine.", "id_d": "Kalahkan Bandar. Hancurkan mesinnya."},
	"quick_learner": {"en": "Quick Learner",     "id": "Cepat Belajar",
		"en_d": "Pass your first quiz.",          "id_d": "Lulus kuis pertamamu."},
	"top_of_class":  {"en": "Top of the Class",  "id": "Juara Kelas",
		"en_d": "Pass every stage quiz.",         "id_d": "Lulus semua kuis stage."},
	"first_shard":   {"en": "Collector",         "id": "Pengumpul",
		"en_d": "Collect your first Truth Shard.", "id_d": "Kumpulkan Pecahan Kebenaran pertama."},
	"eye_opener":    {"en": "Eye Opener",        "id": "Pembuka Mata",
		"en_d": "Collect every Truth Shard in a stage.", "id_d": "Kumpulkan semua Pecahan di satu stage."},
	"truth_seeker":  {"en": "Truth Seeker",      "id": "Pencari Kebenaran",
		"en_d": "Collect every Truth Shard.",     "id_d": "Kumpulkan semua Pecahan Kebenaran."},
	"unshakable":    {"en": "Unshakable",        "id": "Tak Tergoyahkan",
		"en_d": "Clear a stage without taking a hit.", "id_d": "Selesaikan stage tanpa kena serangan."},
	"seasoned":      {"en": "Seasoned",          "id": "Berpengalaman",
		"en_d": "Reach level 5.",                 "id_d": "Capai level 5."},
	"veteran":       {"en": "Veteran",           "id": "Veteran",
		"en_d": "Reach level 10.",                "id_d": "Capai level 10."},
	"questor":       {"en": "Questor",           "id": "Penjelajah",
		"en_d": "Complete your first quest.",     "id_d": "Selesaikan misi pertamamu."},
	"completionist": {"en": "Completionist",     "id": "Perfeksionis",
		"en_d": "Complete every quest.",          "id_d": "Selesaikan semua misi."},
	"maxed_out":     {"en": "Maxed Out",          "id": "Level Maksimal",
		"en_d": "Fully max out every upgrade.",   "id_d": "Maksimalkan semua peningkatan."},
	"well_read":     {"en": "Well Read",          "id": "Paham Betul",
		"en_d": "Unlock every Guide entry.",      "id_d": "Buka semua entri Panduan."},
}

const QUIZ_IDS := ["stage1_quiz", "stage2_quiz", "stage3_quiz", "stage4_quiz", "stage5_quiz"]

var _took_damage_this_stage := false

func _ready() -> void:
	ProgressionManager.game_event.connect(_on_event)

func name_of(badge_id: String) -> String:
	var e: Dictionary = BADGES.get(badge_id, {})
	if e.is_empty(): return badge_id
	return e.get("id" if _is_id() else "en", badge_id)

func desc_of(badge_id: String) -> String:
	var e: Dictionary = BADGES.get(badge_id, {})
	if e.is_empty(): return ""
	return e.get("id_d" if _is_id() else "en_d", "")

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")

# ─── Event handling ───────────────────────────────────────────────────────────────

func _on_event(event_name: String, data: Dictionary) -> void:
	match event_name:
		"stage_entered":
			_took_damage_this_stage = false
		"player_damaged":
			_took_damage_this_stage = true
		"stage_cleared":
			match data.get("stage_id", ""):
				"stage1": _award("first_steps")
				"stage3": _award("halfway_out")
				"stage5": _award("the_way_out")
			if not _took_damage_this_stage:
				_award("unshakable")
		"boss_defeated":
			_award("overdawn")
		"quiz_passed":
			_award("quick_learner")
			if _all_quizzes_passed():
				_award("top_of_class")
		"collectible":
			_award("first_shard")
			if ProgressionManager.collectible_count() >= CollectibleManager.total():
				_award("truth_seeker")
			var st: String = str(data.get("stage", ""))
			if st == "":
				st = CollectibleManager.SHARDS.get(data.get("id", ""), {}).get("stage", "")
			if st != "" and CollectibleManager.total_for_stage(st) > 0 \
					and CollectibleManager.collected_for_stage(st) >= CollectibleManager.total_for_stage(st):
				_award("eye_opener")
		"level_up":
			if int(data.get("level", 0)) >= 5:  _award("seasoned")
			if int(data.get("level", 0)) >= 10: _award("veteran")
		"quest_completed":
			_award("questor")
			if QuestManager.all_completed():
				_award("completionist")
		"all_upgrades_maxed":
			_award("maxed_out")
		"all_guides_unlocked":
			_award("well_read")

func _all_quizzes_passed() -> bool:
	for q in QUIZ_IDS:
		if not ProgressionManager.has_talked_to("quizpass_" + q):
			return false
	return true

# Award + juice. Only fires feedback the first time (award_badge returns false after).
func _award(badge_id: String) -> void:
	if not ProgressionManager.award_badge(badge_id):
		return
	var p = Global.PlayerBody
	if is_instance_valid(p):
		if p.has_method("show_toast"):
			p.show_toast(tr("Badge unlocked") + ": " + name_of(badge_id))
		Global.spawn_burst(p.global_position + Vector2(0, -20), Color(1.0, 0.85, 0.25), 26)
		Global.spawn_fx("pillar", p.global_position, 0.7, Color(1.0, 0.85, 0.3), false, true)
