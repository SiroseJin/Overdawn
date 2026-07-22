extends Control

# ─── Debug Settings ───────────────────────────────────────────────────────────
# The scene provides the stage selector, arcade toggle, HP/Level editors, dead
# test and Back. The rest of the toolkit (god mode, spawning, currency, skill
# locks, etc.) is generated in code below so it's easy to keep growing.
# ───────────────────────────────────────────────────────────────────────────────

@onready var _vbox            = $ColorRect/MarginContainer/VBoxContainer
@onready var _margin          = $ColorRect/MarginContainer
@onready var _arcade_toggle   = $ColorRect/MarginContainer/VBoxContainer/ArcadeModeToggle
@onready var _hp_spin         = $ColorRect/MarginContainer/VBoxContainer/HPRow/CurrentHPSpin
@onready var _hp_max_spin     = $ColorRect/MarginContainer/VBoxContainer/HPRow/MaxHPSpin
@onready var _apply_hp_btn    = $ColorRect/MarginContainer/VBoxContainer/HPRow/ApplyHP
@onready var _level_spin      = $ColorRect/MarginContainer/VBoxContainer/LevelRow/LevelSpin
@onready var _apply_level_btn = $ColorRect/MarginContainer/VBoxContainer/LevelRow/ApplyLevel
@onready var _dead_test_btn   = $ColorRect/MarginContainer/VBoxContainer/DeadTest
@onready var _back_btn        = $ColorRect/MarginContainer/VBoxContainer/Back

const ENEMY_SCENES := {
	"Bat":   preload("res://scene/actors/enemies/adbot/adbot_enemy.tscn"),
	"Frog":  preload("res://scene/actors/enemies/buzzer/buzzer_enemy.tscn"),
	"Witch": preload("res://scene/actors/enemies/collector/collector_enemy.tscn"),
	"Necro": preload("res://scene/actors/enemies/dealer/dealer_enemy.tscn"),
	"Boss":  preload("res://scene/actors/enemies/finalboss/finalboss_enemy.tscn"),
}

const SKILL_ORDER := ["dash", "arrows", "double_jump", "firewall"]

var _font: FontFile
var _skill_checks: Dictionary = {}   # skill id -> CheckButton
var _wave_spin: SpinBox

func _ready() -> void:
	_font = load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")
	# Size the panel and keep it centred. The MarginContainer is centre-anchored
	# (anchors at 0.5), so offsets must be symmetric — half the panel size on each
	# side — or it drifts off-centre. Content taller than this scrolls (see below).
	_margin.offset_left   = -312.0
	_margin.offset_right  = 312.0
	_margin.offset_top    = -300.0
	_margin.offset_bottom = 300.0

	_arcade_toggle.button_pressed = Global.arcade_mode

	var has_player := is_instance_valid(Global.PlayerBody)
	if not has_player:
		for node in [_hp_spin, _hp_max_spin, _apply_hp_btn, _level_spin, _apply_level_btn, _dead_test_btn]:
			node.modulate.a = 0.4
		_hp_spin.editable = false
		_hp_max_spin.editable = false
		_apply_hp_btn.disabled = true
		_level_spin.editable = false
		_apply_level_btn.disabled = true
		_dead_test_btn.disabled = true
	else:
		_hp_spin.value     = Global.PlayerBody.health
		_hp_max_spin.value = Global.PlayerBody.health_max
		_level_spin.value  = Global.PlayerBody.level

	_build_tools(has_player)

	# Keep Dead Test + Back at the very bottom
	_vbox.move_child(_dead_test_btn, _vbox.get_child_count() - 1)
	_vbox.move_child(_back_btn, _vbox.get_child_count() - 1)

	# The toolkit grows past the panel — make it scroll instead of clipping.
	Global.make_scrollable(_vbox)

# ─── Generated toolkit ──────────────────────────────────────────────────────────

func _build_tools(has_player: bool) -> void:
	_vbox.add_child(HSeparator.new())
	_vbox.add_child(_label("DEBUG TOOLS", 16))

	# Player toggles
	var toggles := _row()
	toggles.add_child(_check("God Mode", _get_flag("god_mode"), _on_god_toggled, not has_player))
	toggles.add_child(_check("Inf Arrows", _get_flag("infinite_arrows"), _on_inf_arrows_toggled, not has_player))
	_vbox.add_child(toggles)

	var toggles2 := _row()
	toggles2.add_child(_check("Noclip", _get_flag("noclip"), _on_noclip_toggled, not has_player))
	toggles2.add_child(_check("Fly (up/down)", _get_flag("fly_mode"), _on_fly_toggled, not has_player))
	_vbox.add_child(toggles2)

	# Quick actions
	var r1 := _row()
	r1.add_child(_button("Refill HP", _on_refill_hp, not has_player))
	r1.add_child(_button("Full Heal + Max", _on_full_heal, not has_player))
	r1.add_child(_button("Kill Enemies", _on_kill_enemies, not has_player))
	_vbox.add_child(r1)

	# Currency / points
	var r2 := _row()
	r2.add_child(_button("+100 Coins", func(): ProgressionManager.add_coins(100)))
	r2.add_child(_button("+5 Skill Pts", func(): ProgressionManager.add_skill_points(5)))
	r2.add_child(_button("+1000 Score", _on_give_score, not has_player))
	_vbox.add_child(r2)

	# Skills
	_vbox.add_child(_label("Skills (tap to lock/unlock)", 13))
	var skrow := _row()
	for s in SKILL_ORDER:
		var chk := _check(_skill_name(s), ProgressionManager.is_skill_unlocked(s), _on_skill_toggled.bind(s))
		skrow.add_child(chk)
		_skill_checks[s] = chk
	_vbox.add_child(skrow)
	var skrow2 := _row()
	skrow2.add_child(_button("Unlock All", _on_unlock_all))
	skrow2.add_child(_button("Lock All", _on_lock_all))
	_vbox.add_child(skrow2)

	# Spawning
	_vbox.add_child(_label("Spawn (at player)", 13))
	var sprow := _row()
	for kind in ["Bat", "Frog", "Witch", "Necro", "Boss"]:
		sprow.add_child(_button(kind, _on_spawn.bind(kind), not has_player))
	_vbox.add_child(sprow)

	# Arcade wave editor — start a fresh arcade run at a wave, or jump the running run.
	_vbox.add_child(_label("Arcade Wave (boss every 15)", 13))
	var wrow := _row()
	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 999
	_wave_spin.value = maxi(1, Global.current_wave)
	_wave_spin.custom_minimum_size = Vector2(72, 0)
	_wave_spin.add_theme_font_override("font", _font)
	wrow.add_child(_wave_spin)
	wrow.add_child(_button("Start Arcade @ Wave", _on_start_at_wave))
	wrow.add_child(_button("Jump to Wave", _on_jump_to_wave, _arcade_stage() == null))
	_vbox.add_child(wrow)

	# Progression
	var r3 := _row()
	r3.add_child(_button("Reset Progression", _on_reset_progression))
	_vbox.add_child(r3)

# ─── UI helpers ──────────────────────────────────────────────────────────────────

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	return l

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	return h

func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 12)
	if not disabled:
		b.pressed.connect(cb)
	return b

func _check(text: String, pressed: bool, cb: Callable, disabled := false) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = pressed
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.disabled = disabled
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", 12)
	if not disabled:
		c.toggled.connect(cb)
	return c

func _get_flag(flag: String) -> bool:
	return is_instance_valid(Global.PlayerBody) and Global.PlayerBody.get(flag)

func _skill_name(s: String) -> String:
	match s:
		"dash": return "Dash"
		"arrows": return "Arrows"
		"double_jump": return "Double Jump"
		"firewall": return "Firewall"
		_: return s

# ─── Tool handlers ───────────────────────────────────────────────────────────────

func _on_god_toggled(on: bool) -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.god_mode = on

func _on_inf_arrows_toggled(on: bool) -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.infinite_arrows = on

func _on_noclip_toggled(on: bool) -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.noclip = on

func _on_fly_toggled(on: bool) -> void:
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.fly_mode = on

func _on_refill_hp() -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p):
		p.health = p.health_max
		p.update_health_bar()

func _on_full_heal() -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p):
		p.health_max = max(p.health_max, 200)
		p.health = p.health_max
		p.update_health_bar()

func _on_kill_enemies() -> void:
	for e in _find_enemies(get_tree().current_scene):
		if e.has_method("take_damage"):
			e.take_damage(99999)
		elif is_instance_valid(e):
			e.queue_free()

func _find_enemies(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	for c in node.get_children():
		if c is AdbotEnemy or c is BuzzerEnemy or c is CollectorEnemy or c is DealerEnemy or c is FinalBossEnemy:
			out.append(c)
		out.append_array(_find_enemies(c))
	return out

func _on_skill_toggled(on: bool, skill: String) -> void:
	if on:
		ProgressionManager.unlock_skill(skill)
	else:
		ProgressionManager.lock_skill(skill)
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.refresh_stats_from_skills()
		Global.PlayerBody._refresh_skill_huds()

func _on_unlock_all() -> void:
	ProgressionManager.unlock_all()
	_sync_skill_checks()

func _on_lock_all() -> void:
	ProgressionManager.lock_all()
	_sync_skill_checks()

func _sync_skill_checks() -> void:
	for s in _skill_checks:
		_skill_checks[s].set_pressed_no_signal(ProgressionManager.is_skill_unlocked(s))
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.refresh_stats_from_skills()
		Global.PlayerBody._refresh_skill_huds()

func _on_spawn(kind: String) -> void:
	var p = Global.PlayerBody
	var scn := get_tree().current_scene
	if not is_instance_valid(p) or scn == null:
		return
	var e = ENEMY_SCENES[kind].instantiate()
	e.global_position = p.global_position + Vector2(140, -40)
	if kind == "Boss" and "activation_x" in e:
		e.activation_x = -100000.0
	scn.add_child(e)
	e.add_to_group("enemies")

func _on_reset_progression() -> void:
	ProgressionManager.reset()
	_sync_skill_checks()

# ─── Arcade Wave editor ────────────────────────────────────────────────────────

# The running arcade stage (has the wave system), or null if we're not in it.
func _arcade_stage() -> Node:
	var scn := get_tree().current_scene
	if scn and scn.has_method("position_to_next_wave"):
		return scn
	return null

# Load a fresh arcade run that begins on the chosen wave. The stage's _ready reads
# Global.current_wave and its first wave is that +1, so seed it with value-1.
func _on_start_at_wave() -> void:
	Global.arcade_mode  = true
	Global.current_wave = maxi(0, int(_wave_spin.value) - 1)
	Engine.time_scale   = 1
	get_tree().change_scene_to_file("res://scene/system/stage.tscn")

# Jump the CURRENT arcade run to the chosen wave: set the counter, clear the field,
# and the stage's _process advances into the target wave (uses set() so we don't
# have to statically type the stage script).
func _on_jump_to_wave() -> void:
	var stage := _arcade_stage()
	if stage == null:
		return
	var target := maxi(0, int(_wave_spin.value) - 1)
	stage.set("current_wave", target)
	stage.set("wave_spawn_ended", true)
	Global.current_wave = target
	_on_kill_enemies()   # clears enemies → the wave-advance fires into the target wave
	# Resume play so the stage can advance into the target wave (mirror Dead Test).
	var pause_menu = get_parent().get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.hide()
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	hide()

# ─── Arcade Mode ──────────────────────────────────────────────────────────────

func _on_arcade_mode_toggle_toggled(toggled_on: bool) -> void:
	Global.arcade_mode = toggled_on
	SettingsManager.save_settings()

# ─── Stage Selector ───────────────────────────────────────────────────────────

func _on_lobby_pressed()   -> void: _go("res://scene/system/lobby_level.tscn")
func _on_stage1_pressed()  -> void: _go("res://scene/Levels/Level1/stage1.tscn")
func _on_stage2_pressed()  -> void: _go("res://scene/Levels/Level2/stage2.tscn")
func _on_stage3_pressed()  -> void: _go("res://scene/Levels/Level3/stage3.tscn")
func _on_stage4_pressed()  -> void: _go("res://scene/Levels/Level4/stage4.tscn")
func _on_stage5_pressed()  -> void: _go("res://scene/Levels/Level5/stage5.tscn")
func _on_stage6_pressed()  -> void: _go("res://scene/Levels/Level6/stage6.tscn")

func _go(path: String) -> void:
	Engine.time_scale = 1
	# Teleporting can skip a stage's skill-unlock NPC; grant everything so later
	# stages that need those skills stay clearable.
	ProgressionManager.unlock_all()
	get_tree().change_scene_to_file(path)

# ─── HP Editor ────────────────────────────────────────────────────────────────

func _on_apply_hp_pressed() -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var new_max := int(_hp_max_spin.value)
	var new_hp  := clampi(int(_hp_spin.value), 0, new_max)
	Global.PlayerBody.health_max = new_max
	Global.PlayerBody.health     = new_hp
	Global.PlayerBody.update_health_bar()

# ─── Level Editor ─────────────────────────────────────────────────────────────

func _on_apply_level_pressed() -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var p = Global.PlayerBody
	var target_level := int(_level_spin.value)
	p.level = target_level
	p.exp   = 0
	p.exp_to_next_level = int(10 * pow(1.1, target_level - 1))
	# Grow strength / max-health to match the new level so damage actually changes (#6).
	if p.has_method("recompute_level_stats"):
		p.recompute_level_stats()
	p.update_exp_lvl_label()
	p.update_health_bar()
	# Sync the HP spinners with the recomputed max so the panel stays truthful.
	_hp_spin.value     = p.health
	_hp_max_spin.value = p.health_max
	ProgressionManager.capture_player(p)

# Give score (#7): the debug panel had no way to add score — now it does.
func _on_give_score() -> void:
	if is_instance_valid(Global.PlayerBody) and Global.PlayerBody.has_method("gain_score"):
		Global.PlayerBody.gain_score(1000)

# ─── Dead Test ────────────────────────────────────────────────────────────────

func _on_dead_test_pressed() -> void:
	if not is_instance_valid(Global.PlayerBody):
		return
	var pause_menu = get_parent().get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.hide()
	Global.PlayerBody.is_game_paused = false
	Engine.time_scale = 1
	Dialogic.paused = false
	hide()
	Global.PlayerBody.die()

# ─── Back ─────────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()

# Esc goes back too, not just the Back button (#1).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
