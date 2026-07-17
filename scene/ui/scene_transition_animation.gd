extends Node2D

# ─── Scene Transition ────────────────────────────────────────────────────────────
# The fade is an AnimationPlayer, which advances by the (time-scaled) frame delta.
# Pausing sets Engine.time_scale = 0, so a fade caught mid-play would freeze — and
# since the fade overlay sits above the HUD/menus, that leaves a dark screen over
# the pause menu. To avoid that, while paused we advance the animation ourselves
# using real wall-clock time so the fade still finishes.
# ────────────────────────────────────────────────────────────────────────────────

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _rect: ColorRect = $CanvasLayer/ColorRect

var _last_usec: int = 0

const _STYLE_COUNT := 7   # fade, 4 wipes, 2 iris (see transition.gdshader)

func _ready() -> void:
	# Keep processing even if something pauses the tree (pause here uses time_scale,
	# but this is future-proof) and seed the real-time clock.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	if _anim and not _anim.animation_started.is_connected(_on_anim_started):
		_anim.animation_started.connect(_on_anim_started)

# Pick a random transition shape on each fade-out, and reuse it for the fade-in on the
# next scene so the wipe/iris continues seamlessly across the load (#18).
func _on_anim_started(anim_name: StringName) -> void:
	if _rect == null:
		return
	var mat := _rect.material as ShaderMaterial
	if mat == null:
		return
	if anim_name == "fade_in":
		# Start of a transition (screen going to black) — pick a fresh style, and stash
		# it so the next scene's fade_in-reveal uses the same shape.
		Global.transition_style = randi() % _STYLE_COUNT
		mat.set_shader_parameter("style", Global.transition_style)
	elif anim_name == "fade_out":
		mat.set_shader_parameter("style", Global.transition_style)
	elif anim_name == "between_wave":
		mat.set_shader_parameter("style", 0)   # plain fade for the arcade wave dip

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	# Only take over while the game is paused; otherwise the AnimationPlayer runs
	# normally and we must not double-advance it.
	if Engine.time_scale == 0.0 and _anim and _anim.is_playing():
		_anim.advance(real_delta)
