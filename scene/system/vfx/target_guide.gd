extends Node2D

# ─── Target Guide Line ─────────────────────────────────────────────────────────────
# A soft, pulsing line from the player to a `target` Node2D, in a configurable colour
# (mirrors the gold key-guide look). Set `target` to a node to show it, or null to
# hide it. Used in the boss stage: RED points to the downed boss, GREEN points to a
# server the player is dawdling on. Draws nothing while `target` is unset/invalid.
# ────────────────────────────────────────────────────────────────────────────────────

@export var line_color: Color = Color(1.0, 0.25, 0.25)
@export var arrive_distance: float = 48.0

var target: Node2D = null

var _t: float = 0.0

func _ready() -> void:
	top_level = true
	z_index = -1
	global_position = Vector2.ZERO

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target):
		return
	var player := Global.PlayerBody
	if not is_instance_valid(player):
		return
	var from: Vector2 = player.global_position + Vector2(0, -8)
	var to: Vector2 = target.global_position
	if from.distance_to(to) <= arrive_distance:
		return

	var pulse := 0.5 + 0.35 * sin(_t * 4.5)
	var glow := Color(line_color.r, line_color.g, line_color.b, pulse * 0.22)
	var core := Color(line_color.r, line_color.g, line_color.b, pulse * 0.9)
	draw_line(from, to, glow, 8.0, true)
	draw_line(from, to, core, 2.0, true)

	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := to - dir * 14.0
	draw_line(tip, tip - dir * 10.0 + perp * 7.0, core, 2.0, true)
	draw_line(tip, tip - dir * 10.0 - perp * 7.0, core, 2.0, true)
