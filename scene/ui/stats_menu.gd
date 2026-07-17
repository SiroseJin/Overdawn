extends Control

# ─── Upgrades Screen ────────────────────────────────────────────────────────────
# Spend Skill Points to upgrade the 4 core ability skills (and their augments), base
# stats, and attack scaling. Grouped into Skills / Stats / Attacks sections; within
# a section, available (unlocked) tracks sort above locked ones. All rows are code-
# generated from the SKILLS list + ProgressionManager.UPGRADES, so adding a track is
# data-only. Opened via the "stats" input action.
# ───────────────────────────────────────────────────────────────────────────────────

const FONT_PATH := "res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"

# The 4 core ability skills (tracked in ProgressionManager.skill_levels, unlock-gated).
const SKILLS := [
	{"id": "dash",        "name": "Dash",        "desc": "Shorter cooldown"},
	{"id": "arrows",      "name": "Arrows",      "desc": "Hold more arrows"},
	{"id": "double_jump", "name": "Double Jump", "desc": "Shorter cooldown"},
	{"id": "firewall",    "name": "Firewall",    "desc": "Longer shield"},
]

var _font: FontFile
var _vbox: VBoxContainer
var _info_label: Label
var _skill_rows: Dictionary = {}   # skill id  -> { "label": Label, "button": Button }
var _up_rows: Dictionary = {}      # upgrade id -> { "label": Label, "button": Button }

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(FONT_PATH)
	_vbox = $CenterContainer/Panel/MarginContainer/VBox
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		refresh()

# ─── Build ───────────────────────────────────────────────────────────────────────

func _build_ui():
	for c in _vbox.get_children():
		c.queue_free()

	_add(_title(tr("Upgrades"), 22))
	_info_label = _title("", 14)
	_add(_info_label)
	_add(HSeparator.new())

	# Skills — each core skill, with its augment(s) listed right beneath it.
	_add(_title(tr("Skills"), 16))
	for s in _sorted_skills():
		_skill_rows[s["id"]] = _make_row(s["id"], true)
		for uid in _subs_for(s["id"]):
			_up_rows[uid] = _make_row(uid, false)

	# Stats
	_add(HSeparator.new())
	_add(_title(tr("Stats"), 16))
	for uid in _sorted_upgrades(["stat_health", "stat_strength", "stat_speed", "stat_jump"]):
		_up_rows[uid] = _make_row(uid, false)

	# Attacks
	_add(HSeparator.new())
	_add(_title(tr("Attacks"), 16))
	for uid in _sorted_upgrades(["atk_basic", "atk_heavy", "atk_dash"]):
		_up_rows[uid] = _make_row(uid, false)

	_add(HSeparator.new())
	var back := Button.new()
	back.text = tr("Back to Game")
	_style(back, 14)
	back.pressed.connect(_on_resume_pressed)
	_add(back)

# Unlocked skills first (in definition order), then locked ones.
func _sorted_skills() -> Array:
	var open: Array = []
	var shut: Array = []
	for s in SKILLS:
		if ProgressionManager.is_skill_unlocked(s["id"]):
			open.append(s)
		else:
			shut.append(s)
	return open + shut

# Available (requirement met) upgrades first, then locked ones — preserves input order.
func _sorted_upgrades(ids: Array) -> Array:
	var open: Array = []
	var shut: Array = []
	for uid in ids:
		if ProgressionManager.upgrade_available(uid):
			open.append(uid)
		else:
			shut.append(uid)
	return open + shut

func _subs_for(skill_id: String) -> Array:
	var out: Array = []
	for uid in ProgressionManager.UPGRADES:
		var u: Dictionary = ProgressionManager.UPGRADES[uid]
		if u.get("cat", "") == "sub" and u.get("req", "") == skill_id:
			out.append(uid)
	return out

func _make_row(id: String, is_skill: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(380, 0)
	_style(name_label, 13)
	row.add_child(name_label)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(btn, 13)
	if is_skill:
		btn.pressed.connect(_on_skill_pressed.bind(id))
	else:
		btn.pressed.connect(_on_upgrade_pressed.bind(id))
	row.add_child(btn)
	_add(row)
	return {"label": name_label, "button": btn}

# ─── Refresh ───────────────────────────────────────────────────────────────────────

func refresh() -> void:
	var lvl := 1
	if is_instance_valid(Global.PlayerBody):
		lvl = Global.PlayerBody.level
	_info_label.text = "%s %d    %s: %d    %s: %d" % [
		tr("Level"), lvl, tr("Coins"), ProgressionManager.coins,
		tr("Skill Points"), ProgressionManager.skill_points]

	for id in _skill_rows:
		_refresh_skill_row(id, _skill_rows[id])
	for id in _up_rows:
		_refresh_upgrade_row(id, _up_rows[id])

func _refresh_skill_row(id: String, row: Dictionary) -> void:
	var def: Dictionary = {}
	for s in SKILLS:
		if s["id"] == id:
			def = s
	var label: Label = row["label"]
	var button: Button = row["button"]
	if not ProgressionManager.is_skill_unlocked(id):
		label.text = "%s — %s" % [tr(def.get("name", id)), tr("Locked")]
		button.text = tr("Locked")
		button.disabled = true
		return
	var slvl := ProgressionManager.get_skill_level(id)
	var cap := ProgressionManager.MAX_SKILL_LEVEL
	label.text = "%s  Lv.%d/%d — %s" % [tr(def.get("name", id)), slvl, cap, tr(def.get("desc", ""))]
	_set_buy_button(button, slvl >= cap, ProgressionManager.skill_points > 0)

func _refresh_upgrade_row(id: String, row: Dictionary) -> void:
	var u: Dictionary = ProgressionManager.UPGRADES.get(id, {})
	var label: Label = row["label"]
	var button: Button = row["button"]
	var nm: String = u.get("id" if _is_id() else "en", id)
	var desc: String = u.get("id_d" if _is_id() else "en_d", "")
	if not ProgressionManager.upgrade_available(id):
		var req: String = u.get("req", "")
		label.text = "%s — %s" % [nm, tr("Needs") + " " + tr(_skill_name(req))]
		button.text = tr("Locked")
		button.disabled = true
		return
	var ulvl := ProgressionManager.get_upgrade_level(id)
	var cap := ProgressionManager.upgrade_cap(id)
	label.text = "%s  Lv.%d/%d — %s" % [nm, ulvl, cap, desc]
	_set_buy_button(button, ulvl >= cap, ProgressionManager.skill_points > 0)

func _set_buy_button(button: Button, maxed: bool, has_points: bool) -> void:
	if maxed:
		button.text = tr("MAX")
		button.disabled = true
	else:
		button.text = tr("Upgrade") + " (1 " + tr("SP") + ")"
		button.disabled = not has_points

func _skill_name(id: String) -> String:
	for s in SKILLS:
		if s["id"] == id:
			return s["name"]
	return id

# ─── Actions ───────────────────────────────────────────────────────────────────────

func _on_skill_pressed(skill_id: String) -> void:
	if ProgressionManager.upgrade_skill(skill_id):
		_apply_and_refresh()

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if ProgressionManager.buy_upgrade(upgrade_id):
		_apply_and_refresh()

func _apply_and_refresh() -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.refresh_stats_from_skills()
		Global.PlayerBody._refresh_skill_huds()
		Global.PlayerBody.update_health_bar()
	refresh()

func _on_resume_pressed() -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	hide()

# Esc closes the Upgrades screen too, not just the Return button (#1).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

# ─── Helpers ───────────────────────────────────────────────────────────────────────

func _add(node: Node) -> void:
	_vbox.add_child(node)

func _title(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(l, size)
	return l

func _style(c: Control, size: int) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", size)

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")
