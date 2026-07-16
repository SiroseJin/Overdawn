extends Area2D

class_name RisingDebt

# ─── Rising Debt (Stage 3 gimmick) ──────────────────────────────────────────────
# A slow flood of debt that creeps upward. Stay above it; fall too far / too often
# and it catches you (chip damage that respects the player's i-frames). It pauses
# while the player is in a conversation, so talking to a rest-ledge NPC is always
# safe. Place it so its top edge sits just below the floor and it rises from there.
# Scale the node horizontally to make the flood wider/narrower.
# ───────────────────────────────────────────────────────────────────────────────

@export var rise_speed: float = 6.0   # px/s — how fast the debt floods upward
@export var damage: int      = 12     # chip damage per hit
## The debt stops rising once its top reaches this world Y (a smaller Y = higher).
## Used by arcade so the flood only covers the lower arena instead of drowning it.
@export var min_top_y: float = -100000.0

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

func _ready() -> void:
	var cs := get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		_half_w = (cs.shape as RectangleShape2D).size.x * 0.5

func _process(delta: float) -> void:
	var p = Global.PlayerBody
	# Freeze the debt while the player is talking so conversations are safe.
	var talking: bool = is_instance_valid(p) and p.conversation_safe
	if not talking and position.y > min_top_y:
		position.y -= rise_speed * delta
	if is_instance_valid(p) and p.can_take_damage and overlaps_body(p):
		p.take_damage(damage)

	# Popcorn spray (paused during conversations, same as the flood itself).
	if spew_popcorn and not talking and popcorn_scene:
		_pop_timer += delta
		if _pop_timer >= popcorn_interval:
			_pop_timer = 0.0
			_spew_popcorn()

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
