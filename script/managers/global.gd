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
var banditDamageAmount: int

var witchDamageZone: Area2D
var collectorDamageAmount: int

var necroDamageZone: Area2D
var dealerDamageAmount: int
