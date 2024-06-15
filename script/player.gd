extends CharacterBody2D

class_name Player

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var deal_damage_zone = $DealDamageZone
@onready var projectile_output = $ProjectileOutput

@onready var score_label = $CanvasLayer/Control/ScoreLabel

@onready var health_bar = $CanvasLayer/Control/HealthBar
@onready var health_label = $CanvasLayer/Control/HealthBar/HealthLabel

@onready var level_label = $CanvasLayer/Control/LevelLabel

@onready var dash_cd = $CanvasLayer/Control/DashCD
@onready var dash_cd_label = $CanvasLayer/Control/DashCD/Label

@onready var arrow_cd = $CanvasLayer/Control/ArrowCD
@onready var arrow_refill_label = $CanvasLayer/Control/ArrowCD/ArrowRefillCD
@onready var arrow_count_label = $CanvasLayer/Control/ArrowCD/ArrowCount

@onready var exp_bar = $CanvasLayer/Control/EXPBar
@onready var exp_label = $CanvasLayer/Control/EXPBar/EXPLabel

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var stats_menu = $CanvasLayer/stats_menu

# HP
var health = 100
var health_max = 100
var health_min = 0
var dead: bool

# Speed
var SPEED: int
var DASH_SPEED: int = 140
var NORMAL_SPEED: int = 75

# Strength
var strength: int = 11

# Level and EXP
var level: int = 1
var exp: int = 0
var exp_to_next_level: int = 10

# Attacks
var attack_type: String
var current_attack: bool
var weapon_equip: bool

# Skill
#Dash
var DASH: bool = false
var dash_cooldown: bool = false

#Arrows
var max_arrows: int = 2
var arrows_held: int = 2
var arrow_refill_time: float = 10.0
var current_arrow_refill_time: float = 0.0

# Else
var attack_radius: float = 14
var can_take_damage: bool
var score: int = 0
var is_game_paused: bool

func _ready():
	Global.PlayerBody = self
	current_attack = false
	dead = false
	can_take_damage = true
	Global.playerAlive = true
	SPEED = NORMAL_SPEED
	update_health_bar()
	update_dash_cd(0)
	update_exp_lvl_label()
	update_score_label()
	pause_menu.hide()
	stats_menu.hide()
	is_game_paused = false

func _physics_process(delta):
	if not is_game_paused:
		weapon_equip = Global.PlayerWeaponEquip
		Global.playerDamageZone = deal_damage_zone
		Global.playerHitbox = $PlayerHitbox

		if !dead:
			var direction_x = Input.get_axis("left", "right")
			var direction_y = Input.get_axis("up", "down")
			var direction = Vector2(direction_x, direction_y).normalized()
			velocity = direction * SPEED

			if !weapon_equip and !current_attack:
				if DASH:
					if Input.is_action_just_pressed("left_click") or Input.is_action_just_pressed("right_click"):
						current_attack = true
						attack_type = "dash"
						set_damage(attack_type)
						handle_attack_animation(attack_type)
				elif Input.is_action_just_pressed("left_click") or Input.is_action_just_pressed("right_click"):
					current_attack = true
					if Input.is_action_just_pressed("left_click"):
						attack_type = "normal"
					elif Input.is_action_just_pressed("right_click"):
						attack_type = "special"
					set_damage(attack_type)
					handle_attack_animation(attack_type)
			handle_movement_animation(direction)
			check_hitbox()

			if Input.is_action_just_pressed("dash") and !dash_cooldown:
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

func pause_menu_screen():
	is_game_paused = true
	pause_menu.show()
	pause_game()

func stats_menu_screen():
	is_game_paused = true
	stats_menu.show()
	pause_game()

func pause_game():
	if is_game_paused:
		Engine.time_scale = 0
	elif !is_game_paused:
		Engine.time_scale = 1

func shoot_arrow():
	if arrows_held > 0:
		var arrow_scene = preload("res://scene/arrow.tscn")
		var arrow_instance = arrow_scene.instantiate()
		get_parent().add_child(arrow_instance)

		arrow_instance.position = $ProjectileOutput.global_position
		var mouse_position = get_global_mouse_position()
		var direction = (mouse_position - $ProjectileOutput.global_position).normalized()
		arrow_instance.direction = direction
		arrows_held -= 1
		update_arrow_cd()

func _process(delta):
	if arrows_held < max_arrows:
		current_arrow_refill_time += delta
		if current_arrow_refill_time >= arrow_refill_time:
			arrows_held += 1
			current_arrow_refill_time = 0.0
	update_arrow_cd()

func update_arrow_cd():
	arrow_cd.value = current_arrow_refill_time
	arrow_cd.max_value = arrow_refill_time
	arrow_count_label.text = str(arrows_held) + "/" + str(max_arrows)

	if arrows_held < max_arrows:
		arrow_refill_label.text = str(round(arrow_refill_time - current_arrow_refill_time))
		arrow_refill_label.visible = true
	else:
		arrow_refill_label.visible = false

func check_hitbox():
	var hitbox_areas = $PlayerHitbox.get_overlapping_areas()
	var damage: int
	if hitbox_areas:
		var hitbox = hitbox_areas.front()
		if hitbox.get_parent() is BatEnemy:
			damage = Global.batDamageAmmount
		elif hitbox.get_parent() is FrogEnemy:
			damage = Global.frogDamageAmmount
		elif hitbox.get_parent() is WitchEnemy:
			damage = Global.witchDamageAmmount
		elif hitbox.get_parent() is NecroEnemy:
			damage = Global.necroDamageAmmount

	if can_take_damage:
		take_damage(damage)

func gain_exp(amount):
	exp += amount
	if exp >= exp_to_next_level:
		level_up()
	update_exp_lvl_label()

func level_up():
	level += 1
	exp -= exp_to_next_level
	exp_to_next_level *= 1.1
	health_max += 1
	health += 1
	strength += 0.6
	update_health_bar()
	health = min(health, health_max)

func update_exp_lvl_label():
	if exp_label:
		exp_bar.value = exp
		exp_bar.max_value = exp_to_next_level
		var exp_needed = round(exp_to_next_level)
		exp_label.text = "EXP: " + str(round(exp)) + " / " + str(exp_needed)

	level_label.text = "LVL: " + str(level)

func gain_score(ammounts):
	score += ammounts
	update_score_label()

func update_score_label():
	score_label.text = "Score: " + str(score)

func take_damage(damage):
	if damage != 0:
		if health > 0:
			health -= damage
			print("player hp: ", health)
			update_health_bar()
			if health <= 0:
				health = 0
				dead = true
				Global.playerAlive = false
				handle_death_animation()
			take_damage_cooldown(1.0)
			health = min(health, health_max)

func heal_player(amount: int):
	if health < health_max:
		health += amount
		update_health_bar()
	elif health > health_max:
		health = health_max

func update_health_bar():
	health_bar.value = health
	health_bar.max_value = health_max
	health_label.text = str(health) + "/" + str(health_max)

func handle_death_animation():
	velocity.y = 0
	velocity.x = 0
	$CollisionShape2D.disabled = true
	animated_sprite_2d.play("dead")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom.x = 4
	$Camera2D.zoom.y = 4
	await get_tree().create_timer(3.0).timeout
	self.queue_free()

func take_damage_cooldown(wait_time):
	can_take_damage = false
	await get_tree().create_timer(0.5).timeout
	can_take_damage = true

func handle_movement_animation(dir):
	if !weapon_equip:
		if !current_attack:
			if DASH:
				animated_sprite_2d.play("dash")
			elif !velocity:
				animated_sprite_2d.play("idle")
			elif velocity:
				animated_sprite_2d.play("run")

func update_player_sprite_orientation():
	var mouse_position = get_global_mouse_position()
	var player_position = global_position
	var direction = (mouse_position - player_position).normalized()

	animated_sprite_2d.flip_h = direction.x < 0
	if direction.x < 0:
		$ProjectileOutput.position.x = -5
	else:
		$ProjectileOutput.position.x = 5

func handle_attack_animation(attack_type):
	var animation = str(attack_type, "_attack")
	animated_sprite_2d.play(animation)
	toggle_damage_collision(attack_type)

func _on_animated_sprite_2d_animation_finished():
	current_attack = false

func toggle_damage_collision(attack_type):
	var damage_zone_collision = deal_damage_zone.get_node("CollisionShape2D")
	var wait_time: float
	if attack_type == "normal":
		wait_time = 0.5
	elif attack_type == "special":
		wait_time = 0.8
	elif attack_type == "dash":
		wait_time = 0.3
	damage_zone_collision.disabled = false
	await get_tree().create_timer(wait_time).timeout
	damage_zone_collision.disabled = true

func set_damage(attack_type):
	var current_damage_to_deal: int
	if attack_type == "normal":
		current_damage_to_deal = strength * 1
	elif attack_type == "special":
		current_damage_to_deal = strength * 1.5
	elif attack_type == "dash":
		current_damage_to_deal = strength * 2.5
	Global.playerDamageAmount = current_damage_to_deal

func start_dash():
	DASH = true
	$PlayerHitbox/CollisionShape2D.disabled = true
	can_take_damage = false
	SPEED = DASH_SPEED
	animated_sprite_2d.play("dash")
	await dash_duration()
	DASH = false
	SPEED = NORMAL_SPEED
	dash_cooldown = true
	$PlayerHitbox/CollisionShape2D.disabled = false
	can_take_damage = true
	await dash_cooldown_duration()

func dash_duration():
	await get_tree().create_timer(0.3).timeout

func dash_cooldown_duration():
	var cooldown_time = 7.0
	dash_cd.max_value = cooldown_time  # Set max value to cooldown time
	while cooldown_time > 0:
		update_dash_cd(cooldown_time)
		await get_tree().create_timer(1).timeout
		cooldown_time -= 1.0
	dash_cooldown = false
	update_dash_cd(0)  # Reset DashCD when cooldown is over

func update_dash_cd(cooldown_time):
	if cooldown_time > 0:
		dash_cd.value = cooldown_time
		dash_cd_label.text = str(round(cooldown_time))
		dash_cd_label.visible = true
	else:
		dash_cd.value = 0
		dash_cd_label.visible = false


func update_deal_damage_zone():
	var mouse_position = get_global_mouse_position()
	var player_position = global_position
	var direction = (mouse_position - player_position).normalized()

	deal_damage_zone.position = direction * attack_radius
