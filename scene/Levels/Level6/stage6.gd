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

const GIMMICK_KINDS := ["bait", "debt", "pull", "falling"]

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM
@onready var close_door: StaticBody2D = $CloseDoor
@onready var boss:       FinalBossEnemy = $Boss

var _started := false
var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	SaveManager.autosave_on_enter()   # auto-save (after fade-in) on entering the stage
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	# Door starts open (passable) until the trap is sprung.
	close_door.visible = false
	$CloseDoor/CollisionShape2D.disabled = true
	$BossZone.body_entered.connect(_on_boss_zone_entered)
	# The boss is placed in the editor but dormant/hidden until the countdown ends.
	boss.visible = false
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(_on_boss_phase)

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
	label.add_theme_font_override("font", load("res://art/Fonts/skeleboom.ttf"))
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
	_gimmick_timer -= delta
	if _gimmick_timer <= 0.0:
		_spawn_gimmick_wave()
		_gimmick_timer = lerpf(5.0, 1.5, _intensity())   # faster waves at low HP

# A phase change also fires an immediate wave for a spike of pressure.
func _on_boss_phase(_p: int) -> void:
	if _fight_active:
		_spawn_gimmick_wave()

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

# Stage 2 — glowing false footing with a coin lure, a couple at random spots.
func _g_bait() -> void:
	for i in 2:
		var x := randf_range(500.0, 1900.0)
		var y := randf_range(430.0, 520.0)
		var b := BAIT_SCENE.instantiate()
		b.position = Vector2(x, y)
		_add_gimmick(b, 10.0)
		var c := COIN_SCENE.instantiate()
		c.position = Vector2(x, y - 28.0)
		_add_gimmick(c, 10.0)

# Stage 3 — a debt wall sweeping across (faster the more hurt the boss is).
func _g_debt() -> void:
	var w := DEBT_WALL.instantiate()
	w.position = Vector2(-120.0, randf_range(300.0, 460.0))
	w.speed = lerpf(60.0, 130.0, _intensity())
	w.damage = 16
	w.loop = true
	_add_gimmick(w, 9.0)

# Stage 4 — the pull wall, now MOVING: it sweeps back and forth across the arena
# while dragging the player, instead of sitting in one place. Only one at a time
# (the player has a single external_push slot).
func _g_pull() -> void:
	if is_instance_valid(_pull_zone):
		return
	var z := PULL_ZONE.instantiate()
	var start_x := randf_range(700.0, 1700.0)
	z.position = Vector2(start_x, 600.0)
	z.pull = Vector2(randf_range(70.0, 110.0) * (1.0 if randf() < 0.5 else -1.0), 0.0)
	_add_gimmick(z, 9.0)
	_pull_zone = z
	# Sweep the wall across the arena and back, faster at low HP. Bound to the node
	# so the tween dies with it.
	var leg := lerpf(2.6, 1.3, _intensity())
	var t := z.create_tween().set_loops()
	t.tween_property(z, "position:x", clampf(start_x + 650.0, 300.0, 2100.0), leg)
	t.tween_property(z, "position:x", clampf(start_x - 650.0, 300.0, 2100.0), leg)

# Stage 5 — crumbling perches under random footing.
func _g_falling() -> void:
	for i in 3:
		var fp := FALLING_PLAT.instantiate()
		fp.position = Vector2(randf_range(500.0, 1900.0), randf_range(480.0, 545.0))
		_add_gimmick(fp, 8.0)

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

func _on_boss_died() -> void:
	_end_fight()
	_show_victory()

# ─── Victory / transitions ───────────────────────────────────────────────────────

func _show_victory() -> void:
	if _transitioning:
		return
	_transitioning = true
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
	label.add_theme_font_override("font", load("res://art/Fonts/skeleboom.ttf"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.text = tr("The House is down.\nThe game was always rigged — and you walked away.\nNow help others do the same.")
	layer.add_child(label)

	await get_tree().create_timer(5.0).timeout
	_fade_then_load("res://scene/ui/main_menu.tscn")

func _on_stage_5_portal_body_entered(body: Node2D) -> void:
	if body is Player and not _transitioning and not _started:
		_transitioning = true
		_fade_then_load("res://scene/Levels/Level5/stage5.tscn")

func _fade_then_load(scene_path: String) -> void:
	audio_bgm.stop()
	ResourceLoader.load_threaded_request(scene_path)
	scene_transition_anim.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	var packed: PackedScene
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(scene_path)
	else:
		packed = load(scene_path)
	get_tree().change_scene_to_packed(packed)
