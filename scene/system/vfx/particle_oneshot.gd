extends CPUParticles2D
class_name ParticleOneshot
## A one-shot particle burst that frees itself once the emission finishes.
## Instance it, set global_position (+ optional `color`), add to the scene, done.

func _ready() -> void:
	one_shot = true
	emitting = true
	finished.connect(queue_free)
