extends Control

# ─── Progress Menu (UC-010 + #2) ──────────────────────────────────────────────────
# The LAYOUT (background, title, scroll, section headers, Back) lives in
# progress_menu.tscn so it can be edited in the Godot editor. This script only FILLS
# the dynamic sections (stairs / stats / badges / quests / codex) from the manager
# singletons, since those change with the player's live, persisted progress.
# ──────────────────────────────────────────────────────────────────────────────────

const FONT    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")
const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")

const STAGE_COLORS := {
	1: Color(0.45, 0.85, 1.0), 2: Color(0.78, 0.45, 1.0), 3: Color(1.0, 0.65, 0.3),
	4: Color(1.0, 0.4, 0.4),   5: Color(1.0, 0.6, 0.78),  6: Color(0.5, 1.0, 0.65),
}

@onready var _stairs: HBoxContainer  = $Margin/Root/Scroll/Content/Stairs
@onready var _stats:  GridContainer  = $Margin/Root/Scroll/Content/Stats
@onready var _badges: GridContainer  = $Margin/Root/Scroll/Content/Badges
@onready var _quests: VBoxContainer  = $Margin/Root/Scroll/Content/Quests
@onready var _codex:  VBoxContainer  = $Margin/Root/Scroll/Content/Codex
@onready var _back:   Button         = $Margin/Root/Back

func _ready() -> void:
	_back.pressed.connect(_on_back)
	_build_stairs()
	_build_stats()
	_build_badges()
	_build_quests()
	_build_codex()

func _build_stairs() -> void:
	_clear(_stairs)
	var next_found := false
	for n in range(1, 7):
		var cleared: bool = ProgressionManager.is_stage_cleared("stage%d" % n)
		var is_next := not cleared and not next_found
		if is_next:
			next_found = true
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(96, 62)
		var sb := StyleBoxFlat.new()
		var col: Color = STAGE_COLORS[n]
		sb.bg_color = col.darkened(0.2) if cleared else Color(0.12, 0.13, 0.16)
		sb.set_border_width_all(3 if is_next else 1)
		sb.border_color = Color(1, 1, 0.4) if is_next else col
		sb.set_corner_radius_all(6)
		box.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FONT)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.text = "S%d\n%s" % [n, "✓" if cleared else ("▶" if is_next else "•")]
		lbl.add_theme_color_override("font_color", Color(1, 1, 1) if cleared or is_next else Color(0.5, 0.5, 0.55))
		box.add_child(lbl)
		_stairs.add_child(box)

func _build_stats() -> void:
	_clear(_stats)
	var quizzes := 0
	for q in BadgeManager.QUIZ_IDS:
		if ProgressionManager.has_talked_to("quizpass_" + q):
			quizzes += 1
	_stat(tr("Name"), ProgressionManager.player_name)
	_stat(tr("Level"), str(ProgressionManager.player_level))
	_stat(tr("Coins"), str(ProgressionManager.coins))
	_stat(tr("Skill Points"), str(ProgressionManager.skill_points))
	_stat(tr("Quizzes"), "%d / %d" % [quizzes, BadgeManager.QUIZ_IDS.size()])
	_stat(tr("Truth Shards"), "%d / %d" % [ProgressionManager.collectible_count(), CollectibleManager.total()])
	_stat(tr("Badges"), "%d / %d" % [ProgressionManager.badge_count(), BadgeManager.BADGES.size()])
	_stat(tr("Quests"), "%d / %d" % [QuestManager.completed_count(), QuestManager.total_count()])

func _build_badges() -> void:
	_clear(_badges)
	for bid in BadgeManager.BADGES:
		var earned: bool = ProgressionManager.has_badge(bid)
		var l := _label(12, Color(1, 0.88, 0.4) if earned else Color(0.5, 0.5, 0.55))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		l.text = "%s %s — %s" % ["🏅" if earned else "🔒", BadgeManager.name_of(bid), BadgeManager.desc_of(bid)]
		_badges.add_child(l)

func _build_quests() -> void:
	_clear(_quests)
	for qid in QuestManager.QUESTS:
		var done: bool = QuestManager.is_done(qid)
		var head := _label(13, Color(0.5, 0.9, 0.6) if done else Color(0.85, 0.85, 0.9))
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.text = ("✓ " if done else "• ") + QuestManager.title_of(qid) + " — " + QuestManager.desc_of(qid)
		_quests.add_child(head)
		for ob in QuestManager.objective_progress(qid):
			var o := _label(11, Color(0.55, 0.85, 0.6) if ob["done"] else Color(0.6, 0.6, 0.66), false)
			o.text = "     %s  (%d/%d)" % [ob["text"], ob["cur"], ob["req"]]
			_quests.add_child(o)

func _build_codex() -> void:
	_clear(_codex)
	var any := false
	for sid in CollectibleManager.SHARDS:
		if ProgressionManager.has_collectible(sid):
			any = true
			var l := _label(12, Color(0.6, 1.0, 0.9), false)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.text = "◆ " + CollectibleManager.lore_for(sid)
			_codex.add_child(l)
	if not any:
		var hint := _label(12, Color(0.55, 0.55, 0.6), false)
		hint.text = tr("Collect Truth Shards in the stages to reveal what they teach.")
		_codex.add_child(hint)

# ─── Helpers ──────────────────────────────────────────────────────────────────────

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _label(size: int, color: Color, use_font := true) -> Label:
	var l := Label.new()
	if use_font:
		l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _stat(label: String, value: String) -> void:
	var l := _label(14, Color(0.9, 0.9, 0.95))
	l.text = "%s: %s" % [label, value]
	_stats.add_child(l)

func _on_back() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()
