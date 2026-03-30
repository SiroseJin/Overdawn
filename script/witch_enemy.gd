extends CharacterBody2D

class_name WitchEnemy

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
const GRAVITY: float        = 120.0   # Much lower than normal (900) for a floaty feel
const MAX_FALL_SPEED: float = 20.0    # Very low terminal velocity — she barely sinks
const HOVER_FORCE: float    = -50.0   # Upward nudge applied periodically to maintain hover
const HOVER_INTERVAL: float = 2    # Seconds between hover nudges

var hover_timer: float = 0.0

# ─── State ─────────────────────────────────────────────────────────────────────

var dir: Vector2            # Horizontal movement direction
var dead: bool              = false
var taking_damage: bool     = false
var is_dealing_damage: bool = false
var is_witch_chase: bool    = false
var is_witch_roaming: bool  = false

# Charge state: witch slows down then fires after the timer elapses
var charging: bool = false
var charging_timer: Timer

var Player: CharacterBody2D
var health_bar: ProgressBar

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
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

func _process(_delta):
	move(_delta)
	handle_animation()

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.witchDamageAmount = damage_to_deal
	Global.witchDamageZone    = $WitchDealDamageArea

	if Global.playerAlive:
		is_witch_chase   = true
		is_witch_roaming = false
		Player = Global.PlayerBody

		var distance_to_player = position.distance_to(Player.position)
		if distance_to_player >= 140:
			charge()
		else:
			charging = false
			charging_timer.stop()
	else:
		is_witch_chase   = false
		is_witch_roaming = true

# ───────────────────────────────────────────────────────────────────────────────
# Movement
# ───────────────────────────────────────────────────────────────────────────────

func move(delta):
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
	if not taking_damage and is_witch_chase and Global.playerAlive:
		Player = Global.PlayerBody
		var move_speed = speed / 2.0 if charging else speed
		var chase_dir  = sign(Player.position.x - position.x)
		velocity.x     = chase_dir * move_speed
		dir.x          = chase_dir

	elif taking_damage and is_witch_chase:
		velocity.x = sign(position.x - Player.position.x) * 60

	elif not taking_damage and not is_witch_chase and not Global.playerAlive:
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

func release_fireball():
	if dead:
		return
	var fireball_scene = preload("res://scene/witch_fireball.tscn")
	var fireball       = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = $ProjectileOutput.global_position
	fireball.direction = (Player.global_position - $ProjectileOutput.global_position).normalized()

func take_damage(amount: float):
	health        -= amount
	taking_damage  = true
	if health <= 0:
		health = 0
		dead   = true
		charging_timer.stop()
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

func _on_witch_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_witch_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false
