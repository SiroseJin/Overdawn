extends CharacterBody2D

class_name NecroEnemy

var speed = 60
var dir: Vector2
var is_necro_chase: bool
var is_necro_roaming: bool

var Player: CharacterBody2D

var health = 200
var health_max = 200
var health_min = 0
var dead = false
var taking_damage: bool
var damage_to_deal = 30
var is_dealing_damage: bool

var charging: bool
var charging_timer: Timer
var exp_value = 80
var score_value = 200

var summoning: bool
var summon_timer: Timer
var can_summon: bool = true
var summon_cooldown_timer: Timer

func _ready():
	is_necro_chase = true
	taking_damage = false
	charging = false
	is_dealing_damage = false
	summoning = false

	charging_timer = Timer.new()
	charging_timer.wait_time = 3.0
	charging_timer.one_shot = true
	charging_timer.connect("timeout", Callable(self, "_on_charging_timeout"))
	add_child(charging_timer)

	summon_timer = Timer.new()
	summon_timer.wait_time = 3.0
	summon_timer.one_shot = true
	summon_timer.connect("timeout", Callable(self, "_on_summon_timeout"))
	add_child(summon_timer)

	summon_cooldown_timer = Timer.new()
	summon_cooldown_timer.wait_time = 15.0
	summon_cooldown_timer.one_shot = true
	summon_cooldown_timer.connect("timeout", Callable(self, "_on_summon_cooldown_timeout"))
	add_child(summon_cooldown_timer)

func _process(delta):
	move(delta)
	handle_animation()
	Global.necroDamageAmmount = damage_to_deal
	Global.necroDamageZone = $NecroDealDamageArea
	
	if Global.playerAlive:
		is_necro_chase = true
		is_necro_roaming = false
		Player = Global.PlayerBody
		var distance_to_player = position.distance_to(Player.position)
		if distance_to_player >= 80 and can_summon:
			enter_summon_state()
		elif distance_to_player >= 120:
			charge()
		else:
			charging = false
			charging_timer.stop()
	else:
		is_necro_chase = false
		is_necro_roaming = true

func move(delta):
	if !dead:
		if summoning:
			velocity = Vector2.ZERO
		elif !taking_damage and is_necro_chase and Global.playerAlive:
			Player = Global.PlayerBody
			if charging:
				velocity = position.direction_to(Player.position) * (speed / 6)
			else:
				velocity = position.direction_to(Player.position) * speed
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage and is_necro_chase:
			var knockback_dir = position.direction_to(Player.position) * -7
			velocity = knockback_dir
		elif !taking_damage and !is_necro_chase and !Global.playerAlive:
			velocity.y = 0
			velocity.x = 0
	elif dead:
		velocity.y = 0
		velocity.x = 0
	move_and_slide()

func handle_animation():
	var animated_sprite = $AnimatedSprite2D
	var animated_fvx = $FVX
	if !dead and !taking_damage and !is_dealing_damage:
		if summoning:
			animated_sprite.play("summon")
			animated_fvx.play("summoning")
		elif charging:
			animated_sprite.play("charge")
		elif is_necro_chase:
			animated_sprite.play("run")
		elif is_necro_roaming:
			animated_sprite.play("idle")
		if Player and Player.position.x < position.x:
			animated_sprite.flip_h = true
			$ProjectileOutput.position.x = -12
		else:
			animated_sprite.flip_h = false
			$ProjectileOutput.position.x = 12
	elif !dead and is_dealing_damage:
		animated_sprite.play("attack")
	elif !dead and taking_damage:
		animated_sprite.play("hurt")
		await get_tree().create_timer(0.7).timeout
		taking_damage = false
	elif dead:
		$CollisionShape2D.disabled = true
		$NecroDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled = true
		charging = false
		is_necro_roaming = false
		animated_sprite.play("death")
		await get_tree().create_timer(3.5).timeout
		handle_death()

func handle_death():
	if Global.PlayerBody:
		Global.PlayerBody.gain_exp(exp_value)
		Global.PlayerBody.gain_score(score_value)
	self.queue_free()

func charge():
	if !charging and !dead:
		charging = true
		charging_timer.start()
	elif dead:
		charging = false
		charging_timer.stop()

func _on_charging_timeout():
	if !dead:
		is_dealing_damage = true
		await get_tree().create_timer(0.4).timeout
		release_fireball()
		is_dealing_damage = false
		charging = false

func release_fireball():
	if dead:
		return
	print("Release fireball")
	var fireball_scene = preload("res://scene/witch_fireball.tscn")
	if fireball_scene:
		var fireball_instance = fireball_scene.instantiate()
		if fireball_instance:
			get_parent().add_child(fireball_instance)
			fireball_instance.global_position = $ProjectileOutput.global_position
			var direction_to_player = (Player.global_position - $ProjectileOutput.global_position).normalized()
			fireball_instance.direction = direction_to_player

func take_damage(damage):
	health -= damage
	taking_damage = true
	if health <= 0:
		health = 0
		dead = true
		charging_timer.stop()
		summon_timer.stop()
	print(str(self), "current Hp is", health)

func _on_hit_box_area_entered(area):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)

func _on_necro_deal_damage_area_area_entered(area):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_necro_deal_damage_area_area_exited(area):
	if area == Global.playerHitbox:
		is_dealing_damage = false

func enter_summon_state():
	if can_summon and !summoning:
		summoning = true
		can_summon = false
		summon_timer.start()
		summon_cooldown_timer.start()

func _on_summon_timeout():
	if !dead:
		summon_bats()
		summoning = false

func summon_bats():
	var animated = $FVX
	var bat_scene = preload("res://scene/bat_enemy.tscn")
	if bat_scene:
		var num_bats = randi_range(3, 6)
		for i in range(num_bats):
			var bat_instance = bat_scene.instantiate()
			animated.play("summoned")
			if bat_instance:
				get_parent().add_child(bat_instance)
				var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
				bat_instance.global_position = position + offset

func _on_summon_cooldown_timeout():
	can_summon = true

# Utility functions to generate random ranges
func randi_range(min, max):
	return randi() % (max - min + 1) + min

func randf_range(min, max):
	return randf() * (max - min) + min
