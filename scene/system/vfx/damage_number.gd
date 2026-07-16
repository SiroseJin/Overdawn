extends Node2D

# ─── Floating Damage Number ───────────────────────────────────────────────────────
# A little rising, fading number spawned at whoever just took damage — the player
# (red) or an enemy (gold). Spawned via Global.spawn_damage_number(). Frees itself.
# ──────────────────────────────────────────────────────────────────────────────────

var amount: int = 0
var color: Color = Color.WHITE

const LIFETIME := 0.7
const RISE_SPEED := 42.0

var _t: float = 0.0
@onready var label: Label = $Label

func _ready() -> void:
	label.text = str(amount)
	label.modulate = color

func _process(delta: float) -> void:
	_t += delta
	position.y -= RISE_SPEED * delta
	label.modulate.a = clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	if _t >= LIFETIME:
		queue_free()
