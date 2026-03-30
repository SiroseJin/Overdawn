extends CharacterBody2D

class_name BatEnemy

# ─── Bat Enemy ─────────────────────────────────────────────────────────────────
# Fast but fragile flying enemy. Chases the player freely in both axes —
# no gravity, bats fly directly toward their target.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Stats ─────────────────────────────────────────────────────────────────────

var speed: float        = 35
var health: float       = 20
var health_max: float   = 20
var damage_to_deal: int = 10
var exp_value: int      = 5
var score_value: int    = 10

# ─── State ─────────────────────────────────────────────────────────────────────

var dir: Vector2            # Horizontal movement direction, used for sprite flipping
var dead: bool              = false
var taking_damage: bool     = false
var is_dealing_damage: bool = false
var is_bat_chase: bool      = false
var is_bat_roaming: bool    = false

var Player: CharacterBody2D
var health_bar: ProgressBar

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

func _process(_delta):
	move(_delta)
	handle_animation()

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.batDamageAmount = damage_to_deal
	Global.batDamageZone    = $BatDealDamageArea

	if Global.playerAlive:
		is_bat_chase   = true
		is_bat_roaming = false
	else:
		is_bat_chase   = false
		is_bat_roaming = true

# ───────────────────────────────────────────────────────────────────────────────
# Movement
# ───────────────────────────────────────────────────────────────────────────────

func move(_delta):
	# No gravity — bats fly freely in all directions
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not taking_damage and is_bat_chase and Global.playerAlive:
		Player    = Global.PlayerBody
		# Fly directly toward the player on both axes
		velocity  = position.direction_to(Player.position) * speed
		dir.x     = sign(velocity.x)

	elif taking_damage and is_bat_chase:
		velocity = position.direction_to(Player.position) * -80

	elif not taking_damage and not is_bat_chase and not Global.playerAlive:
		velocity = Vector2.ZERO

	move_and_slide()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

func handle_animation():
	var sprite = $AnimatedSprite2D

	if not dead and not taking_damage and not is_dealing_damage:
		sprite.play("idle")
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false

	elif not dead and is_dealing_damage:
		sprite.play("attack")

	elif not dead and taking_damage:
		sprite.play("hurt")
		await get_tree().create_timer(0.6).timeout
		taking_damage = false

	elif dead:
		$CollisionShape2D.disabled                   = true
		$BatDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled            = true
		sprite.play("death")
		await get_tree().create_timer(0.8).timeout
		handle_death()

# ───────────────────────────────────────────────────────────────────────────────
# Combat
# ───────────────────────────────────────────────────────────────────────────────

func take_damage(amount: float):
	health        -= amount
	taking_damage  = true
	if health <= 0:
		health = 0
		dead   = true
	health_bar.value = health

func handle_death():
	if Global.PlayerBody:
		Global.PlayerBody.gain_exp(exp_value)
		Global.PlayerBody.gain_score(score_value)
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

func _on_bat_hit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

func _on_bat_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_bat_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false
