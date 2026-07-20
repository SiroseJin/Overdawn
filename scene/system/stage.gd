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
@onready var wave_label            = $HUD/WaveLabel

# ─── Enemy / Item Scenes ───────────────────────────────────────────────────────

var enemy_scenes: Array = [
	preload("res://scene/actors/enemies/adbot/adbot_enemy.tscn"),
	preload("res://scene/actors/enemies/bandit/bandit_enemy.tscn"),
	preload("res://scene/actors/enemies/collector/collector_enemy.tscn"),
	preload("res://scene/actors/enemies/dealer/dealer_enemy.tscn"),
]

var item_scenes: Array = [
	preload("res://scene/pickups/coin/coin.tscn"),
	preload("res://scene/pickups/health_pickup/health_pickup.tscn"),
	preload("res://scene/pickups/speed_pickup/speed_pickup.tscn"),
	preload("res://scene/pickups/fake_coin/fake_coin.tscn"),   # the gambling trap
]

# Per-item drop weights (index-aligned with item_scenes; the picker accumulates them).
var item_spawn_probabilities: Array = [0.58, 0.2, 0.12, 0.1]
var max_items_to_spawn: int         = 3

# ─── Arena gimmicks ────────────────────────────────────────────────────────────
# Platforms are rebuilt each wave so the arena changes a bit every round.
const PLAT_STATIC  := preload("res://scene/gimmicks/static_platform/static_platform.tscn")
const PLAT_MOVING  := preload("res://scene/gimmicks/moving_platform/moving_platform.tscn")
const PLAT_FALLING := preload("res://scene/gimmicks/falling_platform/falling_platform.tscn")
const BOSS_SCENE   := preload("res://scene/actors/enemies/finalboss/finalboss_enemy.tscn")

# Hazard gimmicks pulled in from the story stages (appear on later waves).
const PULL_ZONE    := preload("res://scene/Levels/Level4/gimmicks/pull_zone/pull_zone.tscn")
const DEBT_WALL    := preload("res://scene/Levels/Level6/gimmicks/debt_wall/debt_wall.tscn")
const RISING_DEBT  := preload("res://scene/Levels/Level3/gimmicks/rising_debt/rising_debt.tscn")

var _wave_platforms: Array[Node] = []

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
	# Fade in from black at scene start (the fade_out animation starts fully black).
	scene_transition_anim.play("fade_out")

	player_camera.enabled = true
	current_wave          = Global.current_wave  # 0 for fresh start, saved-1 when loading
	AudioManager.play_music("arcade")

	# Verify all enemy scenes loaded correctly
	for enemy_scene in enemy_scenes:
		if enemy_scene == null:
			print("Error: An enemy scene failed to load.")
		else:
			print("Enemy scene loaded successfully.")

	position_to_next_wave()

func _process(_delta):
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
	wave_label.text      = "Waves: %d" % current_wave
	ProgressionManager.notify("arcade_wave", {"wave": current_wave})   # repeatable quest loop

	# Reward the player for surviving the previous wave
	Global.PlayerBody.heal_player(5)
	Global.PlayerBody.update_health_bar()
	Global.PlayerBody.gain_score(10 * current_wave)

	await get_tree().create_timer(1.5).timeout

	# Fresh platform layout each wave — the arena changes a bit every round.
	_rebuild_platforms()

	if current_wave % 15 == 0:
		# Milestone every 15 waves: a boss that loosely flies around the arena.
		_spawn_boss()
	else:
		_spawn_wave_gimmicks()                          # stage hazards on later waves
		# ── Enemy composition per wave ──────────────────────────────────────────
		prepare_spawn("bats", 1.15, 3.0)               # bats every wave
		if current_wave >= 3:
			prepare_spawn("frogs", 1.1, 2.0)            # frogs from wave 3
		# Witches from wave 5 (every other wave until 7, then every wave)
		if current_wave >= 5 and (current_wave >= 7 or (current_wave - 5) % 2 == 0):
			prepare_spawn("witches", 1.1, 1.0)
		# Necromancers from wave 10, once every 4 waves
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
			wave_offset -= 9 if current_wave >= 9 else int(float(current_wave - 5) / 3.0)
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
# Arena platforms (rebuilt every wave)
# ───────────────────────────────────────────────────────────────────────────────

# Clear last wave's platforms and lay out a fresh set: a guaranteed climbable
# column plus scattered perches. More perches — and more hazardous ones (moving /
# crumbling) — appear as the waves climb.
func _rebuild_platforms() -> void:
	for p in _wave_platforms:
		if is_instance_valid(p):
			p.queue_free()
	_wave_platforms.clear()

	# Fixed GRID so platforms can never overlap or make impossible terrain:
	#   • 3 tiers, ~115px apart → each reachable from the one below with a double jump.
	#   • 5 columns, 150px apart → well clear of the 80px platform (70px gaps).
	# At most one platform per (tier, column) cell.
	var tiers := [320.0, 205.0, 90.0]
	var cols  := [-300.0, -150.0, 0.0, 150.0, 300.0]

	# Guaranteed static climb column so there is ALWAYS a route up.
	var climb: float = cols[randi() % cols.size()]
	for ty in tiers:
		_spawn_platform("static", Vector2(climb, ty))

	# Fill a fraction of the other cells (leaving gaps for a real layout). Hazard
	# platforms (moving / crumbling) get more common as the waves climb.
	var fill := clampf(0.4 + current_wave * 0.01, 0.4, 0.62)
	for ty in tiers:
		for cx in cols:
			if cx == climb:
				continue
			if randf() < fill:
				_spawn_platform(_random_platform_kind(), Vector2(cx, ty))

func _spawn_platform(kind: String, pos: Vector2) -> void:
	var p   # untyped so we can set platform-specific props (travel/speed) by duck typing
	match kind:
		"moving":
			# VERTICAL elevator only, capped below the tier gap — it stays inside its
			# own column so it can never slide into a neighbour.
			p = PLAT_MOVING.instantiate()
			p.travel = Vector2(0.0, -randf_range(35.0, 55.0))
			p.speed = randf_range(35.0, 60.0)
			p.auto_return = true
		"falling":
			p = PLAT_FALLING.instantiate()   # fake footing — crumbles when you land
		_:
			p = PLAT_STATIC.instantiate()
	p.position = pos
	add_child(p)
	p.add_to_group("arena_platform")   # so the boss steers around them
	_wave_platforms.append(p)

# Static-heavy early on; moving + crumbling platforms ramp up with the wave count.
func _random_platform_kind() -> String:
	var fall_chance   := clampf(0.05 + current_wave * 0.02, 0.05, 0.32)
	var moving_chance := clampf(0.15 + current_wave * 0.02, 0.15, 0.4)
	var r := randf()
	if r < fall_chance:
		return "falling"
	elif r < fall_chance + moving_chance:
		return "moving"
	return "static"

# ───────────────────────────────────────────────────────────────────────────────
# Stage hazard gimmicks (appear on later waves; cleared with the platforms)
# ───────────────────────────────────────────────────────────────────────────────

func _spawn_wave_gimmicks() -> void:
	# Pull-zone current (Stage 4) — a patrolling, pulsing pull. From wave 4.
	if current_wave >= 4 and randf() < 0.55:
		var z = PULL_ZONE.instantiate()
		var dir := 1.0 if randf() < 0.5 else -1.0
		z.position   = Vector2(randf_range(-140.0, 140.0), 340.0)
		z.pull       = Vector2(randf_range(70.0, 100.0) * dir, 0.0)
		z.travel     = Vector2(randf_range(300.0, 460.0) * dir, 0.0)
		z.move_speed = randf_range(55.0, 85.0)
		add_child(z)
		_wave_platforms.append(z)

	# Sweeping debt wall (Stage 3/6) — loops across; it has a passable gap. From wave 6.
	if current_wave >= 6 and randf() < 0.4:
		var w = DEBT_WALL.instantiate()
		w.position     = Vector2(-460.0, 168.0)
		w.speed        = randf_range(85.0, 130.0)
		w.damage       = 14
		w.loop         = true
		w.loop_reset_x = -460.0
		w.loop_end_x   = 460.0
		add_child(w)
		_wave_platforms.append(w)

	# Rising debt flood (Stage 3) — floods the lower arena, forcing you onto the
	# upper platforms. Every 3rd wave from 9; capped so it never drowns the whole room.
	if current_wave >= 9 and current_wave % 3 == 0:
		var r = RISING_DEBT.instantiate()
		r.position   = Vector2(0.0, 470.0)     # top edge just below the floor
		r.rise_speed = randf_range(6.0, 9.0)
		r.damage     = 12
		r.min_top_y  = 235.0                    # stops after covering the lower arena
		r.scale      = Vector2(0.55, 1.0)       # narrow it toward the arena width
		add_child(r)
		_wave_platforms.append(r)

# ───────────────────────────────────────────────────────────────────────────────
# Boss wave
# ───────────────────────────────────────────────────────────────────────────────

# Server positions sitting on top of the wave's STATIC platforms (never a moving or
# crumbling one, never inside a platform). Always ≥3 (the climb column is static).
func _server_spots_on_platforms() -> Array:
	var statics: Array = []
	for n in _wave_platforms:
		if is_instance_valid(n) and n is StaticBody2D:
			statics.append(n)
	statics.shuffle()
	var spots: Array = []
	for i in mini(5, statics.size()):
		spots.append(statics[i].position + Vector2(0.0, -18.0))
	return spots

func _spawn_boss() -> void:
	# A loose patrol LOOP around the upper arena (kept clear of the floor). The boss
	# drifts slowly along it with a gentle wobble — a lazy patrol, not a fast circle.
	var path := Path2D.new()
	path.name = "BossPatrolPath"
	var curve := Curve2D.new()
	for pt in [Vector2(-300, 110), Vector2(0, 60), Vector2(300, 110),
			Vector2(320, 250), Vector2(0, 320), Vector2(-320, 250), Vector2(-300, 110)]:
		curve.add_point(pt)
	path.curve = curve
	add_child(path)
	_wave_platforms.append(path)   # cleared with the wave once the boss is down

	var boss := BOSS_SCENE.instantiate() as FinalBossEnemy
	boss.position          = Vector2(-300.0, 110.0)   # start on the path
	boss.wait_for_summon   = false          # wake on its own
	boss.activation_x      = -100000.0      # ...immediately
	boss.use_path          = true           # loosely PATROL the loop...
	boss.path_node         = NodePath("../BossPatrolPath")
	boss.path_speed        = 55.0           # ...slowly (ramps up as its HP drops)
	boss.orbit_radius      = 34.0           # gentle wobble on top, not a wide fast circle
	boss.orbit_speed       = 1.2
	boss.health_max        = 200.0 + current_wave * 5.0   # tougher each milestone
	boss.avoid_platforms   = true           # steer around platforms, don't phase through
	# Servers sit ON TOP of the static platforms this wave, so they're always reachable
	# and never buried inside a platform.
	boss.server_spots = _server_spots_on_platforms()
	add_child(boss)
	boss.add_to_group("enemies")            # counts toward the wave being cleared
	wave_spawn_ended = true

# ───────────────────────────────────────────────────────────────────────────────
# Utilities
# ───────────────────────────────────────────────────────────────────────────────

func current_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()
