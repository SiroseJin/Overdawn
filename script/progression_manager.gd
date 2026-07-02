extends Node

# ─── Progression Manager (Autoload) ────────────────────────────────────────────
# Central, save-aware record of everything the player has permanently earned or
# is currently carrying:
#   • unlocked_skills — abilities gated behind story progress (double jump, etc.)
#   • skill_levels    — RPG upgrade level per skill (raised with skill points)
#   • skill_points    — spent in the stat screen to upgrade unlocked skills
#   • coins           — currency collected in levels (spent at NPCs)
#   • cleared_stages  — which stages the player has finished at least once
#   • keys_held       — keys collected for lock-and-key puzzles (per save)
#   • npcs_talked     — NPCs whose dialogue has been completed
#
# Every gameplay system (player skill gating, upgrades, locked doors, NPCs)
# reads/writes through here so progression survives scene changes and saving.
# ───────────────────────────────────────────────────────────────────────────────

signal skill_unlocked(skill_name: String)
signal skill_upgraded(skill_name: String, level: int)
signal key_changed(key_id: String, held: bool)
signal coins_changed(total: int)
signal skill_points_changed(total: int)

# Skills the player starts with. `false` here means the ability is gated until
# unlocked through gameplay (e.g. beating a stage and talking to its NPC).
const DEFAULT_SKILLS := {
	"dash": true,          # core movement — available from the start
	"arrows": true,        # basic ranged attack — available from the start
	"double_jump": false,  # reward skill — unlocked by Stage 1's exit NPC
	"firewall": false,     # defensive shield — unlocked by an NPC (gambling ref)
}

# Highest upgrade level each skill can reach.
const MAX_SKILL_LEVEL := 3

var unlocked_skills: Dictionary = {}
var skill_levels:    Dictionary = {}   # skill -> int (1 once unlocked)
var cleared_stages:  Dictionary = {}
var keys_held:       Dictionary = {}
var npcs_talked:     Dictionary = {}
var coins:        int = 0
var skill_points: int = 0

func _ready() -> void:
	reset()

# Wipe progression back to defaults (new game / fresh arcade run).
func reset() -> void:
	unlocked_skills = DEFAULT_SKILLS.duplicate(true)
	skill_levels    = {}
	for s in DEFAULT_SKILLS:
		skill_levels[s] = 1 if DEFAULT_SKILLS[s] else 0
	cleared_stages  = {}
	keys_held       = {}
	npcs_talked     = {}
	coins        = 0
	skill_points = 0

# ─── Skills: unlock / level ──────────────────────────────────────────────────────

func is_skill_unlocked(skill: String) -> bool:
	# Arcade mode hands the player the full kit so wave survival is fair.
	if Global.arcade_mode:
		return true
	return unlocked_skills.get(skill, false)

func unlock_skill(skill: String) -> void:
	if unlocked_skills.get(skill, false):
		return
	unlocked_skills[skill] = true
	if int(skill_levels.get(skill, 0)) < 1:
		skill_levels[skill] = 1
	skill_unlocked.emit(skill)

# Current upgrade level (0 = still locked, 1 = unlocked/base, up to MAX_SKILL_LEVEL).
func get_skill_level(skill: String) -> int:
	if Global.arcade_mode:
		return MAX_SKILL_LEVEL
	return int(skill_levels.get(skill, 0))

func can_upgrade_skill(skill: String) -> bool:
	return is_skill_unlocked(skill) \
		and get_skill_level(skill) < MAX_SKILL_LEVEL \
		and skill_points > 0

# Spend one skill point to raise a skill's level. Returns true on success.
func upgrade_skill(skill: String) -> bool:
	if not can_upgrade_skill(skill):
		return false
	skill_points -= 1
	skill_levels[skill] = get_skill_level(skill) + 1
	skill_points_changed.emit(skill_points)
	skill_upgraded.emit(skill, skill_levels[skill])
	return true

# Grant every known skill at max level (debug stage teleport safety).
func unlock_all() -> void:
	for s in DEFAULT_SKILLS:
		unlock_skill(s)
		skill_levels[s] = MAX_SKILL_LEVEL

# ─── Skill points ────────────────────────────────────────────────────────────────

func add_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	skill_points += amount
	skill_points_changed.emit(skill_points)

# ─── Coins (currency) ────────────────────────────────────────────────────────────

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)

func has_coins(amount: int) -> bool:
	return coins >= amount

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

# ─── Stages ─────────────────────────────────────────────────────────────────────

func clear_stage(stage_id: String) -> void:
	cleared_stages[stage_id] = true

func is_stage_cleared(stage_id: String) -> bool:
	return cleared_stages.get(stage_id, false)

# ─── Keys ───────────────────────────────────────────────────────────────────────

func add_key(key_id: String) -> void:
	keys_held[key_id] = true
	key_changed.emit(key_id, true)

func has_key(key_id: String) -> bool:
	return keys_held.get(key_id, false)

# Spend a key (returns false if the player doesn't have it).
func consume_key(key_id: String) -> bool:
	if not has_key(key_id):
		return false
	keys_held.erase(key_id)
	key_changed.emit(key_id, false)
	return true

# ─── NPCs ───────────────────────────────────────────────────────────────────────

func mark_npc_talked(npc_id: String) -> void:
	if npc_id != "":
		npcs_talked[npc_id] = true

func has_talked_to(npc_id: String) -> bool:
	return npcs_talked.get(npc_id, false)

# ─── Save / Load ────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"unlocked_skills": unlocked_skills.duplicate(true),
		"skill_levels":    skill_levels.duplicate(true),
		"cleared_stages":  cleared_stages.duplicate(true),
		"keys_held":       keys_held.duplicate(true),
		"npcs_talked":     npcs_talked.duplicate(true),
		"coins":           coins,
		"skill_points":    skill_points,
	}

func from_dict(data: Dictionary) -> void:
	reset()
	for k in data.get("unlocked_skills", {}):
		unlocked_skills[k] = data["unlocked_skills"][k]
	for k in data.get("skill_levels", {}):
		skill_levels[k] = data["skill_levels"][k]
	cleared_stages = (data.get("cleared_stages", {}) as Dictionary).duplicate(true)
	keys_held      = (data.get("keys_held", {}) as Dictionary).duplicate(true)
	npcs_talked    = (data.get("npcs_talked", {}) as Dictionary).duplicate(true)
	coins        = int(data.get("coins", 0))
	skill_points = int(data.get("skill_points", 0))
	coins_changed.emit(coins)
	skill_points_changed.emit(skill_points)
