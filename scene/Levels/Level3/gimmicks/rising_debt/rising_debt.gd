@tool
extends Area2D

class_name RisingDebt

# ─── Rising Debt (Stage 3 gimmick) ──────────────────────────────────────────────
# A slow flood of debt that creeps upward. Stay above it; fall too far / too often
# and it catches you (chip damage that respects the player's i-frames). It pauses
# while the player is in a conversation, so talking to a rest-ledge NPC is always
# safe. Place it so its top edge sits just below the floor and it rises from there.
# Scale the node horizontally to make the flood wider/narrower.
# ───────────────────────────────────────────────────────────────────────────────

## Flood size — drag these in the inspector to resize the debt to fit the stage. The
## body, bright edge, and damage collision all resize together (updates live in-editor).
@export var flood_width: float = 1720.0:
	set(v):
		flood_width = maxf(1.0, v)
		_apply_size()
@export var flood_height: float = 2600.0:
	set(v):
		flood_height = maxf(1.0, v)
		_apply_size()

@export var rise_speed: float = 6.0   # px/s — how fast the debt floods upward
@export var damage: int      = 12     # chip damage per hit
## The debt stops rising once its top reaches this world Y (a smaller Y = higher).
## Used by arcade so the flood only covers the lower arena instead of drowning it.
@export var min_top_y: float = -100000.0
## Scale the rise speed by the save's difficulty (Casual -20% … Expert +20%).
## Arcade turns this off — arcade is exempt from difficulty scaling.
@export var speed_scales_with_difficulty: bool = true

# ─── Staged rise ────────────────────────────────────────────────────────────────
# The debt doesn't drown the whole tower at once. It floods to a first ceiling —
# just below the key — and holds there, so the climb to the key is pressured but
# survivable. Take the key and the debt comes for you again: paying off one debt
# doesn't end it, it just buys the quiet before the next rise.
@export_group("Staged rise")
## Phase 1 ceiling: the flood stops `first_stop_gap` px BELOW this node (the stage's
## key). Leave empty for a debt that rises straight to `min_top_y` with no hold.
@export var first_stop_target: NodePath
## How far below the target the flood holds — ~3x the player's jump height, so the
## key sits clearly above the waterline while you climb for it.
@export var first_stop_gap: float = 195.0
## Collecting this key releases the flood. Empty = never release (holds forever).
@export var release_on_key: String = ""
## Calm beat between taking the key and the debt resuming its climb.
@export var release_delay: float = 2.0

# ─── Enemy damage ────────────────────────────────────────────────────────────────
# The debt doesn't pick sides: anything caught under the waterline drowns, enemies
# included. Thematically the House's own foot soldiers go under with everyone else;
# practically it means retreating upward is rewarded instead of just running away.
# Enemies have no i-frames, so this is paced on its own interval rather than every
# frame (which would delete them instantly).
@export_group("Enemy damage")
@export var damages_enemies: bool = true
@export var enemy_damage: int = 12
@export var enemy_damage_interval: float = 1.0
var _enemy_tick: float = 0.0

# ─── Fake-coin popcorn ───────────────────────────────────────────────────────────
# The debt keeps spitting fake "jackpot" coins into the air like popcorn — a shiny
# promise that you can win your way out of what you owe. They're the same rigged
# fake coins; grabbing one bites. It's the lesson made physical: gambling to clear
# a debt is folly. All tunable from the inspector.
@export_group("Fake-coin popcorn")
## Spit fake coins out of the debt surface. Turn off for a plain flood.
@export var spew_popcorn: bool = true
## The coin that gets flung. Swap for any scene with a launch(vel, surface_y) method.
@export var popcorn_scene: PackedScene = preload("res://scene/Levels/Level3/gimmicks/rising_debt/debt_popcorn.tscn")
@export var popcorn_interval: float = 0.6   # seconds between pops
@export var popcorn_per_pop: int    = 2     # coins flung each pop
@export var popcorn_launch: float   = 320.0 # upward launch speed (px/s)
## Coins pop within this horizontal band around the player, so the shower stays on
## screen instead of scattering across the whole (very wide) flood.
@export var popcorn_spread_x: float = 520.0

var _half_w: float = 860.0   # half the flood width (read from the collision shape)
var _pop_timer: float = 0.0

var _speed_mult: float   = 1.0
var _first_stop_y: float = -INF   # phase-1 ceiling in parent space (-INF = no hold)
var _released: bool      = true   # false while the debt is holding below the key
var _release_timer: float = 0.0

func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	if speed_scales_with_difficulty:
		_speed_mult = Difficulty.debt_speed_mult()
	_setup_first_stop()
	AudioManager.attach_loop(self, "rising_debt", -6.0)   # slow dread bed while the debt floods

# Work out the phase-1 ceiling from the target node. Cached now because the key is
# freed the moment it's collected — we can't ask it for its position later.
func _setup_first_stop() -> void:
	if first_stop_target.is_empty() or release_on_key.is_empty():
		return
	var target := get_node_or_null(first_stop_target) as Node2D
	if target == null:
		push_warning("RisingDebt: first_stop_target '%s' not found — flood will rise unchecked." % first_stop_target)
		return
	var origin: Vector2 = target.global_position
	var parent := get_parent() as Node2D
	var ty: float = parent.to_local(origin).y if parent else origin.y
	_first_stop_y = ty + first_stop_gap
	# Already holding the key (loaded save / backtracked into the stage)? Then the
	# debt has nothing left to wait for — let it rise freely from the start.
	_released = ProgressionManager.has_key(release_on_key)

# Resize the flood's body, bright edge, and damage collision to flood_width/height.
func _apply_size() -> void:
	if not is_inside_tree():
		return
	var hw := flood_width * 0.5
	_half_w = hw
	var body := get_node_or_null("Body") as Polygon2D
	if body:
		body.polygon = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, flood_height), Vector2(-hw, flood_height)])
	var edge := get_node_or_null("Edge") as Polygon2D
	if edge:
		edge.polygon = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, 8), Vector2(-hw, 8)])
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var shp := cs.shape as RectangleShape2D
		if not shp.resource_local_to_scene:      # don't resize a shape shared by other instances
			shp = shp.duplicate()
			cs.shape = shp
		shp.size = Vector2(flood_width, flood_height)
		cs.position = Vector2(0, flood_height * 0.5)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var p = Global.PlayerBody
	# Freeze the debt while the player is talking so conversations are safe.
	var talking: bool = is_instance_valid(p) and p.conversation_safe
	if not talking:
		_update_release(delta)
		if position.y > _ceiling():
			position.y -= rise_speed * _speed_mult * delta
	if is_instance_valid(p) and p.can_take_damage and overlaps_body(p):
		p.take_damage(damage)

	# The debt drowns enemies too (paced — they have no i-frames of their own).
	if damages_enemies and not talking:
		_enemy_tick -= delta
		if _enemy_tick <= 0.0:
			_enemy_tick = maxf(0.1, enemy_damage_interval)
			_drown_enemies()

	# Popcorn spray (paused during conversations, same as the flood itself).
	if spew_popcorn and not talking and popcorn_scene:
		_pop_timer += delta
		if _pop_timer >= popcorn_interval:
			_pop_timer = 0.0
			_spew_popcorn()

# How high the debt may climb right now: the phase-1 ceiling while it's holding
# below the key, the stage's true limit once it's been released.
func _ceiling() -> float:
	return min_top_y if _released else maxf(min_top_y, _first_stop_y)

# Watch for the key, then count down the calm beat before the debt climbs again.
func _update_release(delta: float) -> void:
	if _released:
		return
	if _release_timer > 0.0:
		_release_timer -= delta
		if _release_timer <= 0.0:
			_released = true
	elif ProgressionManager.has_key(release_on_key):
		_release_timer = release_delay

# Chip every enemy whose origin is under the waterline. Tested geometrically against
# the flood rect rather than through the Area2D: the damage collision only masks the
# player's layer, and widening that mask would make every enemy body push the flood
# around. Enemies register themselves in the "enemies" group in their _ready.
func _drown_enemies() -> void:
	var half_w: float  = _half_w * absf(global_scale.x)
	var depth: float   = flood_height * absf(global_scale.y)
	var top: float     = global_position.y
	var left: float    = global_position.x - half_w
	var right: float   = global_position.x + half_w
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D) or not e.has_method("take_damage"):
			continue
		if "dead" in e and e.dead:
			continue
		var at: Vector2 = (e as Node2D).global_position
		if at.y < top or at.y > top + depth or at.x < left or at.x > right:
			continue
		e.take_damage(float(enemy_damage))

func _spew_popcorn() -> void:
	var host := get_parent()
	if host == null:
		return
	var surface_y: float = global_position.y   # the bright top edge of the flood
	var cx: float = global_position.x
	if is_instance_valid(Global.PlayerBody):
		cx = Global.PlayerBody.global_position.x
	for _i in max(1, popcorn_per_pop):
		var coin := popcorn_scene.instantiate()
		host.add_child(coin)   # sibling of the debt so it isn't carried up with it
		var x := clampf(cx + randf_range(-popcorn_spread_x, popcorn_spread_x),
			global_position.x - _half_w, global_position.x + _half_w)
		coin.global_position = Vector2(x, surface_y)
		if coin.has_method("launch"):
			var vx := randf_range(-150.0, 150.0)
			var vy := -popcorn_launch * randf_range(0.75, 1.15)
			coin.launch(Vector2(vx, vy), surface_y)
