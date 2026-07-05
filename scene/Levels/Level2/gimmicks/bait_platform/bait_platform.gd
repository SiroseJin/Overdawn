extends AnimatableBody2D

class_name BaitPlatform

# ─── Bait Platform (Stage 2 gimmick) ────────────────────────────────────────────
# Looks like the best foothold in the room — it glows gold and pulses invitingly.
# The instant you trust it, it vanishes under you. The glow IS the warning; the
# plain platforms are the safe ones. It's the "near-win" made physical: the shiny
# option is the trap. Respawns after a while.
# ───────────────────────────────────────────────────────────────────────────────

@export var betray_delay: float = 0.2    # grace after landing before it drops
@export var respawn_time: float = 3.0

@onready var _col:     CollisionShape2D = $CollisionShape2D
@onready var _visual:  Polygon2D        = $Visual
@onready var _trigger: Area2D           = $Trigger

var _start: Vector2
var _triggered := false
var _pulse := 0.0

func _ready() -> void:
	sync_to_physics = true
	_start = position
	_trigger.body_entered.connect(_on_trigger)

func _process(delta: float) -> void:
	# Enticing gold pulse — the tell
	if _visual.visible:
		_pulse += delta
		var g := 0.6 + 0.4 * sin(_pulse * 9.0)
		_visual.color = Color(1.0, 0.6 + 0.3 * g, 0.15)

func _on_trigger(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	await get_tree().create_timer(betray_delay).timeout

	# Betray: no shake, no warning beyond the glow — just gone
	_col.set_deferred("disabled", true)
	_visual.visible = false

	await get_tree().create_timer(respawn_time).timeout
	position = _start
	_visual.visible = true
	_col.set_deferred("disabled", false)
	_triggered = false
