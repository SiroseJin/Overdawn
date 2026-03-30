extends CharacterBody2D

class_name NecroEnemy

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

# Charge ability (leads into the slow-orb projectile)
var charging: bool = false
var charging_timer: Timer

# Summon ability (spawns bats)
var summoning: bool          = false
var can_summon: bool         = true
var summon_timer: Timer
var summon_cooldown_timer: Timer

var Player: CharacterBody2D
var health_bar: ProgressBar

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
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

func _process(_delta):
	move(_delta)
	handle_animation()

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.necroDamageAmount = damage_to_deal
	Global.necroDamageZone    = $NecroDealDamageArea

	if Global.playerAlive:
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

	elif not taking_damage and is_necro_chase and Global.playerAlive:
		Player = Global.PlayerBody
		# Move at 1/5 speed while charging (winding up the orb shot)
		var move_speed = speed / 5.0 if charging else speed
		var chase_dir  = sign(Player.position.x - position.x)
		velocity.x     = chase_dir * move_speed
		dir.x          = chase_dir

	elif taking_damage and is_necro_chase:
		velocity.x = sign(position.x - Player.position.x) * 30

	elif not taking_damage and not is_necro_chase and not Global.playerAlive:
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

		# Flip sprite and reposition projectile origin to face the player
		if Player and Player.position.x < position.x:
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
		charging_timer.start()
	elif dead:
		charging = false
		charging_timer.stop()

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
	var orb_scene = preload("res://scene/necromancer_slow_orb.tscn")
	var orb       = orb_scene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = $ProjectileOutput.global_position
	orb.direction = (Player.global_position - $ProjectileOutput.global_position).normalized()

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
	var bat_scene = preload("res://scene/bat_enemy.tscn")
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
	if health <= 0:
		health = 0
		dead   = true
		charging_timer.stop()
		summon_timer.stop()
	health_bar.value = health

func handle_death():
	if Global.PlayerBody:
		Global.PlayerBody.gain_exp(exp_value)
		Global.PlayerBody.gain_score(score_value)
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

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
