extends Control

# ─── Load Menu ────────────────────────────────────────────────────────────────
# Displays up to 3 save slots, each with a screenshot thumbnail and metadata.
# ──────────────────────────────────────────────────────────────────────────────

signal slot_loaded

func _ready():
	var back := get_node_or_null("LoadMenuUI/LoadMenuSelect/Back")
	if back and not back.pressed.is_connected(_on_back_pressed):
		back.pressed.connect(_on_back_pressed)
	refresh()

## Call every time the panel becomes visible.
func refresh() -> void:
	SaveManager.populate_slots(get_node_or_null("LoadMenuUI/LoadMenuSelect"), _do_load, false)

func _do_load(slot: int) -> void:
	if SaveManager.load_game(slot):
		emit_signal("slot_loaded")

# Legacy .tscn connections resolve here; the rows themselves are now built in refresh().
func _on_save_1_pressed(): _do_load(1)
func _on_save_2_pressed(): _do_load(2)
func _on_save_3_pressed(): _do_load(3)

func _on_back_pressed() -> void:
	hide()
	var parent = get_parent()
	if parent and parent.has_method("_on_back_pressed"):
		parent._on_back_pressed()
