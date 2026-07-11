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

# ─── FX helper ─────────────────────────────────────────────────────────────────
const _BURST := preload("res://scene/system/vfx/particle_burst.tscn")

## Spawn a one-shot particle burst at a world position, tinted `color`. Frees itself.
func spawn_burst(at: Vector2, color: Color = Color.WHITE, amount: int = 14) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var b := _BURST.instantiate() as CPUParticles2D
	b.color = color
	b.amount = amount
	scene.add_child(b)
	b.global_position = at

# Animated one-shot effects — each event gets its OWN sprite animation (from the
# combosmooth VFX pack), not a recoloured particle burst. Frames packed as horizontal
# strips in art/VFX/fx/, played via SheetAnim.
const _SHEET_ANIM := preload("res://scene/system/vfx/sheet_anim.gd")
const _FX := {
	"poof":     {"tex": "res://art/VFX/fx/poof.png",     "frames": 5, "fps": 24},
	"splosion": {"tex": "res://art/VFX/fx/splosion.png", "frames": 4, "fps": 16},
	"pillar":   {"tex": "res://art/VFX/fx/pillar.png",   "frames": 8, "fps": 22},
	"orb":      {"tex": "res://art/VFX/fx/orb.png",       "frames": 6, "fps": 16},
	"green":    {"tex": "res://art/VFX/fx/green.png",     "frames": 6, "fps": 16},
	"portal":   {"tex": "res://art/VFX/fx/portal.png",   "frames": 4, "fps": 10},
}

## Spawn an animated effect by name at a world position. Frees itself when done
## (unless `loop`). Returns the node so a looping fx can be freed by the caller.
func spawn_fx(fx_name: String, at: Vector2, fx_scale: float = 1.0, tint: Color = Color.WHITE, loop: bool = false, anchor_bottom: bool = false) -> Node2D:
	var scene := get_tree().current_scene
	if scene == null or not _FX.has(fx_name):
		return null
	var info: Dictionary = _FX[fx_name]
	var s := Sprite2D.new()
	s.texture = load(info["tex"])
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # these FX are smooth art, not pixel
	s.hframes = info["frames"]
	# anchor_bottom: shift the sprite up so its BASE sits at `at` and it rises upward
	# (e.g. a pillar of light growing from the ground).
	if anchor_bottom:
		s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.scale = Vector2(fx_scale, fx_scale)
	s.modulate = tint
	s.set_script(_SHEET_ANIM)
	s.fps = info["fps"]
	s.loop = loop
	s.free_on_finish = not loop
	s.frame_count = info["frames"]
	scene.add_child(s)
	s.global_position = at
	return s

# Each stage's "majority" colour (from its parallax): a StageN portal is tinted with
# the DESTINATION stage's colour, so a portal to stage 2 (purple) glows purple, etc.
const _STAGE_COLORS := {
	1: Color(0.45, 0.85, 1.0),   # S1 futuristic city — cyan
	2: Color(0.78, 0.45, 1.0),   # S2 warped city — purple
	3: Color(1.0, 0.65, 0.3),    # S3 industrial — amber
	4: Color(1.0, 0.4, 0.4),     # S4 casino — red
	5: Color(1.0, 0.6, 0.78),    # S5 mountain dusk — rose
	6: Color(0.5, 1.0, 0.65),    # S6 sci-fi lab — green
}

## Place a looping portal beacon on every StageN exit in the current scene, tinted
## by the destination stage's colour. Called from each stage's _ready.
func decorate_stage_portals() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("Stage*Portal", "Area2D", true, false):
		var num := String(node.name).trim_prefix("Stage").trim_suffix("Portal").to_int()
		if not _STAGE_COLORS.has(num):
			continue
		var pos: Vector2 = node.global_position
		var cs := node.get_node_or_null("CollisionShape2D")
		if cs is Node2D:
			pos = (cs as Node2D).global_position
		var fx := spawn_fx("portal", pos, 1.2, _STAGE_COLORS[num], true)
		if fx:
			fx.z_index = -1   # sit behind the player as they step through

# ─── Game State ────────────────────────────────────────────────────────────────

var gameStarted: bool
var current_wave: int
var moving_to_next_wave: bool
var arcade_mode: bool = false   # When true, enemies always chase — DetectionZone is ignored
var settings_return_path: String = "res://scene/ui/main_menu.tscn"

# True only when every "must" NPC in the current scene has had its requirement met
# (skill unlocked / key granted / required quiz passed). Stage exit portals call this
# to forbid leaving until the mandatory NPCs have been spoken to.
func all_required_npcs_done() -> bool:
	for n in get_tree().get_nodes_in_group("npc"):
		if n.has_method("is_required") and n.is_required() \
				and n.has_method("is_requirement_met") and not n.is_requirement_met():
			return false
	return true

# ─── Enemy Damage (shared per enemy type) ──────────────────────────────────────
# Each enemy writes its stats here every frame so the player can read them
# without holding a direct reference to each individual enemy.
# NOTE: "Amount" typo preserved to match existing variable names across scenes.

var batDamageZone: Area2D
var adbotDamageAmount: int

var frogDamageZone: Area2D
var banditDamageAmount: int

var witchDamageZone: Area2D
var collectorDamageAmount: int

var necroDamageZone: Area2D
var dealerDamageAmount: int
