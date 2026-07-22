extends Control

# ─── Quest List Menu (B / #4) ─────────────────────────────────────────────────────
# Shows every quest the player has actually been GIVEN by an NPC (offered), with its
# lore, description, hint, giver and reward. The layout lives in quest_menu.tscn (so
# it's editable); this only fills the scrolling List with one card per known quest.
#
# Opened two ways: from the HUD quest box (click) and from the Settings menu. As an
# overlay it frees itself on Back; as a standalone scene it returns to settings_return_path.
# ──────────────────────────────────────────────────────────────────────────────────

const FONT    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")
const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")

@onready var _list: VBoxContainer = $Margin/Root/Scroll/List
@onready var _back: Button        = $Margin/Root/Back

func _ready() -> void:
	_back.pressed.connect(_on_back)
	_build()

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()

	var ids: Array = QuestManager.offered_quest_ids()
	if ids.is_empty():
		var empty := _label(14, Color(0.7, 0.72, 0.8))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("No quests yet. Talk to the people you meet — they'll give you quests as you go.")
		_list.add_child(empty)
		return

	# Main quests first, then side/challenge, done ones last.
	ids.sort_custom(func(a, b):
		var ka := _sort_key(a)
		var kb := _sort_key(b)
		return ka < kb)

	for qid in ids:
		_add_card(qid)

func _sort_key(qid: String) -> int:
	var done := 1 if QuestManager.is_done(qid) else 0
	var side := 0 if QuestManager.is_mandatory(qid) else 1
	return done * 10 + side

func _add_card(qid: String) -> void:
	var done: bool = QuestManager.is_done(qid)
	var main: bool = QuestManager.is_mandatory(qid)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.border_color = Color(0.4, 0.85, 0.5) if done else (Color(1.0, 0.82, 0.35) if main else Color(0.55, 0.7, 1.0))
	sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	# Header: [Main/Side] Title — status
	var kind := tr("Main") if main else tr("Side")
	var status := ("✓ " + tr("Completed")) if done else tr("In progress")
	var head := _label(17, Color(1, 1, 1), DISPLAY)
	head.text = "[%s]  %s" % [kind, QuestManager.title_of(qid)]
	box.add_child(head)

	_field(box, tr("Status"), status, Color(0.5, 0.9, 0.6) if done else Color(0.9, 0.85, 0.5))
	var giver := QuestManager.giver_of(qid)
	if giver != "":
		_field(box, tr("Given by"), giver, Color(0.8, 0.85, 0.95))

	_para(box, QuestManager.desc_of(qid), Color(0.92, 0.93, 0.98))

	var lore := QuestManager.lore_of(qid)
	if lore != "":
		_para(box, "“" + lore + "”", Color(0.6, 0.78, 0.7))

	# Objectives with live progress.
	for ob in QuestManager.objective_progress(qid):
		var o := _label(12, Color(0.55, 0.85, 0.6) if ob["done"] else Color(0.75, 0.77, 0.83))
		o.text = "   %s %s  (%d/%d)" % ["✓" if ob["done"] else "•", ob["text"], ob["cur"], ob["req"]]
		box.add_child(o)

	if not done:
		var hint := QuestManager.hint_of(qid)
		if hint != "":
			_para(box, "💡 " + hint, Color(0.95, 0.85, 0.5))

	_field(box, tr("Reward"), QuestManager.reward_text(qid), Color(1.0, 0.88, 0.5))

	_list.add_child(card)

# ─── Helpers ──────────────────────────────────────────────────────────────────────

func _label(font_size: int, color: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

# A "Label: value" one-liner.
func _field(parent: Node, label: String, value: String, color: Color) -> void:
	var l := _label(12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = "%s: %s" % [label, value]
	parent.add_child(l)

# A wrapped paragraph of body text.
func _para(parent: Node, text: String, color: Color) -> void:
	if text == "":
		return
	var l := _label(12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	parent.add_child(l)

func _on_back() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()

# Esc goes back too, not just the Back button (#1).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# Consume the key BEFORE running the Back action. Back may call
		# change_scene_to_file(), which detaches this node from the tree — and once
		# it's detached get_viewport() is null, so marking the input handled
		# afterwards crashed with "Cannot call method 'set_input_as_handled' on a
		# null value". Pressing Esc in Settings hit this every time.
		get_viewport().set_input_as_handled()
		_on_back()
