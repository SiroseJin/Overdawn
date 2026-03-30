extends Node2D

# ─── Main Scene ────────────────────────────────────────────────────────────────
# Thin bootstrap scene — immediately hands off to the lobby level on startup.
# Keeping this as a separate scene makes it easy to add pre-load logic later
# (e.g. loading screens, save-data reads) without touching lobby_level.gd.
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	var lobby_scene = preload("res://scene/lobby_level.tscn")
	get_tree().change_scene(lobby_scene)
