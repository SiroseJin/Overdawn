extends Area2D

class_name Collectible

# ─── Truth Shard (UC-004 collectible) ─────────────────────────────────────────────
# A glowing fragment you gather across the stages. Drop instances of this scene right
# into a level in the editor and drag them wherever you like — no code needed. Walking
# into one records it permanently (ProgressionManager) and unlocks the NEXT Lore entry:
# lore is gated by HOW MANY shards you've collected (1 shard → lore 1, 2 → lore 2, …),
# not by which specific shard, so order and placement are entirely up to you.
#
# Identity (so a grabbed shard stays grabbed and never double-counts): set `collectible_id`
# for a stable hand-authored id, or leave it blank and one is derived from the shard's
# place in the scene. Collected state lives in ProgressionManager (persisted).
# ──────────────────────────────────────────────────────────────────────────────────

## Stable id used to remember this shard was taken. Leave BLANK on shards you drag in —
## a unique id is derived from its stage + position in the scene tree.
@export var collectible_id: String = ""
## Optional flavour line shown when picked up (leave blank for a generic message).
@export_multiline var truth_en: String = ""
@export_multiline var truth_id: String = ""

@onready var visual: Node2D = get_node_or_null("Visual")

var _float_tween: Tween
var _taken := false

func _ready() -> void:
	add_to_group("collectible")
	body_entered.connect(_on_body_entered)
	# Already grabbed on a previous run? Never spawn a ghost of it.
	if ProgressionManager.has_collectible(_id()):
		queue_free()
		return
	_start_float()

# A stable identity for this physical shard. Hand-set id wins; otherwise derive one from
# the stage file + this node's path, which is unique and survives reloads.
func _id() -> String:
	if collectible_id != "":
		return collectible_id
	var scn := get_tree().current_scene
	if scn == null:
		return "shard:" + str(name)
	return "shard:%s:%s" % [scn.scene_file_path.get_file().get_basename(), str(scn.get_path_to(self))]

# Which stage this shard sits in (for stage-scoped quests/badges), from the scene file.
func _stage_id() -> String:
	var scn := get_tree().current_scene
	return scn.scene_file_path.get_file().get_basename() if scn else ""

func _process(delta: float) -> void:
	if visual:
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
	# collect() records it, bumps the count, and fires the "collectible" event that
	# unlocks the next lore by count (see CodexManager). Returns false if already taken.
	if not ProgressionManager.collect(_id(), {"stage": _stage_id()}):
		return
	_taken = true

	# Juice: burst + rising orb + a chime, and reveal the truth this shard carries.
	AudioManager.play_sfx("shard")
	Global.spawn_burst(global_position, Color(0.4, 1.0, 0.9), 22)
	Global.spawn_fx("orb", global_position, 0.5, Color(0.5, 1.0, 0.85))
	var sfx := get_node_or_null("Sound")
	if sfx:
		sfx.play()
	if body.has_method("show_toast"):
		var t := _truth()
		body.show_toast(t if t != "" else tr("Truth Shard collected!"))

	_collect_anim()

# Flavour line: this shard's own text if set, else fall back to the shared data table.
func _truth() -> String:
	var is_id := TranslationServer.get_locale().begins_with("id")
	if is_id and truth_id != "":
		return truth_id
	if not is_id and truth_en != "":
		return truth_en
	return CollectibleManager.lore_for(collectible_id)

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
