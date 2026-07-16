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
		"en": "Awakening", "id": "Kesadaran",
		"en_d": "Learn what online gambling really is, then prove it.",
		"id_d": "Pelajari apa itu judi online sebenarnya, lalu buktikan.",
		"objectives": [{"type": "stage_cleared", "target": "stage1"},
					   {"type": "quiz_passed", "target": "stage1_quiz"}],
		"reward": {"coins": 30, "skill_points": 1, "exp": 15}},
	"q_spot_the_bait": {
		"en": "Spot the Bait", "id": "Kenali Umpan",
		"en_d": "See through the shiny lures of Stage 2.",
		"id_d": "Lihat tembus umpan berkilau di Stage 2.",
		"objectives": [{"type": "stage_cleared", "target": "stage2"},
					   {"type": "collectible_stage", "target": "stage2", "count": 1}],
		"reward": {"coins": 35, "exp": 20}},
	"q_break_the_cycle": {
		"en": "Break the Cycle", "id": "Putus Rantainya",
		"en_d": "Escape the rising debt and understand why it grows.",
		"id_d": "Lolos dari utang yang naik dan pahami kenapa ia tumbuh.",
		"objectives": [{"type": "stage_cleared", "target": "stage3"},
					   {"type": "quiz_passed", "target": "stage3_quiz"}],
		"reward": {"coins": 40, "skill_points": 1, "exp": 25}},
	"q_inside_machine": {
		"en": "Inside the Machine", "id": "Di Dalam Mesin",
		"en_d": "Ride the machine's current and reach the core.",
		"id_d": "Lewati arus mesin dan capai intinya.",
		"objectives": [{"type": "stage_cleared", "target": "stage4"}],
		"reward": {"coins": 45, "exp": 30}},
	"q_final_test": {
		"en": "The Final Test", "id": "Ujian Terakhir",
		"en_d": "Pass the gauntlet and the last quiz before the House.",
		"id_d": "Lewati rintangan dan kuis terakhir sebelum Bandar.",
		"objectives": [{"type": "stage_cleared", "target": "stage5"},
					   {"type": "quiz_passed", "target": "stage5_quiz"}],
		"reward": {"coins": 50, "skill_points": 2, "exp": 40}},
	"q_overdawn": {
		"en": "Overdawn", "id": "Fajar Menyingsing",
		"en_d": "Beat the House and break the machine for good.",
		"id_d": "Kalahkan Bandar dan hancurkan mesinnya selamanya.",
		"objectives": [{"type": "boss_defeated"}],
		"reward": {"coins": 100, "skill_points": 1, "exp": 60}},
	# ── Challenge quests (UC-007) ──
	"q_survivor": {
		"en": "Unshaken", "id": "Tak Goyah", "challenge": true,
		"en_d": "Clear any stage without taking a single hit.",
		"id_d": "Selesaikan stage mana pun tanpa kena serangan sekali pun.",
		"objectives": [{"type": "no_damage_clear"}],
		"reward": {"coins": 60, "exp": 30}},
	"q_hunter": {
		"en": "Truth Hunter", "id": "Pemburu Kebenaran", "challenge": true,
		"en_d": "Collect 5 Truth Shards across the city.",
		"id_d": "Kumpulkan 5 Pecahan Kebenaran di seantero kota.",
		"objectives": [{"type": "collectible", "count": 5}],
		"reward": {"coins": 50, "skill_points": 1, "exp": 25}},
	# ── Repeatable loop ──
	"q_arcade_run": {
		"en": "Arcade Run", "id": "Lari Arena", "repeatable": true,
		"en_d": "Survive 5 arcade waves. Repeats — chase your streak.",
		"id_d": "Bertahan 5 gelombang arena. Berulang — kejar rekormu.",
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
		if st.get("done", false):
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
				var st: String = CollectibleManager.SHARDS.get(data.get("id", ""), {}).get("stage", "")
				if st == obj.get("target", ""):
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
		"boss_defeated":    return tr("Defeat the House")
		"arcade_wave":      return tr("Survive arcade waves")
	return obj["type"]

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")
