extends Area2D

class_name DebtPopcorn

# ─── Debt Popcorn — a fake "jackpot" spat out of the Rising Debt ─────────────────
# The debt keeps flinging shiny coins into the air like popcorn. They look like a
# way to cash out and clear what you owe — but they're the SAME rigged fake coins
# from the rest of the game. Diving off your climb to grab one only bites you and
# drops you toward the flood. The lesson, made physical: gambling to pay off a debt
# is a fool's move — the "wins" the debt throws you are all fake.
#
# Launched by rising_debt.gd via launch(); arcs up under gravity, tumbles, and
# frees itself when it falls back into the flood or its lifetime runs out.
# ────────────────────────────────────────────────────────────────────────────────

const GRAVITY := 900.0

# Rigged outcomes — a lighter echo of the full fake_coin (they come thick and fast).
const SLOW_FACTOR      := 0.7
const SLOW_DURATION    := 2.5
const DAMAGE           := 8
const REVERSE_DURATION := 3.0
const ROB_AMOUNT       := 10
enum { SLOW, DAMAGE_HIT, REVERSE, ROBBED }

## Seconds before it despawns if it hasn't already fallen back into the debt.
@export var lifetime: float = 4.0
## When false the coin is pure decoration (no bite on touch) — flip in the editor
## if you want the popcorn to be visual-only.
@export var collectible: bool = true

var _vel: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _surface_y: float = INF   # despawn once it arcs back down to the debt surface
var _age: float = 0.0
var _collected := false

# Called by the spawner right after instancing.
func launch(vel: Vector2, surface_y: float) -> void:
	_vel = vel
	_surface_y = surface_y
	_spin = randf_range(-9.0, 9.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return   # game paused (time_scale 0) — hold still
	_age += delta
	_vel.y += GRAVITY * delta
	position += _vel * delta
	rotation += _spin * delta
	# Gone once it falls back into the flood it came from, or it simply times out.
	if (_vel.y > 0.0 and global_position.y >= _surface_y) or _age >= lifetime:
		_poof(false)

func _on_body_entered(body: Node2D) -> void:
	if _collected or not collectible:
		return
	if not (body is CharacterBody2D and body.has_method("slow_down")):
		return
	# Never punish while the player is in a safe conversation.
	if "conversation_safe" in body and body.conversation_safe:
		return
	_collected = true
	AudioManager.play_sfx("debt_pop")
	_roll_effect(body)
	_poof(true)

# One random rigged outcome — same menu as the fake_coin, just cheaper.
func _roll_effect(body: Node2D) -> void:
	match randi() % 4:
		SLOW:
			if body.has_method("apply_slow"):
				body.apply_slow(SLOW_FACTOR, SLOW_DURATION)
			else:
				body.slow_down(SLOW_FACTOR)
			_toast(body, "A 'win' to clear the debt? Rigged — you're slowed.")
		DAMAGE_HIT:
			if body.has_method("take_damage"):
				body.take_damage(DAMAGE)
			_toast(body, "Chasing the debt's jackpot bites — you lose health.")
		REVERSE:
			if body.has_method("reverse_controls"):
				body.reverse_controls(REVERSE_DURATION)
			_toast(body, "Rigged payout! Your controls scramble.")
		ROBBED:
			var take: int = min(ProgressionManager.coins, ROB_AMOUNT)
			if take > 0:
				ProgressionManager.spend_coins(take)
				_toast(body, "The debt skimmed %d coins back." % take)
			else:
				_toast(body, "Nothing left for the debt to skim.")

func _toast(body: Node2D, text: String) -> void:
	if is_instance_valid(body) and body.has_method("show_toast"):
		body.show_toast(tr(text))

func _poof(picked: bool) -> void:
	var col := Color(1, 0.3, 0.25) if picked else Color(0.9, 0.4, 0.4)
	Global.spawn_burst(global_position, col, 8 if picked else 5)
	queue_free()
