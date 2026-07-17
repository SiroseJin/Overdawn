extends Node2D

# ─── Key Guide Line (#5) ──────────────────────────────────────────────────────────
# A faint, pulsing golden line that points the player toward a key they still need,
# whenever a LockedDoor is blocking the way and they don't yet hold its key. It
# quietly does nothing in stages without a locked door / uncollected key, so it's safe
# to keep parented to the player everywhere.
#
# Story hook: "getting the key" is a mandatory objective on the anti-gambling climb —
# the guide keeps the player moving toward the real exit instead of wandering, the same
# way the game keeps steering them away from the false promise of the House. It reads
# the world through groups ("key" / "locked_door") so any stage that drops in a
# key + door gets the guidance for free — no per-stage wiring.
# ──────────────────────────────────────────────────────────────────────────────────

## How close (px) the player must be to a needed key before the line fades out — no
## point pointing at something already underfoot.
@export var arrive_distance: float = 40.0
## Only guide toward keys within this range of the player (0 = unlimited).
@export var max_range: float = 0.0
## Base colour of the guide line (alpha is animated at runtime).
@export var line_color: Color = Color(1.0, 0.85, 0.3)

var _t: float = 0.0
var _target: Node2D = null

func _ready() -> void:
	top_level = true            # draw in world space regardless of the player's transform
	z_index = -1                # sit behind actors/props
	global_position = Vector2.ZERO

func _process(delta: float) -> void:
	_t += delta
	_target = _find_needed_key()
	queue_redraw()

func _draw() -> void:
	if _target == null:
		return
	var player := Global.PlayerBody
	if not is_instance_valid(player):
		return
	var from: Vector2 = player.global_position + Vector2(0, -8)
	var to: Vector2 = _target.global_position
	var dist := from.distance_to(to)
	if dist <= arrive_distance:
		return

	var pulse := 0.5 + 0.35 * sin(_t * 4.5)
	var glow := Color(line_color.r, line_color.g, line_color.b, pulse * 0.22)
	var core := Color(line_color.r, line_color.g, line_color.b, pulse * 0.85)

	# Soft glow underlay + a crisper core line.
	draw_line(from, to, glow, 7.0, true)
	draw_line(from, to, core, 2.0, true)

	# A little chevron near the key so the destination reads clearly.
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := to - dir * 14.0
	draw_line(tip, tip - dir * 10.0 + perp * 7.0, core, 2.0, true)
	draw_line(tip, tip - dir * 10.0 - perp * 7.0, core, 2.0, true)

# Returns the nearest uncollected key whose id is required by a still-locked door.
func _find_needed_key() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	# No quest given yet → no world guidance. A fresh save with no quests shows nothing.
	if not QuestManager.has_active_quest():
		return null
	var doors := tree.get_nodes_in_group("locked_door")
	if doors.is_empty():
		return null

	# Collect the key ids that are actually still blocking a door.
	var wanted := {}
	for door in doors:
		if not is_instance_valid(door):
			continue
		if door.get("_opened") == true:
			continue
		var kid: String = str(door.get("required_key"))
		if kid != "" and not ProgressionManager.has_key(kid):
			wanted[kid] = true
	if wanted.is_empty():
		return null

	var player := Global.PlayerBody
	var origin: Vector2 = player.global_position if is_instance_valid(player) else Vector2.ZERO
	var best: Node2D = null
	var best_d := INF
	for key in tree.get_nodes_in_group("key"):
		if not is_instance_valid(key):
			continue
		var kid: String = str(key.get("key_id"))
		if not wanted.has(kid):
			continue
		var d: float = origin.distance_to(key.global_position)
		if max_range > 0.0 and d > max_range:
			continue
		if d < best_d:
			best_d = d
			best = key
	return best
