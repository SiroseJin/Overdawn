extends Control

# ─── Arif's Help Prompt ────────────────────────────────────────────────────────────
# A full-screen Yes/No offer shown AFTER Arif's dialogue ends (mirrors the lobby's
# tutorial prompt, so it isn't lost when the dialogue is skipped). Emits `answered(yes)`.
# ──────────────────────────────────────────────────────────────────────────────────

signal answered(yes: bool)

const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")
const BODY    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var id := TranslationServer.get_locale().begins_with("id")

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "Apakah kamu butuh bantuanku?" if id else "Do you need my help?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	row.add_child(_btn("Ya" if id else "Yes", true))
	row.add_child(_btn("Tidak" if id else "No", false))

func _btn(text: String, yes: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 44)
	b.add_theme_font_override("font", BODY)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func():
		answered.emit(yes)
		queue_free())
	return b
