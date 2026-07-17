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

const BULLET := preload("res://scene/actors/enemies/finalboss/boss_bullet.tscn")
const SERVER := preload("res://scene/actors/enemies/finalboss/boss_server.tscn")
# Adds scale with how hurt the boss is: weak fodder early, tougher foes as HP drops.
const WEAK_ADDS := [
	preload("res://scene/actors/enemies/adbot/adbot_enemy.tscn"),
	preload("res://scene/actors/enemies/bandit/bandit_enemy.tscn"),
]
const TOUGH_ADDS := [
	preload("res://scene/actors/enemies/collector/collector_enemy.tscn"),
	preload("res://scene/actors/enemies/dealer/dealer_enemy.tscn"),
]

# Pickup drops. GOOD are rewards; the shield-break gamble can also roll a fake_coin.
const PU_COIN   := preload("res://scene/pickups/coin/coin.tscn")
const PU_HEALTH := preload("res://scene/pickups/health_pickup/health_pickup.tscn")
const PU_SPEED  := preload("res://scene/pickups/speed_pickup/speed_pickup.tscn")
const PU_FAKE   := preload("res://scene/pickups/fake_coin/fake_coin.tscn")
const GOOD_PICKUPS := [PU_COIN, PU_HEALTH, PU_SPEED]
const GAMBLE_PICKUPS := [PU_COIN, PU_HEALTH, PU_SPEED, PU_FAKE]   # may include a fake

const VFX_BURST  := preload("res://scene/system/vfx/vfx_burst.tscn")
const VFX_SHIELD := preload("res://scene/system/vfx/boss_shield.tscn")
# The House throws the ultimate rigged jackpot — the same fake coin its dealers use.
const FAKE_COIN_PROJECTILE := preload("res://scene/actors/enemies/fake_coin_projectile.tscn")

@export var health_max: float = 400.0
@export var shield_max: float = 75.0
@export var activation_x: float = 145.0
@export var down_time: float = 10.0
## Grace period after the boss re-shields and heaves back up before it may fire again.
## Stops it from instantly bursting a player who was meleeing it while it was down.
@export var recover_attack_delay: float = 1.4
## How long the slow "getting back up" rise takes (seconds). Higher = weightier.
@export var rise_time: float = 1.2
## Chance, per shielded attack, that the boss also hurls a rigged fake-coin projectile.
@export var fake_coin_chance: float = 0.25
@export var server_shield_damage: float = 25.0   # each destroyed server chips this off the shield
@export var shield_chip_mult: float = 0.15   # direct attacks to the shield reduced
@export var servers_per_cycle: int = 4        # how many of the spawn points are used each cycle

## Servers spawn at nodes in this group (place Marker2D/Node2D spawn points in the
## stage and add them to it — move them freely in the editor). Only `servers_per_cycle`
## of them are picked at random each cycle.
@export var server_spawn_group: StringName = &"server_spawn"

## Optional: when true the boss stays dormant/hidden until summon() is called
## (Stage 6 does this after its countdown) instead of auto-waking at activation_x.
@export var wait_for_summon: bool = false

## Slow circular drift (radius in px, speed in rad/s). This is the "loose hover"
## wobble — it rides on top of the path so the boss is never exactly on the line.
## Set radius 0 to sit dead-centre.
@export var orbit_radius: float = 45.0
@export var orbit_speed: float = 1.6

## When on, the boss loosely patrols back and forth along a Path2D (edit its curve
## in the editor — add/drag as many points as you like). When off, there's no path
## and it just hovers in place.
@export var use_path: bool = false
## NodePath to the Path2D to follow (e.g. a "BossPath" node placed in the stage).
@export var path_node: NodePath
## How fast the hover centre travels along the path, in px/s.
@export var path_speed: float = 60.0

## Steer around nodes in the `avoid_group` instead of phasing through them (used by
## arcade so the boss goes around platforms). Off by default so it doesn't change
## the story fights.
@export var avoid_platforms: bool = false
@export var avoid_group: StringName = &"arena_platform"

## Fallback absolute positions if no spawn-point nodes are found in the group.
var server_spots: Array = []

var _avoid_shape: CircleShape2D
var _avoid_params: PhysicsShapeQueryParameters2D

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
var _base_x := 0.0
var _base_y := 0.0
var _down_y := 0.0
var _down_x := 0.0        # column the boss crashes straight down in (wherever it was)
var _down_amount := 0.0   # 0 = hovering, 1 = crashed to the floor; tweened crash/rise
var _shield_grace := 0.0  # post-recovery seconds during which the boss holds its fire
var _path: Path2D = null
var _path_offset := 0.0   # distance travelled along the path
var _path_dir := 1.0      # +1 / -1 for back-and-forth patrol
var _wob_phase := 0.0     # accumulated wobble phase (speed varies, so integrate it)
var _jitter := Vector2.ZERO        # current erratic offset
var _jitter_target := Vector2.ZERO # where the jitter is easing toward
var _jitter_timer := 0.0

var _servers: Array = []
var _adds: Array = []
var _shield_fx: Node2D = null   # electric-shield VFX, follows the boss while shielded

@onready var _hud:          CanvasLayer = $HUD
@onready var _hp_bar:       ProgressBar = $HUD/HPBar
@onready var _shield_bar:   ProgressBar = $HUD/ShieldBar
@onready var _status_label: Label       = $HUD/StatusLabel
@onready var _core_inner:   Polygon2D   = $CoreInner
@onready var _muzzle:       Marker2D    = $Muzzle
@onready var _body_collision: CollisionShape2D = $BodyCollision

func _ready() -> void:
	Global.apply_enemy_scaling(self)   # story-mode level scaling (#6)
	health = health_max
	shield = shield_max
	_base_x = position.x
	_base_y = position.y
	_down_x = position.x
	_down_y = position.y + 175.0
	if not path_node.is_empty():
		_path = get_node_or_null(path_node) as Path2D
	if avoid_platforms:
		_avoid_shape = CircleShape2D.new()
		_avoid_shape.radius = 46.0
		_avoid_params = PhysicsShapeQueryParameters2D.new()
		_avoid_params.shape = _avoid_shape
		_avoid_params.collision_mask = 1          # platforms live on layer 1
		_avoid_params.collide_with_bodies = true
		_avoid_params.collide_with_areas = false
	_hp_bar.max_value = health_max
	_hp_bar.value = health
	_shield_bar.max_value = shield_max
	_shield_bar.value = shield
	_hud.visible = false
	$HitBox.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if dead:
		return

	# Core pulse (always)
	_bob += delta
	_core_inner.scale = Vector2.ONE * (1.0 + 0.08 * sin(_bob * 6.0))

	# Wake once the player is in the arena (unless the stage drives summon() itself)
	if not active:
		if not wait_for_summon and is_instance_valid(Global.PlayerBody) \
				and Global.PlayerBody.global_position.x >= activation_x:
			_activate()
		else:
			return

	if not Global.playerAlive:
		return

	# Everything ramps with how hurt the boss is: the lower its HP, the faster and
	# more erratic it moves.
	var intensity := _intensity()

	# Hover centre: travel loosely along the path (faster at low HP) or stay put.
	if _has_path() and state == "shielded":
		_advance_path(delta, 1.0 + intensity * 1.6)
	var hover_centre := _path_point() if _has_path() else Vector2(_base_x, _base_y)

	# Loose circular wobble — faster and a touch wider as HP drops. Integrate the
	# phase so changing speed doesn't snap it.
	_wob_phase += delta * orbit_speed * (1.0 + intensity * 1.6)
	var wob_r := orbit_radius * (1.0 + intensity * 0.5)
	var wobble := Vector2(cos(_wob_phase), sin(_wob_phase)) * wob_r

	# Erratic darting — grows with intensity, retargets faster when badly hurt.
	_update_jitter(delta, intensity)

	# Blend toward a straight crash-down column while downed (0 = hover, 1 = floor).
	# _process is the ONLY writer of position — the crash/rise just tweens _down_amount.
	var target := (hover_centre + wobble + _jitter).lerp(Vector2(_down_x, _down_y), _down_amount)
	# Steer around platforms rather than phasing through them (arcade). Skipped while
	# crashing down so it can still reach the floor.
	if avoid_platforms and _down_amount < 0.4:
		target = _steer_around_platforms(target)
	position = target

	match state:
		"shielded": _process_shielded(delta)
		"down":     _process_down(delta)

# ─── Activation ──────────────────────────────────────────────────────────────────

## Externally summon the boss (used when it's placed in the editor and revealed
## after a countdown). Reveals it if it was hidden, then activates.
func summon() -> void:
	if active or dead:
		return
	visible = true
	_activate()

func _activate() -> void:
	active = true
	visible = true
	# Enter the path at the nearest point so it eases in instead of snapping to start.
	if _has_path():
		_path_offset = _path.curve.get_closest_offset(_path.to_local(global_position))
	# Become a solid, standable object now that the fight has begun (kept disabled
	# beforehand so a dormant/hidden boss isn't an invisible wall).
	_body_collision.set_deferred("disabled", false)
	_hud.visible = true
	phase = 1
	phase_changed.emit(1)
	_spawn_servers()
	_show_shield()
	_update_status()

# ─── SHIELDED ────────────────────────────────────────────────────────────────────

func _process_shielded(delta: float) -> void:
	# Hold fire briefly after getting back up, so the boss can't instantly burst a
	# player who was meleeing it while it was down.
	if _shield_grace > 0.0:
		_shield_grace -= delta
		return
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

# Called by a Server when it's destroyed by the player (passes where it died).
func on_server_destroyed(at: Vector2) -> void:
	if dead or state != "shielded":
		return
	_servers = _servers.filter(func(s): return is_instance_valid(s))
	_spawn_burst(at, 0.7)   # server pops
	# Reward for taking down a server: 1–2 random GOOD pickups where it stood.
	for i in randi_range(1, 2):
		_drop(GOOD_PICKUPS.pick_random(), at + Vector2(randf_range(-24, 24), randf_range(-22, -4)))
	_reduce_shield(server_shield_damage)   # may break the shield → _enter_down drops more
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
	_hide_shield()
	_spawn_burst(global_position, 1.6)   # shield shatters as it crashes
	_clear_servers()
	_spawn_adds()
	_down_left = down_time
	# Crash straight down from wherever it currently is — now reachable for melee.
	_down_x = position.x
	var t := create_tween()
	t.tween_property(self, "_down_amount", 1.0, 0.4).set_ease(Tween.EASE_IN)
	# Shield broken: a GUARANTEED health pickup near the boss, plus a gamble of 1–2
	# more that may include a fake (a last "free bonus?" temptation at the payoff).
	var landing := Vector2(_down_x, _down_y)
	_drop(PU_HEALTH, landing + Vector2(randf_range(-28, 28), -10))
	for i in randi_range(1, 2):
		_drop(GAMBLE_PICKUPS.pick_random(), landing + Vector2(randf_range(-100, 100), -10))
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
	# NOTE: adds spawned during the down phase are intentionally NOT cleared here —
	# they stick around and keep pressuring the player after the boss rises. They're
	# only cleared when the boss finally dies (_die).
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)  # Stage 6 layers this phase's gimmick
	shield = shield_max
	_shield_bar.value = shield
	shield_changed.emit(shield, shield_max)
	_spawn_servers()
	_show_shield()
	state = "shielded"
	# Hold fire for a moment and reset the attack cadence, so it doesn't fire the instant
	# it's back up.
	_shield_grace = recover_attack_delay
	_attack_accum = 0.0
	_spiral_accum = 0.0
	# Slow, weighty "getting back up": a brief anticipation, then a long eased rise
	# (instead of the old near-instant snap).
	var t := create_tween()
	t.tween_interval(0.15)
	t.tween_property(self, "_down_amount", 0.0, rise_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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

# Nudge a target position out of / away from any nearby platform (nodes in
# `avoid_group`) so the boss goes around them instead of phasing through.
func _steer_around_platforms(target: Vector2) -> Vector2:
	if _avoid_params == null:
		return target
	_avoid_params.transform = Transform2D(0.0, target)
	var hits := get_world_2d().direct_space_state.intersect_shape(_avoid_params, 6)
	if hits.is_empty():
		return target
	var push := Vector2.ZERO
	var reach := _avoid_shape.radius + 24.0
	for h in hits:
		var col = h.get("collider")
		if col == null or not (col is Node2D) or not col.is_in_group(avoid_group):
			continue
		var away: Vector2 = target - col.global_position
		var d := away.length()
		if d < 0.01:
			away = Vector2.UP
			d = 0.01
		push += away.normalized() * (reach - minf(d, reach))
	return target + push

# ─── Intensity (0 at full HP → 1 near death) ──────────────────────────────────────

func _intensity() -> float:
	if health_max <= 0.0:
		return 0.0
	return clampf(1.0 - health / health_max, 0.0, 1.0)

# Ease an erratic offset toward a random target that grows and retargets faster
# the more hurt the boss is.
func _update_jitter(delta: float, intensity: float) -> void:
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		var amp := intensity * 75.0
		_jitter_target = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		_jitter_timer = lerpf(0.7, 0.18, intensity)
	_jitter = _jitter.lerp(_jitter_target, clampf(delta * lerpf(3.0, 10.0, intensity), 0.0, 1.0))

# ─── Pickup drops ────────────────────────────────────────────────────────────────

# Spawn a pickup into the arena at a world position. Deferred add_child because
# these fire from physics callbacks (a server destroyed by an arrow/melee).
func _drop(scene: PackedScene, world_pos: Vector2) -> void:
	var p := scene.instantiate()
	p.position = get_parent().to_local(world_pos)
	get_parent().call_deferred("add_child", p)

# ─── Path following ────────────────────────────────────────────────────────────

func _has_path() -> bool:
	return use_path and is_instance_valid(_path) and _path.curve != null \
		and _path.curve.get_baked_length() > 0.0

# Move the hover centre back and forth along the path (ping-pong between its ends).
func _advance_path(delta: float, speed_mult: float = 1.0) -> void:
	var length := _path.curve.get_baked_length()
	_path_offset += _path_dir * path_speed * speed_mult * delta
	if _path_offset >= length:
		_path_offset = length
		_path_dir = -1.0
	elif _path_offset <= 0.0:
		_path_offset = 0.0
		_path_dir = 1.0

# The current point on the path, in world space.
func _path_point() -> Vector2:
	return _path.to_global(_path.curve.sample_baked(_path_offset))

func _pick_spots(n: int) -> Array:
	var pool: Array = _gather_spots()
	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))

# Collect server spawn positions, preferring placed spawn-point nodes (movable in
# the editor) → the server_spots fallback array → a spread around the boss.
func _gather_spots() -> Array:
	var pool: Array = []
	for node in get_tree().get_nodes_in_group(server_spawn_group):
		if is_instance_valid(node) and node is Node2D:
			pool.append(node.global_position)
	if not pool.is_empty():
		return pool
	if not server_spots.is_empty():
		return server_spots.duplicate()
	# Last resort: spread around the boss
	var bx := global_position.x
	return [
		Vector2(bx - 500, _down_y), Vector2(bx - 250, _base_y + 60),
		Vector2(bx, _down_y), Vector2(bx + 250, _base_y + 60),
		Vector2(bx + 500, _down_y),
	]

func _clear_servers() -> void:
	for s in _servers:
		if is_instance_valid(s):
			s.queue_free()
	_servers.clear()

func _spawn_adds() -> void:
	var intensity := _intensity()
	var count := 2 + int(round(intensity * 4.0))   # 2 (full HP) → 6 (near death)
	for i in count:
		# Tougher foes become more likely as the boss weakens.
		var pool: Array = TOUGH_ADDS if randf() < intensity * 0.8 else WEAK_ADDS
		var e = pool.pick_random().instantiate()
		get_parent().add_child(e)
		e.global_position = global_position + Vector2(randf_range(-360, 360), randf_range(-40, 20))
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
	# Sometimes the House also flings a rigged "jackpot" fake coin at the player.
	if randf() < fake_coin_chance:
		_fire_fake_coin()

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

# Hurl a rigged fake-coin projectile toward the player (the House's "free jackpot").
func _fire_fake_coin() -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var fc := FAKE_COIN_PROJECTILE.instantiate()
	fc.global_position = _muzzle.global_position
	fc.direction = (Global.PlayerBody.global_position - _muzzle.global_position).normalized()
	get_parent().add_child(fc)

# ─── Damage / death ──────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if dead:
		return
	if state == "shielded":
		# Shield eats most of a direct hit — servers are the real answer
		_reduce_shield(amount * shield_chip_mult)
		_flash()
		Global.spawn_damage_number(global_position + Vector2(0, -34), int(amount * shield_chip_mult), Color(0.6, 0.8, 1.0))
	else:
		Global.spawn_damage_number(global_position + Vector2(0, -34), int(amount))
		health = max(0.0, health - amount)
		_hp_bar.value = health
		hp_changed.emit(health, health_max)
		_flash()
		if health <= 0.0:
			_die()

func _flash() -> void:
	modulate = Color(1.8, 0.4, 0.4)   # reddish "hit" flash
	await get_tree().create_timer(0.06).timeout
	if not dead:
		modulate = Color.WHITE

# ─── VFX ───────────────────────────────────────────────────────────────────────────

# One-shot explosion burst in world space (parented to the arena so it survives us).
func _spawn_burst(at: Vector2, size := 1.0) -> void:
	var fx := VFX_BURST.instantiate() as Node2D
	fx.global_position = at
	fx.scale *= size
	get_parent().add_child(fx)

func _show_shield() -> void:
	if _shield_fx == null:
		_shield_fx = VFX_SHIELD.instantiate() as Node2D
		add_child(_shield_fx)          # child of the boss → tracks its position
	_shield_fx.visible = true

func _hide_shield() -> void:
	if _shield_fx != null:
		_shield_fx.visible = false

func _die() -> void:
	dead = true
	ProgressionManager.notify("boss_defeated", {})   # UC-009/008: the House is beaten
	_hide_shield()
	_spawn_burst(global_position, 2.2)   # the House goes down
	_clear_servers()
	_clear_adds()
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	_body_collision.set_deferred("disabled", true)   # no more standing on the corpse
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
