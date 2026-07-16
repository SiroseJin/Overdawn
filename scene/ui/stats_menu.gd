extends Control

# ─── Character / Skill Screen ───────────────────────────────────────────────────
# RPG stat + skill upgrade panel. Shows level, coins and skill points, and lets
# the player spend skill points to upgrade unlocked skills. Locked skills can't
# be upgraded until an NPC unlocks them. Opened via the "stats" input action.
# Rows are generated in code so adding a skill only means editing the SKILLS list.
# ───────────────────────────────────────────────────────────────────────────────

const SKILLS := [
	{"id": "dash",        "name": "Dash",        "desc": "Shorter cooldown"},
	{"id": "arrows",      "name": "Arrows",      "desc": "Hold more arrows"},
	{"id": "double_jump", "name": "Double Jump", "desc": "Shorter cooldown"},
	{"id": "firewall",    "name": "Firewall",    "desc": "Longer shield"},
]

var _font: FontFile
var _vbox: VBoxContainer
var _info_label: Label
var _rows: Dictionary = {}   # skill id -> { "label": Label, "button": Button, "def": Dictionary }

func _ready():
	# The instance in player.tscn collapses our anchors; force full-screen so the
	# centered panel lays out correctly.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")
	_vbox = $CenterContainer/Panel/MarginContainer/VBox
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		refresh()

func _build_ui():
	var title := Label.new()
	title.text = tr("Character")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(title, 22)
	_vbox.add_child(title)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_info_label, 14)
	_vbox.add_child(_info_label)

	_vbox.add_child(HSeparator.new())

	var skills_title := Label.new()
	skills_title.text = tr("Skills")
	_style(skills_title, 16)
	_vbox.add_child(skills_title)

	for s in SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(360, 0)
		_style(name_label, 13)
		row.add_child(name_label)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style(btn, 13)
		btn.pressed.connect(_on_upgrade_pressed.bind(s["id"]))
		row.add_child(btn)

		_vbox.add_child(row)
		_rows[s["id"]] = { "label": name_label, "button": btn, "def": s }

	_vbox.add_child(HSeparator.new())

	var back := Button.new()
	back.text = tr("Back to Game")
	_style(back, 14)
	back.pressed.connect(_on_resume_pressed)
	_vbox.add_child(back)

func _style(c: Control, size: int) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", size)

# Refresh all labels/buttons from current progression state.
func refresh() -> void:
	var lvl := 1
	if is_instance_valid(Global.PlayerBody):
		lvl = Global.PlayerBody.level

	_info_label.text = "%s %d    %s: %d    %s: %d" % [
		tr("Level"), lvl,
		tr("Coins"), ProgressionManager.coins,
		tr("Skill Points"), ProgressionManager.skill_points]

	for id in _rows:
		var row: Dictionary = _rows[id]
		var def: Dictionary = row["def"]
		var label: Label    = row["label"]
		var button: Button  = row["button"]

		if not ProgressionManager.is_skill_unlocked(id):
			label.text     = "%s — %s" % [tr(def["name"]), tr("Locked")]
			button.text    = tr("Locked")
			button.disabled = true
			continue

		var slvl := ProgressionManager.get_skill_level(id)
		label.text = "%s  Lv.%d/%d — %s" % [tr(def["name"]), slvl, ProgressionManager.MAX_SKILL_LEVEL, tr(def["desc"])]
		if slvl >= ProgressionManager.MAX_SKILL_LEVEL:
			button.text     = tr("MAX")
			button.disabled = true
		else:
			button.text     = tr("Upgrade") + " (1 " + tr("SP") + ")"
			button.disabled = ProgressionManager.skill_points <= 0

# ───────────────────────────────────────────────────────────────────────────────
# Signals
# ───────────────────────────────────────────────────────────────────────────────

func _on_upgrade_pressed(skill_id: String) -> void:
	if ProgressionManager.upgrade_skill(skill_id):
		if is_instance_valid(Global.PlayerBody):
			Global.PlayerBody.refresh_stats_from_skills()
			Global.PlayerBody._refresh_skill_huds()
		refresh()

func _on_resume_pressed() -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	hide()
