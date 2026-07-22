@tool
extends AnimatableBody2D

class_name MovingPlatform

# ─── Moving Platform ────────────────────────────────────────────────────────────
# Rides between its start and start+travel, carrying the player.
# AnimatableBody2D + physics-mode movement so standing bodies are moved with it.
#
# Travel: set the `travel` offset, or add & DRAG a child "End" marker (its position
# overrides `travel`). In the EDITOR it draws a ghost of the platform at its end.
#
# Inspector toggles:
#   • speed         — travel speed in px/s.
#   • downtime      — pause (s) at each end before heading back (auto mode only).
#   • move_on_stand — only move while the player is standing on it (otherwise it
#                     moves on its own). Great for elevators you ride.
#   • start_on_touch — sit still until the player first steps on it, THEN commit to
#                     the run and keep going to the end even after they leave. (A
#                     one-shot trigger; overrides move_on_stand's "hold to move".)
#   • auto_return   — after the end, return to start (loop). If false it makes a
#                     one-way trip and stays at the end (or, with move_on_stand,
#                     stays wherever you left it).
#   • start_active  — false = starts hidden + non-solid until activate() is called.
# ───────────────────────────────────────────────────────────────────────────────

@export var travel: Vector2 = Vector2(200, 0):
	set(v):
		travel = v
		queue_redraw()
## Travel speed in pixels per second.
@export var speed: float = 120.0
## Downtime (seconds) the platform pauses at each end before setting off again.
## Only used when it moves on its own (move_on_stand off).
@export var downtime: float = 0.3
## Only move while the player is standing on it; otherwise it moves on its own.
@export var move_on_stand: bool = false
## Sit still until the player first touches it, then run to the end on its own and
## don't stop when they step off. A one-shot trigger (takes priority over move_on_stand).
@export var start_on_touch: bool = false
## After reaching the far end, return to the start. If false: one-way trip, stays.
@export var auto_return: bool = true
## When false, the platform starts hidden + non-solid and does NOT move until
## activate() is called — e.g. a hidden lift revealed after talking to an NPC.
@export var start_active: bool = true

# ─── Skin ────────────────────────────────────────────────────────────────────────
# Set per stage so the platform matches that level's terrain tileset. Left empty it
# keeps the flat cyan look. The bright top Edge keeps its colour either way, so a
# moving platform still reads as a moving platform at a glance.
@export_group("Skin")
## Tileset texture painted onto the platform body. Empty = flat colour.
@export var skin: Texture2D:
	set(v):
		skin = v
		_apply_skin()
## Tint multiplied over the skin (white = the texture's own colours).
@export var skin_tint: Color = Color.WHITE:
	set(v):
		skin_tint = v
		_apply_skin()

const PlatformSkin = preload("res://scene/gimmicks/platform_skin.gd")
const _BASE_COLOR := Color(0.3, 0.8, 0.82, 1)   # the unskinned cyan body

func _apply_skin() -> void:
	if not is_inside_tree():
		return
	PlatformSkin.apply(get_node_or_null("Visual") as Polygon2D, skin, skin_tint, _BASE_COLOR)

var _active := false
var _awaiting_trigger := false   # start_on_touch: placed but waiting for first touch
var _start: Vector2
var _end: Vector2
var _progress: float = 0.0   # 0 = at start, 1 = at end (used by move_on_stand)
var _run_tween: Tween = null   # the automatic-run tween, so we can pause it with the game

func _game_paused() -> bool:
	return is_instance_valid(Global.PlayerBody) and Global.PlayerBody.is_game_paused

# The effective travel offset: the "End" marker child if present, else `travel`.
func _travel_offset() -> Vector2:
	var e := get_node_or_null("End")
	return e.position if e else travel

func _ready() -> void:
	_apply_skin()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	sync_to_physics = true
	if start_active:
		activate()
	else:
		_set_dormant(true)

# Reveal the platform and start it. Idempotent — safe to call more than once.
func activate() -> void:
	if _active:
		return
	_active = true
	_set_dormant(false)
	_start = position
	_end = position + _travel_offset()
	if move_on_stand:
		return   # movement is handled per-frame in _physics_process
	if start_on_touch:
		_awaiting_trigger = true   # wait for the player to step on it (see _physics_process)
		return
	_start_tween_run()

# Kick off the automatic run to the end (looping if auto_return, else one-way stay).
func _start_tween_run() -> void:
	var leg := _leg_time()
	if auto_return:
		var t := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_property(self, "position", _end, leg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(downtime)
		t.tween_property(self, "position", _start, leg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(downtime)
		_run_tween = t
	else:
		# One-way: travel to the end and stay there.
		var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_property(self, "position", _end, leg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_run_tween = t

func _leg_time() -> float:
	var dist := _travel_offset().length()
	return dist / speed if speed > 0.0 and dist > 0.0 else 2.0

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _active:
		return
	# While the game is paused, hold the platform completely still (pause its run tween
	# and skip move_on_stand stepping). An AnimatableBody2D that jumps position on the
	# resume frame flings whoever is standing on it off into the void — that was the
	# "grey/unplayable after pausing on the moving platform" bug.
	if _game_paused():
		if _run_tween and _run_tween.is_valid() and _run_tween.is_running():
			_run_tween.pause()
		return
	elif _run_tween and _run_tween.is_valid() and not _run_tween.is_running():
		_run_tween.play()
	# start_on_touch: once the player steps on, commit to the run and stop waiting.
	if _awaiting_trigger:
		if _player_on_top():
			_awaiting_trigger = false
			_start_tween_run()
		return
	if not move_on_stand:
		return
	var dist := _start.distance_to(_end)
	if dist <= 0.0:
		return
	# Advance toward the end while ridden; return toward the start when empty
	# (unless auto_return is off, in which case it just stays put).
	var dir := 0.0
	if _player_on_top():
		dir = 1.0
	elif auto_return:
		dir = -1.0
	if dir == 0.0:
		return
	_progress = clampf(_progress + dir * (speed * delta) / dist, 0.0, 1.0)
	position = _start.lerp(_end, _progress)

func _player_on_top() -> bool:
	var zone := get_node_or_null("StandZone")
	if zone == null:
		return false
	for b in zone.get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false

# Hidden + non-solid while dormant, visible + solid once revealed.
func _set_dormant(dormant: bool) -> void:
	visible = not dormant
	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", dormant)

func _process(_delta: float) -> void:
	# Keep the ghost in sync while you drag the "End" marker in the editor.
	if Engine.is_editor_hint():
		queue_redraw()

# Editor-only guide: outline the platform footprint at the far end + a travel line.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var d := _travel_offset()
	var half := Vector2(40, 8)                    # platform is 80x16, centred
	var mark := Color(0.4, 1.0, 0.7, 0.9)
	draw_line(Vector2.ZERO, d, mark, 1.5)         # travel path
	draw_rect(Rect2(d - half, half * 2.0), mark, false, 2.0)          # end ghost
	draw_rect(Rect2(-half, half * 2.0), Color(1, 1, 1, 0.5), false, 1.0)  # start
