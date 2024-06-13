extends Node

var score = 0

@onready var score_label = $ScoreLabel

func add_pointcoin():
	score += 1
	score_label.text = "Score: " + str(score)

func add_pointbat():
	score += 2
	score_label.text = "Score: " + str(score)

func add_pointfrog():
	score += 4
	score_label.text = "Score: " + str(score)

func add_pointwitch():
	score += 10
	score_label.text = "Score: " + str(score)
