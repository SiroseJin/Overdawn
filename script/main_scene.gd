extends Node2D

func _ready():
	# Load and change to the lobby_level scene
	var lobby_level_scene = preload("res://scene/lobby_level.tscn")
	get_tree().change_scene(lobby_level_scene)

func _process(delta):
	pass
