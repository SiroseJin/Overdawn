extends Area2D
class_name WitchFireball

@export var speed: int = 240
var direction: Vector2 = Vector2.ZERO
@onready var animated_sprite_2d = $AnimatedSprite2D

const DAMAGE_AMOUNT: int = 40

func _ready():
	set_process(true)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2 

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		area.get_parent().take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		speed = 0
		await get_tree().create_timer(0.5).timeout
		self.queue_free()
	elif area.get_parent() is CoinItem or area.get_parent() is BatEnemy or area.get_parent() is FrogEnemy or area.get_parent() is WitchEnemy or area.get_parent() is NecroEnemy:
		pass
	else:
		self.queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	self.queue_free()
