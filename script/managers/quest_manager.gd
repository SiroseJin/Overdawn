extends Node

# ─── Quest Manager (Autoload) — quests & challenges (UC-008 + UC-007) ──────────────
# Quests are engagement loops: each has objectives and a reward. Progress is driven by
# the ProgressionManager.game_event hub (no quest-specific code scattered around the
# game) and stored in ProgressionManager.quest_state (persisted). Completing a quest
# grants coins / skill points / exp, fires juice, and emits "quest_completed" for the
# BadgeManager. Includes optional CHALLENGE quests (no-hit run, collect-all) and one
# REPEATABLE loop (arcade waves) so there's an always-on engagement cycle.
# ──────────────────────────────────────────────────────────────────────────────────

signal quests_changed()

# Objective types: stage_cleared(target), quiz_passed(target|any), collectible(count),
# collectible_stage(target,count), boss_defeated, no_damage_clear, arcade_wave(count).
const QUESTS := {
	"q_awakening": {
		"en": "Awakening", "id": "Kesadaran", "mandatory": true,
		"en_d": "Learn what online gambling really is, then prove it.",
		"id_d": "Pelajari apa itu judi online sebenarnya, lalu buktikan.",
		"en_lore": "Every 'judol' story starts the same way — a flashy ad, a free-credit hook, a first small bet. Knowing the trap is the first step out of it.",
		"id_lore": "Setiap cerita 'judol' dimulai sama — iklan mencolok, umpan kredit gratis, taruhan kecil pertama. Mengenali jebakannya adalah langkah pertama untuk keluar.",
		"en_hint": "Talk to the people of Stage 1, then find the quiz NPC near the exit.",
		"id_hint": "Bicara dengan warga Stage 1, lalu temui NPC kuis dekat pintu keluar.",
		"objectives": [{"type": "stage_cleared", "target": "stage1"},
					   {"type": "quiz_passed", "target": "stage1_quiz"}],
		"reward": {"coins": 30, "skill_points": 1, "exp": 15}},
	"q_spot_the_bait": {
		"en": "Spot the Bait", "id": "Kenali Umpan",
		"en_d": "See through the shiny lures of Stage 2.",
		"id_d": "Lihat tembus umpan berkilau di Stage 2.",
		"en_lore": "'Free' coins cost the house nothing and hook you fast. Stage 2's shiny lures are the same trick in platform form.",
		"id_lore": "Koin 'gratis' tak merugikan bandar dan cepat mengailmu. Umpan berkilau Stage 2 adalah trik yang sama dalam bentuk platform.",
		"en_hint": "Reach the Stage 2 exit and grab at least one Truth Shard on the way.",
		"id_hint": "Capai pintu keluar Stage 2 dan ambil setidaknya satu Pecahan Kebenaran di jalan.",
		"objectives": [{"type": "stage_cleared", "target": "stage2"},
					   {"type": "collectible_stage", "target": "stage2", "count": 1}],
		"reward": {"coins": 35, "exp": 20}},
	"q_break_the_cycle": {
		"en": "Break the Cycle", "id": "Putus Rantainya", "mandatory": true,
		"en_d": "Escape the rising debt and understand why it grows.",
		"id_d": "Lolos dari utang yang naik dan pahami kenapa ia tumbuh.",
		"en_lore": "Debt compounds whether you win or lose. The longer you linger, the more it grows — and borrowing to chase it only deepens the trap.",
		"id_lore": "Utang berbunga entah kamu menang atau kalah. Makin lama berdiam, makin ia tumbuh — dan berutang untuk mengejarnya hanya memperdalam jebakan.",
		"en_hint": "Don't stand still — clear Stage 3 and pass its quiz.",
		"id_hint": "Jangan diam — selesaikan Stage 3 dan lewati kuisnya.",
		"objectives": [{"type": "stage_cleared", "target": "stage3"},
					   {"type": "quiz_passed", "target": "stage3_quiz"}],
		"reward": {"coins": 40, "skill_points": 1, "exp": 25}},
	"q_find_key": {
		"en": "The Locked Way", "id": "Jalan Terkunci", "mandatory": true,
		"en_d": "The gate ahead is locked. Find the key at the top of the climb.",
		"id_d": "Gerbang di depan terkunci. Temukan kunci di puncak pendakian.",
		"en_lore": "There's no shortcut past the machine and no shortcut up this tower — only the long, honest climb. The key is earned by making it, not by chasing it.",
		"id_lore": "Tak ada jalan pintas melewati mesin dan tak ada jalan pintas menaiki menara ini — hanya pendakian panjang yang jujur. Kunci didapat dengan menempuhnya, bukan mengejarnya.",
		"en_hint": "Follow the glowing guide-line up the tower to the key, then take the gate.",
		"id_hint": "Ikuti garis pemandu bercahaya menaiki menara menuju kunci, lalu lewati gerbang.",
		"objectives": [{"type": "key_collected", "target": "stage3_key"}],
		"reward": {"coins": 30, "exp": 20}},
	"q_s5_side_key": {
		"en": "The Warded Gate", "id": "Gerbang Terjaga",
		"en_d": "A locked side gate bars the way. Find its key.",
		"id_d": "Gerbang samping terkunci menghalangi jalan. Temukan kuncinya.",
		"en_hint": "Follow the glowing guide-line to the key, then open the gate.",
		"id_hint": "Ikuti garis pemandu bercahaya menuju kunci, lalu buka gerbangnya.",
		"objectives": [{"type": "key_collected", "target": "stage5_keyA"}],
		"reward": {"coins": 20, "exp": 12}},
	"q_s5_gate_key": {
		"en": "The Gatekeeper's Key", "id": "Kunci Penjaga Gerbang", "mandatory": true,
		"en_d": "The gatekeeper won't open the final gate without its key. Go find it.",
		"id_d": "Penjaga gerbang tak akan membuka gerbang terakhir tanpa kuncinya. Temukan.",
		"en_hint": "Follow the glowing guide-line to the key, then return to the gate.",
		"id_hint": "Ikuti garis pemandu bercahaya menuju kunci, lalu kembali ke gerbang.",
		"objectives": [{"type": "key_collected", "target": "stage5_key4"}],
		"reward": {"coins": 30, "exp": 20}},
	"q_inside_machine": {
		"en": "Inside the Machine", "id": "Di Dalam Mesin", "mandatory": true,
		"en_d": "Ride the machine's current and reach the core.",
		"id_d": "Lewati arus mesin dan capai intinya.",
		"en_lore": "Near-misses, pull-back bonuses, engineered dopamine — Stage 4 is the machine's psychology laid bare.",
		"id_lore": "Nyaris-menang, bonus penarik, dopamin yang direkayasa — Stage 4 memperlihatkan psikologi mesin apa adanya.",
		"en_hint": "Ride the pull zones and reach the core at the end of Stage 4.",
		"id_hint": "Manfaatkan zona tarik dan capai inti di ujung Stage 4.",
		"objectives": [{"type": "stage_cleared", "target": "stage4"}],
		"reward": {"coins": 45, "exp": 30}},
	"q_final_test": {
		"en": "The Final Test", "id": "Ujian Terakhir", "mandatory": true,
		"en_d": "Defeat the Dealer, then pass the last quiz before the House.",
		"id_d": "Kalahkan Dealer, lalu lewati kuis terakhir sebelum Bandar.",
		"en_lore": "The Dealer is the House's last salesman. Beat him, pass the final quiz, and nothing stands between you and the truth.",
		"id_lore": "Dealer adalah penjual terakhir sang Bandar. Kalahkan dia, lewati kuis terakhir, dan tak ada lagi penghalang menuju kebenaran.",
		"en_hint": "Defeat the Dealer in Stage 5, then pass the last quiz.",
		"id_hint": "Kalahkan Dealer di Stage 5, lalu lewati kuis terakhir.",
		"objectives": [{"type": "stage_cleared", "target": "stage5"},
					   {"type": "quiz_passed", "target": "stage5_quiz"}],
		"reward": {"coins": 50, "skill_points": 2, "exp": 40}},
	"q_overdawn": {
		"en": "Overdawn", "id": "Fajar Menyingsing", "mandatory": true,
		"en_d": "Beat the House and break the machine for good.",
		"id_d": "Kalahkan Bandar dan hancurkan mesinnya selamanya.",
		"en_lore": "The House always wins by design — so you don't beat it at its game. You break the machine, and help others walk away too.",
		"id_lore": "Bandar selalu menang secara desain — jadi kamu tak mengalahkannya di permainannya. Kamu hancurkan mesinnya, dan bantu orang lain pergi juga.",
		"en_hint": "Destroy the servers to drop the House's shield, then strike while it's down.",
		"id_hint": "Hancurkan server untuk menjatuhkan perisai Bandar, lalu serang saat ia tumbang.",
		"objectives": [{"type": "boss_defeated"}],
		"reward": {"coins": 100, "skill_points": 1, "exp": 60}},
	# ── Minor optional side quests (early stages) ──
	"q_s1_curious": {
		"en": "Curious Mind", "id": "Rasa Ingin Tahu",
		"en_d": "Look a little closer at Stage 1 — pick up a Truth Shard.",
		"id_d": "Perhatikan Stage 1 lebih dekat — ambil satu Pecahan Kebenaran.",
		"en_lore": "The people the machine hurt left their words behind. Listening is how the truth spreads.",
		"id_lore": "Orang-orang yang dilukai mesin meninggalkan kata-kata mereka. Mendengarkan adalah cara kebenaran menyebar.",
		"en_hint": "Explore a little off the main path in Stage 1 and grab a Truth Shard.",
		"id_hint": "Jelajahi sedikit di luar jalur utama di Stage 1 dan ambil satu Pecahan Kebenaran.",
		"objectives": [{"type": "collectible_stage", "target": "stage1", "count": 1}],
		"reward": {"coins": 20, "exp": 10}},
	"q_s2_quiz_whiz": {
		"en": "Quiz Whiz", "id": "Jago Kuis",
		"en_d": "Pass the Stage 2 quiz on seeing through the bait.",
		"id_d": "Lewati kuis Stage 2 tentang melihat tembus umpan.",
		"en_lore": "Knowing the trick by name is half of beating it. Say it out loud and it loses its grip.",
		"id_lore": "Mengetahui triknya sudah setengah mengalahkannya. Sebutkan, dan cengkeramannya melemah.",
		"en_hint": "Find Rafi in Stage 2 and pass his quiz.",
		"id_hint": "Temui Rafi di Stage 2 dan lewati kuisnya.",
		"objectives": [{"type": "quiz_passed", "target": "stage2_quiz"}],
		"reward": {"coins": 20, "exp": 10}},
	# ── Challenge quests (UC-007) ──
	"q_survivor": {
		"en": "Unshaken", "id": "Tak Goyah", "challenge": true,
		"en_d": "Clear any stage without taking a single hit.",
		"id_d": "Selesaikan stage mana pun tanpa kena serangan sekali pun.",
		"en_lore": "Discipline beats luck. Clearing a stage untouched proves you're reading the danger, not gambling on it.",
		"id_lore": "Disiplin mengalahkan keberuntungan. Menyelesaikan stage tanpa tergores membuktikan kamu membaca bahaya, bukan mempertaruhkannya.",
		"en_hint": "Pick a stage you know well and clear it without taking a hit.",
		"id_hint": "Pilih stage yang kamu kuasai dan selesaikan tanpa kena serangan.",
		"objectives": [{"type": "no_damage_clear"}],
		"reward": {"coins": 60, "exp": 30}},
	"q_hunter": {
		"en": "Truth Hunter", "id": "Pemburu Kebenaran", "challenge": true,
		"en_d": "Collect 5 Truth Shards across the city.",
		"id_d": "Kumpulkan 5 Pecahan Kebenaran di seantero kota.",
		"en_lore": "Truth Shards are the words of people the machine hurt. Collect them and their stories become yours to carry.",
		"id_lore": "Pecahan Kebenaran adalah kata-kata orang yang dilukai mesin. Kumpulkan, dan kisah mereka menjadi milikmu untuk dibawa.",
		"en_hint": "Explore off the main path — shards hide in corners across the stages.",
		"id_hint": "Jelajahi luar jalur utama — pecahan tersembunyi di sudut-sudut stage.",
		"objectives": [{"type": "collectible", "count": 5}],
		"reward": {"coins": 50, "skill_points": 1, "exp": 25}},
	# ── Repeatable loop ──
	"q_arcade_run": {
		"en": "Arcade Run", "id": "Lari Arena", "repeatable": true,
		"en_d": "Survive 5 arcade waves. Repeats — chase your streak.",
		"id_d": "Bertahan 5 gelombang arena. Berulang — kejar rekormu.",
		"en_lore": "The arcade never really ends — that's the point of a machine built to keep you playing. Here, you survive it on your own terms.",
		"id_lore": "Arena tak pernah benar-benar berakhir — itulah inti mesin yang dibuat agar kamu terus main. Di sini, kamu bertahan dengan caramu sendiri.",
		"en_hint": "Survive 5 waves in Arcade mode. It resets — chase your best streak.",
		"id_hint": "Bertahan 5 gelombang di mode Arena. Ia mengulang — kejar rekor terbaikmu.",
		"objectives": [{"type": "arcade_wave", "count": 5}],
		"reward": {"coins": 25, "exp": 15}},
}

var _took_damage := false

func _ready() -> void:
	ProgressionManager.game_event.connect(_on_event)

# ─── Public accessors (for the quest log / progress screen) ───────────────────────

func title_of(qid: String) -> String:
	var q: Dictionary = QUESTS.get(qid, {})
	return q.get("id" if _is_id() else "en", qid)

func desc_of(qid: String) -> String:
	var q: Dictionary = QUESTS.get(qid, {})
	return q.get("id_d" if _is_id() else "en_d", "")

func is_done(qid: String) -> bool:
	return _state(qid).get("done", false)

## Story quests are MANDATORY (they gate the climb); challenge/repeatable ones are
## optional side quests. Used by NPC quest-givers and the quest log (#5).
func is_mandatory(qid: String) -> bool:
	return QUESTS.get(qid, {}).get("mandatory", false)

func is_offered(qid: String) -> bool:
	return _state(qid).get("offered", false)

# An NPC "gives" a quest, the same way an NPC hosts a quiz: the first time it's offered
# we announce it to the player and remember it (persisted in quest_state) so it isn't
# re-announced. Progress itself is still event-driven, so nothing else has to change.
func offer_quest(qid: String, giver: String = "") -> void:
	if not QUESTS.has(qid):
		return
	var st := _state(qid)
	if st.get("offered", false) or st.get("done", false):
		return
	st["offered"] = true
	AudioManager.play_ui("quest_accept")
	if giver != "":
		st["giver"] = giver          # remembered for the quest-list menu ("Given by …")
	quests_changed.emit()
	ProgressionManager.notify("quest_offered", {"id": qid})
	var p = Global.PlayerBody
	if is_instance_valid(p) and p.has_method("show_toast"):
		var kind := tr("Main Quest") if is_mandatory(qid) else tr("Side Quest")
		p.show_toast("★ " + kind + ": " + title_of(qid))

# ─── Quest-list menu helpers ──────────────────────────────────────────────────────

## True if the player has at least one quest that's been given and isn't finished.
## Gates world guidance (e.g. the key guide-line) so a fresh save with no quests shows
## no highlights.
func has_active_quest() -> bool:
	for qid in QUESTS:
		var st := _state(qid)
		if st.get("offered", false) and not st.get("done", false):
			return true
	return false

## Quest ids the player actually knows about (has been offered), for the menu.
func offered_quest_ids() -> Array:
	var out: Array = []
	for qid in QUESTS:
		if _state(qid).get("offered", false):
			out.append(qid)
	return out

func giver_of(qid: String) -> String:
	return str(_state(qid).get("giver", ""))

func lore_of(qid: String) -> String:
	var q: Dictionary = QUESTS.get(qid, {})
	return q.get("id_lore" if _is_id() else "en_lore", "")

func hint_of(qid: String) -> String:
	var q: Dictionary = QUESTS.get(qid, {})
	return q.get("id_hint" if _is_id() else "en_hint", "")

## Human-readable reward summary, e.g. "30 coins · 1 skill point · 15 XP".
func reward_text(qid: String) -> String:
	var r: Dictionary = QUESTS.get(qid, {}).get("reward", {})
	var parts: Array = []
	if int(r.get("coins", 0)) > 0:
		parts.append("%d %s" % [int(r["coins"]), tr("coins")])
	if int(r.get("skill_points", 0)) > 0:
		parts.append("%d %s" % [int(r["skill_points"]), tr("skill pts")])
	if int(r.get("exp", 0)) > 0:
		parts.append("%d %s" % [int(r["exp"]), tr("XP")])
	return "  ·  ".join(parts) if not parts.is_empty() else tr("—")

func objective_progress(qid: String) -> Array:
	# Returns [{text, cur, req, done}] for each objective.
	var q: Dictionary = QUESTS.get(qid, {})
	var st := _state(qid)
	var prog: Array = st.get("prog", [])
	var out := []
	var objs: Array = q.get("objectives", [])
	for i in objs.size():
		var req: int = int(objs[i].get("count", 1))
		var cur: int = int(prog[i]) if i < prog.size() else 0
		out.append({"text": _objective_text(objs[i]), "cur": min(cur, req), "req": req, "done": cur >= req})
	return out

func completed_count() -> int:
	var n := 0
	for qid in QUESTS:
		if not QUESTS[qid].get("repeatable", false) and is_done(qid):
			n += 1
	return n

func total_count() -> int:
	var n := 0
	for qid in QUESTS:
		if not QUESTS[qid].get("repeatable", false):
			n += 1
	return n

func all_completed() -> bool:
	return completed_count() >= total_count()

# ─── Event-driven progress ────────────────────────────────────────────────────────

func _on_event(event_name: String, data: Dictionary) -> void:
	if event_name == "stage_entered":
		_took_damage = false
		return
	if event_name == "player_damaged":
		_took_damage = true
		return

	var changed := false
	for qid in QUESTS:
		var st := _state(qid)
		# Quests only track once an NPC has GIVEN them — an untouched save has none.
		if not st.get("offered", false) or st.get("done", false):
			continue
		var objs: Array = QUESTS[qid]["objectives"]
		var advanced := false
		for i in objs.size():
			var add := _event_advances(objs[i], event_name, data)
			if add > 0:
				st["prog"][i] = int(st["prog"][i]) + add
				advanced = true
		if advanced:
			changed = true
			if _all_objectives_met(qid):
				_complete(qid)
	if changed:
		quests_changed.emit()

func _event_advances(obj: Dictionary, event_name: String, data: Dictionary) -> int:
	match obj["type"]:
		"stage_cleared":
			if event_name == "stage_cleared" and data.get("stage_id", "") == obj.get("target", ""):
				return 1
		"no_damage_clear":
			if event_name == "stage_cleared" and not _took_damage:
				return 1
		"quiz_passed":
			if event_name == "quiz_passed":
				var t: String = obj.get("target", "any")
				if t == "any" or data.get("quiz_id", "") == t:
					return 1
		"collectible":
			if event_name == "collectible":
				return 1
		"collectible_stage":
			if event_name == "collectible":
				# Shards report their stage in the event; fall back to the data table.
				var st: String = str(data.get("stage", ""))
				if st == "":
					st = CollectibleManager.SHARDS.get(data.get("id", ""), {}).get("stage", "")
				if st == obj.get("target", ""):
					return 1
		"key_collected":
			if event_name == "key_collected":
				var t: String = obj.get("target", "")
				if t == "" or data.get("key", "") == t:
					return 1
		"boss_defeated":
			if event_name == "boss_defeated":
				return 1
		"arcade_wave":
			if event_name == "arcade_wave":
				return 1
	return 0

func _all_objectives_met(qid: String) -> bool:
	var objs: Array = QUESTS[qid]["objectives"]
	var prog: Array = _state(qid)["prog"]
	for i in objs.size():
		if int(prog[i]) < int(objs[i].get("count", 1)):
			return false
	return true

func _complete(qid: String) -> void:
	AudioManager.play_ui("quest_complete")
	var st := _state(qid)
	var q: Dictionary = QUESTS[qid]
	# Grant rewards.
	var r: Dictionary = q.get("reward", {})
	if int(r.get("coins", 0)) > 0:        ProgressionManager.add_coins(int(r["coins"]))
	if int(r.get("skill_points", 0)) > 0: ProgressionManager.add_skill_points(int(r["skill_points"]))
	var p = Global.PlayerBody
	if is_instance_valid(p):
		if int(r.get("exp", 0)) > 0 and p.has_method("gain_exp"):
			p.gain_exp(int(r["exp"]))
		if p.has_method("show_toast"):
			p.show_toast(tr("Quest complete") + ": " + title_of(qid))
		Global.spawn_burst(p.global_position + Vector2(0, -18), Color(0.5, 0.85, 1.0), 24)
		Global.spawn_fx("portal", p.global_position + Vector2(0, -16), 0.7, Color(0.5, 0.85, 1.0))

	ProgressionManager.notify("quest_completed", {"id": qid})

	# Repeatable quests loop: reset so the player can chase the streak again.
	if q.get("repeatable", false):
		st["done"] = false
		st["prog"] = _zero_prog(qid)
	else:
		st["done"] = true

# ─── State helpers ────────────────────────────────────────────────────────────────

func _state(qid: String) -> Dictionary:
	var s = ProgressionManager.quest_state.get(qid)
	if s == null:
		s = {"prog": _zero_prog(qid), "done": false}
		ProgressionManager.quest_state[qid] = s
	# Guard: objective count could change between versions — keep prog sized right.
	var need: int = QUESTS[qid]["objectives"].size()
	if (s["prog"] as Array).size() != need:
		var np := _zero_prog(qid)
		for i in min(need, (s["prog"] as Array).size()):
			np[i] = s["prog"][i]
		s["prog"] = np
	return s

func _zero_prog(qid: String) -> Array:
	var a := []
	for _i in QUESTS[qid]["objectives"].size():
		a.append(0)
	return a

func _objective_text(obj: Dictionary) -> String:
	match obj["type"]:
		"stage_cleared":    return tr("Clear") + " " + str(obj.get("target", "")).to_upper()
		"no_damage_clear":  return tr("Clear a stage without taking a hit")
		"quiz_passed":
			return tr("Pass the quiz") if obj.get("target", "any") != "any" else tr("Pass any quiz")
		"collectible":      return tr("Collect Truth Shards")
		"collectible_stage":return tr("Collect a Truth Shard in") + " " + str(obj.get("target", "")).to_upper()
		"key_collected":    return tr("Find the key")
		"boss_defeated":    return tr("Defeat the House")
		"arcade_wave":      return tr("Survive arcade waves")
	return obj["type"]

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")
