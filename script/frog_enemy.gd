extends CharacterBody2D

class_name FrogEnemy

# ─── Frog Enemy ────────────────────────────────────────────────────────────────
# Slow, tanky melee enemy that walks along the ground.
# Affected by gravity — falls off ledges and lands on platforms.
# Being a frog, it also has a periodic jump to reach higher platforms.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Stats ─────────────────────────────────────────────────────────────────────

var speed: float        = 17
var health: float       = 35
var health_max: float   = 35
var damage_to_deal: int = 20
var exp_value: int      = 10
var score_value: int    = 20

# Gravity & Jump
const GRAVITY: float        = 900.0
const MAX_FALL_SPEED: float = 800.0
const JUMP_FORCE: float     = -180.0  # Reduced — small hop, not a leap  # Frogs hop periodically to reach platforms

var jump_timer: float = 0.0
const JUMP_INTERVAL: float = 2.5  # Seconds between hops

# ─── State ─────────────────────────────────────────────────────────────────────

var dir: Vector2            # Horizontal movement direction, used for sprite flipping
var dead: bool              = false
var taking_damage: bool     = false
var is_dealing_damage: bool = false
var is_frog_chase: bool     = false
var is_frog_roaming: bool   = false

# Detection zone / roaming
var player_in_range: bool = false
var spawn_position: Vector2
var roam_direction: int = 1   # +1 = right, -1 = left
var roam_range: float = 60.0

var Player: CharacterBody2D
var health_bar: ProgressBar

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

	spawn_position   = position
	$Timer.wait_time = 3.0

func _process(_delta):
	move(_delta)
	handle_animation()

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.frogDamageAmount = damage_to_deal
	Global.frogDamageZone    = $FrogDealDamageArea

	if not Global.playerAlive:
		is_frog_chase   = false
		is_frog_roaming = false
	elif Global.arcade_mode or (player_in_range and has_line_of_sight_to_player()):
		is_frog_chase   = true
		is_frog_roaming = false
	else:
		is_frog_chase   = false
		is_frog_roaming = true

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

	if not taking_damage and is_frog_chase and Global.playerAlive:
		Player = Global.PlayerBody
		var chase_dir = sign(Player.position.x - position.x)
		velocity.x    = chase_dir * speed
		dir.x         = chase_dir

		# Periodic hop — lets the frog navigate up onto platforms
		jump_timer += delta
		if jump_timer >= JUMP_INTERVAL and is_on_floor():
			velocity.y  = JUMP_FORCE
			jump_timer  = 0.0

	elif taking_damage and is_frog_chase:
		velocity.x = sign(position.x - Player.position.x) * 50

	elif not taking_damage and is_frog_roaming:
		# Walk back and forth within roam_range of spawn position
		if abs(position.x - spawn_position.x) >= roam_range:
			roam_direction *= -1
		velocity.x = roam_direction * speed * 0.4
		dir.x      = roam_direction

	else:
		velocity.x = 0

	move_and_slide()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

func handle_animation():
	var sprite = $AnimatedSprite2D

	if not dead and not taking_damage and not is_dealing_damage:
		sprite.play("walk")
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
		$CollisionShape2D.disabled                    = true
		$FrogDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled             = true
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

func has_line_of_sight_to_player() -> bool:
	if not Global.PlayerBody:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, Global.PlayerBody.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == Global.PlayerBody

func _on_direction_timer_timeout():
	roam_direction *= -1

func _on_detection_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = true

func _on_detection_zone_body_exited(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = false

func _on_frog_hit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

func _on_frog_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_frog_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false
