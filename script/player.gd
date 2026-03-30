extends CharacterBody2D

class_name Player

# ─── Node References ───────────────────────────────────────────────────────────

@onready var animated_sprite_2d   = $AnimatedSprite2D
@onready var deal_damage_zone     = $DealDamageZone
@onready var projectile_output    = $ProjectileOutput

@onready var audio_walk = $AudioStreamPlayer_walk
@onready var audio_dash = $AudioStreamPlayer_dash

@onready var score_label = $CanvasLayer/Control/ScoreLabel

@onready var health_bar   = $CanvasLayer/Control/HealthBar
@onready var health_label = $CanvasLayer/Control/HealthBar/HealthLabel

@onready var level_label = $CanvasLayer/Control/LevelLabel

@onready var dash_cd       = $CanvasLayer/Control/DashCD
@onready var dash_cd_label = $CanvasLayer/Control/DashCD/Label

@onready var arrow_cd           = $CanvasLayer/Control/ArrowCD
@onready var arrow_refill_label = $CanvasLayer/Control/ArrowCD/ArrowRefillCD
@onready var arrow_count_label  = $CanvasLayer/Control/ArrowCD/ArrowCount

@onready var exp_bar   = $CanvasLayer/Control/EXPBar
@onready var exp_label = $CanvasLayer/Control/EXPBar/EXPLabel

@onready var pause_menu  = $CanvasLayer/PauseMenu
@onready var stats_menu  = $CanvasLayer/stats_menu
@onready var dbjump_cd   = $CanvasLayer/Control/DBJumpCD

# ─── Stats ─────────────────────────────────────────────────────────────────────

# Health
var health: int     = 100
var health_max: int = 100
var health_min: int = 0
var dead: bool

# Movement
var SPEED: int
const NORMAL_SPEED: int = 100
const DASH_SPEED:   int = int(NORMAL_SPEED * 3.2)

# Gravity & Jump
const GRAVITY: float       = 900.0   # Downward acceleration in pixels/s²
const JUMP_FORCE: float    = -380.0  # Initial upward velocity on jump (negative = up)
const MAX_FALL_SPEED: float = 800.0  # Terminal velocity cap

# Combat
var strength: int = 11

# ─── Levelling ─────────────────────────────────────────────────────────────────

var level: int             = 1
var exp: int               = 0
var exp_to_next_level: int = 10

# ─── Attack State ──────────────────────────────────────────────────────────────

var attack_type: String
var current_attack: bool  # True while an attack animation is playing
var weapon_equip: bool

# ─── Dash ──────────────────────────────────────────────────────────────────────

var DASH: bool          = false  # True during the active dash window
var dash_cooldown: bool = false  # True while the dash cooldown is ticking

# ─── Double Jump ───────────────────────────────────────────────────────────────

var can_double_jump: bool    = true   # Resets on landing
var double_jump_cooldown: bool = false # True while the cooldown is ticking
const DOUBLE_JUMP_FORCE: float = -320.0  # Slightly weaker than the first jump
const DOUBLE_JUMP_COOLDOWN: float = 1.0  # Seconds before the skill is available again

# ─── Arrows ────────────────────────────────────────────────────────────────────

var max_arrows: int              = 2
var arrows_held: int             = 2
var arrow_refill_time: float     = 1.0
var current_arrow_refill_time: float = 0.0

# ─── Misc ──────────────────────────────────────────────────────────────────────

var attack_radius: float  = 12
var can_take_damage: bool
var score: int            = 0
var is_game_paused: bool

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.PlayerBody  = self
	current_attack     = false
	dead               = false
	can_take_damage    = true
	Global.playerAlive = true
	SPEED              = NORMAL_SPEED

	update_health_bar()
	update_dash_cd(0)
	update_dbjump_cd(0)
	update_exp_lvl_label()
	update_score_label()

	pause_menu.hide()
	stats_menu.hide()
	is_game_paused = false

func _physics_process(delta):
	if is_game_paused:
		return

	weapon_equip            = Global.PlayerWeaponEquip
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox     = $PlayerHitbox

	if dead:
		move_and_slide()
		return

	# ── Gravity ────────────────────────────────────────────────────────────────
	# Gravity is suppressed during a dash so it doesn't drag the player down
	# mid-air and make the dash feel heavy. Resumes the moment the dash ends.
	if not DASH:
		if not is_on_floor():
			velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		else:
			velocity.y = 0
			# Restore double jump when the player lands (only if not on cooldown)
			if not double_jump_cooldown:
				can_double_jump = true

	# ── Horizontal movement ────────────────────────────────────────────────────
	# Only apply normal input when not in a dash (dash sets its own velocity)
	if not DASH:
		var direction_x = Input.get_axis("left", "right")
		velocity.x = direction_x * SPEED

	# ── Jump & Double Jump ─────────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_FORCE
		elif can_double_jump and not double_jump_cooldown:
			velocity.y      = DOUBLE_JUMP_FORCE
			can_double_jump = false
			start_double_jump_cooldown()

	# ── Melee attacks (unarmed, not mid-attack) ────────────────────────────────
	if not weapon_equip and not current_attack:
		if DASH:
			if Input.is_action_just_pressed("left_click") or Input.is_action_just_pressed("right_click"):
				current_attack = true
				attack_type    = "dash"
				set_damage(attack_type)
				handle_attack_animation(attack_type)
		else:
			if Input.is_action_just_pressed("left_click"):
				current_attack = true
				attack_type    = "normal"
				set_damage(attack_type)
				handle_attack_animation(attack_type)
			elif Input.is_action_just_pressed("right_click"):
				current_attack = true
				attack_type    = "special"
				set_damage(attack_type)
				handle_attack_animation(attack_type)

	handle_movement_animation(velocity)
	check_hitbox()

	if Input.is_action_just_pressed("dash") and not dash_cooldown:
		start_dash()

	if Input.is_action_just_pressed("shoot"):
		shoot_arrow()

	if Input.is_action_just_pressed("pause"):
		pause_menu_screen()

	if Input.is_action_just_pressed("stats"):
		stats_menu_screen()

	update_deal_damage_zone()
	update_player_sprite_orientation()

	move_and_slide()

func _process(delta):
	if arrows_held < max_arrows:
		current_arrow_refill_time += delta
		if current_arrow_refill_time >= arrow_refill_time:
			arrows_held               += 1
			current_arrow_refill_time  = 0.0
	update_arrow_cd()

# ───────────────────────────────────────────────────────────────────────────────
# Pause / Menu
# ───────────────────────────────────────────────────────────────────────────────

func pause_menu_screen():
	is_game_paused = true
	pause_menu.show()
	pause_game()

func stats_menu_screen():
	is_game_paused = true
	stats_menu.show()
	pause_game()

func pause_game():
	Engine.time_scale = 0 if is_game_paused else 1

# ───────────────────────────────────────────────────────────────────────────────
# Ranged Attack – Arrows
# ───────────────────────────────────────────────────────────────────────────────

func shoot_arrow():
	if arrows_held <= 0:
		return

	var arrow_scene    = preload("res://scene/arrow.tscn")
	var arrow_instance = arrow_scene.instantiate()
	get_parent().add_child(arrow_instance)

	arrow_instance.position  = $ProjectileOutput.global_position
	var mouse_pos             = get_global_mouse_position()
	arrow_instance.direction  = (mouse_pos - $ProjectileOutput.global_position).normalized()

	arrows_held -= 1
	update_arrow_cd()

func update_arrow_cd():
	arrow_cd.value     = current_arrow_refill_time
	arrow_cd.max_value = arrow_refill_time
	arrow_count_label.text = str(arrows_held) + "/" + str(max_arrows)

	if arrows_held < max_arrows:
		arrow_refill_label.text    = str(round(arrow_refill_time - current_arrow_refill_time))
		arrow_refill_label.visible = true
	else:
		arrow_refill_label.visible = false

# ───────────────────────────────────────────────────────────────────────────────
# Hit Detection
# ───────────────────────────────────────────────────────────────────────────────

func check_hitbox():
	var hitbox_areas = $PlayerHitbox.get_overlapping_areas()
	if hitbox_areas.is_empty():
		return

	var damage: int = 0
	var hitbox = hitbox_areas.front()
	var parent = hitbox.get_parent()

	if   parent is BatEnemy:   damage = Global.batDamageAmount
	elif parent is FrogEnemy:  damage = Global.frogDamageAmount
	elif parent is WitchEnemy: damage = Global.witchDamageAmount
	elif parent is NecroEnemy: damage = Global.necroDamageAmount

	if can_take_damage:
		take_damage(damage)

# ───────────────────────────────────────────────────────────────────────────────
# Levelling & Score
# ───────────────────────────────────────────────────────────────────────────────

func gain_exp(amount):
	exp += amount
	if exp >= exp_to_next_level:
		level_up()
	update_exp_lvl_label()

func level_up():
	level             += 1
	exp               -= exp_to_next_level
	exp_to_next_level  = int(exp_to_next_level * 1.1)
	health_max        += 1
	health            += 1
	strength          += 0.6
	health             = min(health, health_max)
	update_health_bar()

func update_exp_lvl_label():
	if exp_label:
		exp_bar.value     = exp
		exp_bar.max_value = exp_to_next_level
		exp_label.text    = "EXP: " + str(round(exp)) + " / " + str(round(exp_to_next_level))
	level_label.text = "LVL: " + str(level)

func gain_score(amount):
	score += amount
	update_score_label()

func update_score_label():
	score_label.text = "Score: " + str(score)

# ───────────────────────────────────────────────────────────────────────────────
# Health
# ───────────────────────────────────────────────────────────────────────────────

func take_damage(damage: int):
	if damage == 0 or health <= 0:
		return

	health -= damage
	update_health_bar()

	if health <= 0:
		health             = 0
		dead               = true
		Global.playerAlive = false
		handle_death_animation()

	take_damage_cooldown(1.0)
	health = min(health, health_max)

func heal_player(amount: int):
	health = min(health + amount, health_max)
	update_health_bar()

func update_health_bar():
	health_bar.value     = health
	health_bar.max_value = health_max
	health_label.text    = str(health) + "/" + str(health_max)

# Prevent damage for a short window after being hit (i-frames)
func take_damage_cooldown(_wait_time: float):
	can_take_damage = false
	await get_tree().create_timer(0.5).timeout
	can_take_damage = true

# ───────────────────────────────────────────────────────────────────────────────
# Death
# ───────────────────────────────────────────────────────────────────────────────

func handle_death_animation():
	velocity = Vector2.ZERO
	$CollisionShape2D.disabled = true
	animated_sprite_2d.play("dead")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom = Vector2(4, 4)
	await get_tree().create_timer(3.0).timeout
	queue_free()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

# Play the correct idle / run / jump / dash animation when not attacking
func handle_movement_animation(_vel: Vector2):
	if weapon_equip or current_attack:
		return

	if DASH:
		animated_sprite_2d.play("dash")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("fall")
	elif velocity.x == 0:
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("run")

# Flip sprite and reposition projectile origin based on mouse side
func update_player_sprite_orientation():
	var dir = (get_global_mouse_position() - global_position).normalized()
	animated_sprite_2d.flip_h    = dir.x < 0
	$ProjectileOutput.position.x = -5 if dir.x < 0 else 5

func handle_attack_animation(type: String):
	animated_sprite_2d.play(str(type, "_attack"))
	toggle_damage_collision(type)

func _on_animated_sprite_2d_animation_finished():
	current_attack = false

func toggle_damage_collision(type: String):
	var damage_col = deal_damage_zone.get_node("CollisionShape2D")
	var wait_time: float

	match type:
		"normal":  wait_time = 0.5
		"special": wait_time = 0.8
		"dash":    wait_time = 0.3
		_:         wait_time = 0.5

	damage_col.disabled = false
	await get_tree().create_timer(wait_time).timeout
	damage_col.disabled = true

# ───────────────────────────────────────────────────────────────────────────────
# Combat – Damage Output
# ───────────────────────────────────────────────────────────────────────────────

func set_damage(type: String):
	var multiplier: float

	match type:
		"normal":  multiplier = 1.0
		"special": multiplier = 1.5
		"dash":    multiplier = 2.5
		_:         multiplier = 1.0

	Global.playerDamageAmount = int(strength * multiplier)

func update_deal_damage_zone():
	var dir = (get_global_mouse_position() - global_position).normalized()
	deal_damage_zone.position = dir * attack_radius

# ───────────────────────────────────────────────────────────────────────────────
# Dash
# ───────────────────────────────────────────────────────────────────────────────

func start_dash():
	DASH = true
	audio_dash.play()
	$PlayerHitbox/CollisionShape2D.disabled = true
	can_take_damage = false

	# Dash in the direction of keyboard input; fall back to sprite facing if no input
	var input_x  = Input.get_axis("left", "right")
	var dash_dir = sign(input_x) if input_x != 0 else (-1.0 if animated_sprite_2d.flip_h else 1.0)
	velocity.x   = dash_dir * DASH_SPEED
	velocity.y   = 0.0

	animated_sprite_2d.play("dash")
	await get_tree().create_timer(0.25).timeout  # Dash active window

	DASH          = false
	dash_cooldown = true
	$PlayerHitbox/CollisionShape2D.disabled = false
	can_take_damage = true

	await dash_cooldown_duration()

func dash_cooldown_duration():
	var cooldown_time: float = 0.1
	dash_cd.max_value        = cooldown_time

	while cooldown_time > 0:
		update_dash_cd(cooldown_time)
		await get_tree().create_timer(1.0).timeout
		cooldown_time -= 1.0

	dash_cooldown = false
	update_dash_cd(0)

func update_dash_cd(cooldown_time: float):
	if cooldown_time > 0:
		dash_cd.value         = cooldown_time
		dash_cd_label.text    = str(round(cooldown_time))
		dash_cd_label.visible = true
	else:
		dash_cd.value         = 0
		dash_cd_label.visible = false

# ───────────────────────────────────────────────────────────────────────────────
# Double Jump
# ───────────────────────────────────────────────────────────────────────────────

# Trigger the cooldown after a double jump is consumed
func start_double_jump_cooldown():
	double_jump_cooldown = true
	can_double_jump      = false
	var remaining        = DOUBLE_JUMP_COOLDOWN
	dbjump_cd.max_value  = remaining

	while remaining > 0:
		update_dbjump_cd(remaining)
		await get_tree().create_timer(1.0).timeout
		remaining -= 1.0

	double_jump_cooldown = false
	update_dbjump_cd(0)

# Refresh the double jump cooldown bar label
func update_dbjump_cd(remaining: float):
	dbjump_cd.value   = remaining
	dbjump_cd.visible = true

# ───────────────────────────────────────────────────────────────────────────────
# Speed Modifiers (used by enemy effects)
# ───────────────────────────────────────────────────────────────────────────────

# Temporarily reduce movement speed by a fractional factor (e.g. 0.6 = 40% slow)
func slow_down(factor: float):
	SPEED = int(NORMAL_SPEED * factor)

func restore_speed():
	SPEED = NORMAL_SPEED
