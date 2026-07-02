extends CharacterBody2D

class_name FinalBossEnemy

# ─── Final Boss ─────────────────────────────────────────────────────────────────
# "The thing that runs it all." Fought in a shield/knockdown loop rather than a
# pure bullet-hell grind:
#
#   SHIELDED  — hovers, fires phase-appropriate bullets. Direct hits only chip the
#               shield (heavily reduced). Real progress comes from destroying the
#               scattered Servers (each removes a big chunk of shield).
#   DOWN      — shield broken → it crashes to the floor, stops firing, and is fully
#               vulnerable (melee AND arrows deal full HP damage). A moderate wave
#               of adds spawns. Lasts up to `down_time` seconds.
#   RECOVER   — the down ends (timeout, or the player knocks HP into the next
#               phase). Shield + servers are restored, adds cleared, and if the
#               phase advanced it emits `phase_changed` (Stage 6 layers a gimmick)
#               and the bullets step up. Then it rises and re-shields.
#
# HP has four phase quarters. Bullets are blocked by terrain (cover) and kept
# fair for a non-bullet-hell player.
# ───────────────────────────────────────────────────────────────────────────────

signal died
signal phase_changed(phase: int)
signal shield_changed(shield: float, shield_max: float)
signal hp_changed(hp: float, hp_max: float)

const BULLET := preload("res://scene/boss_bullet.tscn")
const SERVER := preload("res://scene/boss_server.tscn")
const ADD_SCENES := [
	preload("res://scene/bat_enemy.tscn"),
	preload("res://scene/frog_enemy.tscn"),
]

@export var health_max: float = 400.0
@export var shield_max: float = 75.0
@export var activation_x: float = 145.0
@export var down_time: float = 10.0
@export var server_shield_damage: float = 25.0
@export var shield_chip_mult: float = 0.15   # direct attacks to the shield reduced
@export var servers_per_cycle: int = 3

## Absolute world positions where servers may appear. Set by the stage so they're
## always reachable. If empty, a spread around the boss is used as a fallback.
var server_spots: Array = []

var health: float
var shield: float
var active := false
var dead := false
var phase := 0
var state := "shielded"       # "shielded" | "down"

var _down_left := 0.0
var _attack_accum := 0.0
var _spiral_accum := 0.0
var _spiral_angle := 0.0
var _bob := 0.0
var _base_y := 0.0
var _down_y := 0.0

var _servers: Array = []
var _adds: Array = []

@onready var _hud:          CanvasLayer = $HUD
@onready var _hp_bar:       ProgressBar = $HUD/HPBar
@onready var _shield_bar:   ProgressBar = $HUD/ShieldBar
@onready var _status_label: Label       = $HUD/StatusLabel
@onready var _core_inner:   Polygon2D   = $CoreInner
@onready var _muzzle:       Marker2D    = $Muzzle

func _ready() -> void:
	health = health_max
	shield = shield_max
	_base_y = position.y
	_down_y = position.y + 175.0
	_hp_bar.max_value = health_max
	_hp_bar.value = health
	_shield_bar.max_value = shield_max
	_shield_bar.value = shield
	_hud.visible = false
	$HitBox.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if dead:
		return

	# Core pulse (always) + hover bob (only while up/shielded)
	_bob += delta
	_core_inner.scale = Vector2.ONE * (1.0 + 0.08 * sin(_bob * 6.0))
	if state == "shielded":
		position.y = _base_y + sin(_bob * 2.0) * 4.0

	# Wake once the player is in the arena
	if not active:
		if is_instance_valid(Global.PlayerBody) and Global.PlayerBody.global_position.x >= activation_x:
			_activate()
		else:
			return

	if not Global.playerAlive:
		return

	match state:
		"shielded": _process_shielded(delta)
		"down":     _process_down(delta)

# ─── Activation ──────────────────────────────────────────────────────────────────

func _activate() -> void:
	active = true
	_hud.visible = true
	phase = 1
	phase_changed.emit(1)
	_spawn_servers()
	_update_status()

# ─── SHIELDED ────────────────────────────────────────────────────────────────────

func _process_shielded(delta: float) -> void:
	_attack_accum += delta
	if _attack_accum >= _attack_interval():
		_attack_accum = 0.0
		_do_attack()
	if phase >= 2:
		_spiral_accum += delta
		if _spiral_accum >= _spiral_interval():
			_spiral_accum = 0.0
			_spawn_bullet(Vector2.RIGHT.rotated(_spiral_angle), 90.0)
			_spiral_angle += deg_to_rad(_spiral_step())

# Called by a Server when it's destroyed by the player.
func on_server_destroyed() -> void:
	if dead or state != "shielded":
		return
	_servers = _servers.filter(func(s): return is_instance_valid(s))
	_reduce_shield(server_shield_damage)
	if state == "shielded":
		_update_status()

func _reduce_shield(amount: float) -> void:
	shield = max(0.0, shield - amount)
	_shield_bar.value = shield
	shield_changed.emit(shield, shield_max)
	if shield <= 0.0:
		_enter_down()

# ─── DOWN ────────────────────────────────────────────────────────────────────────

func _enter_down() -> void:
	state = "down"
	_clear_servers()
	_spawn_adds()
	_down_left = down_time
	# Crash to the floor — now reachable for melee
	var t := create_tween()
	t.tween_property(self, "position:y", _down_y, 0.4).set_ease(Tween.EASE_IN)
	_update_status()

func _process_down(delta: float) -> void:
	_down_left -= delta

	var target := _phase_for_health()
	if target > phase:
		_recover(target)          # player knocked it into a new phase
	elif _down_left <= 0.0:
		_recover(phase)           # timed out — gets back up, same phase
	else:
		_update_status()

func _recover(new_phase: int) -> void:
	_clear_adds()
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)  # Stage 6 layers this phase's gimmick
	shield = shield_max
	_shield_bar.value = shield
	shield_changed.emit(shield, shield_max)
	_spawn_servers()
	state = "shielded"
	var t := create_tween()
	t.tween_property(self, "position:y", _base_y, 0.4).set_ease(Tween.EASE_OUT)
	_update_status()

# ─── Servers / adds ──────────────────────────────────────────────────────────────

func _spawn_servers() -> void:
	var spots := _pick_spots(servers_per_cycle)
	for pos in spots:
		var s := SERVER.instantiate()
		s.global_position = pos
		if s.has_method("setup"):
			s.setup(self)
		get_parent().add_child(s)
		_servers.append(s)

func _pick_spots(n: int) -> Array:
	var pool: Array = server_spots.duplicate()
	if pool.is_empty():
		# Fallback: spread around the boss
		var bx := global_position.x
		pool = [
			Vector2(bx - 500, _down_y), Vector2(bx - 250, _base_y + 60),
			Vector2(bx, _down_y), Vector2(bx + 250, _base_y + 60),
			Vector2(bx + 500, _down_y),
		]
	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))

func _clear_servers() -> void:
	for s in _servers:
		if is_instance_valid(s):
			s.queue_free()
	_servers.clear()

func _spawn_adds() -> void:
	var count := clampi(phase, 1, 3)   # 1..3 adds, scaling with phase — moderate
	for i in count:
		var scene = ADD_SCENES[i % ADD_SCENES.size()]
		var e = scene.instantiate()
		e.global_position = global_position + Vector2(randf_range(-360, 360), -30)
		get_parent().add_child(e)
		e.add_to_group("enemies")
		_adds.append(e)

func _clear_adds() -> void:
	for e in _adds:
		if is_instance_valid(e):
			e.queue_free()
	_adds.clear()

# ─── Phase / cadence ─────────────────────────────────────────────────────────────

func _phase_for_health() -> int:
	var frac := health / health_max
	if frac <= 0.25: return 4
	elif frac <= 0.5: return 3
	elif frac <= 0.75: return 2
	return 1

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
	get_parent().add_child(b)

# ─── Damage / death ──────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if dead:
		return
	if state == "shielded":
		# Shield eats most of a direct hit — servers are the real answer
		_reduce_shield(amount * shield_chip_mult)
	else:
		health = max(0.0, health - amount)
		_hp_bar.value = health
		hp_changed.emit(health, health_max)
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
	_clear_servers()
	_clear_adds()
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	died.emit()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

# ─── HUD status ──────────────────────────────────────────────────────────────────

func _update_status() -> void:
	match state:
		"down":
			_status_label.text = "%s  %s: %d" % [tr("VULNERABLE"), tr("Recovers in"), ceil(_down_left)]
			_status_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		_:
			_status_label.text = "%s  —  %s: %d/%d" % [tr("SHIELDED"), tr("Servers"), _servers.size(), servers_per_cycle]
			_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1))
