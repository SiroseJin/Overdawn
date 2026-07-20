extends Node2D

# ─── NPC Guide Line ────────────────────────────────────────────────────────────────
# A soft, pulsing GREEN line that points the player toward a marked NPC — used when
# an NPC (Arif) offers to help and the player accepts. It points at whatever node is
# in the `guide_group` group; clear that group (e.g. once the player reaches / talks to
# the NPC) and the line fades away. Green is used so it reads apart from the gold
# key-guide line. Safe to keep in the scene: it draws nothing while the group is empty.
# ──────────────────────────────────────────────────────────────────────────────────

@export var guide_group: String = "guide_to"
@export var arrive_distance: float = 60.0
@export var line_color: Color = Color(0.4, 1.0, 0.6)

var _t: float = 0.0

func _ready() -> void:
	top_level = true
	z_index = -1
	global_position = Vector2.ZERO

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var target: Node2D = null
	for n in tree.get_nodes_in_group(guide_group):
		if is_instance_valid(n) and n is Node2D:
			target = n
			break
	if target == null:
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
	var core := Color(line_color.r, line_color.g, line_color.b, pulse * 0.85)
	draw_line(from, to, glow, 7.0, true)
	draw_line(from, to, core, 2.0, true)

	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := to - dir * 14.0
	draw_line(tip, tip - dir * 10.0 + perp * 7.0, core, 2.0, true)
	draw_line(tip, tip - dir * 10.0 - perp * 7.0, core, 2.0, true)
