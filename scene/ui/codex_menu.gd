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

func _add_card(kind: String, id: String, unlocked: bool) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.95) if unlocked else Color(0.07, 0.08, 0.1, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.border_color = Color(0.5, 0.7, 1.0) if unlocked else Color(0.2, 0.22, 0.26)
	sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var head := _label(16, Color(1, 1, 1) if unlocked else Color(0.5, 0.52, 0.58), DISPLAY)
	head.text = ("◆ " + CodexManager.name_of(kind, id)) if unlocked else ("🔒 " + tr("Undiscovered"))
	box.add_child(head)

	# Optional illustration on unlocked entries — bigger card to fit it (#8).
	if unlocked:
		var img_path := CodexManager.img_of(kind, id)
		if img_path != "" and ResourceLoader.exists(img_path):
			var tex := load(img_path) as Texture2D
			if tex:
				var pic := TextureRect.new()
				pic.texture = tex
				pic.custom_minimum_size = Vector2(0, 128)
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
				box.add_child(pic)

	var body := _label(12, Color(0.9, 0.92, 0.97) if unlocked else Color(0.45, 0.47, 0.52))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = CodexManager.desc_of(kind, id) if unlocked else tr("Keep playing to reveal this entry.")
	box.add_child(body)

	# On a locked entry, tell the player how to unlock it (#9).
	if not unlocked:
		var hint := CodexManager.hint_of(kind, id)
		if hint != "":
			var h := _label(11, Color(0.85, 0.72, 0.4))
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.text = "💡 " + hint
			box.add_child(h)

	_list.add_child(card)

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
