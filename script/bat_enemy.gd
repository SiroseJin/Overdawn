extends CharacterBody2D

class_name BatEnemy

var speed = 35
var dir: Vector2
var is_bat_chase: bool
var is_bat_roaming: bool

var Player: CharacterBody2D

var health = 20
var health_max = 20
var health_min = 0
var dead = false
var taking_damage: bool
var damage_to_deal = 10
var is_dealing_damage: bool
var exp_value = 5
var score_value = 10

func _ready():
	taking_damage = false
	is_dealing_damage = false

func _process(delta):
	move(delta)
	handle_animation()
	Global.batDamageAmmount = damage_to_deal
	Global.batDamageZone = $BatDealDamageArea
	if Global.playerAlive:
		is_bat_chase = true
		is_bat_roaming = false
	else:
		is_bat_chase = false
		is_bat_roaming = true

func move(delta):
	if !dead:
		if !taking_damage and is_bat_chase and Global.playerAlive:
			Player = Global.PlayerBody
			velocity = position.direction_to(Player.position) * speed
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage and is_bat_chase:
			var knockback_dir = position.direction_to(Player.position) * -20
			velocity = knockback_dir
		elif !taking_damage and !is_bat_chase and !Global.playerAlive:
			velocity.y = 0
			velocity.x = 0
	elif dead:
		velocity.y = 0
		velocity.x = 0
	
	move_and_slide()

func handle_animation():
	var animated_sprite = $AnimatedSprite2D
	if !dead and !taking_damage and !is_dealing_damage:
		animated_sprite.play("idle")
		if dir.x == -1:
			animated_sprite.flip_h = true
		elif dir.x == 1:
			animated_sprite.flip_h = false

	elif !dead and is_dealing_damage:
		animated_sprite.play("attack")

	elif !dead and taking_damage:
		animated_sprite.play("hurt")
		await get_tree().create_timer(0.6).timeout
		taking_damage = false

	elif dead and is_bat_roaming or is_bat_chase:
		$CollisionShape2D.disabled = true
		$BatDealDamageArea/CollisionShape2D.disabled = true
		$HitBox/CollisionShape2D.disabled = true
		animated_sprite.play("death")
		await get_tree().create_timer(0.8).timeout
		handle_death()

func handle_death():
	if Global.PlayerBody:
		Global.PlayerBody.gain_exp(exp_value)
		Global.PlayerBody.gain_score(score_value)
	self.queue_free()

func _on_bat_hit_box_area_entered(area):
	if area == Global.playerDamageZone:
		var player_damage = Global.playerDamageAmount
		take_damage(player_damage)

func take_damage(player_damage):
	health -= player_damage
	taking_damage = true
	if health <= 0:
		health = 0
		dead = true
	print(str(self), "current Hp is", health)

func _on_bat_deal_damage_area_area_entered(area):
	if area == Global.playerHitbox:
		is_dealing_damage = true

func _on_bat_deal_damage_area_area_exited(area):
	if area == Global.playerHitbox:
		is_dealing_damage = false
