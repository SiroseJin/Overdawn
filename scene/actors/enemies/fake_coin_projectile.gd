extends Area2D

class_name FakeCoinProjectile

# ─── Fake Coin Projectile ─────────────────────────────────────────────────────────
# A rigged "jackpot" the gambling enemies (Collector, Dealer) hurl at the player,
# alongside their normal ranged attack. Flies straight, spins, and on contact rolls
# one of the fake-coin losses — the same trap as the pickup, made into a weapon.
# ──────────────────────────────────────────────────────────────────────────────────

const SLOW_FACTOR      := 0.7
const SLOW_DURATION    := 3.0
const DAMAGE           := 12
const REVERSE_DURATION := 3.0
const ROB_AMOUNT       := 12
enum { SLOW, DAMAGE_HIT, REVERSE, ROBBED }

@export var speed: float         = 210.0
@export var lifetime: float      = 6.0
@export var cull_distance: float = 1500.0
const ARM_TIME: float = 0.08   # can't hit anything until it clears the caster

var direction: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _spent := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	AudioManager.play_sfx("fake_coin_shot")   # tempting jackpot chime flung at the player

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_age += delta
	position += direction * speed * delta
	if is_instance_valid(sprite):
		sprite.rotation += delta * 8.0   # spin so it reads as a coin
	if _age >= lifetime:
		queue_free()
		return
	if is_instance_valid(Global.PlayerBody) \
			and global_position.distance_to(Global.PlayerBody.global_position) > cull_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _spent or _age < ARM_TIME:
		return
	if not (body is CharacterBody2D and body.has_method("slow_down")):
		return
	if "conversation_safe" in body and body.conversation_safe:
		return
	_spent = true
	_roll(body)
	Global.spawn_burst(global_position, Color(1, 0.3, 0.25), 14)   # rigged — red pop
	queue_free()

func _roll(body: Node2D) -> void:
	match randi() % 4:
		SLOW:
			if body.has_method("apply_slow"):
				body.apply_slow(SLOW_FACTOR, SLOW_DURATION)
			else:
				body.slow_down(SLOW_FACTOR)
			_toast(body, "Rigged coin! You're slowed.")
		DAMAGE_HIT:
			if body.has_method("take_damage"):
				body.take_damage(DAMAGE)
			_toast(body, "Rigged coin! It bites — you lose health.")
		REVERSE:
			if body.has_method("reverse_controls"):
				body.reverse_controls(REVERSE_DURATION)
			_toast(body, "Rigged coin! Your controls scramble.")
		ROBBED:
			var take: int = min(ProgressionManager.coins, ROB_AMOUNT)
			if take > 0:
				ProgressionManager.spend_coins(take)
				_toast(body, "Rigged coin! The house skimmed %d coins." % take)
			else:
				_toast(body, "Rigged coin! Nothing left to skim.")

func _toast(body: Node2D, text: String) -> void:
	if is_instance_valid(body) and body.has_method("show_toast"):
		body.show_toast(tr(text))
