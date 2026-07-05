extends Area2D

class_name PullZone

# ─── Pull Zone (Stage 4 gimmick) — a pulsing current you time & ride ─────────────
# The machine's current no longer just drags you forever. It PULSES: a gust blows
# for `active_time`, then rests for `rest_time`. The scrolling arrows telegraph the
# rhythm, so it becomes a timing/parkour beat instead of flat friction:
#   • Move or platform across during the lull (arrows dim, no push).
#   • Or punch straight through with a DASH — dashing ignores the current entirely
#     (the player's dash overrides external pushes), so the dash skill is the answer.
#   • Moving WITH the gust carries you fast; fighting it head-on is the slow, losing
#     play — the same trap as chasing the machine.
# ────────────────────────────────────────────────────────────────────────────────

@export var pull: Vector2 = Vector2(-90, 0)   # push applied while a gust is blowing
@export var pulse: bool = true                # gust on/off rhythm (off = constant)
@export var active_time: float = 1.4          # seconds the gust blows
@export var rest_time: float   = 1.0          # seconds of calm between gusts

## Patrol: the zone drifts back and forth by this offset from where it's placed
## (Vector2.ZERO = stationary). Set e.g. (600, 0) to roam horizontally.
@export var travel: Vector2 = Vector2.ZERO
@export var move_speed: float = 90.0          # patrol speed, px/s

var _bodies: Array = []          # players currently inside
var _on := true                  # is a gust currently blowing?
var _phase := 0.0                # time in the current on/off phase
var _scroll := 0.0               # arrow scroll offset
var _region := Vector2(400, 220) # drawn field size (read from the collision shape)
var _home := Vector2.ZERO         # placed position; patrol swings around it
var _move_dist := 0.0
var _move_dir := 1.0

@onready var _visual: Polygon2D = get_node_or_null("Visual")

func _ready() -> void:
	_home = position
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var cs := get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		_region = (cs.shape as RectangleShape2D).size
	# We draw our own animated arrows now.
	var old := get_node_or_null("Arrows")
	if old:
		old.visible = false

func _process(delta: float) -> void:
	# Patrol: drift back and forth along `travel` from where it was placed.
	if travel != Vector2.ZERO and move_speed > 0.0:
		var length := travel.length()
		_move_dist = clampf(_move_dist + _move_dir * move_speed * delta, 0.0, length)
		if _move_dist >= length:
			_move_dir = -1.0
		elif _move_dist <= 0.0:
			_move_dir = 1.0
		position = _home + travel.normalized() * _move_dist

	# Gust rhythm.
	if pulse:
		_phase += delta
		if _phase >= (active_time if _on else rest_time):
			_phase = 0.0
			_on = not _on
	else:
		_on = true

	if _on:
		_scroll += delta * 70.0

	# Apply the current to everyone inside — off while resting, and a dashing player
	# punches through (their dash already ignores external_push, so match that here).
	for b in _bodies:
		if not is_instance_valid(b):
			continue
		if "external_push" in b:
			var dashing: bool = ("DASH" in b) and b.DASH
			b.external_push = pull if (_on and not dashing) else Vector2.ZERO

	# Telegraph: brighten the field while a gust blows, dim it during the lull.
	if _visual:
		var m := _visual.self_modulate
		m.a = lerpf(m.a, (1.0 if _on else 0.35), delta * 8.0)
		_visual.self_modulate = m
	queue_redraw()

# Scrolling chevrons pointing along the pull direction — bright while blowing.
func _draw() -> void:
	var d := pull.normalized()
	if d == Vector2.ZERO:
		return
	var perp := Vector2(-d.y, d.x)
	var col := Color(0.85, 0.6, 1.0, 0.7 if _on else 0.2)
	var span: float = _region.x if absf(d.x) >= absf(d.y) else _region.y
	var spacing := 64.0
	var s := 13.0
	var off := fmod(_scroll, spacing)
	var n := int(span / spacing) + 2
	for i in n:
		var t := -span * 0.5 + i * spacing + off
		var c := d * t
		var tip := c + d * s
		draw_line(c - d * s + perp * s, tip, col, 3.0)
		draw_line(c - d * s - perp * s, tip, col, 3.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _bodies.has(body):
		_bodies.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
	if body.is_in_group("player") and "external_push" in body:
		body.external_push = Vector2.ZERO

# If the zone is removed (e.g. a boss phase ends) while the player is inside,
# body_exited won't fire — clear any push so they aren't dragged forever.
func _exit_tree() -> void:
	for b in _bodies:
		if is_instance_valid(b) and "external_push" in b:
			b.external_push = Vector2.ZERO
