extends Control

# ─── Load Menu ────────────────────────────────────────────────────────────────
# Displays up to 3 save slots, each with a screenshot thumbnail and metadata.
# ──────────────────────────────────────────────────────────────────────────────

signal slot_loaded

# Each entry: [button_path, thumbnail_path]
const SLOT_NODES : Array = [
	["LoadMenuUI/LoadMenuSelect/Slot1Row/Save1", "LoadMenuUI/LoadMenuSelect/Slot1Row/Thumb1"],
	["LoadMenuUI/LoadMenuSelect/Slot2Row/Save2", "LoadMenuUI/LoadMenuSelect/Slot2Row/Thumb2"],
	["LoadMenuUI/LoadMenuSelect/Slot3Row/Save3", "LoadMenuUI/LoadMenuSelect/Slot3Row/Thumb3"],
]

func _ready():
	var back := get_node_or_null("LoadMenuUI/LoadMenuSelect/Back")
	if back and not back.pressed.is_connected(_on_back_pressed):
		back.pressed.connect(_on_back_pressed)
	refresh()

## Call every time the panel becomes visible.
func refresh() -> void:
	for i in range(SLOT_NODES.size()):
		var slot  : int  = i + 1
		var btn          = get_node_or_null(SLOT_NODES[i][0])
		var thumb        = get_node_or_null(SLOT_NODES[i][1])
		if btn == null:
			continue

		var exists : bool = SaveManager.slot_exists(slot)
		btn.text     = SaveManager.slot_label(slot)
		btn.disabled = not exists

		# Load thumbnail
		if thumb != null:
			if exists:
				var tex := SaveManager.slot_thumbnail(slot)
				thumb.texture = tex          # null is fine — shows empty rect
			else:
				thumb.texture = null

func _on_save_1_pressed(): _do_load(1)
func _on_save_2_pressed(): _do_load(2)
func _on_save_3_pressed(): _do_load(3)

func _do_load(slot: int) -> void:
	if SaveManager.load_game(slot):
		emit_signal("slot_loaded")

func _on_back_pressed() -> void:
	hide()
	var parent = get_parent()
	if parent and parent.has_method("_on_back_pressed"):
		parent._on_back_pressed()
