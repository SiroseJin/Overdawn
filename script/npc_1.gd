extends CharacterBody2D

@onready var sprite = get_node_or_null("AnimatedSprite2D")

var is_chatting = false

func _ready():
	if sprite == null:
		print("ERROR: AnimatedSprite2D not found")

func on_player_enter():
	if sprite:
		sprite.play("dialog")

func on_player_exit():
	if sprite:
		sprite.play("idle")

func start_dialogue():
	if is_chatting:
		return

	print("Starting dialogue")
	is_chatting = true

	if not Dialogic:
		print("Dialogic not found")
		return

	Dialogic.start("npc1timeline")
