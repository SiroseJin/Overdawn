extends CharacterBody2D

class_name AdbotEnemy

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

# ── Attack pacing (anti-spam): min seconds between contact hits (#16). Editable. ──
@export var attack_cooldown: float = 0.9
var _atk_cd_remaining: float = 0.0

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.apply_enemy_scaling(self)   # story-mode level scaling (#6)
	ProgressionManager.notify("enemy_seen", {"type": "adbot"})   # unlocks its Guide entry
	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

	spawn_position   = position
	roam_target      = position
	$Timer.wait_time = 2.5

func _process(_delta):
	move(_delta)
	handle_animation()
	_tick_attack(_delta)

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.adbotDamageAmount = damage_to_deal
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
	if not dead and _knockback_active():
		return
	# No gravity — bats fly freely in all directions
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not taking_damage and is_bat_chase and Global.playerAlive and is_instance_valid(Global.PlayerBody):
		Player    = Global.PlayerBody
		# Fly directly toward the player on both axes
		velocity  = position.direction_to(Player.position) * speed
		dir.x     = sign(velocity.x)

	elif taking_damage and is_bat_chase and is_instance_valid(Global.PlayerBody):
		velocity = position.direction_to(Global.PlayerBody.position) * -80

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
	Global.spawn_damage_number(global_position + Vector2(0, -18), int(amount))
	taking_damage  = true
	if health <= 0:
		health = 0
		dead   = true
	health_bar.value = health
	if not dead:
		AudioManager.play_sfx("enemy_hurt")
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
	ProgressionManager.notify("enemy_defeated", {"type": "adbot"})   # can unlock lore
	AudioManager.play_sfx("adbot_death")
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

# Slope-aware sight (walls block, walkable slopes don't) — shared in Global (#11).
func has_line_of_sight_to_player() -> bool:
	return Global.enemy_line_of_sight(self)

# Pace contact damage so the bat can't spam-hit (#16). One hit lands, then the
# contact hitbox disarms for `attack_cooldown` before it can strike again.
func _tick_attack(delta: float) -> void:
	if dead:
		return
	var col: CollisionShape2D = $BatDealDamageArea/CollisionShape2D
	if _atk_cd_remaining > 0.0:
		_atk_cd_remaining -= delta
		if _atk_cd_remaining <= 0.0 and is_instance_valid(col):
			col.set_deferred("disabled", false)
		return
	if is_instance_valid(Global.playerHitbox) and $BatDealDamageArea.overlaps_area(Global.playerHitbox):
		_atk_cd_remaining = attack_cooldown
		AudioManager.play_sfx("adbot_attack")
		if is_instance_valid(col):
			col.set_deferred("disabled", true)

func _on_timer_timeout():
	# Pick a new random roam target within roam_range of the spawn position
	roam_target = spawn_position + Vector2(
		randf_range(-roam_range, roam_range),
		randf_range(-roam_range, roam_range)
	)

func _on_detection_zone_body_entered(body: Node2D):
	if body == Global.PlayerBody:
		player_in_range = true
		if AudioManager.play_alert():
			Global.enemy_spot_hop(self)   # small startled hop, on the alert's cooldown

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
