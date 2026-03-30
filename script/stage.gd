extends Node2D

# ─── Stage ─────────────────────────────────────────────────────────────────────
# Root script for the main gameplay scene.
# Manages the wave system: spawning enemies, scaling difficulty, distributing
# loot, and transitioning back to the lobby when the player dies.
# ───────────────────────────────────────────────────────────────────────────────

# ─── Node References ───────────────────────────────────────────────────────────

@onready var scene_transition_anim = $SceneTransitionAnimation/AnimationPlayer
@onready var player_camera         = $Player/Camera2D
@onready var player                = $Player
@onready var audio_bgm             = $AudioBGM

# ─── Enemy / Item Scenes ───────────────────────────────────────────────────────

var enemy_scenes: Array = [
	preload("res://scene/bat_enemy.tscn"),
	preload("res://scene/frog_enemy.tscn"),
	preload("res://scene/witch_enemy.tscn"),
	preload("res://scene/necromancer_enemy.tscn"),
]

var item_scenes: Array = [
	preload("res://scene/coin.tscn"),
	# Add more item scenes here as the game expands
]

# Cumulative drop probabilities for items (must add up to ≤ 1.0)
var item_spawn_probabilities: Array = [0.8, 0.15, 0.05]
var max_items_to_spawn: int         = 3

# ─── Spawn Points ──────────────────────────────────────────────────────────────

@onready var spawn_points: Array = [
	$SpawnPoint1, $SpawnPoint2, $SpawnPoint3,
	$SpawnPoint4, $SpawnPoint5, $SpawnPoint6,
]

@onready var boss_spawn_points: Array = [
	$BossSpawnPoint1, $BossSpawnPoint2,
]

@onready var item_spawn_points: Array = [
	$ItemSpawnPoint1, $ItemSpawnPoint2, $ItemSpawnPoint3,
	$ItemSpawnPoint4, $ItemSpawnPoint5,
]

# ─── Wave State ────────────────────────────────────────────────────────────────

var current_wave: int          = 0
var wave_spawn_ended: bool     = false
var base_mob_wait_time: float  = 4.0   # Delay between individual mob spawns at wave 1
var min_spawn_distance: int    = 100   # Minimum distance from player for a spawn point to be valid

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	# Fade in from black at scene start
	scene_transition_anim.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_anim.play("fade_out")

	player_camera.enabled  = true
	current_wave           = 0
	Global.current_wave    = current_wave
	audio_bgm.play()

	# Verify all enemy scenes loaded correctly
	for enemy_scene in enemy_scenes:
		if enemy_scene == null:
			print("Error: An enemy scene failed to load.")
		else:
			print("Enemy scene loaded successfully.")

	position_to_next_wave()

func _process(_delta):
	# Return to lobby after a short pause when the player dies
	if !Global.playerAlive:
		await get_tree().create_timer(3.0).timeout
		Global.gameStarted = false
		scene_transition_anim.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/lobby_level.tscn")
		return

	# Advance to the next wave once all spawned enemies are dead
	if wave_spawn_ended and current_enemy_count() == 0:
		position_to_next_wave()

# ───────────────────────────────────────────────────────────────────────────────
# Wave Management
# ───────────────────────────────────────────────────────────────────────────────

# Called at the start of every new wave — heals the player, awards bonus score,
# then queues up the appropriate enemy types for the current wave number.
func position_to_next_wave():
	if current_enemy_count() != 0:
		return

	if current_wave != 0:
		Global.moving_to_next_wave = true

	wave_spawn_ended = false
	scene_transition_anim.play("between_wave")

	current_wave        += 1
	Global.current_wave  = current_wave

	# Reward the player for surviving the previous wave
	Global.PlayerBody.heal_player(5)
	Global.PlayerBody.update_health_bar()
	Global.PlayerBody.gain_score(10 * current_wave)

	await get_tree().create_timer(1.5).timeout

	# ── Enemy composition per wave ──────────────────────────────────────────
	# Bats spawn every wave, scaling ×1.15 per wave
	prepare_spawn("bats", 1.15, 3.0)

	# Frogs join from wave 3, scaling ×1.1 per wave
	if current_wave >= 3:
		prepare_spawn("frogs", 1.1, 2.0)

	# Witches join from wave 5: every 2 waves until wave 7, then every wave
	if current_wave >= 5:
		if current_wave >= 7:
			prepare_spawn("witches", 1.1, 1.0)
		elif (current_wave - 5) % 2 == 0:
			prepare_spawn("witches", 1.1, 1.0)

	# Necromancers appear from wave 10 onwards, once every 4 waves
	if current_wave >= 10 and (current_wave - 10) % 4 == 0:
		prepare_spawn("necromancers", 1.0, 1.0)

	print("Wave: ", current_wave)

	spawn_items()

# ───────────────────────────────────────────────────────────────────────────────
# Spawning
# ───────────────────────────────────────────────────────────────────────────────

# Calculate count and spacing for a mob type, then spawn them
func prepare_spawn(type: String, multiplier: float, base_amount: float):
	var mob_amount    = calculate_mob_amount(type, multiplier, base_amount)
	var mob_wait_time = calculate_mob_wait_time()
	print("Spawning %s × %d" % [type, mob_amount])
	spawn_type(type, mob_amount, mob_wait_time)

# Exponential scaling formula with a small random variance (±20%)
func calculate_mob_amount(type: String, multiplier: float, base_amount: float) -> int:
	var wave_offset = current_wave - 1

	# Each enemy type starts counting from the wave it is first introduced
	match type:
		"frogs":
			wave_offset -= 2  # Frogs first appear at wave 3
		"witches":
			wave_offset -= 9 if current_wave >= 9 else int((current_wave - 5) / 3)
		"necromancers":
			wave_offset -= 9 if current_wave >= 10 else 0

	if wave_offset < 0:
		return 0

	var mob_amount: float = base_amount * (multiplier ** wave_offset)
	mob_amount *= randf_range(1.0, 1.2)  # Add ±20% randomness
	return int(mob_amount)

# Spawn interval decreases as waves progress; slightly randomised each call
func calculate_mob_wait_time() -> float:
	var wait = base_mob_wait_time / current_wave
	wait *= randf_range(1.0, 1.4)
	return wait

# Instantiate a mob of the given type at a valid spawn point with a delay between each
func spawn_type(type: String, mob_amount: int, mob_wait_time: float):
	for i in range(mob_amount):
		var spawn_point  = select_valid_spawn_point(spawn_points)
		var mob_instance = null

		match type:
			"bats":
				mob_instance = enemy_scenes[0].instantiate()
			"frogs":
				mob_instance = enemy_scenes[1].instantiate()
			"witches":
				spawn_point  = select_valid_spawn_point(boss_spawn_points)
				mob_instance = enemy_scenes[2].instantiate()
			"necromancers":
				spawn_point  = select_valid_spawn_point(boss_spawn_points)
				mob_instance = enemy_scenes[3].instantiate()

		if mob_instance:
			mob_instance.global_position = spawn_point.global_position
			adjust_mob_attributes(mob_instance)
			add_child(mob_instance)
			mob_instance.add_to_group("enemies")
			await get_tree().create_timer(mob_wait_time).timeout

	wave_spawn_ended = true

# Scale a newly spawned mob's speed and health based on the current wave number.
# Speed is capped at a 15% increase to keep the game playable.
func adjust_mob_attributes(mob_instance):
	var speed_factor  = min(1.005 ** current_wave, 1.15)
	var health_factor = 1.005 ** current_wave

	mob_instance.speed      *= speed_factor
	mob_instance.health     *= health_factor
	mob_instance.health_max *= health_factor

# Choose a spawn point that is at least min_spawn_distance away from the player.
# Falls back to a random point if none qualify.
func select_valid_spawn_point(points: Array) -> Node:
	var valid = []
	for point in points:
		if player.global_position.distance_to(point.global_position) >= min_spawn_distance:
			valid.append(point)

	if valid.is_empty():
		return points[randi() % points.size()]

	return valid[randi() % valid.size()]

# ───────────────────────────────────────────────────────────────────────────────
# Item Spawning
# ───────────────────────────────────────────────────────────────────────────────

# Spawn 1–3 items at random item spawn points after each wave ends.
# Item count is weighted: 5% chance for 3, 15% chance for 2, otherwise 1.
func spawn_items():
	var item_count: int = 1
	var roll = randf()
	if roll < 0.05:
		item_count = 3
	elif roll < 0.2:
		item_count = 2

	var used_points = []

	for i in range(item_count):
		# Pick a unique spawn point for each item
		var point = item_spawn_points[randi() % item_spawn_points.size()]
		while point in used_points:
			point = item_spawn_points[randi() % item_spawn_points.size()]
		used_points.append(point)

		# Weighted random item selection via cumulative probability
		var item_index       = 0
		var roll2            = randf()
		var cumulative: float = 0.0
		for j in range(item_scenes.size()):
			cumulative += item_spawn_probabilities[j]
			if roll2 < cumulative:
				item_index = j
				break

		var item_instance = item_scenes[item_index].instantiate()
		var offset        = Vector2(randf_range(-75, 75), randf_range(-75, 75))
		item_instance.global_position = point.global_position + offset

		add_child(item_instance)
		item_instance.add_to_group("items")

# ───────────────────────────────────────────────────────────────────────────────
# Utilities
# ───────────────────────────────────────────────────────────────────────────────

func current_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()
