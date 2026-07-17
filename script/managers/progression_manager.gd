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

# ─── Gamification hub ────────────────────────────────────────────────────────────
# A single generic event bus so quests (QuestManager) and badges (BadgeManager) can
# react to anything that happens without every gameplay system needing to know they
# exist. Gameplay code calls ProgressionManager.notify("quiz_passed", {...}); the
# managers listen on `game_event`. Keeps the new systems fully additive.
signal game_event(event_name: String, data: Dictionary)
signal collectible_changed(total: int)
signal badge_unlocked(badge_id: String)

# Skills the player starts with. `false` here means the ability is gated until
# unlocked through gameplay (e.g. beating a stage and talking to its NPC).
const DEFAULT_SKILLS := {
	"arrows": true,        # basic ranged attack — available from the start
	"dash": false,         # unlocked by Stage 1's Gatekeeper ("break away fast")
	"double_jump": false,  # unlocked by Yani at the Stage 2 gate ("second chance")
	"firewall": false,     # unlocked by Damar in Stage 3 (network firewall)
}

# Highest upgrade level each of the 4 core skills can reach.
const MAX_SKILL_LEVEL := 5

# ─── Upgrade tracks (spend Skill Points) ─────────────────────────────────────────
# Beyond the 4 core ability skills, the Upgrade screen also offers stat / attack /
# skill-augment tracks. Each has its own cap and (optionally) a required skill.
#   cat: "sub" (augments a skill) | "stat" (base stat) | "attack" (attack scaling)
#   req: skill that must be unlocked first ("" = always available)
const UPGRADES := {
	# Skill augments
	"arrow_dmg": {"en": "Arrow Damage", "id": "Damage Panah", "cat": "sub", "cap": 5, "req": "arrows",
		"en_d": "+1 damage & +1% strength per level", "id_d": "+1 damage & +1% kekuatan per level"},
	"dash_dist": {"en": "Dash Distance", "id": "Jarak Dash", "cat": "sub", "cap": 5, "req": "dash",
		"en_d": "+1% dash distance per level", "id_d": "+1% jarak dash per level"},
	"dj_height": {"en": "Double Jump Height", "id": "Tinggi Lompat Ganda", "cat": "sub", "cap": 5, "req": "double_jump",
		"en_d": "Recover the double-jump height penalty (1%/lvl)", "id_d": "Pulihkan penalti tinggi lompat ganda (1%/lvl)"},
	# Base stats
	"stat_health":   {"en": "Max Health", "id": "Nyawa Maks", "cat": "stat", "cap": 10, "req": "",
		"en_d": "+1.5% max health per level", "id_d": "+1.5% nyawa maks per level"},
	"stat_strength": {"en": "Strength", "id": "Kekuatan", "cat": "stat", "cap": 10, "req": "",
		"en_d": "+1.5% strength per level", "id_d": "+1.5% kekuatan per level"},
	"stat_speed":    {"en": "Move Speed", "id": "Kecepatan", "cat": "stat", "cap": 5, "req": "",
		"en_d": "+1.5% move speed per level", "id_d": "+1.5% kecepatan per level"},
	"stat_jump":     {"en": "Jump Height", "id": "Tinggi Lompat", "cat": "stat", "cap": 3, "req": "",
		"en_d": "+1.5% jump height per level", "id_d": "+1.5% tinggi lompat per level"},
	# Attack scaling
	"atk_basic": {"en": "Basic Attack", "id": "Serangan Dasar", "cat": "attack", "cap": 5, "req": "",
		"en_d": "+1% basic attack scaling per level", "id_d": "+1% skala serangan dasar per level"},
	"atk_heavy": {"en": "Heavy Attack", "id": "Serangan Berat", "cat": "attack", "cap": 5, "req": "",
		"en_d": "+1% heavy attack scaling per level", "id_d": "+1% skala serangan berat per level"},
	"atk_dash":  {"en": "Dash Attack", "id": "Serangan Dash", "cat": "attack", "cap": 5, "req": "",
		"en_d": "+1% dash attack scaling per level", "id_d": "+1% skala serangan dash per level"},
}

var unlocked_skills: Dictionary = {}
var skill_levels:    Dictionary = {}   # skill -> int (1 once unlocked)
var stat_levels:     Dictionary = {}   # upgrade_id (see UPGRADES) -> int level
var cleared_stages:  Dictionary = {}
var keys_held:       Dictionary = {}
var npcs_talked:     Dictionary = {}
var coins:        int = 0
var skill_points: int = 0

# Player identity + playtime — make each save unique and informative (UC-15/17).
var player_name: String = "Player"
var play_time:   float  = 0.0        # total seconds of active gameplay

# Gamification state (all persisted through to_dict/from_dict → SaveManager).
var collectibles: Dictionary = {}   # collectible_id -> true  (UC-004 "Truth Shards")
var badges:       Dictionary = {}   # badge_id -> true        (UC-009 achievements)
var guides:       Dictionary = {}   # guide_id -> true        (Guide codex, CodexManager)
var lore:         Dictionary = {}   # lore_id  -> true        (Lore codex,  CodexManager)
var quest_state:  Dictionary = {}   # quest_id -> { "progress": {..}, "done": bool } (UC-008)

# Player RPG stats that must survive scene changes (each stage rebuilds the Player
# node, so these can't live only on it). `player_initialized` is false until the
# first Player seeds them, so a fresh run keeps the Player scene's own defaults.
var player_initialized: bool = false
var player_level:         int = 1
var player_exp:           int = 0
var player_exp_to_next:   int = 10
var player_health:        int = 100
var player_health_max:    int = 100
var player_strength:      int = 11
var player_score:         int = 0

func _ready() -> void:
	reset()

# Wipe progression back to defaults (new game / fresh arcade run).
func reset() -> void:
	unlocked_skills = DEFAULT_SKILLS.duplicate(true)
	skill_levels    = {}
	for s in DEFAULT_SKILLS:
		skill_levels[s] = 1 if DEFAULT_SKILLS[s] else 0
	stat_levels     = {}
	cleared_stages  = {}
	keys_held       = {}
	npcs_talked     = {}
	collectibles = {}
	badges       = {}
	guides       = {}
	lore         = {}
	quest_state  = {}
	coins        = 0
	skill_points = 0
	player_name  = "Player"
	play_time    = 0.0
	player_initialized = false
	player_level       = 1
	player_exp         = 0
	player_exp_to_next = 10
	player_health      = 100
	player_health_max  = 100
	player_strength    = 11
	player_score       = 0

# ─── Skills: unlock / level ──────────────────────────────────────────────────────

func is_skill_unlocked(skill: String) -> bool:
	# The tutorial hands out every skill so it can teach them, WITHOUT touching the
	# real save (it just reads true while tutorial_mode is on).
	if Global.tutorial_mode:
		return true
	# Skills are earned by unlocking them through the story NPCs — arcade uses whatever
	# you've actually unlocked (it does NOT hand out the full kit).
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

# ─── Upgrade tracks (stats / attacks / skill augments) ───────────────────────────

func get_upgrade_level(id: String) -> int:
	return int(stat_levels.get(id, 0))

func upgrade_cap(id: String) -> int:
	return int(UPGRADES.get(id, {}).get("cap", 0))

## Available = its required skill (if any) is unlocked. Locked tracks show but can't buy.
func upgrade_available(id: String) -> bool:
	var req: String = UPGRADES.get(id, {}).get("req", "")
	return req == "" or is_skill_unlocked(req)

func can_buy_upgrade(id: String) -> bool:
	return UPGRADES.has(id) and upgrade_available(id) \
		and get_upgrade_level(id) < upgrade_cap(id) and skill_points > 0

# Spend one skill point on an upgrade track. Returns true on success.
func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	skill_points -= 1
	stat_levels[id] = get_upgrade_level(id) + 1
	skill_points_changed.emit(skill_points)
	skill_upgraded.emit(id, stat_levels[id])
	if all_upgrades_maxed():
		notify("all_upgrades_maxed", {})   # BadgeManager awards the completionist badge
	return true

## True once all 4 skills AND every upgrade track are at their cap (badge trigger).
func all_upgrades_maxed() -> bool:
	for s in DEFAULT_SKILLS:
		if get_skill_level(s) < MAX_SKILL_LEVEL:
			return false
	for id in UPGRADES:
		if get_upgrade_level(id) < upgrade_cap(id):
			return false
	return true

# Grant every known skill at max level (debug stage teleport safety).
func unlock_all() -> void:
	for s in DEFAULT_SKILLS:
		unlock_skill(s)
		skill_levels[s] = MAX_SKILL_LEVEL

# Re-lock a skill (debug). Level drops to 0 so it can't be used or upgraded.
func lock_skill(skill: String) -> void:
	unlocked_skills[skill] = false
	skill_levels[skill] = 0

func lock_all() -> void:
	for s in DEFAULT_SKILLS:
		lock_skill(s)

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
	var was_cleared: bool = cleared_stages.get(stage_id, false)
	cleared_stages[stage_id] = true
	if not was_cleared:
		notify("stage_cleared", {"stage_id": stage_id})

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

# ─── Player RPG stats (persist across stages) ─────────────────────────────────────

# Copy the Player's current RPG stats into here. Call after any change so the
# record stays current for the next stage / a save.
func capture_player(p) -> void:
	if not is_instance_valid(p):
		return
	player_level       = p.level
	player_exp         = p.exp
	player_exp_to_next = p.exp_to_next_level
	player_health      = p.health
	player_health_max  = p.health_max
	player_strength    = p.strength
	player_score       = p.score
	player_initialized = true

# Push the stored stats onto a freshly-spawned Player. On the very first spawn
# (nothing stored yet) we instead seed from the Player's own defaults so a new
# run starts correctly.
func restore_player(p) -> void:
	if not is_instance_valid(p):
		return
	if not player_initialized:
		capture_player(p)
		return
	p.level             = player_level
	p.exp               = player_exp
	p.exp_to_next_level = player_exp_to_next
	p.health_max        = player_health_max
	# A stored health of 0 means the player died (e.g. before a retry) — respawn at
	# full health rather than spawning already dead.
	p.health            = player_health_max if player_health <= 0 else min(player_health, player_health_max)
	p.strength          = player_strength
	p.score             = player_score

# ─── Gamification: event hub, collectibles, badges (UC-004/008/009) ───────────────

## Broadcast a gameplay event so QuestManager / BadgeManager can react. Safe to call
## from anywhere; if no one listens it's a no-op.
func notify(event_name: String, data: Dictionary = {}) -> void:
	game_event.emit(event_name, data)

# Collectibles (UC-004) — permanent, per-save. Returns true only the first time.
func collect(collectible_id: String) -> bool:
	if collectibles.get(collectible_id, false):
		return false
	collectibles[collectible_id] = true
	collectible_changed.emit(collectibles.size())
	notify("collectible", {"id": collectible_id})
	return true

func has_collectible(collectible_id: String) -> bool:
	return collectibles.get(collectible_id, false)

func collectible_count() -> int:
	return collectibles.size()

# Badges (UC-009). Returns true only on the first award (so callers can juice it).
func award_badge(badge_id: String) -> bool:
	if badges.get(badge_id, false):
		return false
	badges[badge_id] = true
	badge_unlocked.emit(badge_id)
	notify("badge_unlocked", {"id": badge_id})
	return true

func has_badge(badge_id: String) -> bool:
	return badges.get(badge_id, false)

func badge_count() -> int:
	return badges.size()

# ─── Save / Load ────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"unlocked_skills": unlocked_skills.duplicate(true),
		"skill_levels":    skill_levels.duplicate(true),
		"cleared_stages":  cleared_stages.duplicate(true),
		"keys_held":       keys_held.duplicate(true),
		"npcs_talked":     npcs_talked.duplicate(true),
		"collectibles":    collectibles.duplicate(true),
		"badges":          badges.duplicate(true),
		"guides":          guides.duplicate(true),
		"lore":            lore.duplicate(true),
		"quest_state":     quest_state.duplicate(true),
		"stat_levels":     stat_levels.duplicate(true),
		"coins":           coins,
		"skill_points":    skill_points,
		"player_name":     player_name,
		"play_time":       play_time,
		"player_initialized": player_initialized,
		"player_level":       player_level,
		"player_exp":         player_exp,
		"player_exp_to_next": player_exp_to_next,
		"player_health":      player_health,
		"player_health_max":  player_health_max,
		"player_strength":    player_strength,
		"player_score":       player_score,
	}

func from_dict(data: Dictionary) -> void:
	reset()
	for k in data.get("unlocked_skills", {}):
		unlocked_skills[k] = data["unlocked_skills"][k]
	for k in data.get("skill_levels", {}):
		skill_levels[k] = data["skill_levels"][k]
	stat_levels    = (data.get("stat_levels", {}) as Dictionary).duplicate(true)
	cleared_stages = (data.get("cleared_stages", {}) as Dictionary).duplicate(true)
	keys_held      = (data.get("keys_held", {}) as Dictionary).duplicate(true)
	npcs_talked    = (data.get("npcs_talked", {}) as Dictionary).duplicate(true)
	collectibles   = (data.get("collectibles", {}) as Dictionary).duplicate(true)
	badges         = (data.get("badges", {}) as Dictionary).duplicate(true)
	guides         = (data.get("guides", {}) as Dictionary).duplicate(true)
	lore           = (data.get("lore", {}) as Dictionary).duplicate(true)
	quest_state    = (data.get("quest_state", {}) as Dictionary).duplicate(true)
	coins        = int(data.get("coins", 0))
	skill_points = int(data.get("skill_points", 0))
	player_name  = str(data.get("player_name", "Player"))
	play_time    = float(data.get("play_time", 0.0))
	player_initialized = bool(data.get("player_initialized", false))
	player_level       = int(data.get("player_level", 1))
	player_exp         = int(data.get("player_exp", 0))
	player_exp_to_next = int(data.get("player_exp_to_next", 10))
	player_health      = int(data.get("player_health", 100))
	player_health_max  = int(data.get("player_health_max", 100))
	player_strength    = int(data.get("player_strength", 11))
	player_score       = int(data.get("player_score", 0))
	coins_changed.emit(coins)
	skill_points_changed.emit(skill_points)
