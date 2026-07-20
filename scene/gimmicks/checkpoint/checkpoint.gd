extends Area2D

# ─── Checkpoint ───────────────────────────────────────────────────────────────────
# Attach to an Area2D placed in a stage. The first time the player passes through, it
# becomes their respawn point (CheckpointManager), fires an auto-save and a "Checkpoint
# set" toast, and its faint indicator fades away. Triggers ONCE — standing in the area
# won't spam saves. Respects the Checkpoints setting (Global.checkpoints_enabled).
#
# The indicator is drawn (no art needed): a soft pulsing beam + a little flag, rising
# from the area's origin — which is also where the player respawns.
# ──────────────────────────────────────────────────────────────────────────────────────

## Colour of the faint indicator.
@export var indicator_color: Color = Color(0.5, 1.0, 0.75)
## Height of the indicator beam, in px.
@export var indicator_height: float = 190.0

var _triggered: bool = false
var _t: float = 0.0
var _alpha: float = 1.0

func _ready() -> void:
	# The player is on collision layer 2; detect it (areas placed in the editor default
	# to mask 1, which would never see the player).
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	# If this checkpoint is already the active one (we just respawned here), start spent
	# and hidden so it doesn't re-fire or re-show.
	if CheckpointManager.is_active_at(global_position):
		_triggered = true
		_alpha = 0.0
		visible = false

func _process(delta: float) -> void:
	if _triggered:
		return
	_t += delta
	queue_redraw()   # gentle pulse while un-reached

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	var c := indicator_color
	var glow := Color(c.r, c.g, c.b, 0.20 * _alpha * pulse)
	var core := Color(c.r, c.g, c.b, 0.45 * _alpha)
	var top := Vector2(0, -indicator_height)
	# Soft beam (wide glow + thin core).
	draw_line(Vector2.ZERO, top, glow, 10.0)
	draw_line(Vector2.ZERO, top, core, 2.0)
	# Little pennant at the top.
	draw_colored_polygon(
		PackedVector2Array([top, top + Vector2(18, 6), top + Vector2(0, 12)]),
		Color(c.r, c.g, c.b, 0.5 * _alpha))
	# Base glow.
	draw_circle(Vector2.ZERO, 8.0, glow)

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	if not Global.checkpoints_enabled:
		return
	if CheckpointManager.is_active_at(global_position):
		return   # already the active checkpoint (e.g. respawned here)
	_triggered = true
	AudioManager.play_sfx("checkpoint")
	var scene := get_tree().current_scene
	CheckpointManager.set_checkpoint(global_position, scene.scene_file_path if scene else "")
	SaveManager.autosave()
	if body.has_method("show_toast"):
		body.show_toast(tr("Checkpoint set"))
	_fade_out()

func _fade_out() -> void:
	var t := create_tween()
	t.tween_method(func(v: float):
		_alpha = v
		queue_redraw(), _alpha, 0.0, 0.6)
	t.tween_callback(func(): visible = false)
