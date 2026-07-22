extends Node

# ─── Difficulty (Autoload) ──────────────────────────────────────────────────────────
# Per-save difficulty, chosen on New Game and persisted with the save (via
# ProgressionManager), restored on load. It changes ONLY three things:
#   • enemy ATTACK + HP (a single multiplier applied in Global.apply_enemy_scaling)
#   • the EXP needed to level up (a multiplier applied by the player)
#   • how fast the Stage 3 rising debt floods (applied in rising_debt.gd)
# Nothing else — player stats, drops, movement speeds, etc. are untouched.
# ────────────────────────────────────────────────────────────────────────────────────

enum Level { CASUAL, EASY, NORMAL, HARD, EXPERT }

const NAMES_EN := ["Casual", "Easy", "Normal", "Hard", "Expert"]
const NAMES_ID := ["Santai", "Mudah", "Normal", "Sulit", "Ahli"]

# Enemy attack + HP multiplier — Casual -40%, Easy -15%, Normal 0, Hard +15%, Expert +40%.
const ENEMY_MULT := [0.60, 0.85, 1.00, 1.15, 1.40]
# EXP-to-level-up multiplier — Casual -25%, Easy -10%, Normal 0, Hard +15%, Expert +30%.
const EXP_MULT := [0.75, 0.90, 1.00, 1.15, 1.30]
# Rising-debt flood speed — Casual -20%, Easy -10%, Normal 0, Hard +10%, Expert +20%.
# A slower flood buys you more time to climb the Debt Tower; a faster one hounds you.
const DEBT_MULT := [0.80, 0.90, 1.00, 1.10, 1.20]

# One-line effect summaries for the selection screen.
const BLURB_EN := [
	"Enemies -40% ATK/HP · Level up 25% faster",
	"Enemies -15% ATK/HP · Level up 10% faster",
	"The intended balance",
	"Enemies +15% ATK/HP · Level up 15% slower",
	"Enemies +40% ATK/HP · Level up 30% slower",
]
const BLURB_ID := [
	"Musuh -40% SRG/HP · Naik level 25% lebih cepat",
	"Musuh -15% SRG/HP · Naik level 10% lebih cepat",
	"Keseimbangan yang dimaksudkan",
	"Musuh +15% SRG/HP · Naik level 15% lebih lambat",
	"Musuh +40% SRG/HP · Naik level 30% lebih lambat",
]

var current: int = Level.NORMAL

func set_difficulty(d: int) -> void:
	current = clampi(d, 0, NAMES_EN.size() - 1)

func enemy_mult() -> float:
	return ENEMY_MULT[current]

func exp_req_mult() -> float:
	return EXP_MULT[current]

func debt_speed_mult() -> float:
	return DEBT_MULT[current]

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")

# Localised display name for a difficulty (defaults to the current one).
func name_of(d: int = -1) -> String:
	var i := current if d < 0 else clampi(d, 0, NAMES_EN.size() - 1)
	return NAMES_ID[i] if _is_id() else NAMES_EN[i]

func blurb_of(d: int) -> String:
	var i := clampi(d, 0, NAMES_EN.size() - 1)
	return BLURB_ID[i] if _is_id() else BLURB_EN[i]
