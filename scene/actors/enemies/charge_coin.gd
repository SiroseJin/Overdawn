extends Sprite2D

class_name ChargeCoin

# ─── Charge Coin ──────────────────────────────────────────────────────────────────
# A blinking, slowly-spinning fake coin shown at an enemy's hands while it winds up a
# throw — the telegraph that a rigged "jackpot" is about to be flung. Pure visual;
# the enemy spawns it during the charge and frees it on release.
# ──────────────────────────────────────────────────────────────────────────────────

@export var blink_hz: float = 5.0   # blinks per second

var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	var period: float = 1.0 / max(0.1, blink_hz)
	visible = fmod(_t, period) < period * 0.62   # on ~62% of each cycle = a clear blink
	rotation += delta * 3.0
