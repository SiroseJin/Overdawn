extends Control

# ─── Progress Menu (UC-010 progression stairs + UC-006 codex) ─────────────────────
# One screen that shows how far the player has come and what's next: the 6-stage
# progression stairs, headline stats, the badge grid (UC-009), the quest log (UC-008),
# and the "Truths Learned" codex — every anti-gambling fact the player has collected
# (UC-004/006). Built entirely in code from the manager singletons so it always
# reflects live, persisted state. Opens as a full scene (main menu) or an overlay
# (pause menu); Back handles both.
# ──────────────────────────────────────────────────────────────────────────────────

const FONT := preload("res://art/Fonts/skeleboom.ttf")

const STAGE_COLORS := {
	1: Color(0.45, 0.85, 1.0), 2: Color(0.78, 0.45, 1.0), 3: Color(1.0, 0.65, 0.3),
	4: Color(1.0, 0.4, 0.4),   5: Color(1.0, 0.6, 0.78),  6: Color(0.5, 1.0, 0.65),
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_title(tr("PROGRESS"), 30, Color(1, 1, 1)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	_build_stairs(content)
	_build_stats(content)
	_build_badges(content)
	_build_quests(content)
	_build_codex(content)

	var back := Button.new()
	back.text = tr("Back")
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_on_back)
	root.add_child(back)

# ─── Sections ─────────────────────────────────────────────────────────────────────

# The progression stairs: 6 stages, cleared ones lit, the next one highlighted.
func _build_stairs(parent: VBoxContainer) -> void:
	parent.add_child(_header(tr("Your Climb")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
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
		var mark := "✓" if cleared else ("▶" if is_next else "•")
		lbl.text = "S%d\n%s" % [n, mark]
		lbl.add_theme_color_override("font_color", Color(1,1,1) if cleared or is_next else Color(0.5,0.5,0.55))
		box.add_child(lbl)
		row.add_child(box)

func _build_stats(parent: VBoxContainer) -> void:
	var shards := "%d / %d" % [ProgressionManager.collectible_count(), CollectibleManager.total()]
	var badges := "%d / %d" % [ProgressionManager.badge_count(), BadgeManager.BADGES.size()]
	var quests := "%d / %d" % [QuestManager.completed_count(), QuestManager.total_count()]
	var quizzes := 0
	for q in BadgeManager.QUIZ_IDS:
		if ProgressionManager.has_talked_to("quizpass_" + q):
			quizzes += 1
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(_header(tr("Overview")))
	parent.add_child(grid)
	_stat(grid, tr("Level"), str(ProgressionManager.player_level))
	_stat(grid, tr("Coins"), str(ProgressionManager.coins))
	_stat(grid, tr("Skill Points"), str(ProgressionManager.skill_points))
	_stat(grid, tr("Quizzes"), "%d / %d" % [quizzes, BadgeManager.QUIZ_IDS.size()])
	_stat(grid, tr("Truth Shards"), shards)
	_stat(grid, tr("Badges"), badges)
	_stat(grid, tr("Quests"), quests)

func _build_badges(parent: VBoxContainer) -> void:
	parent.add_child(_header(tr("Badges")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for bid in BadgeManager.BADGES:
		var earned: bool = ProgressionManager.has_badge(bid)
		var l := Label.new()
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		var icon := "🏅" if earned else "🔒"
		l.text = "%s %s — %s" % [icon, BadgeManager.name_of(bid), BadgeManager.desc_of(bid)]
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.4) if earned else Color(0.5, 0.5, 0.55))
		grid.add_child(l)

func _build_quests(parent: VBoxContainer) -> void:
	parent.add_child(_header(tr("Quests")))
	for qid in QuestManager.QUESTS:
		var done: bool = QuestManager.is_done(qid)
		var head := Label.new()
		head.add_theme_font_override("font", FONT)
		head.add_theme_font_size_override("font_size", 13)
		head.text = ("✓ " if done else "• ") + QuestManager.title_of(qid) + " — " + QuestManager.desc_of(qid)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6) if done else Color(0.85, 0.85, 0.9))
		parent.add_child(head)
		for ob in QuestManager.objective_progress(qid):
			var o := Label.new()
			o.add_theme_font_size_override("font_size", 11)
			o.text = "     %s  (%d/%d)" % [ob["text"], ob["cur"], ob["req"]]
			o.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6) if ob["done"] else Color(0.6, 0.6, 0.66))
			parent.add_child(o)

# The educational payoff: every truth the player has collected, gathered in one place.
func _build_codex(parent: VBoxContainer) -> void:
	parent.add_child(_header(tr("Truths Learned")))
	var any := false
	for sid in CollectibleManager.SHARDS:
		if ProgressionManager.has_collectible(sid):
			any = true
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 12)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.text = "◆ " + CollectibleManager.lore_for(sid)
			l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
			parent.add_child(l)
	if not any:
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 12)
		hint.text = tr("Collect Truth Shards in the stages to reveal what they teach.")
		hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		parent.add_child(hint)

# ─── Little builders ──────────────────────────────────────────────────────────────

func _title(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _header(text: String) -> Label:
	var l := _title(text, 18, Color(0.7, 0.85, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

func _stat(grid: GridContainer, label: String, value: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 14)
	l.text = "%s: %s" % [label, value]
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	grid.add_child(l)

func _on_back() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()
