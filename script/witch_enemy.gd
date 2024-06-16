extends CharacterBody2D

class_name WitchEnemy

var speed = 40
var dir: Vector2
var is_witch_chase: bool
var is_witch_roaming: bool

var Player: CharacterBody2D

var health = 80
var health_max = 80
var health_min = 0
var dead = false
var taking_damage: bool
var damage_to_deal = 20
var is_dealing_damage: bool

var charging: bool
var charging_timer: Timer
var exp_value = 20
var score_value = 40

var health_bar

func _ready():
	is_witch_chase = true
	taking_damage = false
	charging = false
	is_dealing_damage = false
	charging_timer = Timer.new()
	charging_timer.wait_time = 5.0
	charging_timer.one_shot = true
	charging_timer.connect("timeout", Callable(self, "_on_charging_timeout"))
	add_child(charging_timer)
	health_bar = $HealthBar
	health_bar.max_value = health_max
	health_bar.value = health

func _process(delta):
	move(delta)
	handle_animation()
	Global.witchDamageAmmount = damage_to_deal
	Global.witchDamageZone = $WitchDealDamageArea
	
	if Global.playerAlive:
		is_witch_chase = true
		is_witch_roaming = false
		Player = Global.PlayerBody
		var distance_to_player = position.distance_to(Player.position)
		if distance_to_player >= 140:
			charge()
		else:
			charging = false
			charging_timer.stop()
	else:
		is_witch_chase = false
		is_witch_roaming = true

func move(delta):
	if !dead:
		is_witch_chase = true
		if !taking_damage and is_witch_chase and Global.playerAlive:
			Player = Global.PlayerBody
			if charging:
				velocity = position.direction_to(Player.position) * (speed / 2)
			else:
				velocity = position.direction_to(Player.position) * speed
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage and is_witch_chase:
			var knockback_dir = position.direction_to(Player.position) * -15
			velocity = knockback_dir
		elif !taking_damage and !is_witch_chase and !Global.playerAlive:
			velocity.y = 0
			velocity.x = 0
	elif dead:
		velocity.y = 0
		velocity.x = 0
	move_and_slide()

func handle_animation():
	var animated_sprite = $AnimatedSprite2D
	if !dead and !taking_damage and !is_dealing_damage:
		if charging:
			animated_sprite.play("charge")
		elif is_witch_chase:
			animated_sprite.play("run")
		else:
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
		$WitchDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled = true
		charging = false
		is_witch_roaming = false
		animated_sprite.play("death")
		await get_tree().create_timer(2.7).timeout
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
	health_bar.value = health

func _on_hit_box_area_entered(area):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)

func _on_witch_deal_damage_area_area_entered(area):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_witch_deal_damage_area_area_exited(area):
	if area == Global.playerHitbox:
		is_dealing_damage = false
