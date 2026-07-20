extends Node2D

# ─── Stage 6 — The Core (Final Boss) ────────────────────────────────────────────
# The player walks in, and the moment they cross into the boss zone the door
# slams shut behind them. A 5-second countdown, then the boss is summoned. The
# arena keeps the previous mechanics in play — moving and falling platforms — so
# the fight is dodging bullets AND managing footing at once. Beating the boss
# ends the game.
# ───────────────────────────────────────────────────────────────────────────────

const BAIT_SCENE    := preload("res://scene/Levels/Level2/gimmicks/bait_platform/bait_platform.tscn")
const DEBT_WALL     := preload("res://scene/Levels/Level6/gimmicks/debt_wall/debt_wall.tscn")
const PULL_ZONE     := preload("res://scene/Levels/Level4/gimmicks/pull_zone/pull_zone.tscn")
const FALLING_PLAT  := preload("res://scene/gimmicks/falling_platform/falling_platform.tscn")
const COIN_SCENE    := preload("res://scene/pickups/coin/coin.tscn")

# Gimmicks now spawn continuously through the whole fight (not one-per-phase), and
# more often + several at once as the boss's HP drops. Roots are tracked so they can
# be cleared on death; each also self-despawns after a lifetime so they cycle.
var _active_gimmicks: Array[Node] = []
var _fight_active := false
var _gimmick_timer := 0.0
var _pull_zone: Node = null   # at most one pull wall active at a time (shared push var)

# Weighted rotation — "debt" (the sweeping Debt Wall) is listed extra times so it
# shows up in most waves instead of a 1-in-4 chance. Duplicates in the first picks
# can spawn a second wall, which is fine (more pressure).
const GIMMICK_KINDS := ["bait", "debt", "debt", "pull", "falling", "debt"]

# Where arena platforms (bait + falling) may spawn — a Rect2 you can drag/resize in the
# inspector. Kept inside the walls (x 0–2400) and above the floor (y≈648) so nothing
# spawns out of bounds. x, y = top-left; the last two numbers are width, height.
@export var platform_area: Rect2 = Rect2(560, 340, 1740, 260)
## Minimum gap between two spawned platforms so they never clump or overlap.
@export var platform_min_gap: Vector2 = Vector2(210, 80)
## Hard cap on platforms alive at once (keeps the arena readable).
@export var max_platforms: int = 6

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM
@onready var close_door: StaticBody2D = $CloseDoor
@onready var boss:       FinalBossEnemy = $Boss

const TARGET_GUIDE := preload("res://scene/system/vfx/target_guide.gd")

var _started := false
var _transitioning := false

# Boss-stage guide lines: RED points to the boss while it's DOWN; GREEN points to a
# random live server, re-picked ~every 7s, if the player dawdles during the shield.
var _boss_guide: Node2D
var _server_guide: Node2D
var _server_guide_timer := 7.0

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	Global.decorate_stage_portals()
	# Truth Shards are placed in the editor now (collectible.tscn instances you can drag).
	scene_transition_anim.play("fade_out")
	AudioManager.play_music("boss")
	AudioManager.play_ambience("server")
	# Door starts open (passable) until the trap is sprung.
	close_door.visible = false
	$CloseDoor/CollisionShape2D.disabled = true
	$BossZone.body_entered.connect(_on_boss_zone_entered)
	# The boss is placed in the editor but dormant/hidden until the countdown ends.
	boss.visible = false
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(_on_boss_phase)
	_boss_guide   = _make_guide(Color(1.0, 0.25, 0.25))   # red  -> boss when it's down
	_server_guide = _make_guide(Color(0.4, 1.0, 0.5))     # green -> a server if dawdling

func _make_guide(color: Color) -> Node2D:
	var g := Node2D.new()
	g.set_script(TARGET_GUIDE)
	g.line_color = color
	add_child(g)
	return g

func _on_boss_zone_entered(body: Node2D) -> void:
	if _started or not (body is Player):
		return
	_started = true
	# Slam the door shut behind the player — no backing out now.
	close_door.visible = true
	$CloseDoor/CollisionShape2D.set_deferred("disabled", false)
	_countdown_then_summon()

func _countdown_then_summon() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"))
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color(1, 0.4, 0.5))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)

	for i in range(5, 0, -1):
		label.text = str(i)
		await get_tree().create_timer(1.0).timeout
	label.text = tr("SURVIVE")
	await get_tree().create_timer(0.7).timeout
	layer.queue_free()
	# Reveal & wake the boss that's already placed in the arena. Servers spawn at
	# the ServerSpawn markers (see the scene) — 4 of the 7 picked at random.
	boss.summon()
	_fight_active = true
	_gimmick_timer = 3.0   # short grace before the first gimmick wave

# ── Continuous gimmicks ─────────────────────────────────────────────────────────
# Every earlier stage's gimmick can resurface at any time (phase no longer gates
# them), and several run at once. As the boss's HP falls, waves come faster and
# bring more gimmicks — the whole game's lessons pile onto you at the climax.

func _process(delta: float) -> void:
	if not _fight_active:
		return
	if not is_instance_valid(boss) or boss.dead or not boss.active:
		return
	_update_boss_guides(delta)
	_gimmick_timer -= delta
	if _gimmick_timer <= 0.0:
		_spawn_gimmick_wave()
		_gimmick_timer = lerpf(5.0, 1.5, _intensity())   # faster waves at low HP

# Red guide to the boss while it's DOWN; green guide to a random live server, re-picked
# ~every 7s, if the player is taking too long to break the shield.
func _update_boss_guides(delta: float) -> void:
	_boss_guide.target = boss if boss.state == "down" else null

	if boss.state == "shielded":
		var servers := _alive_servers()
		if servers.is_empty():
			_server_guide.target = null
		else:
			_server_guide_timer -= delta
			if _server_guide_timer <= 0.0:
				_server_guide.target = servers.pick_random()
				_server_guide_timer = 7.0
			elif not (is_instance_valid(_server_guide.target) and servers.has(_server_guide.target)):
				_server_guide.target = null   # highlighted server gone — wait for the next tick
	else:
		_server_guide.target = null
		_server_guide_timer = 7.0             # reset the delay for the next shielded phase

func _alive_servers() -> Array:
	var out: Array = []
	for s in get_tree().get_nodes_in_group("boss_server"):
		if is_instance_valid(s) and not s._destroyed:
			out.append(s)
	return out

# A phase change also fires an immediate wave for a spike of pressure.
func _on_boss_phase(_p: int) -> void:
	if _fight_active:
		_spawn_gimmick_wave()
	AudioManager.play_sfx("boss_phase")
	# Second half of the fight escalates to the harder boss theme.
	if _p >= 3:
		AudioManager.play_music("boss_phase2")

# 0 at full boss HP → 1 near death.
func _intensity() -> float:
	if not is_instance_valid(boss) or boss.health_max <= 0.0:
		return 0.0
	return clampf(1.0 - boss.health / boss.health_max, 0.0, 1.0)

func _spawn_gimmick_wave() -> void:
	# Drop already-freed entries, then cap how many can coexist so it stays fair-ish.
	_active_gimmicks = _active_gimmicks.filter(func(n): return is_instance_valid(n))
	if _active_gimmicks.size() >= 8:
		return
	var kinds := GIMMICK_KINDS.duplicate()
	kinds.shuffle()
	var n := 1 + int(round(_intensity() * 2.0))       # 1 → 3 gimmicks per wave
	for i in min(n, kinds.size()):
		_spawn_gimmick(kinds[i])

func _spawn_gimmick(kind: String) -> void:
	match kind:
		"bait":    _g_bait()
		"debt":    _g_debt()
		"pull":    _g_pull()
		"falling": _g_falling()

# Stage 2 — glowing false footing with a coin lure, spread across the arena (never
# overlapping and never outside platform_area).
func _g_bait() -> void:
	for i in 2:
		var pos := _find_free_spot()
		if pos == Vector2.INF:
			return   # arena is already full — don't force an overlap
		var b := BAIT_SCENE.instantiate()
		b.position = pos
		b.set_meta("arena_plat", true)
		_add_gimmick(b, 10.0)
		var c := COIN_SCENE.instantiate()
		c.position = pos + Vector2(0, -28.0)
		_add_gimmick(c, 10.0)

# Stage 3 — a debt wall sweeping across (faster the more hurt the boss is).
func _g_debt() -> void:
	var w := DEBT_WALL.instantiate()
	w.position = Vector2(-120.0, randf_range(300.0, 460.0))
	# Fast enough — and alive long enough — to actually sweep across the whole arena to
	# the boss (~x1636) and beyond, instead of despawning partway. At 130px/s it clears
	# ~2080px in its lifetime, well past the boss; faster at low HP, and it loops.
	w.speed = lerpf(130.0, 210.0, _intensity())
	w.damage = 16
	w.loop = true
	_add_gimmick(w, 16.0)

# Stage 4 — the pull wall, now MOVING: it sweeps back and forth across the arena
# while dragging the player, instead of sitting in one place. Only one at a time
# (the player has a single external_push slot).
func _g_pull() -> void:
	if is_instance_valid(_pull_zone):
		return
	var z := PULL_ZONE.instantiate()
	var start_x := randf_range(platform_area.position.x + 140.0, platform_area.end.x - 140.0)
	z.position = Vector2(start_x, 600.0)
	z.pull = Vector2(randf_range(70.0, 110.0) * (1.0 if randf() < 0.5 else -1.0), 0.0)
	_add_gimmick(z, 9.0)
	_pull_zone = z
	# Sweep the wall across the arena and back, faster at low HP. Bound to the node
	# so the tween dies with it.
	var leg := lerpf(2.6, 1.3, _intensity())
	var lo := platform_area.position.x
	var hi := platform_area.end.x
	var t := z.create_tween().set_loops()
	t.tween_property(z, "position:x", clampf(start_x + 650.0, lo, hi), leg)
	t.tween_property(z, "position:x", clampf(start_x - 650.0, lo, hi), leg)

# Stage 5 — crumbling perches, spread across the arena (no overlap, in bounds).
func _g_falling() -> void:
	for i in 3:
		var pos := _find_free_spot()
		if pos == Vector2.INF:
			return
		var fp := FALLING_PLAT.instantiate()
		fp.position = pos
		fp.set_meta("arena_plat", true)
		_add_gimmick(fp, 8.0)

# Find a spawn position inside platform_area that isn't too close to any platform
# already out there. Returns Vector2.INF if it can't (arena full / capped) so callers
# skip rather than force an overlap.
func _find_free_spot() -> Vector2:
	# Respect the live platform cap.
	var live := 0
	for n in _active_gimmicks:
		if is_instance_valid(n) and n.has_meta("arena_plat"):
			live += 1
	if live >= max_platforms:
		return Vector2.INF
	for _try in 14:
		var pos := Vector2(
			randf_range(platform_area.position.x, platform_area.end.x),
			randf_range(platform_area.position.y, platform_area.end.y))
		var clear := true
		for n in _active_gimmicks:
			if is_instance_valid(n) and n.has_meta("arena_plat"):
				if absf(n.position.x - pos.x) < platform_min_gap.x \
						and absf(n.position.y - pos.y) < platform_min_gap.y:
					clear = false
					break
		if clear:
			return pos
	return Vector2.INF

# Add a gimmick to the arena, track it, and auto-remove after `lifetime` seconds.
func _add_gimmick(node: Node, lifetime: float) -> void:
	add_child(node)
	_active_gimmicks.append(node)
	_despawn_after(node, lifetime)

func _despawn_after(node: Node, secs: float) -> void:
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(node):
		node.queue_free()

func _end_fight() -> void:
	_fight_active = false
	for n in _active_gimmicks:
		if is_instance_valid(n):
			n.queue_free()
	_active_gimmicks.clear()
	_pull_zone = null
	if is_instance_valid(_boss_guide):
		_boss_guide.target = null
	if is_instance_valid(_server_guide):
		_server_guide.target = null

func _on_boss_died() -> void:
	_end_fight()
	_show_victory()

# ─── Victory / transitions ───────────────────────────────────────────────────────

func _show_victory() -> void:
	if _transitioning:
		return
	_transitioning = true
	AudioManager.stop_ambience()
	AudioManager.play_music("victory")
	ProgressionManager.clear_stage("stage6")

	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.text = tr("The House is down.\nThe game was always rigged — and you walked away.\nNow help others do the same.")
	layer.add_child(label)

	await get_tree().create_timer(5.0).timeout
	_fade_then_load("res://scene/system/lobby_level.tscn")

func _on_stage_5_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning and not _started:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level5/stage5.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	# Delegate to the shared hardened loader (fixes the portal crash — see Global).
	await Global.load_scene_with_fade(scene_transition_anim, scene_path)
