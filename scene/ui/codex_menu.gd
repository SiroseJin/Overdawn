extends Control

# ─── Codex Menu (Guide + Lore) ────────────────────────────────────────────────────
# Two tabs over the CodexManager databases. Guide = how the game works (controls,
# enemies, gimmicks); Lore = the anti-gambling story. Unlocked entries show their full
# text; still-locked ones show as "Undiscovered" so the player sees there's more to
# find. Layout lives in codex_menu.tscn (editable); this fills the scrolling list.
#
# Overlay (Back frees it) or standalone (returns to settings_return_path). Open it on a
# given tab by setting `start_tab` ("guide"/"lore") before adding it to the tree.
# ──────────────────────────────────────────────────────────────────────────────────

const FONT    := preload("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")
const DISPLAY := preload("res://art/Fonts/VT323/VT323-Regular.ttf")

var start_tab: String = "guide"
var _tab: String = "guide"

@onready var _list:      VBoxContainer = $Margin/Root/Scroll/List
@onready var _count:     Label         = $Margin/Root/Count
@onready var _guide_tab: Button        = $Margin/Root/Tabs/GuideTab
@onready var _lore_tab:  Button        = $Margin/Root/Tabs/LoreTab
@onready var _back:      Button        = $Margin/Root/Back

func _ready() -> void:
	_guide_tab.pressed.connect(func(): _select("guide"))
	_lore_tab.pressed.connect(func(): _select("lore"))
	_back.pressed.connect(_on_back)
	_select(start_tab)

func _select(tab: String) -> void:
	_tab = tab
	_guide_tab.button_pressed = tab == "guide"
	_lore_tab.button_pressed = tab == "lore"
	_build()

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()

	var is_guide := _tab == "guide"
	var table: Dictionary = CodexManager.GUIDE if is_guide else CodexManager.LORE
	var have := CodexManager.guide_count() if is_guide else CodexManager.lore_count()
	_count.text = "%s: %d / %d" % [tr("Unlocked"), have, table.size()]

	for id in table:
		var unlocked: bool = CodexManager.is_guide_unlocked(id) if is_guide else CodexManager.is_lore_unlocked(id)
		_add_card(_tab, id, unlocked)

# Each entry is a click-to-expand card: the header shows the title; clicking it reveals
# the picture + full detail (#6). Collapsed by default so the list stays scannable.
func _add_card(kind: String, id: String, unlocked: bool) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.95) if unlocked else Color(0.07, 0.08, 0.1, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.border_color = Color(0.5, 0.7, 1.0) if unlocked else Color(0.2, 0.22, 0.26)
	sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title := CodexManager.name_of(kind, id) if unlocked else tr("Undiscovered")
	var tag := ("◆ " if unlocked else "🔒 ")

	# Clickable header (Button → gets the global UI click sound for free).
	var header := Button.new()
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_override("font", DISPLAY)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1, 1, 1) if unlocked else Color(0.5, 0.52, 0.58))
	header.text = "▶  " + tag + title
	box.add_child(header)

	# Collapsible body (built once, shown/hidden on click).
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.visible = false
	box.add_child(body)

	if unlocked:
		var portrait := _portrait(kind, id)
		if portrait != null:
			var pic := TextureRect.new()
			pic.texture = portrait
			pic.custom_minimum_size = Vector2(0, 140)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
			body.add_child(pic)
		var desc := _label(12, Color(0.9, 0.92, 0.97))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = CodexManager.desc_of(kind, id)
		body.add_child(desc)
		# The "great detail" section, if the entry has one.
		var detail := CodexManager.detail_of(kind, id)
		if detail != "":
			var dd := _label(12, Color(0.78, 0.85, 0.95))
			dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dd.text = detail
			body.add_child(dd)
	else:
		var locked := _label(12, Color(0.45, 0.47, 0.52))
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.text = tr("Keep playing to reveal this entry.")
		body.add_child(locked)
		var hint := CodexManager.hint_of(kind, id)
		if hint != "":
			var h := _label(11, Color(0.85, 0.72, 0.4))
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.text = "💡 " + hint
			body.add_child(h)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼  " if body.visible else "▶  ") + tag + title)

	_list.add_child(card)

# Build a clean single-frame portrait from an entry's `img` (handles spritesheets by
# cropping the first frame via AtlasTexture). Returns null if the entry has no image.
func _portrait(kind: String, id: String) -> Texture2D:
	var path := CodexManager.img_of(kind, id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var frames: int = CodexManager.img_frames_of(kind, id)
	if frames <= 1:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, float(tex.get_width()) / frames, tex.get_height())
	return at

# ─── Helpers ──────────────────────────────────────────────────────────────────────

func _label(font_size: int, color: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_back() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.settings_return_path)
	else:
		queue_free()

# Esc goes back too, not just the Back button (#1).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
