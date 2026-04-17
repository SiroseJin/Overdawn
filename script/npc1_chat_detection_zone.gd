extends Area2D

@onready var npc = get_parent()

var player_in_area = false

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(delta):
	if Input.is_action_just_pressed("interact"):
		print("F works")

	if player_in_area and Input.is_action_just_pressed("interact"):
		print("Interact pressed in zone")
		npc.start_dialogue()

func _on_body_entered(body):
	print("Entered:", body.name)
	if body.is_in_group("player"):
		print("Player detected")
		player_in_area = true
		npc.on_player_enter()

func _on_body_exited(body):
	print("Exited:", body.name)
	if body.is_in_group("player"):
		print("Player left")
		player_in_area = false
		npc.on_player_exit()
