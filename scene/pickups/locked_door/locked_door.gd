extends StaticBody2D

# ─── Locked Door ────────────────────────────────────────────────────────────────
# A solid barrier that blocks the path until the player carries the matching key.
# When the player approaches (DetectZone, mask = 2): if they hold `required_key`
# it is spent and the door opens; otherwise a hint tells them to find the key.
# ───────────────────────────────────────────────────────────────────────────────

@export var required_key: String = "stage1_key"
## Overrides the "locked" hint text. Leave empty to keep the scene default.
@export var locked_hint: String = ""
## When true the key is spent on opening (single-use puzzle door). When false the
## key just needs to be held — the door re-opens on scene reload (e.g. a boss
## gate you shouldn't have to re-earn after dying).
@export var consume_key: bool = true

@onready var hint:      Label            = $Hint
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var detect:    Area2D           = $DetectZone

var _opened := false

func _ready() -> void:
	add_to_group("locked_door")   # the key-guide line reads our required_key (#5)
	detect.body_entered.connect(_on_detect_entered)
	detect.body_exited.connect(_on_detect_exited)
	if locked_hint != "":
		hint.text = locked_hint
	hint.hide()

func _on_detect_entered(body: Node2D) -> void:
	if _opened or not body.is_in_group("player"):
		return

	if not ProgressionManager.has_key(required_key):
		hint.show()
		return
	if consume_key:
		ProgressionManager.consume_key(required_key)
	_open(body)

func _on_detect_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hint.hide()

func _open(body: Node2D) -> void:
	_opened = true
	hint.hide()
	collision.set_deferred("disabled", true)
	if body.has_method("show_toast"):
		body.show_toast(tr("The way out opens"))
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): visible = false)
