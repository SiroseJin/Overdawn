extends Node

# ─── Global Singleton ──────────────────────────────────────────────────────────
# Autoload script that acts as a shared blackboard for data that must be
# accessible from any script without direct node references.
#
# Convention: enemy damage variables have a typo ("Amount") that is kept
# intentionally to avoid breaking existing signal connections and scene data.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Player ────────────────────────────────────────────────────────────────────

var PlayerBody: CharacterBody2D       # Reference to the active Player node
var PlayerWeaponEquip: bool           # Whether the player currently has a weapon equipped

var playerAlive: bool
var playerDamageZone: Area2D          # The player's active melee hitbox zone
var playerDamageAmount: int           # Outgoing damage set each time the player attacks
var playerHitbox: Area2D              # The player's own hurtbox (receives incoming hits)

# ─── Game State ────────────────────────────────────────────────────────────────

var gameStarted: bool
var current_wave: int
var moving_to_next_wave: bool

# ─── Enemy Damage (shared per enemy type) ──────────────────────────────────────
# Each enemy writes its stats here every frame so the player can read them
# without holding a direct reference to each individual enemy.
# NOTE: "Amount" typo preserved to match existing variable names across scenes.

var batDamageZone: Area2D
var batDamageAmount: int

var frogDamageZone: Area2D
var frogDamageAmount: int

var witchDamageZone: Area2D
var witchDamageAmount: int

var necroDamageZone: Area2D
var necroDamageAmount: int
