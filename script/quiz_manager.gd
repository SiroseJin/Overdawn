extends Node

# ─── Quiz Manager (Autoload) ────────────────────────────────────────────────────
# NPC-triggered multiple-choice quizzes about online gambling. The point is
# educational: whether right or wrong, the player is shown the explanation so
# they actually read the important information. Getting answers right rewards
# coins (and a skill point for a perfect score), first completion only.
#
# Trigger from an NPC with:  QuizManager.start_quiz("stage1_quiz")
# Add new quizzes by extending QUIZZES below.
# ───────────────────────────────────────────────────────────────────────────────

const QUIZZES := {
	"stage1_quiz": {
		"en": [
			{
				"q": "A gambling app shows you almost-winning again and again. Why?",
				"options": [
					"A big win must be coming soon",
					"'Near-misses' are engineered to keep you playing",
					"The app is broken",
					"You're just unlucky today",
				],
				"correct": 1,
				"explain": "Near-misses aren't luck — they're designed. Your brain reacts to an almost-win almost like a real one, which keeps you hooked and betting.",
			},
			{
				"q": "You've lost money. The app offers a 'bonus' to keep going. Smart?",
				"options": [
					"Yes, it's free money",
					"Only if you bet bigger to win it back",
					"No — bonuses lock you in and chasing losses makes it worse",
					"Yes, one more round will fix it",
				],
				"correct": 2,
				"explain": "Chasing losses is the trap. 'Bonuses' come with strings that keep you gambling. The winning move is to stop — and to ask for help.",
			},
		],
		"id": [
			{
				"q": "Aplikasi judi terus menunjukkan kamu 'hampir menang'. Kenapa?",
				"options": [
					"Kemenangan besar pasti akan datang",
					"'Hampir menang' dirancang agar kamu terus bermain",
					"Aplikasinya rusak",
					"Kamu sedang sial saja",
				],
				"correct": 1,
				"explain": "'Hampir menang' bukan keberuntungan — itu dirancang. Otakmu bereaksi terhadap hampir-menang hampir seperti menang sungguhan, sehingga kamu terus terpancing.",
			},
			{
				"q": "Kamu sudah kalah. Aplikasi menawarkan 'bonus' agar lanjut. Bijak?",
				"options": [
					"Ya, itu uang gratis",
					"Hanya jika bertaruh lebih besar untuk menebus",
					"Tidak — bonus mengunci kamu dan mengejar kekalahan memperburuknya",
					"Ya, satu ronde lagi pasti menutup",
				],
				"correct": 2,
				"explain": "Mengejar kekalahan adalah jebakannya. 'Bonus' punya syarat yang membuatmu terus berjudi. Langkah yang benar adalah berhenti — dan minta bantuan.",
			},
		],
	},
	# Stage 4 — inside the machine.
	"stage4_quiz": {
		"en": [
			{
				"q": "Why does the app hand you a 'bonus' right as you're about to quit?",
				"options": [
					"To thank you for playing",
					"The algorithm saw you slowing down and is pulling you back in",
					"Because you earned it fairly",
					"It's completely random",
				],
				"correct": 1,
				"explain": "The system tracks your behavior. The instant you hesitate, it offers a reward to re-hook you. The timing is deliberate — not generosity.",
			},
			{
				"q": "You're out of money, so the app offers a loan to 'win it back'. The truth?",
				"options": [
					"A helpful lifeline",
					"Borrowing to gamble deepens the trap — the debt is the point",
					"A smart way to recover losses",
					"Basically free money",
				],
				"correct": 1,
				"explain": "You can't win back a rigged game with borrowed money. Lending you more is exactly how the machine takes everything. The debt is the goal, not a favor.",
			},
		],
		"id": [
			{
				"q": "Kenapa aplikasi memberimu 'bonus' tepat saat kamu hampir berhenti?",
				"options": [
					"Untuk berterima kasih karena bermain",
					"Algoritma melihatmu melambat dan menarikmu kembali",
					"Karena kamu memang pantas mendapatkannya",
					"Itu benar-benar acak",
				],
				"correct": 1,
				"explain": "Sistem melacak perilakumu. Begitu kamu ragu, ia menawarkan hadiah untuk memancingmu lagi. Waktunya disengaja — bukan kemurahan hati.",
			},
			{
				"q": "Uangmu habis, lalu aplikasi menawarkan pinjaman untuk 'menang kembali'. Faktanya?",
				"options": [
					"Pertolongan yang membantu",
					"Berutang untuk berjudi memperdalam jebakan — utang itulah intinya",
					"Cara cerdas menebus kerugian",
					"Pada dasarnya uang gratis",
				],
				"correct": 1,
				"explain": "Kamu tidak bisa memenangkan kembali permainan yang dicurangi dengan uang pinjaman. Meminjamkanmu lebih banyak justru cara mesin mengambil segalanya. Utang adalah tujuannya, bukan bantuan.",
			},
		],
	},
	# The final lesson — a must-do gate before the Stage 5 boss.
	"stage5_quiz": {
		"en": [
			{
				"q": "After all you've seen, what is an online gambling company's real product?",
				"options": [
					"Fun games of chance",
					"Your time, money and attention — engineered into a habit",
					"A fair shot at getting rich",
					"Generous free bonuses",
				],
				"correct": 1,
				"explain": "The house always wins by design. What they truly sell is a habit built to extract your time and money for as long as possible.",
			},
			{
				"q": "A friend says: 'I can stop anytime, I'm just unlucky lately.' The red flag?",
				"options": [
					"Nothing — that's normal",
					"They need a better strategy",
					"Chasing losses while insisting you can quit is a classic warning sign",
					"They should bet more to recover",
				],
				"correct": 2,
				"explain": "Believing you can quit anytime while chasing losses is one of the clearest signs of gambling harm. Recovery starts with honesty and asking for help.",
			},
			{
				"q": "What actually beats a system built to keep you playing?",
				"options": [
					"Winning big just once",
					"A smarter betting system",
					"Walking away — and helping others do the same",
					"Only playing on weekends",
				],
				"correct": 2,
				"explain": "No betting system beats a rigged game. The only real win is to walk away, and to help others see the trap too. That is why you are here.",
			},
		],
		"id": [
			{
				"q": "Setelah semua yang kamu lihat, apa produk asli perusahaan judi online?",
				"options": [
					"Permainan untung-untungan yang seru",
					"Waktu, uang, dan perhatianmu — dirancang jadi kebiasaan",
					"Kesempatan adil untuk jadi kaya",
					"Bonus gratis yang murah hati",
				],
				"correct": 1,
				"explain": "Bandar selalu menang secara desain. Yang mereka jual sebenarnya adalah kebiasaan yang dibuat untuk menguras waktu dan uangmu selama mungkin.",
			},
			{
				"q": "Temanmu berkata: 'Aku bisa berhenti kapan saja, cuma lagi sial.' Tanda bahaya?",
				"options": [
					"Tidak ada — itu wajar",
					"Dia butuh strategi lebih baik",
					"Mengejar kekalahan sambil merasa bisa berhenti adalah tanda peringatan klasik",
					"Dia harus bertaruh lebih untuk menebus",
				],
				"correct": 2,
				"explain": "Merasa bisa berhenti kapan saja sambil mengejar kekalahan adalah salah satu tanda paling jelas kecanduan judi. Pemulihan dimulai dari kejujuran dan meminta bantuan.",
			},
			{
				"q": "Apa yang benar-benar mengalahkan sistem yang dibuat agar kamu terus bermain?",
				"options": [
					"Menang besar sekali saja",
					"Sistem taruhan yang lebih pintar",
					"Berhenti dan pergi — serta membantu orang lain melakukannya",
					"Bermain hanya di akhir pekan",
				],
				"correct": 2,
				"explain": "Tidak ada sistem taruhan yang mengalahkan permainan yang dicurangi. Kemenangan sejati adalah pergi, dan membantu orang lain melihat jebakannya juga. Itulah sebabnya kamu di sini.",
			},
		],
	},
}

var _on_finished: Callable = Callable()

var _layer: CanvasLayer
var _title_label: Label
var _q_label: Label
var _options_box: VBoxContainer
var _explain_label: Label
var _continue_btn: Button
var _font: FontFile

var _active := false
var _questions: Array = []
var _index := 0
var _correct_count := 0
var _quiz_id := ""

# ───────────────────────────────────────────────────────────────────────────────

# Must-do quiz: jumps straight into the questions (no skip). `on_finished` is
# called as on_finished(correct, total) once the player closes the results —
# the caller (an NPC) decides the reward / whether they may proceed. A perfect
# score (correct == total) is a pass.
func start_quiz(quiz_id: String, on_finished := Callable()) -> void:
	if _begin(quiz_id, on_finished):
		_show_question()

# Optional quiz: shows a Take / Not now choice first. Skipping closes without a
# reward; the caller can offer it again later.
func offer_quiz(quiz_id: String, on_finished := Callable()) -> void:
	if _begin(quiz_id, on_finished):
		_show_prompt()

# Shared setup. Returns false (and fires the callback empty) if the quiz has no
# questions or one is already running.
func _begin(quiz_id: String, on_finished: Callable) -> bool:
	if _active:
		return false
	var quiz_set: Dictionary = QUIZZES.get(quiz_id, {})
	var locale := "id" if TranslationServer.get_locale().begins_with("id") else "en"
	_questions = quiz_set.get(locale, quiz_set.get("en", []))
	if _questions.is_empty():
		if on_finished.is_valid():
			on_finished.call(0, 0)
		return false

	_quiz_id       = quiz_id
	_on_finished   = on_finished
	_index         = 0
	_correct_count = 0
	_active        = true

	_ensure_ui()
	_layer.visible = true
	_set_paused(true)
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.conversation_safe = true
	return true

# Take / Not now choice for optional quizzes.
func _show_prompt() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	_title_label.text = tr("Optional Quiz")
	_q_label.text = tr("Answer a few questions about what you learned this stage? You can skip and come back anytime.")
	_explain_label.visible = false
	_continue_btn.visible  = false

	var take := Button.new()
	take.text = tr("Take the quiz")
	_style(take, 14)
	take.pressed.connect(_show_question)
	_options_box.add_child(take)

	var skip := Button.new()
	skip.text = tr("Not now")
	_style(skip, 14)
	skip.pressed.connect(_on_skip_pressed)
	_options_box.add_child(skip)

func _on_skip_pressed() -> void:
	_on_finished = Callable()   # skipping earns no reward
	_close()

# ─── UI construction (lazy, once) ────────────────────────────────────────────────

func _ensure_ui() -> void:
	if _layer != null:
		return
	_font = load("res://art/Fonts/skeleboom.ttf")

	_layer = CanvasLayer.new()
	_layer.layer = 50
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_title_label, 20)
	vbox.add_child(_title_label)

	_q_label = Label.new()
	_q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_q_label, 15)
	vbox.add_child(_q_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_options_box)

	_explain_label = Label.new()
	_explain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explain_label.visible = false
	_style(_explain_label, 13)
	_explain_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	vbox.add_child(_explain_label)

	_continue_btn = Button.new()
	_continue_btn.visible = false
	_style(_continue_btn, 14)
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)

func _style(c: Control, size: int) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", size)

# ─── Flow ────────────────────────────────────────────────────────────────────────

func _show_question() -> void:
	var qd: Dictionary = _questions[_index]
	_title_label.text = "%s  (%d/%d)" % [tr("Quiz"), _index + 1, _questions.size()]
	_q_label.text = qd["q"]

	for child in _options_box.get_children():
		child.queue_free()

	var options: Array = qd["options"]
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style(b, 13)
		b.pressed.connect(_on_answer_pressed.bind(i))
		_options_box.add_child(b)

	_explain_label.visible = false
	_continue_btn.visible  = false

func _on_answer_pressed(chosen: int) -> void:
	var qd: Dictionary = _questions[_index]
	var correct: int = qd["correct"]

	# Lock the options and color-code the result
	var buttons := _options_box.get_children()
	for i in buttons.size():
		var b: Button = buttons[i]
		b.disabled = true
		if i == correct:
			b.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elif i == chosen:
			b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if chosen == correct:
		_correct_count += 1

	_explain_label.text    = qd["explain"]
	_explain_label.visible = true
	_continue_btn.text = tr("Continue") if _index < _questions.size() - 1 else tr("Finish")
	_continue_btn.visible  = true

func _on_continue_pressed() -> void:
	_index += 1
	if _index < _questions.size():
		_show_question()
	else:
		_show_summary()

func _show_summary() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	var passed: bool = _correct_count == _questions.size()
	_title_label.text = tr("Quiz Complete")
	_q_label.text = "%s: %d / %d" % [tr("Correct answers"), _correct_count, _questions.size()]
	_explain_label.text    = tr("Passed!") if passed else tr("Not quite — talk to me to try again.")
	_explain_label.visible = true
	_continue_btn.text     = tr("Close")
	_continue_btn.visible  = true
	# Rewire continue to close
	if _continue_btn.pressed.is_connected(_on_continue_pressed):
		_continue_btn.pressed.disconnect(_on_continue_pressed)
	_continue_btn.pressed.connect(_close, CONNECT_ONE_SHOT)

func _close() -> void:
	_active = false
	_layer.visible = false
	_set_paused(false)
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.conversation_safe = false
	# Restore the normal continue handler for next time (skip path never
	# disconnected it, so only reconnect when needed)
	if not _continue_btn.pressed.is_connected(_on_continue_pressed):
		_continue_btn.pressed.connect(_on_continue_pressed)
	# Hand the result back to the caller (NPC) to decide reward / progression
	var cb := _on_finished
	_on_finished = Callable()
	if cb.is_valid():
		cb.call(_correct_count, _questions.size())

func _set_paused(paused: bool) -> void:
	Engine.time_scale = 0 if paused else 1
	if is_instance_valid(Global.PlayerBody):
		Global.PlayerBody.is_game_paused = paused
