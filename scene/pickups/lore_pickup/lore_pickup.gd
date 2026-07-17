extends Area2D

class_name LorePickup

# ─── Lore Pickup (#10) ─────────────────────────────────────────────────────────────
# A placeable, movable lore fragment. Drop it anywhere in a stage in the editor and set
# its `lore_id` to any entry in CodexManager.LORE — walking into it unlocks that lore in
# the Codex instead of it being tied to a coded story event. Because it reads its id from
# an @export, you can move these around freely without touching code.
#
# Story hook: the truth about the machine is scattered — you find it by exploring and
# refusing to look away, not by being handed it. Already-unlocked lore never re-spawns.
# ──────────────────────────────────────────────────────────────────────────────────────

## Which CodexManager.LORE entry this pickup reveals (e.g. "l_house").
@export var lore_id: String = ""

@onready var _visual: Node2D = get_node_or_null("Visual")

var _float_tween: Tween
var _taken := false

func _ready() -> void:
	add_to_group("lore_pickup")
	body_entered.connect(_on_body_entered)
	# Already revealed on a previous run? Don't spawn a ghost of it.
	if lore_id != "" and CodexManager.is_lore_unlocked(lore_id):
		queue_free()
		return
	_start_float()

func _process(delta: float) -> void:
	if _visual:
		_visual.rotation += delta * 1.4   # gentle shimmer-spin

func _start_float() -> void:
	var base_y := position.y
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(self, "position:y", base_y - 5.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", base_y, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	if lore_id == "" or CodexManager.is_lore_unlocked(lore_id):
		return
	_taken = true
	CodexManager.unlock_lore(lore_id)   # fires the "Lore Unlocked" toast itself

	# Juice: a warm gold burst + rising orb + chime.
	Global.spawn_burst(global_position, Color(1.0, 0.85, 0.4), 20)
	Global.spawn_fx("orb", global_position, 0.5, Color(1.0, 0.86, 0.45))
	var sfx := get_node_or_null("Sound")
	if sfx:
		sfx.play()

	_collect_anim()

func _collect_anim() -> void:
	set_deferred("monitoring", false)
	if _float_tween:
		_float_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.7, 0.14)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	t.tween_interval(0.25)   # let the chime finish
	t.tween_callback(queue_free)
