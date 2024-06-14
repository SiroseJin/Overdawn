extends Control

@onready var resume_button = $ColorRect/MarginContainer/VBoxContainer/Resume
@onready var health_label = $ColorRect/MarginContainer/VBoxContainer/HealthLabel
@onready var strength_label = $ColorRect/MarginContainer/VBoxContainer/StrengthLabel
@onready var exp_label = $ColorRect/MarginContainer/VBoxContainer/EXPLabel
@onready var level_label = $ColorRect/MarginContainer/VBoxContainer/LevelLabel
@onready var speed_label = $ColorRect/MarginContainer/VBoxContainer/SpeedLabel
@onready var score_label = $ColorRect/MarginContainer/VBoxContainer/ScoreLabel

func _ready():
	pass

func _on_resume_pressed():
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	self.hide()
