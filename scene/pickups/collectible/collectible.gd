extends Area2D

class_name Collectible

# ─── Truth Shard (UC-004 collectible) ─────────────────────────────────────────────
# A glowing fragment. Walking into it records it permanently in ProgressionManager
# (which fires the "collectible" event for quests/badges) and reveals its truth as a
# toast. Spawned by CollectibleManager.populate(); `collectible_id` links it to lore.
# ──────────────────────────────────────────────────────────────────────────────────

@export var collectible_id: String = ""

@onready var visual: Polygon2D = $Visual

var _float_tween: Tween
var _taken := false

func _ready() -> void:
	add_to_group("collectible")
	body_entered.connect(_on_body_entered)
	# Already grabbed on a previous run? Never spawn a ghost of it.
	if collectible_id != "" and ProgressionManager.has_collectible(collectible_id):
		queue_free()
		return
	_start_float()

func _process(delta: float) -> void:
	visual.rotation += delta * 1.6   # slow shimmer-spin

func _start_float() -> void:
	var base_y := position.y
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(self, "position:y", base_y - 5.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", base_y, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	if collectible_id == "" or not ProgressionManager.collect(collectible_id):
		return
	_taken = true

	# Juice: burst + rising orb + a chime, and reveal the truth this shard carries.
	Global.spawn_burst(global_position, Color(0.4, 1.0, 0.9), 22)
	Global.spawn_fx("orb", global_position, 0.5, Color(0.5, 1.0, 0.85))
	var sfx := get_node_or_null("Sound")
	if sfx:
		sfx.play()
	if body.has_method("show_toast"):
		var lore := CollectibleManager.lore_for(collectible_id)
		body.show_toast(lore if lore != "" else tr("Truth Shard collected!"))

	_collect_anim()

func _collect_anim() -> void:
	set_deferred("monitoring", false)
	if _float_tween:
		_float_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.7, 0.14)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	# Keep the node (and its sound) alive just long enough for the chime to play.
	t.tween_interval(0.25)
	t.tween_callback(queue_free)
