extends CharacterBody2D

class_name BanditEnemy

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

# ── Attack pacing (anti-spam): min seconds between contact hits (#16). Editable. ──
@export var attack_cooldown: float = 0.9
var _atk_cd_remaining: float = 0.0

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.apply_enemy_scaling(self)   # story-mode level scaling (#6)
	ProgressionManager.notify("enemy_seen", {"type": "bandit"})   # unlocks its Guide entry
	health_bar           = $HealthBar
	health_bar.max_value = health_max
	health_bar.value     = health

	spawn_position   = position
	$Timer.wait_time = 3.0

func _process(_delta):
	move(_delta)
	handle_animation()
	_tick_attack(_delta)

	# NOTE: "Amount" typo is intentional — matches the Global variable name
	Global.banditDamageAmount = damage_to_deal
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

	if not taking_damage and is_frog_chase and Global.playerAlive and is_instance_valid(Global.PlayerBody):
		Player = Global.PlayerBody
		var chase_dir = sign(Player.position.x - position.x)
		velocity.x    = chase_dir * speed
		dir.x         = chase_dir

		# Periodic hop — lets the frog navigate up onto platforms
		jump_timer += delta
		if jump_timer >= JUMP_INTERVAL and is_on_floor():
			velocity.y  = JUMP_FORCE
			jump_timer  = 0.0

	elif taking_damage and is_frog_chase and is_instance_valid(Global.PlayerBody):
		# Recoil away from the player (resolve it here — the chase branch above may
		# never have run to assign Player, e.g. if hit the instant it spawned).
		velocity.x = sign(position.x - Global.PlayerBody.position.x) * 50

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
	Global.spawn_damage_number(global_position + Vector2(0, -18), int(amount))
	taking_damage  = true
	if health <= 0:
		health = 0
		dead   = true
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

# Pace contact damage so the enemy can't spam-hit (#16). One hit lands, then the
# contact hitbox disarms for `attack_cooldown` before it can strike again.
func _tick_attack(delta: float) -> void:
	if dead:
		return
	var col: CollisionShape2D = $FrogDealDamageArea/CollisionShape2D
	if _atk_cd_remaining > 0.0:
		_atk_cd_remaining -= delta
		if _atk_cd_remaining <= 0.0 and is_instance_valid(col):
			col.set_deferred("disabled", false)
		return
	if is_instance_valid(Global.playerHitbox) and $FrogDealDamageArea.overlaps_area(Global.playerHitbox):
		_atk_cd_remaining = attack_cooldown
		if is_instance_valid(col):
			col.set_deferred("disabled", true)

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
