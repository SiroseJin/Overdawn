extends Node2D

class_name BossServer

# ─── Boss Server ────────────────────────────────────────────────────────────────
# A destructible node the boss relies on while shielded. Shoot or melee it down
# and it deals a big chunk to the boss's shield (the boss handles the amount).
# Non-blocking (no physical collision) so the player passes through it — the
# challenge is parkouring into reach, not bumping it. Its HitBox is on layer 1 so
# arrows (raycast) and the melee zone both connect.
# ───────────────────────────────────────────────────────────────────────────────

@export var health: int = 30

var _boss: Node = null
var _destroyed := false   # guard so a burst of arrows can't trigger destroy repeatedly

@onready var _bar:    ProgressBar = $Bar
@onready var _hitbox: Area2D      = $HitBox

func setup(boss: Node) -> void:
	_boss = boss

func _ready() -> void:
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	_bar.max_value = health
	_bar.value = health

func take_damage(amount: float) -> void:
	if _destroyed:
		return
	health -= int(max(1.0, amount))
	_bar.value = health
	_flash()
	if health <= 0:
		_destroy()

func _flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func _destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	if is_instance_valid(_boss) and _boss.has_method("on_server_destroyed"):
		_boss.on_server_destroyed(global_position)
	_hitbox.set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.4, 0.12)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	t.tween_callback(queue_free)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Player melee zone landed on the server
	if area == Global.playerDamageZone:
		take_damage(Global.playerDamageAmount)
