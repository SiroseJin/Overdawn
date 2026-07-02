extends CharacterBody2D

class_name FinalBoss

# ─── Final Boss ─────────────────────────────────────────────────────────────────
# The bullet-hell boss behind the Stage 5 gate — "the thing that runs it all"
# (the gambling system's core; the Necromancer was its earlier placeholder form).
#
# It hovers and cycles bullet patterns that escalate across four HP-quarter phases.
# Each phase also emits `phase_changed`, which Stage 6 uses to layer in one gimmick
# from an earlier stage (bait platforms, debt wall, pull zone, treacherous floor).
# The player dodges with dash/double-jump, blocks with the Firewall, and deals
# damage with arrows (ranged) or melee (risky, up close). Emits `died` when beaten.
#
# Combat wiring follows the game's convention (all combat areas on layer 1):
#   • HitBox (Area2D, layer 1) takes the player's melee zone + arrow raycasts.
#   • Bullets live on layer 2 so arrows don't collide with them.
# ───────────────────────────────────────────────────────────────────────────────

signal died
signal phase_changed(phase: int)   # 1..4 — Stage 6 layers a gimmick per phase

const BULLET := preload("res://scene/boss_bullet.tscn")

@export var health_max: float = 400.0
## The boss wakes once the player crosses this X (i.e. is past the sealed gate).
@export var activation_x: float = 145.0

var health: float
var active: bool = false
var dead: bool   = false
var phase: int   = 0   # 0 = not yet started; set to 1 on wake

var _attack_accum: float = 0.0
var _spiral_accum: float = 0.0
var _spiral_angle: float = 0.0
var _bob: float = 0.0
var _base_y: float = 0.0

@onready var _hud:        CanvasLayer = $HUD
@onready var _bar:        ProgressBar = $HUD/BossBar
@onready var _core_inner: Polygon2D   = $CoreInner
@onready var _muzzle:     Marker2D    = $Muzzle

func _ready() -> void:
	health = health_max
	_base_y = position.y
	_bar.max_value = health_max
	_bar.value = health
	_hud.visible = false
	$HitBox.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if dead:
		return

	# Idle hover + core pulse (purely visual)
	_bob += delta
	position.y = _base_y + sin(_bob * 2.0) * 4.0
	_core_inner.scale = Vector2.ONE * (1.0 + 0.08 * sin(_bob * 6.0))

	# Wake only when the player has entered the boss area (past the gate)
	if not active:
		if is_instance_valid(Global.PlayerBody) and Global.PlayerBody.global_position.x >= activation_x:
			active = true
			_hud.visible = true
			_set_phase(1)
		else:
			return

	if not Global.playerAlive:
		return

	_update_phase()

	# Main attack cadence
	_attack_accum += delta
	if _attack_accum >= _attack_interval():
		_attack_accum = 0.0
		_do_attack()

	# Continuous spiral from phase 2 onward (slow, so there's always a gap to slip)
	if phase >= 2:
		_spiral_accum += delta
		if _spiral_accum >= _spiral_interval():
			_spiral_accum = 0.0
			_spawn_bullet(Vector2.RIGHT.rotated(_spiral_angle), 90.0)
			_spiral_angle += deg_to_rad(_spiral_step())

# ─── Phase / cadence ─────────────────────────────────────────────────────────────
# Four phases by HP quarter. Each is telegraphed and only a step harder than the
# last — meant to be beatable by a careful non-bullet-hell player (dash to dodge,
# Firewall to eat a wave, platforms for cover).

func _update_phase() -> void:
	var frac := health / health_max
	var p := 1
	if frac <= 0.25:   p = 4
	elif frac <= 0.5:  p = 3
	elif frac <= 0.75: p = 2
	if p != phase:
		_set_phase(p)

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)

func _attack_interval() -> float:
	match phase:
		1:  return 2.2
		2:  return 1.8
		3:  return 1.5
		_:  return 1.2

func _spiral_interval() -> float:
	return 0.18 if phase == 2 else (0.15 if phase == 3 else 0.13)

func _spiral_step() -> float:
	return 32.0 if phase == 2 else (28.0 if phase == 3 else 25.0)

func _do_attack() -> void:
	match phase:
		1:
			# Read-and-dodge: a single telegraphed threat at a time
			if randf() < 0.5:
				_fire_aimed(3, 22.0, 120.0)
			else:
				_fire_ring(8, 85.0)
		2:
			_fire_ring(10, 95.0)
			_fire_aimed(3, 24.0, 130.0)
		3:
			_fire_ring(12, 100.0)
			_fire_aimed(4, 30.0, 135.0)
		_:
			_fire_ring(16, 110.0)
			_fire_aimed(5, 38.0, 140.0)

# ─── Bullet patterns ─────────────────────────────────────────────────────────────

func _fire_ring(count: int, speed: float) -> void:
	for i in count:
		_spawn_bullet(Vector2.RIGHT.rotated(TAU * i / count), speed)

func _fire_aimed(count: int, spread_deg: float, speed: float) -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var base := (Global.PlayerBody.global_position - _muzzle.global_position).angle()
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		_spawn_bullet(Vector2.RIGHT.rotated(base + deg_to_rad(spread_deg) * t), speed)

func _spawn_bullet(dir: Vector2, speed: float) -> void:
	var b := BULLET.instantiate()
	b.global_position = _muzzle.global_position
	b.direction = dir.normalized()
	b.speed = speed
	# Parent to the stage so bullets outlive/behave independently of the boss
	get_parent().add_child(b)

# ─── Damage / death ──────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if dead:
		return
	health = max(0.0, health - amount)
	_bar.value = health
	_flash()
	if health <= 0.0:
		_die()

func _flash() -> void:
	modulate = Color(1.7, 1.7, 1.7)
	await get_tree().create_timer(0.06).timeout
	if not dead:
		modulate = Color.WHITE

func _die() -> void:
	dead = true
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	died.emit()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Player melee zone landed a hit
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)
