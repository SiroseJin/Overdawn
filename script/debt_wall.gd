extends Node2D

class_name DebtWall

# ─── Debt Wall (Stage 3 gimmick) ────────────────────────────────────────────────
# A wall of red that creeps forward and never stops. Stand still and it reaches
# you; touch it and it grinds your health down. You can't out-wait it, only keep
# moving — the debt always catches up. In the boss it sweeps across on a phase and
# resets. Damage respects the player's i-frames so it pressures without one-shots.
# ───────────────────────────────────────────────────────────────────────────────

@export var speed: float    = 55.0   # advance speed (px/s)
@export var damage: int     = 25     # damage per hit while touching
@export var auto_start: bool = true
## When true, the wall wraps back to loop_reset_x after passing loop_end_x — used
## by the boss to sweep the arena repeatedly during a phase.
@export var loop: bool         = false
@export var loop_reset_x: float = -120.0
@export var loop_end_x: float   = 2520.0

@onready var _hurt: Area2D = $Hurt

var _advancing := false

func _ready() -> void:
	_advancing = auto_start

func _process(delta: float) -> void:
	if _advancing:
		position.x += speed * delta
		if loop and position.x > loop_end_x:
			position.x = loop_reset_x

	var p = Global.PlayerBody
	if is_instance_valid(p) and p.can_take_damage and _hurt.overlaps_body(p):
		p.take_damage(damage)

func start() -> void:
	_advancing = true

func stop() -> void:
	_advancing = false

# Reposition and (re)start a sweep — used by the boss between phases.
func sweep_from(x: float) -> void:
	position.x = x
	_advancing = true
