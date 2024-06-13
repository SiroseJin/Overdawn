extends Area2D

var speed = 270
var direction = Vector2.ZERO
const DAMAGE_AMOUNT: int = 15
@onready var sprite_2d = $Sprite2D

func _ready():
	set_process(true)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2 

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent.has_method("take_damage") and !area.get_parent() is Player:
		parent.take_damage(DAMAGE_AMOUNT)
		self.queue_free()
	else:
		pass

func _on_visible_on_screen_enabler_2d_screen_exited():
	self.queue_free()
