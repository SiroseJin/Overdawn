extends Node2D

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var player_camera = $Player/Camera2D
@onready var player = $Player
@onready var audio_bgm = $AudioBGM

var current_wave: int

# Enemies
var enemy_scenes: Array = [
	preload("res://scene/bat_enemy.tscn"),
	preload("res://scene/frog_enemy.tscn"),
	preload("res://scene/witch_enemy.tscn"),
	preload("res://scene/necromancer_enemy.tscn")
]

# Items
var item_scenes: Array = [
	preload("res://scene/coin.tscn"),
	# Add more item paths here
]
var item_spawn_probabilities: Array = [0.8, 0.15, 0.05] # Probabilities for each item to spawn
var max_items_to_spawn: int = 3
var starting_nodes: int
var current_nodes: int
var wave_spawn_ended: bool

@onready var spawn_points = [
	$SpawnPoint1, $SpawnPoint2, $SpawnPoint3, 
	$SpawnPoint4, $SpawnPoint5, $SpawnPoint6
]
@onready var boss_spawn_points = [
	$BossSpawnPoint1, $BossSpawnPoint2
]

@onready var item_spawn_points = [
	$ItemSpawnPoint1, $ItemSpawnPoint2, $ItemSpawnPoint3, $ItemSpawnPoint4, $ItemSpawnPoint5
]

var base_mob_wait_time: float = 4.0
var current_mob_wait_time: float

var min_spawn_distance = 100

# Called when the node enters the scene tree for the first time.
func _ready():
	SceneTransitionAnimation.get_parent().get_node("ColorRect").color.a = 255
	SceneTransitionAnimation.play("fade_out")
	
	player_camera.enabled = true
	current_wave = 0
	Global.current_wave = current_wave
	starting_nodes = get_child_count()
	current_nodes = get_child_count()
	audio_bgm.play()
	
	# Check if PackedScenes are not null
	for enemy_scene in enemy_scenes:
		if enemy_scene == null:
			print("Error: Enemy scene is null")
		else:
			print("Enemy scene loaded successfully")
	
	position_to_next_wave()

func position_to_next_wave():
	if current_enemy_count() == 0:
		if current_wave != 0:
			Global.moving_to_next_wave = true
		wave_spawn_ended = false
		SceneTransitionAnimation.play("between_wave")
		current_wave += 1
		Global.current_wave = current_wave
		Global.PlayerBody.heal_player(5)
		Global.PlayerBody.update_health_bar()
		Global.PlayerBody.gain_score(10 * current_wave)
		await get_tree().create_timer(1.5).timeout
		
		# Determine which enemies/items to spawn based on current wave
		prepare_spawn("bats", 1.15, 3.0) # Bats increase by 1.15 each wave
		if current_wave >= 3:
			prepare_spawn("frogs", 1.1, 2.0) # Frogs increase by 1.1 every wave after wave 3
		if current_wave >= 5:
			if current_wave >= 7:
				prepare_spawn("witches", 1.1, 1.0) # Witches spawn every wave after wave 9
			elif (current_wave - 5) % 2 == 0:
				prepare_spawn("witches", 1.1, 1.0) # Witches increase by 1 every 2 waves after wave 5
		if current_wave >= 10 and (current_wave - 10) % 4 == 0:
			prepare_spawn("necromancers", 1.0, 1.0) # Necromancers spawn every 4 waves after wave 10

		print(current_wave)

		spawn_items() # Spawn items after a wave ends

func prepare_spawn(type, multiplier, base_amount):
	var mob_amount = calculate_mob_amount(type, multiplier, base_amount)
	var mob_wait_time = calculate_mob_wait_time()
	print("Preparing spawn for type: ", type)
	print("mob_amount: ", mob_amount)
	spawn_type(type, mob_amount, mob_wait_time)

func calculate_mob_amount(type, multiplier, base_amount):
	var wave_offset = current_wave - 1
	if type == "frogs":
		wave_offset -= 2 # Frogs start from wave 3
	elif type == "witches":
		wave_offset -= 9 if current_wave >= 9 else int((current_wave - 5) / 3) # Witches every 3 waves starting from wave 5
	elif type == "necromancers":
		wave_offset -= 9 if current_wave >= 10 else 0 # Necromancers spawn after wave 10, every 4 waves
	
	if wave_offset < 0:
		return 0

	var mob_amount = base_amount * (multiplier ** wave_offset)
	# Introduce randomness to mob_amount
	var random_factor = randf_range(1, 1.2) # Random factor between 1.0 and 1.2
	mob_amount *= random_factor
	return int(mob_amount)

func calculate_mob_wait_time():
	# Adjust mob_wait_time based on the current wave
	var mob_wait_time = base_mob_wait_time / current_wave
	# Introduce randomness to mob_wait_time
	var random_factor = randf_range(1, 1.4) # Random factor between 1.0 and 1.4
	mob_wait_time *= random_factor
	return mob_wait_time

func spawn_type(type, mob_amount, mob_wait_time):
	for i in range(mob_amount):
		var spawn_point = select_valid_spawn_point(spawn_points)
		var mob_instance
		if type == "bats":
			mob_instance = enemy_scenes[0].instantiate()
		elif type == "frogs":
			mob_instance = enemy_scenes[1].instantiate()
		elif type == "witches":
			spawn_point = select_valid_spawn_point(boss_spawn_points)
			mob_instance = enemy_scenes[2].instantiate()
		elif type == "necromancers":
			spawn_point = select_valid_spawn_point(boss_spawn_points)
			mob_instance = enemy_scenes[3].instantiate()

		if mob_instance:
			mob_instance.global_position = spawn_point.global_position
			adjust_mob_attributes(mob_instance)
			add_child(mob_instance)
			mob_instance.add_to_group("enemies")
			await get_tree().create_timer(mob_wait_time).timeout

	wave_spawn_ended = true

func adjust_mob_attributes(mob_instance):
	# Calculate the 0.5% per wave increase
	var speed_increase_factor = 1.005 ** current_wave
	var health_increase_factor = 1.005 ** current_wave

	# Cap the speed increase to a maximum of 15%
	var max_speed_increase = 1.15
	if speed_increase_factor > max_speed_increase:
		speed_increase_factor = max_speed_increase

	# Apply the increase factors to speed, health, and health_max
	mob_instance.speed *= speed_increase_factor
	mob_instance.health *= health_increase_factor
	mob_instance.health_max *= health_increase_factor

func _process(delta):
	if !Global.playerAlive:
		await get_tree().create_timer(3.0).timeout
		Global.gameStarted = false
		SceneTransitionAnimation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/lobby_level.tscn")
		return

	if wave_spawn_ended and current_enemy_count() == 0:
		position_to_next_wave()

func select_valid_spawn_point(spawn_points):
	var valid_spawn_points = []
	for spawn_point in spawn_points:
		if player.global_position.distance_to(spawn_point.global_position) >= min_spawn_distance:
			valid_spawn_points.append(spawn_point)
	
	if valid_spawn_points.size() == 0:
		return spawn_points[randi() % spawn_points.size()]
	
	return valid_spawn_points[randi() % valid_spawn_points.size()]

func spawn_items():
	var item_count = 1
	var rand_val = randf()
	if rand_val < 0.05:
		item_count = 3
	elif rand_val < 0.2:
		item_count = 2

	var used_spawn_points = []
	for i in range(item_count):
		var spawn_point = item_spawn_points[randi() % item_spawn_points.size()]
		while spawn_point in used_spawn_points:
			spawn_point = item_spawn_points[randi() % item_spawn_points.size()]
		used_spawn_points.append(spawn_point)

		var random_item_index = 0
		var rand_val2 = randf()
		var cumulative_probability = 0.0
		for j in range(item_scenes.size()):
			cumulative_probability += item_spawn_probabilities[j]
			if rand_val2 < cumulative_probability:
				random_item_index = j
				break

		var item_scene = item_scenes[random_item_index]
		var item_instance = item_scene.instantiate()
		var offset = Vector2(randf_range(-75, 75), randf_range(-75, 75))
		item_instance.global_position = spawn_point.global_position + offset
		
		add_child(item_instance)
		item_instance.add_to_group("items")

func current_enemy_count():
	return get_tree().get_nodes_in_group("enemies").size()

