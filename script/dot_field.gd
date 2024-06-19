extends Area2D
class_name NecroDotField

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var damage_timer: Timer = $DamageTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

const DAMAGE_AMOUNT: int = 1
const SLOW_FACTOR: float = 0.6

func _ready():
	on_lifetime_timeout()

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if area.get_parent() is Player:
		parent.slow_down(SLOW_FACTOR)
		parent.take_damage(DAMAGE_AMOUNT)
		await get_tree().create_timer(1.2).timeout
		parent.take_damage(DAMAGE_AMOUNT)
		await get_tree().create_timer(1.2).timeout
		parent.take_damage(DAMAGE_AMOUNT)
		await get_tree().create_timer(1.2).timeout
		parent.take_damage(DAMAGE_AMOUNT)
		await get_tree().create_timer(1.2).timeout
		parent.take_damage(DAMAGE_AMOUNT)

func on_lifetime_timeout():
	await get_tree().create_timer(6.0).timeout
	self.queue_free()

func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() is Player:
		# Restore the player's speed when exiting the field
		area.get_parent().restore_speed()

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	self.queue_free()
