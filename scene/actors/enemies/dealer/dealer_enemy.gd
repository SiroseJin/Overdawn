extends CharacterBody2D

class_name DealerEnemy

# ─── Necromancer Enemy ─────────────────────────────────────────────────────────
# The heaviest enemy. Walks along the ground and has two special abilities:
#   • Charge + Orb: winds up and fires a slow orb at the player.
#   • Summon: stops and spawns a pack of bats on a 15-second cooldown.
# Affected by gravity — falls and lands on platforms.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Stats ─────────────────────────────────────────────────────────────────────

var speed: float        = 50
var health: float       = 200
var health_max: float   = 200
var damage_to_deal: int = 30
var exp_value: int      = 80
var score_value: int    = 200

# Gravity
const GRAVITY: float        = 900.0
const MAX_FALL_SPEED: float = 800.0

# ─── State ─────────────────────────────────────────────────────────────────────

var dir: Vector2            # Horizontal movement direction, used for sprite flipping
var dead: bool              = false
var taking_damage: bool     = false
var is_dealing_damage: bool = false
var is_necro_chase: bool    = false
var is_necro_roaming: bool  = false

# Detection zone / roaming
var player_in_range: bool = false
var spawn_position: Vector2
var roam_direction: int = 1   # +1 = right, -1 = left
var roam_range: float = 50.0

# Charge ability (leads into the slow-orb projectile)
var charging: bool = false
var charging_timer: Timer

const _CHARGE_COIN := preload("res://scene/actors/enemies/charge_coin.tscn")
const _FAKE_COIN_PROJECTILE := preload("res://scene/actors/enemies/fake_coin_projectile.tscn")
var _charge_coin: Node2D   # blinking fake-coin telegraph shown while charging

# Summon ability (spawns bats)
var summoning: bool          = false
var can_summon: bool         = true
var summon_timer: Timer
var summon_cooldown_timer: Timer

var Player: CharacterBody2D
var health_bar: ProgressBar

# ── Attack pacing (anti-spam): min seconds between contact hits (#16). Editable. ──
@export var attack_cooldown: float = 0.9
var _atk_cd_remaining: float = 0.0

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.apply_enemy_scaling(self)   # story-mode level scaling (#6)
	ProgressionManager.notify("enemy_seen", {"type": "dealer"})   # unlocks its Guide entry
	is_necro_chase    = true
	taking_damage     = false
	charging          = false
	is_dealing_damage = false
	summoning         = false

	# Charge timer — fires the orb when it expires
	charging_timer           = Timer.new()
	charging_timer.wait_time = 3.0
	charging_timer.one_shot  = true
	charging_timer.connect("timeout", Callable(self, "_on_charging_timeout"))
	add_child(charging_timer)

	# Summon timer — actually spawns the bats when it expires
	summon_timer           = Timer.new()
	summon_timer.wait_time = 3.0
	summon_timer.one_shot  = true
	summon_timer.connect("timeout", Callable(self, "_on_summon_timeout"))
	add_child(summon_timer)

	# Cooldown before the necromancer can summon again
	summon_cooldown_timer           = Timer.new()
	summon_cooldown_timer.wait_time = 15.0
	summon_cooldown_timer.one_shot  = true
	summon_cooldown_timer.connect("timeout", Callable(self, "_on_summon_cooldown_timeout"))
	add_child(summon_cooldown_timer)

	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

	spawn_position   = position
	$Timer.wait_time = 4.0

func _process(_delta):
	move(_delta)
	handle_animation()
	_tick_attack(_delta)
	if not charging and is_instance_valid(_charge_coin):
		_clear_charge_coin()   # telegraph coin only shows during the wind-up

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.dealerDamageAmount = damage_to_deal
	Global.necroDamageZone    = $NecroDealDamageArea

	if not Global.playerAlive:
		is_necro_chase   = false
		is_necro_roaming = false
	elif Global.arcade_mode or (player_in_range and has_line_of_sight_to_player()):
		is_necro_chase   = true
		is_necro_roaming = false
		Player = Global.PlayerBody

		var dist = position.distance_to(Player.position)
		if dist >= 80 and can_summon:
			enter_summon_state()
		elif dist >= 120:
			charge()
		else:
			charging = false
			charging_timer.stop()
	else:
		is_necro_chase   = false
		is_necro_roaming = true

# ───────────────────────────────────────────────────────────────────────────────
# Movement
# ───────────────────────────────────────────────────────────────────────────────

func move(delta):
	if not dead and _knockback_active():
		return
	# Always apply gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0

	if dead:
		velocity.x = 0
		move_and_slide()
		return

	if summoning:
		# Stand completely still while summoning
		velocity.x = 0

	elif not taking_damage and is_necro_chase and Global.playerAlive and is_instance_valid(Global.PlayerBody):
		Player = Global.PlayerBody
		# Move at 1/5 speed while charging (winding up the orb shot)
		var move_speed = speed / 5.0 if charging else speed
		var chase_dir  = sign(Player.position.x - position.x)
		velocity.x     = chase_dir * move_speed
		dir.x          = chase_dir

	elif taking_damage and is_necro_chase and is_instance_valid(Global.PlayerBody):
		velocity.x = sign(position.x - Global.PlayerBody.position.x) * 30

	elif not taking_damage and is_necro_roaming:
		# Slow patrol back and forth within roam_range of spawn position
		if abs(position.x - spawn_position.x) >= roam_range:
			roam_direction *= -1
		velocity.x = roam_direction * speed * 0.2
		dir.x      = roam_direction

	else:
		velocity.x = 0

	move_and_slide()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

func handle_animation():
	var sprite = $AnimatedSprite2D
	var fvx    = $FVX

	if not dead and not taking_damage and not is_dealing_damage:
		if summoning:
			sprite.play("summon")
			fvx.play("summoning")
		elif charging:
			sprite.play("charge")
		elif is_necro_chase:
			sprite.play("run")
		elif is_necro_roaming:
			sprite.play("idle")

		# Flip sprite and reposition projectile origin to face movement direction
		var facing_left = (is_necro_chase and Player and Player.position.x < position.x) \
			or (is_necro_roaming and dir.x == -1)
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
		$NecroDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled              = true
		charging         = false
		is_necro_roaming = false
		sprite.play("death")
		await get_tree().create_timer(3.5).timeout
		handle_death()

# ───────────────────────────────────────────────────────────────────────────────
# Charge Ability (slow orb)
# ───────────────────────────────────────────────────────────────────────────────

func charge():
	if not charging and not dead:
		charging = true
		Global.spawn_fx("green", global_position, 0.3)   # gathering energy blast — telegraph
		_show_charge_coin()                              # + a blinking fake coin at his hand
		charging_timer.start()
	elif dead:
		charging = false
		charging_timer.stop()

# A blinking fake coin at the muzzle while he winds up (parented to ProjectileOutput so
# it follows and flips with facing). Freed once he stops charging (see _process).
func _show_charge_coin() -> void:
	if is_instance_valid(_charge_coin):
		return
	_charge_coin = _CHARGE_COIN.instantiate()
	var out := get_node_or_null("ProjectileOutput")
	if out:
		out.add_child(_charge_coin)
	else:
		add_child(_charge_coin)
	_charge_coin.z_index = 3

func _clear_charge_coin() -> void:
	if is_instance_valid(_charge_coin):
		_charge_coin.queue_free()
	_charge_coin = null

func _on_charging_timeout():
	if dead:
		return
	is_dealing_damage = true
	await get_tree().create_timer(0.4).timeout
	release_fireball()
	is_dealing_damage = false
	charging          = false

# Spawn a slow orb aimed at the player
func release_fireball():
	if dead:
		return
	# The charge timer can fire before a chase state assigned Player — resolve it
	# now and bail if there's genuinely no player to aim at.
	var target = Player if is_instance_valid(Player) else Global.PlayerBody
	if not is_instance_valid(target):
		return
	var orb_scene = preload("res://scene/actors/enemies/dealer/dealer_slow_orb.tscn")
	var orb       = orb_scene.instantiate()
	get_parent().add_child(orb)
	var from: Vector2 = $ProjectileOutput.global_position
	orb.global_position = from
	orb.direction = (target.global_position - from).normalized()

	# He also throws the rigged fake coin he was charging.
	var fc = _FAKE_COIN_PROJECTILE.instantiate()
	get_parent().add_child(fc)
	fc.global_position = from
	fc.direction = (target.global_position - from).normalized()

# ───────────────────────────────────────────────────────────────────────────────
# Summon Ability (bat pack)
# ───────────────────────────────────────────────────────────────────────────────

func enter_summon_state():
	if can_summon and not summoning:
		summoning  = true
		can_summon = false
		summon_timer.start()
		summon_cooldown_timer.start()

func _on_summon_timeout():
	if not dead:
		summon_bats()
	summoning = false

# Spawn 3–6 bats in a tight cluster around the necromancer
func summon_bats():
	var fvx       = $FVX
	var bat_scene = preload("res://scene/actors/enemies/adbot/adbot_enemy.tscn")
	if not bat_scene:
		return

	var num_bats = randi_range(3, 6)
	for i in range(num_bats):
		var bat = bat_scene.instantiate()
		fvx.play("summoned")
		get_parent().add_child(bat)
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		bat.global_position = position + offset

func _on_summon_cooldown_timeout():
	can_summon = true

# ───────────────────────────────────────────────────────────────────────────────
# Combat
# ───────────────────────────────────────────────────────────────────────────────

func take_damage(amount: float):
	health        -= amount
	taking_damage  = true
	Global.spawn_damage_number(global_position + Vector2(0, -22), int(amount))
	if health <= 0:
		health = 0
		dead   = true
		charging_timer.stop()
		summon_timer.stop()
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

# Slope-aware sight (walls block, walkable slopes don't) — shared in Global (#11).
func has_line_of_sight_to_player() -> bool:
	return Global.enemy_line_of_sight(self)

# Pace contact damage so the dealer can't spam-hit up close (#16). One hit lands,
# then the contact hitbox disarms for `attack_cooldown` before it can strike again.
func _tick_attack(delta: float) -> void:
	if dead:
		return
	var col: CollisionShape2D = $NecroDealDamageArea/CollisionShape2D
	if _atk_cd_remaining > 0.0:
		_atk_cd_remaining -= delta
		if _atk_cd_remaining <= 0.0 and is_instance_valid(col):
			col.set_deferred("disabled", false)
		return
	if is_instance_valid(Global.playerHitbox) and $NecroDealDamageArea.overlaps_area(Global.playerHitbox):
		_atk_cd_remaining = attack_cooldown
		if is_instance_valid(col):
			col.set_deferred("disabled", true)

func _on_timer_timeout():
	roam_direction *= -1

func _on_detection_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = true

func _on_detection_zone_body_exited(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = false

func _on_hit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

func _on_necro_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_necro_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false

# ───────────────────────────────────────────────────────────────────────────────
# Utilities
# ───────────────────────────────────────────────────────────────────────────────

func randi_range(min_val: int, max_val: int) -> int:
	return randi() % (max_val - min_val + 1) + min_val

func randf_range(min_val: float, max_val: float) -> float:
	return randf() * (max_val - min_val) + min_val
