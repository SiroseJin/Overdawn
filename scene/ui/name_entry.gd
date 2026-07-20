extends Control

# ─── Name Entry (#15) ─────────────────────────────────────────────────────────────
# Shown on New Game: the player types a name so each save is uniquely theirs. Blank
# falls back to "Player". Emits submitted(name) / cancelled.
# ──────────────────────────────────────────────────────────────────────────────────

signal submitted(player_name: String)
signal cancelled

const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")
const BODY    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")

var _line: LineEdit

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var id := TranslationServer.get_locale().begins_with("id")

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "Siapa namamu?" if id else "What's your name?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	_line = LineEdit.new()
	_line.custom_minimum_size = Vector2(340, 42)
	_line.max_length = 16
	_line.placeholder_text = "Player"
	_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_override("font", BODY)
	_line.add_theme_font_size_override("font_size", 18)
	_line.text_submitted.connect(func(_t): _submit())
	_line.text_changed.connect(func(_t): AudioManager.play_ui("name_key"))
	box.add_child(_line)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(_btn("Mulai" if id else "Begin", func(): _submit()))
	row.add_child(_btn("Batal" if id else "Cancel", func(): cancelled.emit(); queue_free()))

	_line.call_deferred("grab_focus")

func _submit() -> void:
	var n := _line.text.strip_edges()
	submitted.emit(n if n != "" else "Player")
	queue_free()

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 42)
	b.add_theme_font_override("font", BODY)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b
