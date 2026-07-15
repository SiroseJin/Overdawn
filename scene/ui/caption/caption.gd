@tool
extends Label

class_name Caption

# ─── Caption — a modular, editor-driven name-tag ─────────────────────────────────
# Drop this scene in as a CHILD of ANY object (enemy, NPC, door, gimmick, platform,
# pickup — anything but plain walls/floors) to give it a floating label describing
# what it is. Designed to be edited entirely from the Godot editor:
#
#   • Type the wording in the Inspector: `text_en` (English) and, optionally,
#     `text_id` (Bahasa Indonesia — falls back to text_en when left blank).
#   • DRAG the node in the 2D viewport to move the tag anywhere around the object
#     (above, below, to the side — wherever reads best). For platforms, drag it
#     just BELOW the platform like the tutorial does.
#   • Nothing to wire up: on load it joins the global "caption" group, so the
#     Settings ▸ "Object labels" toggle shows/hides every tag in the game at once.
#
# To caption something new later: instance caption.tscn under it and type the text.
# ────────────────────────────────────────────────────────────────────────────────

## Text shown in English — also the fallback for any language without its own text.
@export_multiline var text_en: String = "Label":
	set(value):
		text_en = value
		if Engine.is_editor_hint():
			text = value

## Text shown when the game language is Indonesian. Leave blank to reuse text_en.
@export_multiline var text_id: String = ""

func _ready() -> void:
	# In the editor just preview the English text so you can see/place the tag.
	if Engine.is_editor_hint():
		text = text_en
		return
	var is_id := TranslationServer.get_locale().begins_with("id")
	text = text_id if (is_id and text_id.strip_edges() != "") else text_en
	add_to_group("caption")
	visible = Global.show_captions
