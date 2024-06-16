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
	var parent = area.get_parent()
	if area.get_parent() is Player:
		parent.take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		self.queue_free()
	else:
		pass

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	self.queue_free()
