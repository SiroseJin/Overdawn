extends Control

# ─── Difficulty Select ──────────────────────────────────────────────────────────────
# Shown on New Game (after the name prompt). Five choices — Casual/Easy/Normal/Hard/
# Expert — each with a one-line effect summary. Emits chosen(difficulty:int) / cancelled.
# The choice is persisted with the save; it only scales enemy attack+HP and level-up EXP.
# ────────────────────────────────────────────────────────────────────────────────────

signal chosen(difficulty: int)
signal cancelled

const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")
const BODY    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")

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
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Pilih Tingkat Kesulitan" if id else "Choose Difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	for d in Difficulty.NAMES_EN.size():
		box.add_child(_row(d))

	var cancel := _btn("Batal" if id else "Cancel", func(): cancelled.emit(); queue_free())
	cancel.custom_minimum_size = Vector2(120, 38)
	var cwrap := CenterContainer.new()
	cwrap.add_child(cancel)
	box.add_child(cwrap)

func _row(d: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var b := _btn(Difficulty.name_of(d), func(): chosen.emit(d); queue_free())
	b.custom_minimum_size = Vector2(150, 46)
	row.add_child(b)

	var blurb := Label.new()
	blurb.text = Difficulty.blurb_of(d)
	blurb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blurb.custom_minimum_size = Vector2(430, 46)
	blurb.add_theme_font_override("font", BODY)
	blurb.add_theme_font_size_override("font_size", 15)
	blurb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	row.add_child(blurb)
	return row

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 46)
	b.add_theme_font_override("font", BODY)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b
