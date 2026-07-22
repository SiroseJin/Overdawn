extends Node

# ─── Global Singleton ──────────────────────────────────────────────────────────
# Autoload script that acts as a shared blackboard for data that must be
# accessible from any script without direct node references.
#
# Convention: enemy damage variables have a typo ("Amount") that is kept
# intentionally to avoid breaking existing signal connections and scene data.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Player ────────────────────────────────────────────────────────────────────

## Emitted when the in-game language changes so manually-localized text (tutorial
## signs, captions, etc.) can re-apply itself live instead of only at _ready (#7/#8).
signal locale_changed

var PlayerBody: CharacterBody2D       # Reference to the active Player node
var PlayerWeaponEquip: bool           # Whether the player currently has a weapon equipped

var playerAlive: bool
var playerDamageZone: Area2D          # The player's active melee hitbox zone
var playerDamageAmount: int           # Outgoing damage set each time the player attacks
var playerHitbox: Area2D              # The player's own hurtbox (receives incoming hits)

# ─── FX helper ─────────────────────────────────────────────────────────────────
const _BURST := preload("res://scene/system/vfx/particle_burst.tscn")

# The Dialogic default name-plate is styled with an empty FontVariation (null base
# font). It measures fine but renders NO glyphs in-game, so the speaker's name shows
# as a blank box (#1). Force a real, known-good body font on every name label instead.
const _DIALOGUE_NAME_FONT := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")

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

const _CAPTION_SCENE := preload("res://scene/ui/caption/caption.tscn")

## Hang a name-tag over a portal saying where it goes. It's an ordinary caption, so it
## joins the global "caption" group and the Settings ▸ "Object labels" toggle hides or
## shows it along with every other tag. Idempotent — a portal that already carries a
## Caption (e.g. one placed by hand in the editor) is left alone.
func add_portal_caption(portal: Node, en: String, id_text: String = "") -> void:
	if portal == null or portal.get_node_or_null("Caption") != null:
		return
	var cap := _CAPTION_SCENE.instantiate()
	cap.text_en = en                      # set before add_child: caption._ready reads these
	cap.text_id = id_text
	# Sit above the portal MOUTH, not the node origin — a portal's Area2D is often at
	# (0,0) with the real opening offset onto its collision shape.
	var at := Vector2.ZERO
	var cs := portal.get_node_or_null("CollisionShape2D")
	if cs is Node2D:
		at = (cs as Node2D).position
	portal.add_child(cap)
	cap.position = at + Vector2(-60.0, -86.0)   # tag is 120 wide, so -60 centres it

## Place a looping portal beacon on every StageN exit in the current scene, tinted
## by the destination stage's colour, and tag it with where it leads. Called from
## each stage's _ready.
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
		add_portal_caption(node, "To Stage %d" % num, "Ke Tahap %d" % num)

# ─── Game State ────────────────────────────────────────────────────────────────

var gameStarted: bool
var current_wave: int
var moving_to_next_wave: bool
var arcade_mode: bool = false   # When true, enemies always chase — DetectionZone is ignored
var tutorial_mode: bool = false # When true (tutorial stage only), every skill reads as unlocked
var settings_return_path: String = "res://scene/ui/main_menu.tscn"
# Random scene-transition style, chosen on each fade-out and reused for the matching
# fade-in on the next scene so the wipe/iris/fade continues seamlessly (#18).
var transition_style: int = 0

# ─── Robust scene loading (fixes portal crashes) ─────────────────────────────────
# One shared, hardened routine every stage's _fade_then_load delegates to. It fixes
# two intermittent portal crashes:
#   1. Engine.time_scale could still be 0 from a quiz/pause when the portal fired, so
#      the old time-scaled 0.5s wait never elapsed and the load stalled. We force
#      time_scale back to 1 and wait in REAL time (ignore_time_scale = true).
#   2. The old code raced a bare load() against a still-running threaded request,
#      which can hand back a half-loaded resource and crash change_scene. We now poll
#      the threaded load to completion and only ever swap in a fully-loaded scene.
func load_scene_with_fade(anim: AnimationPlayer, scene_path: String) -> void:
	# A transition must always run at normal speed — never inherit a leftover pause.
	Engine.time_scale = 1.0
	if is_instance_valid(Dialogic):
		Dialogic.paused = false

	ResourceLoader.load_threaded_request(scene_path)
	if anim and anim.has_animation("fade_in"):
		anim.play("fade_in")

	# Real-time wait (immune to time_scale) so the fade always plays out.
	await get_tree().create_timer(0.5, true, false, true).timeout

	# Never call load() while the threaded request is still in flight — wait it out.
	var status := ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path)

	var packed: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(scene_path)
	if packed == null:   # request failed/was cleared — last-resort direct load
		packed = load(scene_path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)

# ─── Object labels / captions ───────────────────────────────────────────────────
# Floating name-tags over gameplay objects (see scene/ui/caption/caption.tscn). Every
# Caption node adds itself to the "caption" group on load, so this one flag + toggle
# controls all of them at once. Persisted by SettingsManager under [game] show_captions.
var show_captions: bool = true

## Turn every object label on/off live and remember the choice for tags spawned later.
func set_captions_enabled(on: bool) -> void:
	show_captions = on
	get_tree().call_group("caption", "set_visible", on)

## Enroll a hand-authored Label (e.g. a pickup's existing "Tag") into the caption
## system so it obeys the global toggle just like an instanced Caption node.
func register_caption(node: CanvasItem) -> void:
	if not is_instance_valid(node):
		return
	node.add_to_group("caption")
	node.visible = show_captions

# ─── Damage numbers ──────────────────────────────────────────────────────────────
# Floating hit numbers over whoever took damage — player (red) and enemies (gold).
# Toggle persisted by SettingsManager under [game] show_damage_numbers.
var show_damage_numbers: bool = true
const _DAMAGE_NUMBER := preload("res://scene/system/vfx/damage_number.tscn")

# When true, the up/W key also jumps (in addition to the jump key). Persisted by
# SettingsManager under [game] use_w_to_jump; toggled from the Settings menu.
var use_w_to_jump: bool = false

# When true (default), mid-stage checkpoints are active: dying respawns the player at
# the last checkpoint (rolling progression back to it) instead of the death screen.
# Persisted by SettingsManager under [game] checkpoints_enabled.
var checkpoints_enabled: bool = true

# ─── Story-mode enemy scaling ────────────────────────────────────────────────────
# ─── Story-mode enemy scaling (proportional to the player) ───────────────────────
# STORY mode only. Instead of a flat % (which the player's own +2 STR / +8 HP per level
# quickly outgrows), enemies scale off the PLAYER'S stats so the *effort per enemy*
# stays roughly flat as you level:
#   • HP        += your basic attack damage × HP_PER_DMG   → kills take ~the same #hits
#   • Contact dmg += your max HP           × DMG_PER_HP    → a hit stays a real % of your bar
# It's ADDITIVE off your stats (not a multiplier), so it lifts a weak enemy and a beefy
# one by the same absolute amount and never turns the tanky ones into HP sponges.
#
# HP_PER_DMG is tuned so the weakest enemy (Adbot, 20 base HP) first becomes a one-shot
# around Lv40: one-shot when STR ≥ 20 + STR×0.78  →  STR ≥ ~91  →  Lv41. Below that it
# takes 2 hits; tougher enemies (Buzzer/Collector/Dealer) take proportionally more.
# Speed only creeps up a little (capped +10%) so it never becomes an unfair chase.
# Arcade mode is unaffected (it has its own wave scaling).
const HP_PER_DMG  := 0.78   # enemy bonus HP per point of player attack damage
const DMG_PER_HP  := 0.08   # enemy bonus contact damage per point of player max HP

func apply_enemy_scaling(e: Object) -> void:
	if arcade_mode or not is_instance_valid(PlayerBody):
		return
	# Per-save DIFFICULTY multiplier on enemy attack + HP (story mode only). Applied
	# first so it scales the base stats regardless of the level-scaling below.
	_apply_difficulty_scaling(e)
	var p = PlayerBody
	# Player's basic melee damage (= effective strength) and effective max HP.
	var pdmg: float = float(p.strength) if ("strength" in p) else 0.0
	var php: float
	if p.has_method("max_hp"):
		php = float(p.max_hp())
	elif "health_max" in p:
		php = float(p.health_max)
	if pdmg <= 0.0 and php <= 0.0:
		return

	var hp_bonus: float = pdmg * HP_PER_DMG
	if "health_max" in e:
		e.health_max += hp_bonus
		if "health" in e:
			e.health = e.health_max
	elif "health" in e:
		e.health += hp_bonus

	if "damage_to_deal" in e:
		e.damage_to_deal = int(round(e.damage_to_deal + php * DMG_PER_HP))

	if "speed" in e and ("level" in p):
		e.speed *= 1.0 + minf((int(p.level) - 1) * 0.003, 0.10)   # up to +10%, ~Lv34

# Scale ONLY enemy attack + HP by the chosen difficulty. Runs before the level
# scaling so it multiplies the enemy's base stats.
func _apply_difficulty_scaling(e: Object) -> void:
	var m: float = Difficulty.enemy_mult()
	if is_equal_approx(m, 1.0):
		return
	if "health_max" in e:
		e.health_max *= m
		if "health" in e:
			e.health = e.health_max
	elif "health" in e:
		e.health *= m
	if "damage_to_deal" in e:
		e.damage_to_deal = int(round(e.damage_to_deal * m))

# ─── Enemy line-of-sight (slope-aware) ─────────────────────────────────────────────
## Can `from` see `target` (defaults to the player)? A steep wall blocks sight, but a
## walkable slope or floor lump the enemy could just climb does NOT — the ray steps
## over it and keeps going. `slope_up` is how strongly a surface must face upward to
## count as walkable (its normal.y ≤ -slope_up); anything flatter/vertical is a wall.
## The endpoints are lifted to roughly torso height so small ground bumps never block.
func enemy_line_of_sight(from: Node2D, target: Node2D = null, slope_up: float = 0.5) -> bool:
	if target == null:
		target = PlayerBody
	if not is_instance_valid(from) or not is_instance_valid(target):
		return false
	var space := from.get_world_2d().direct_space_state
	var eye := Vector2(0, -12)                     # look from/at torso height, not the feet
	var a: Vector2 = from.global_position + eye
	var b: Vector2 = target.global_position + eye
	# Step the ray through any walkable slopes; a wall (or the target) ends the walk.
	for _i in 6:
		var q := PhysicsRayQueryParameters2D.create(a, b)
		q.exclude = [from]
		var r := space.intersect_ray(q)
		if r.is_empty() or r.get("collider") == target:
			return true
		# Surface facing up enough to walk over → not a real blocker; step past and retry.
		if float(r.normal.y) <= -slope_up:
			a = r.position + (b - a).normalized() * 4.0
			continue
		return false                               # vertical-ish wall (or ceiling) → blocked
	return false

# ─── Enemy behaviour helpers ─────────────────────────────────────────────────────
# Shared by every ground enemy so the behaviour is written once instead of copied
# into adbot/buzzer/collector/dealer.

## A small startled hop the moment an enemy notices the player — reads as "it saw
## you" without changing how the chase plays. Call it only when
## AudioManager.play_alert() returns true, so the hop follows the same global
## cooldown as the alert sting and a room of enemies doesn't pop in unison.
func enemy_spot_hop(e: Node2D, force: float = -165.0) -> void:
	if not (e is CharacterBody2D):
		return
	var body := e as CharacterBody2D
	if not body.is_on_floor():
		return                                   # flyers and mid-air enemies stay put
	body.velocity.y = force
	spawn_burst(body.global_position + Vector2(0, 10), Color(1, 1, 1, 0.55), 4)

## True when there is NO solid ground a step ahead of `e` in `dir` — i.e. walking on
## would drop it into a pit. Ground enemies flip instead of strolling off a ledge.
## Probes from just in front of the enemy's feet straight down.
func enemy_ledge_ahead(e: Node2D, dir: float, probe_x: float = 24.0, probe_down: float = 56.0) -> bool:
	if dir == 0.0 or not is_instance_valid(e):
		return false
	var world := e.get_world_2d()
	if world == null:
		return false
	var from: Vector2 = e.global_position + Vector2(signf(dir) * probe_x, -6.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, probe_down))
	q.collide_with_areas = false
	if e is CollisionObject2D:
		q.exclude = [(e as CollisionObject2D).get_rid()]
	return world.direct_space_state.intersect_ray(q).is_empty()

# ─── Scrollable menus ────────────────────────────────────────────────────────────
## Wrap `content` (a menu's main container) in a ScrollContainer occupying the same
## slot, so it scrolls vertically instead of overflowing/clipping. Idempotent and
## layout-preserving — call it once from a menu's _ready. Future-proof: any menu that
## might grow past its panel just calls this and stays scrollable.
func make_scrollable(content: Control) -> void:
	if content == null:
		return
	var parent := content.get_parent() as Control
	if parent == null or parent is ScrollContainer:
		return
	var idx := content.get_index()
	var scroll := ScrollContainer.new()
	scroll.name = String(content.name) + "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Occupy the same slot/layout the content had.
	scroll.size_flags_horizontal = content.size_flags_horizontal
	scroll.size_flags_vertical   = content.size_flags_vertical
	scroll.anchor_left   = content.anchor_left
	scroll.anchor_top    = content.anchor_top
	scroll.anchor_right  = content.anchor_right
	scroll.anchor_bottom = content.anchor_bottom
	scroll.offset_left   = content.offset_left
	scroll.offset_top    = content.offset_top
	scroll.offset_right  = content.offset_right
	scroll.offset_bottom = content.offset_bottom
	parent.remove_child(content)
	parent.add_child(scroll)
	parent.move_child(scroll, idx)
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

# ─── Dialogic warm-up ────────────────────────────────────────────────────────────
## Pre-build the Dialogic layout (during a scene fade-in, so any flash is hidden) so
## the FIRST dialogue of the session doesn't stall while the layout scene is built.
## The layout lives at /root and persists, so this only does work once per run.
func warm_dialogic() -> void:
	if not is_instance_valid(Dialogic):
		return
	var styles = Dialogic.get("Styles")
	if styles == null or styles.has_active_layout_node():
		return
	styles.load_style()                 # builds the layout (deferred add_child)
	await get_tree().process_frame
	await get_tree().process_frame
	if styles.has_active_layout_node():
		styles.get_layout_node().hide() # keep it hidden until a real dialogue shows it
	fix_dialogue_name_labels()

## Force a real font onto every Dialogic name label so the speaker's name renders
## instead of showing a blank plate (#1). Idempotent — safe to call before each talk.
## The label keeps Dialogic's per-character colour (applied via self_modulate).
func fix_dialogue_name_labels() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for l in tree.get_nodes_in_group("dialogic_name_label"):
		if l is Label:
			l.add_theme_font_override("font", _DIALOGUE_NAME_FONT)
			l.add_theme_font_size_override("font_size", 16)

## Spawn a rising, fading damage number at a world position. No-op if the toggle is off.
func spawn_damage_number(at: Vector2, amount: int, color: Color = Color(1, 0.9, 0.5)) -> void:
	if not show_damage_numbers or amount <= 0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dn := _DAMAGE_NUMBER.instantiate()
	dn.amount = amount
	dn.color = color
	scene.add_child(dn)
	dn.global_position = at + Vector2(randf_range(-6.0, 6.0), -12.0)

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
var buzzerDamageAmount: int

var witchDamageZone: Area2D
var collectorDamageAmount: int

var necroDamageZone: Area2D
var dealerDamageAmount: int
