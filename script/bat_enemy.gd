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

# Detection zone / roaming
var player_in_range: bool = false
var spawn_position: Vector2
var roam_target: Vector2
var roam_range: float = 80.0

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
	roam_target      = position
	$Timer.wait_time = 2.5

func _process(_delta):
	move(_delta)
	handle_animation()

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.batDamageAmount = damage_to_deal
	Global.batDamageZone    = $BatDealDamageArea

	if not Global.playerAlive:
		is_bat_chase   = false
		is_bat_roaming = false
	elif Global.arcade_mode or (player_in_range and has_line_of_sight_to_player()):
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

	elif not taking_damage and is_bat_roaming:
		# Drift toward the current roam target at 40% speed
		if position.distance_to(roam_target) > 5.0:
			velocity = position.direction_to(roam_target) * (speed * 0.4)
			dir.x    = sign(velocity.x)
		else:
			velocity = Vector2.ZERO

	else:
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

func has_line_of_sight_to_player() -> bool:
	if not Global.PlayerBody:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, Global.PlayerBody.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == Global.PlayerBody

func _on_timer_timeout():
	# Pick a new random roam target within roam_range of the spawn position
	roam_target = spawn_position + Vector2(
		randf_range(-roam_range, roam_range),
		randf_range(-roam_range, roam_range)
	)

func _on_detection_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = true

func _on_detection_zone_body_exited(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = false

func _on_bat_hit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)

func _on_bat_deal_damage_area_area_entered(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_bat_deal_damage_area_area_exited(area: Area2D):
	if area == Global.playerHitbox:
		is_dealing_damage = false
