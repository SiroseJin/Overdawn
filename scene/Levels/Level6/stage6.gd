extends Node2D

# ─── Stage 6 — The Core (Final Boss) ────────────────────────────────────────────
# The player walks in, and the moment they cross into the boss zone the door
# slams shut behind them. A 5-second countdown, then the boss is summoned. The
# arena keeps the previous mechanics in play — moving and falling platforms — so
# the fight is dodging bullets AND managing footing at once. Beating the boss
# ends the game.
# ───────────────────────────────────────────────────────────────────────────────

const BOSS_SCENE    := preload("res://scene/finalboss_enemy.tscn")
const BAIT_SCENE    := preload("res://scene/bait_platform.tscn")
const DEBT_WALL     := preload("res://scene/debt_wall.tscn")
const PULL_ZONE     := preload("res://scene/pull_zone.tscn")
const FALLING_PLAT  := preload("res://scene/falling_platform.tscn")
const COIN_SCENE    := preload("res://scene/coin.tscn")

# Active gimmick nodes for the current phase (removed when the next phase starts).
var _phase_transient: Array[Node] = []

@onready var scene_transition_anim: AnimationPlayer  = $SceneTransitionAnimation/AnimationPlayer
@onready var audio_bgm:             AudioStreamPlayer = $AudioBGM
@onready var close_door: StaticBody2D = $CloseDoor

var _started := false
var _transitioning := false

func _ready() -> void:
	Global.gameStarted = true
	scene_transition_anim.play("fade_out")
	audio_bgm.play()
	# Door starts open (passable) until the trap is sprung.
	close_door.visible = false
	$CloseDoor/CollisionShape2D.disabled = true
	$BossZone.body_entered.connect(_on_boss_zone_entered)

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
	_summon_boss()

func _summon_boss() -> void:
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector2(1400, 450)
	boss.activation_x = -100000.0   # already trapped in the arena — fight now
	# Server spawn spots — only on the floor and STATIC platforms, so servers are
	# always reachable no matter which moving/falling gimmick is active.
	boss.server_spots = [
		Vector2(400, 620), Vector2(625, 535), Vector2(1000, 620),
		Vector2(1400, 535), Vector2(1600, 620), Vector2(1825, 535),
		Vector2(2050, 620),
	]
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(_on_boss_phase)
	add_child(boss)

# ── Boss-phase gimmicks ─────────────────────────────────────────────────────────
# Each HP-quarter phase brings back one earlier stage's gimmick, so the whole
# game's lessons resurface in the final fight. The active/pressuring gimmicks
# (debt wall, pull zones) are cleared when the next phase begins so it never
# piles into an unfair wall of mechanics.
func _on_boss_phase(p: int) -> void:
	_clear_transient()
	match p:
		1: _phase_bait()      # Stage 2 — bait platforms (glowing false footing)
		2: _phase_debt()      # Stage 3 — a debt wall sweeps the arena
		3: _phase_pull()      # Stage 4 — the floor drags you toward the core
		4: _phase_falling()   # Stage 5 — perches crumble underfoot

func _clear_transient() -> void:
	for n in _phase_transient:
		if is_instance_valid(n):
			n.queue_free()
	_phase_transient.clear()

func _phase_bait() -> void:
	for pos in [Vector2(850, 470), Vector2(1950, 470)]:
		var b := BAIT_SCENE.instantiate()
		b.position = pos
		add_child(b)
		var c := COIN_SCENE.instantiate()
		c.position = pos + Vector2(0, -28)
		add_child(c)

func _phase_debt() -> void:
	var w := DEBT_WALL.instantiate()
	w.position = Vector2(-120, 400)
	w.speed = 70.0
	w.damage = 18
	w.loop = true
	add_child(w)
	_phase_transient.append(w)

func _phase_pull() -> void:
	var left := PULL_ZONE.instantiate()
	left.position = Vector2(760, 600)
	left.pull = Vector2(70, 0)          # pulls you right, toward the core
	add_child(left)
	_phase_transient.append(left)
	var right := PULL_ZONE.instantiate()
	right.position = Vector2(2040, 600)
	right.pull = Vector2(-70, 0)         # pulls you left, toward the core
	add_child(right)
	_phase_transient.append(right)

func _phase_falling() -> void:
	for pos in [Vector2(700, 520), Vector2(1400, 520), Vector2(2100, 520)]:
		var fp := FALLING_PLAT.instantiate()
		fp.position = pos
		add_child(fp)

func _on_boss_died() -> void:
	_clear_transient()
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
	label.text = tr("The system is down.\nYou made it out — now help others do the same.")
	layer.add_child(label)

	await get_tree().create_timer(5.0).timeout
	_fade_then_load("res://scene/main_menu.tscn")

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
