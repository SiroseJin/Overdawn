extends CharacterBody2D

## Emitted when this NPC's dialogue finishes (a level can react — e.g. reveal a
## hidden platform once the player has talked to them).
signal talked(npc_id: String)

@export var dialogue_timeline: String = "npc1timeline"
## Optional id so the game can remember this NPC was spoken to.
@export var npc_id: String = ""
## If set (e.g. "double_jump"), finishing this NPC's dialogue unlocks that skill.
@export var unlocks_skill: String = ""
## If set, finishing this NPC's dialogue hands the player this key (opens a
## matching LockedDoor). Used to gate stage exits behind a story beat.
@export var grants_key: String = ""
## If set (e.g. "stage1_quiz"), talking to this NPC runs an educational quiz.
## The player must answer everything correctly to pass; failing lets them talk
## again to retry. Once passed, the quiz won't re-appear.
@export var quiz_id: String = ""
## Passing the quiz grants this key (use a matching LockedDoor to gate the exit).
@export var quiz_grants_key: String = ""
## Passing the quiz grants these bonus coins (first pass only).
@export var quiz_bonus_coins: int = 0
## Passing the quiz grants a bonus skill point (first pass only).
@export var quiz_bonus_skill_point: bool = false
## Optional quiz: the player is offered a Take / Not now choice and may skip it.
## Once they've heard the intro once, talking again jumps straight to that offer.
## When false, it's a must-do quiz (no skip; typically gates the exit via a key).
@export var quiz_optional: bool = true
## Dialogue shown once the quiz has been passed — a different, closing line so the
## NPC doesn't just repeat the intro. Falls back to the intro if left empty.
@export var post_quiz_timeline: String = ""
## Optional distinct look. Assign idle + dialogue sprite sheets (128×128 frames)
## to make this NPC visually different from the others.
@export var idle_texture: Texture2D
@export var dialogue_texture: Texture2D

const FRAME_SIZE := 128

# Built SpriteFrames are shared across every NPC using the same skin (and across
# scene loads) so we only slice each sprite sheet once per session.
static var _frames_cache: Dictionary = {}

@onready var sprite:        AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_hint: Label            = $InteractHint

var is_chatting    := false
var player_nearby  := false

func _ready():
	add_to_group("npc")
	_setup_marker()
	# The stage's _ready configures npc_id / unlocks_skill / grants_key AFTER this
	# node's _ready, so colour/show the marker one frame later.
	call_deferred("refresh_marker")
	if sprite == null:
		print("ERROR: AnimatedSprite2D not found")
		return
	if idle_texture and dialogue_texture:
		_build_frames()

# ─── Required / optional ─────────────────────────────────────────────────────────
# A "must" NPC either unlocks a skill or hands over a key that opens the way forward.
# Everyone else is optional lore/teaching. The stage forbids leaving until every
# must NPC's requirement is met (see Global.all_required_npcs_done).

func is_required() -> bool:
	return unlocks_skill != "" or grants_key != "" or quiz_grants_key != ""

# Has this NPC's gate condition been satisfied? Skill/key NPCs: talked to. Quiz-key
# NPCs: the quiz has actually been passed.
func is_requirement_met() -> bool:
	if not is_required():
		return true
	if quiz_grants_key != "":
		return quiz_id != "" and ProgressionManager.has_talked_to("quizpass_" + quiz_id)
	return npc_id != "" and ProgressionManager.has_talked_to(npc_id)

# ─── "!" marker (red = must talk, yellow = optional) ─────────────────────────────

var _marker: Label

func _setup_marker() -> void:
	_marker = Label.new()
	_marker.text = "!"
	_marker.add_theme_font_override("font", load("res://art/Fonts/skeleboom.ttf"))
	_marker.add_theme_font_size_override("font_size", 30)
	_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	_marker.add_theme_constant_override("outline_size", 5)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.custom_minimum_size = Vector2(20, 0)
	_marker.position = Vector2(-10, -86)
	_marker.z_index = 20
	add_child(_marker)

# Colour by must/optional and hide once satisfied. Safe to call any time.
func refresh_marker() -> void:
	if _marker == null:
		return
	var required := is_required()
	_marker.add_theme_color_override("font_color",
		Color(1, 0.25, 0.2) if required else Color(1, 0.85, 0.2))
	if required:
		_marker.visible = not is_requirement_met()
	else:
		_marker.visible = npc_id == "" or not ProgressionManager.has_talked_to(npc_id)

# Swap this NPC's sprite sheets at runtime (used by stage scripts to give each
# placed NPC a distinct look without duplicating the scene).
func set_appearance(idle_tex: Texture2D, dialogue_tex: Texture2D) -> void:
	idle_texture = idle_tex
	dialogue_texture = dialogue_tex
	if is_inside_tree():
		_build_frames()

func _build_frames() -> void:
	if idle_texture == null or dialogue_texture == null or sprite == null:
		return
	var key := idle_texture.resource_path + "|" + dialogue_texture.resource_path
	var sf: SpriteFrames = _frames_cache.get(key)
	if sf == null:
		sf = SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		_add_anim(sf, "idle", idle_texture, true)
		_add_anim(sf, "dialog", dialogue_texture, false)
		_frames_cache[key] = sf
	sprite.sprite_frames = sf
	sprite.play("idle")

func _add_anim(sf: SpriteFrames, anim: String, tex: Texture2D, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 5.0)
	var count: int = max(1, int(tex.get_width() / FRAME_SIZE))
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		sf.add_frame(anim, at)

func on_player_enter():
	player_nearby = true
	if sprite:
		sprite.play("dialog")
	interact_hint.show()
	refresh_marker()

func on_player_exit():
	player_nearby = false
	if sprite:
		sprite.play("idle")
	interact_hint.hide()

func start_dialogue():
	if is_chatting:
		return

	is_chatting = true
	interact_hint.hide()

	# Safe zone: the player can't be hurt while a conversation is happening.
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.conversation_safe = true

	var to_play := _dialogue_to_play()
	if to_play == "" or not Dialogic:
		# No dialogue to show (intro already heard, quiz not done) — go straight
		# to the quiz offer / gate.
		is_chatting = false
		_on_dialogue_finished()
		if player_nearby:
			interact_hint.show()
		return

	var timeline := to_play
	if TranslationServer.get_locale().begins_with("id"):
		var id_variant := to_play + "_id"
		var dtl_dir: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
		if dtl_dir.has(id_variant):
			timeline = id_variant

	Dialogic.start(timeline)
	Dialogic.timeline_ended.connect(func():
		is_chatting = false
		_on_dialogue_finished()
		if player_nearby:
			interact_hint.show()
	, CONNECT_ONE_SHOT)

# Which dialogue (if any) to play before the quiz offer/gate, based on progress.
func _dialogue_to_play() -> String:
	if quiz_id == "":
		return dialogue_timeline
	if ProgressionManager.has_talked_to("quizpass_" + quiz_id):
		# Quiz already passed → show the distinct post-quiz dialogue.
		return post_quiz_timeline if post_quiz_timeline != "" else dialogue_timeline
	if npc_id != "" and ProgressionManager.has_talked_to(npc_id):
		# Intro already heard, quiz not done → skip straight to the offer/gate.
		return ""
	return dialogue_timeline

func _on_dialogue_finished():
	ProgressionManager.mark_npc_talked(npc_id)
	talked.emit(npc_id)
	if unlocks_skill != "":
		ProgressionManager.unlock_skill(unlocks_skill)
	if grants_key != "" and not ProgressionManager.has_key(grants_key):
		ProgressionManager.add_key(grants_key)
		if is_instance_valid(Global.PlayerBody) and Global.PlayerBody.has_method("show_toast"):
			Global.PlayerBody.show_toast(tr("You found a way out"))

	# Quiz handling. Once passed, no quiz runs (the post-quiz dialogue already
	# played). Otherwise optional quizzes offer a Take / Not now choice, and
	# must-do quizzes run straight away. The QuizManager owns the safe zone until
	# it closes.
	if quiz_id != "":
		if ProgressionManager.has_talked_to("quizpass_" + quiz_id):
			if is_instance_valid(Global.PlayerBody):
				Global.PlayerBody.conversation_safe = false
		elif quiz_optional:
			QuizManager.offer_quiz(quiz_id, _on_quiz_finished)
		else:
			QuizManager.start_quiz(quiz_id, _on_quiz_finished)
	elif is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.conversation_safe = false

	refresh_marker()   # update / hide the "!" now that we've been talked to

# Called when the player closes the quiz results. A perfect score is a pass and
# grants the configured key / bonus once; otherwise they can talk again to retry.
func _on_quiz_finished(correct: int, total: int) -> void:
	var p := Global.PlayerBody
	var has_toast := is_instance_valid(p) and p.has_method("show_toast")
	if total <= 0 or correct != total:
		# Skipped or failed — nothing granted, they can come back.
		if has_toast and total > 0:
			p.show_toast(tr("Talk again to retry the quiz"))
		return

	# Passed. Reward only the first time so retakes are review, not farming.
	var first_pass := not ProgressionManager.has_talked_to("quizpass_" + quiz_id)
	ProgressionManager.mark_npc_talked("quizpass_" + quiz_id)
	if first_pass:
		if quiz_grants_key != "" and not ProgressionManager.has_key(quiz_grants_key):
			ProgressionManager.add_key(quiz_grants_key)
		if quiz_bonus_coins > 0:
			ProgressionManager.add_coins(quiz_bonus_coins)
		if quiz_bonus_skill_point:
			ProgressionManager.add_skill_points(1)
		if has_toast:
			p.show_toast(tr("Quiz passed! Bonus earned"))
	elif has_toast:
		p.show_toast(tr("Quiz passed"))
	refresh_marker()   # a passed quiz may clear a "must" requirement
