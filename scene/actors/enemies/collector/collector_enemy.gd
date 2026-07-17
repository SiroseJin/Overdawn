extends CharacterBody2D

class_name CollectorEnemy

# ─── Witch Enemy ───────────────────────────────────────────────────────────────
# Ranged mini-boss with a floaty hover movement. She is affected by a very weak
# gravity and bobs up and down slowly, giving the impression of levitation.
# Fires fireballs at the player after a charge wind-up.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Stats ─────────────────────────────────────────────────────────────────────

var speed: float        = 40
var health: float       = 80
var health_max: float   = 80
var damage_to_deal: int = 20
var exp_value: int      = 20
var score_value: int    = 40

# Floaty movement — very weak gravity so she drifts rather than falls
const GRAVITY: float        = 480.0   # Floaty, but ~60% less than before (was 120; she sinks more now)
const MAX_FALL_SPEED: float = 70.0    # Terminal velocity — falls noticeably faster than before
const HOVER_FORCE: float    = -20.0   # Weaker upward hover nudge, so she drifts down more
const HOVER_INTERVAL: float = 2    # Seconds between hover nudges

var hover_timer: float = 0.0

# ─── State ─────────────────────────────────────────────────────────────────────

var dir: Vector2            # Horizontal movement direction
var dead: bool              = false
var taking_damage: bool     = false
var is_dealing_damage: bool = false
var is_witch_chase: bool    = false
var is_witch_roaming: bool  = false

# Detection zones / roaming. Two coexisting, editor-resizable trigger circles:
#   • DetectionZone (big)  → the player is close enough to engage / wind up the ranged
#                            attack. Resize its CircleShape2D to change ranged reach.
#   • MeleeZone     (small)→ the player is close enough that she drops the ranged
#                            charge and rushes in for a melee hit instead.
var player_in_range: bool = false
var player_in_melee: bool = false
var spawn_position: Vector2
var roam_target_x: float
var roam_range: float = 80.0

# Charge state: witch slows down then fires after the timer elapses
var charging: bool = false
var charging_timer: Timer

# Charge telegraph: a glowing orb gathers at her hands and swells while she winds up,
# then vanishes the moment the fireball launches.
@export var charge_fx_color: Color = Color(0.5, 0.75, 1.0)   # bluish glow, matches the blue fireball
## The orb halo is kept ~5% bigger than the blinking fake coin. If padding makes it
## read too big/small, tune this "fill" fraction (how much of the 75px frame the glow uses).
@export var charge_orb_fill: float = 0.7
var _charge_fx: Node2D
var _charge_coin: Node2D
var _charge_elapsed: float = 0.0

const _CHARGE_COIN := preload("res://scene/actors/enemies/charge_coin.tscn")
const _FAKE_COIN_PROJECTILE := preload("res://scene/actors/enemies/fake_coin_projectile.tscn")

var Player: CharacterBody2D
var health_bar: ProgressBar

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.apply_enemy_scaling(self)   # story-mode level scaling (#6)
	is_dealing_damage = false
	taking_damage     = false
	charging          = false

	charging_timer           = Timer.new()
	charging_timer.wait_time = 5.0
	charging_timer.one_shot  = true
	charging_timer.connect("timeout", Callable(self, "_on_charging_timeout"))
	add_child(charging_timer)

	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

	spawn_position   = position
	roam_target_x    = position.x
	$Timer.wait_time = 2.5

func _process(_delta):
	move(_delta)
	handle_animation()
	_update_charge_fx(_delta)

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.collectorDamageAmount = damage_to_deal
	Global.witchDamageZone    = $WitchDealDamageArea

	if not Global.playerAlive:
		is_witch_chase   = false
		is_witch_roaming = false
	elif Global.arcade_mode or (player_in_range and has_line_of_sight_to_player()):
		is_witch_chase   = true
		is_witch_roaming = false
		Player = Global.PlayerBody

		# Coexisting states: far (inside DetectionZone, outside MeleeZone) → wind up and
		# fire the ranged attack while drifting closer; close (inside MeleeZone) → drop
		# the charge and rush in for a melee hit.
		if player_in_melee:
			charging = false
			charging_timer.stop()
		else:
			charge()
	else:
		is_witch_chase   = false
		is_witch_roaming = true

# ───────────────────────────────────────────────────────────────────────────────
# Movement
# ───────────────────────────────────────────────────────────────────────────────

func move(delta):
	if not dead and _knockback_active():
		return
	if dead:
		# On death let her fall normally (use standard gravity)
		velocity.y = min(velocity.y + 900.0 * delta, 800.0)
		velocity.x = 0
		move_and_slide()
		return

	# ── Floaty vertical movement ──────────────────────────────────────────────
	# Apply weak gravity so she gently sinks between hover nudges
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	# Periodic upward nudge creates the bobbing hover effect
	hover_timer += delta
	if hover_timer >= HOVER_INTERVAL:
		velocity.y  = HOVER_FORCE
		hover_timer = 0.0

	# ── Horizontal chasing ────────────────────────────────────────────────────
	if not taking_damage and is_witch_chase and Global.playerAlive and is_instance_valid(Global.PlayerBody):
		Player = Global.PlayerBody
		var move_speed = speed / 2.0 if charging else speed
		var chase_dir  = sign(Player.position.x - position.x)
		velocity.x     = chase_dir * move_speed
		dir.x          = chase_dir

	elif taking_damage and is_witch_chase and is_instance_valid(Global.PlayerBody):
		velocity.x = sign(position.x - Global.PlayerBody.position.x) * 60

	elif not taking_damage and is_witch_roaming:
		# Drift horizontally toward the current roam target at 30% speed
		var dist = roam_target_x - position.x
		if abs(dist) > 5.0:
			velocity.x = sign(dist) * speed * 0.3
			dir.x      = sign(velocity.x)
		else:
			velocity.x = 0

	else:
		velocity.x = 0

	move_and_slide()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

func handle_animation():
	var sprite = $AnimatedSprite2D

	if not dead and not taking_damage and not is_dealing_damage:
		if charging:
			sprite.play("charge")
		elif is_witch_chase:
			sprite.play("run")
		else:
			sprite.play("idle")

		var facing_left = (is_witch_chase and Player and Player.position.x < position.x) \
			or (is_witch_roaming and dir.x == -1)
		if facing_left:
			sprite.flip_h                = true
			$ProjectileOutput.position.x = -12
		else:
			sprite.flip_h                = false
			$ProjectileOutput.position.x = 12

	elif not dead and is_dealing_damage:
		sprite.play("attack")

	elif not dead and taking_damage:
		sprite.play("hurt")
		await get_tree().create_timer(0.7).timeout
		taking_damage = false

	elif dead:
		$CollisionShape2D.disabled                     = true
		$WitchDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled              = true
		charging         = false
		is_witch_roaming = false
		sprite.play("death")
		await get_tree().create_timer(2.7).timeout
		handle_death()

# ───────────────────────────────────────────────────────────────────────────────
# Combat
# ───────────────────────────────────────────────────────────────────────────────

func charge():
	if not charging and not dead:
		charging = true
		charging_timer.start()   # the swelling telegraph orb is driven by _update_charge_fx
	elif dead:
		charging = false
		charging_timer.stop()

# ─── Charge telegraph ────────────────────────────────────────────────────────────
# Where the orb / fireball leaves her: forward toward the player and up at hand height.
func _muzzle_pos() -> Vector2:
	var facing := 1.0
	var p = Global.PlayerBody
	if is_instance_valid(p):
		facing = 1.0 if p.global_position.x >= global_position.x else -1.0
	elif dir.x != 0.0:
		facing = signf(dir.x)
	return global_position + Vector2(facing * 20.0, -26.0)

# While she charges: a blinking fake coin gathers at her hands (the telegraph that a
# rigged jackpot is coming), with the orb glow kept just ~5% bigger, blinking, and sat
# BEHIND the coin. Cleared the instant the throw releases.
func _update_charge_fx(delta: float) -> void:
	if charging and not dead:
		var muzzle := _muzzle_pos()
		# Blinking fake coin, in front.
		if not is_instance_valid(_charge_coin):
			_charge_coin = _CHARGE_COIN.instantiate()
			get_parent().add_child(_charge_coin)
			_charge_coin.z_index = 3
		_charge_coin.global_position = muzzle
		# Orb halo, behind the coin, ~5% bigger, blinking.
		if not is_instance_valid(_charge_fx):
			_charge_fx = Global.spawn_fx("orb", muzzle, 0.2, charge_fx_color, true)
			_charge_elapsed = 0.0
			if is_instance_valid(_charge_fx):
				_charge_fx.z_index = 1   # behind the coin
		if is_instance_valid(_charge_fx):
			_charge_elapsed += delta
			_charge_fx.global_position = muzzle
			var orb_s := _orb_scale_for_coin()
			_charge_fx.scale = Vector2(orb_s, orb_s)
			# Blink the glow (alpha pulse), keeping the tint.
			var a: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_charge_elapsed * 30.0))
			_charge_fx.modulate = Color(charge_fx_color.r, charge_fx_color.g, charge_fx_color.b, a)
	else:
		_clear_charge_fx()

# Orb scale so the visible glow is ~5% wider than the fake coin (orb frame = 75px).
func _orb_scale_for_coin() -> float:
	var coin_w := 22.0
	if is_instance_valid(_charge_coin) and _charge_coin is Sprite2D and (_charge_coin as Sprite2D).texture:
		coin_w = (_charge_coin as Sprite2D).texture.get_width() * (_charge_coin as Sprite2D).scale.x
	return clampf(coin_w * 1.05 / (75.0 * max(0.1, charge_orb_fill)), 0.05, 1.5)

func _clear_charge_fx() -> void:
	if is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null
	if is_instance_valid(_charge_coin):
		_charge_coin.queue_free()
	_charge_coin = null

func _exit_tree() -> void:
	_clear_charge_fx()

func _on_charging_timeout():
	if dead:
		return
	is_dealing_damage = true
	await get_tree().create_timer(0.4).timeout
	release_fireball()
	is_dealing_damage = false
	charging          = false

func release_fireball():
	if dead:
		return
	# The charge timer can fire before a chase state assigned Player — resolve it
	# now and bail if there's genuinely no player to aim at.
	var target = Player if is_instance_valid(Player) else Global.PlayerBody
	if not is_instance_valid(target):
		return
	# Spawn from the witch's hands (same point the charge orb gathered): lifted above
	# her feet and pushed forward toward the player, so it never appears at ground level.
	var muzzle := _muzzle_pos()
	var fireball_scene = preload("res://scene/actors/enemies/collector/collector_fireball.tscn")
	var fireball       = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = muzzle
	fireball.direction = (target.global_position - muzzle).normalized()

	# She also hurls the rigged fake coin she was charging.
	_throw_fake_coin(muzzle, target)

# Fling a fake-coin projectile from `from` toward `target`.
func _throw_fake_coin(from: Vector2, target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var fc = _FAKE_COIN_PROJECTILE.instantiate()
	get_parent().add_child(fc)
	fc.global_position = from
	fc.direction = (target.global_position - from).normalized()

func take_damage(amount: float):
	health        -= amount
	taking_damage  = true
	Global.spawn_damage_number(global_position + Vector2(0, -22), int(amount))
	if health <= 0:
		health = 0
		dead   = true
		charging_timer.stop()
	health_bar.value = health
	if not dead:
		_hit_knockback()

# ─── Hit reaction (knockback + red flash) ────────────────────────────────────────
const KB_SPEED: float = 230.0
const KB_TIME: float  = 0.15
var _kb_vel: Vector2 = Vector2.ZERO
var _kb_time: float  = 0.0
var _hit_tween: Tween

# While knocked back, override the AI: ride the impulse and let it decay.
func _knockback_active() -> bool:
	if _kb_time <= 0.0:
		return false
	var d := get_process_delta_time()
	_kb_time -= d
	velocity = _kb_vel
	move_and_slide()
	_kb_vel = _kb_vel.move_toward(Vector2.ZERO, 1100.0 * d)
	return true

# Fling away from the player and flash red — called on a non-fatal hit.
func _hit_knockback() -> void:
	var dir := Vector2(1, 0)
	var p = Global.PlayerBody
	if is_instance_valid(p):
		dir = (global_position - p.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(1, 0)
	_kb_vel  = dir * KB_SPEED + Vector2(0, -70)
	_kb_time = KB_TIME
	_flash_red()

func _flash_red() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(1.0, 0.3, 0.3)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func handle_death():
	if Global.PlayerBody:
		Global.PlayerBody.gain_exp(exp_value)
		Global.PlayerBody.gain_score(score_value)
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

func has_line_of_sight_to_player() -> bool:
	if not Global.PlayerBody:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, Global.PlayerBody.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == Global.PlayerBody

func _on_timer_timeout():
	# Pick a new random horizontal roam target within roam_range of spawn position
	roam_target_x = spawn_position.x + randf_range(-roam_range, roam_range)

func _on_detection_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = true

func _on_detection_zone_body_exited(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = false

func _on_melee_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_melee = true

func _on_melee_zone_body_exited(body: Node2D):
	if body == Global.PlayerBody:
		player_in_melee = false

func _on_hit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

func _on_witch_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_witch_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false
