extends Area2D
class_name NecroSlowOb

@export var speed: int = 150
var direction: Vector2 = Vector2.ZERO
@onready var animated_sprite_2d = $AnimatedSprite2D
@export var necro_dot_field_scene: PackedScene = preload("res://scene/dot_field.tscn")

const DAMAGE_AMOUNT: int = 10

func _ready():
	set_process(true)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if direction.length() > 0:
		rotation = direction.angle() + PI / 2 

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player:
		parent.take_damage(DAMAGE_AMOUNT)
		animated_sprite_2d.play("hit")
		summon_necro_dot_field()
		self.queue_free()
	else:
		pass

func summon_necro_dot_field():
	if necro_dot_field_scene:
		print("Instancing NecroDotField")
		var dot_field = necro_dot_field_scene.instantiate()
		dot_field.position = self.position
		get_parent().add_child(dot_field)
		print("NecroDotField added to scene at position: ", dot_field.position)
	else:
		print("NecroDotField scene not assigned")
