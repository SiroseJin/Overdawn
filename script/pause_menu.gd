extends Control

@onready var resume = $MarginContainer/VBoxContainer/Resume
@onready var quit = $MarginContainer/VBoxContainer/Quit
@onready var lobby = $MarginContainer/VBoxContainer/Lobby

func _ready():
	pass

func _on_resume_pressed():
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	self.hide()

func _on_lobby_pressed():
	Global.gameStarted = false
	get_tree().change_scene_to_file("res://scene/lobby_level.tscn")

func _on_quit_pressed():
	get_tree().quit()
