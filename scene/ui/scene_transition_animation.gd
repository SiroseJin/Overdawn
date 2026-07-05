extends Node2D

# ─── Scene Transition ────────────────────────────────────────────────────────────
# The fade is an AnimationPlayer, which advances by the (time-scaled) frame delta.
# Pausing sets Engine.time_scale = 0, so a fade caught mid-play would freeze — and
# since the fade overlay sits above the HUD/menus, that leaves a dark screen over
# the pause menu. To avoid that, while paused we advance the animation ourselves
# using real wall-clock time so the fade still finishes.
# ────────────────────────────────────────────────────────────────────────────────

@onready var _anim: AnimationPlayer = $AnimationPlayer

var _last_usec: int = 0

func _ready() -> void:
	# Keep processing even if something pauses the tree (pause here uses time_scale,
	# but this is future-proof) and seed the real-time clock.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	# Only take over while the game is paused; otherwise the AnimationPlayer runs
	# normally and we must not double-advance it.
	if Engine.time_scale == 0.0 and _anim and _anim.is_playing():
		_anim.advance(real_delta)
