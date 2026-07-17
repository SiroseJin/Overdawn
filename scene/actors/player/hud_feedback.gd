extends Control

# ─── HUD Feedback layer (UC-008/009 + notifications) ──────────────────────────────
# Drives the three feedback boxes the player added to the HUD:
#   • QuestList        — live list of active quests + objective progress (QuestManager)
#   • NotificationList — transient stacked messages (quest complete / reward / item
#                        picked up / badge …). Fed by player.show_toast() so every toast
#                        in the game funnels here.
#   • Badge Unlock     — a prominent popup when a badge is earned (ProgressionManager).
# All content is centered inside its box (the boxes are positioned in the editor).
# ──────────────────────────────────────────────────────────────────────────────────

const FONT    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")  # body
const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")                          # display

const MAX_NOTIFS := 5

## Global size multiplier for the feedback text (quests / notifications / badge popup).
## Bumped to make these read a bit bigger — tweak in one place.
const UI_SCALE := 1.15

@onready var quest_list: VBoxContainer = get_node_or_null("QuestList")
@onready var notif_list: VBoxContainer = get_node_or_null("NotificationList")
@onready var badge_box:  VBoxContainer = get_node_or_null("Badge Unlock")

func _ready() -> void:
	if QuestManager.has_signal("quests_changed"):
		QuestManager.quests_changed.connect(_refresh_quests)
	ProgressionManager.badge_unlocked.connect(_on_badge)
	ProgressionManager.game_event.connect(_on_event)
	_refresh_quests()

# ─── Quest list ───────────────────────────────────────────────────────────────────

func _refresh_quests() -> void:
	if quest_list == null:
		return
	for c in quest_list.get_children():
		c.queue_free()
	_mk_label(quest_list, tr("QUESTS"), 13, Color(0.7, 0.85, 1.0), DISPLAY)
	var shown := 0
	for qid in QuestManager.QUESTS:
		if QuestManager.is_done(qid) or shown >= 4:
			continue
		var objs: Array = QuestManager.objective_progress(qid)
		var done_obj := 0
		for o in objs:
			if o["done"]:
				done_obj += 1
		_mk_label(quest_list, "◆ %s  %d/%d" % [QuestManager.title_of(qid), done_obj, objs.size()],
			11, Color(0.85, 0.9, 1.0))
		shown += 1
	if shown == 0:
		_mk_label(quest_list, tr("All quests done!"), 11, Color(0.6, 0.9, 0.6))

# ─── Notifications ────────────────────────────────────────────────────────────────

# Called by player.show_toast so every in-game toast stacks here.
func push_notification(text: String, color: Color = Color(1, 1, 1)) -> void:
	if notif_list == null:
		return
	var lbl := _mk_label(notif_list, text, 12, color)
	while notif_list.get_child_count() > MAX_NOTIFS:
		notif_list.get_child(0).queue_free()
	var t := create_tween()
	t.tween_interval(2.6)
	t.tween_property(lbl, "modulate:a", 0.0, 0.8)
	t.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free())

func _on_event(event_name: String, data: Dictionary) -> void:
	# Collectibles don't always route a toast through the player — surface them here.
	if event_name == "collectible":
		push_notification(tr("Truth Shard collected"), Color(0.5, 1.0, 0.9))

# ─── Badge unlock popup ───────────────────────────────────────────────────────────

func _on_badge(badge_id: String) -> void:
	if badge_box == null:
		return
	for c in badge_box.get_children():
		c.queue_free()
	badge_box.modulate.a = 1.0
	_mk_label(badge_box, "★ " + tr("BADGE UNLOCKED"), 16, Color(1.0, 0.85, 0.3), DISPLAY)
	_mk_label(badge_box, BadgeManager.name_of(badge_id), 12, Color(1.0, 0.95, 0.7))
	var t := create_tween()
	t.tween_interval(3.6)
	t.tween_property(badge_box, "modulate:a", 0.0, 0.8)
	t.tween_callback(func():
		if is_instance_valid(badge_box):
			for c in badge_box.get_children():
				c.queue_free()
			badge_box.modulate.a = 1.0)

# ─── Helper ───────────────────────────────────────────────────────────────────────

func _mk_label(parent: Node, text: String, size: int, color: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(round(size * UI_SCALE)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # centered content
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
