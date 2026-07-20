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
	# Stage 1 — INTRO. Easy, definitional: what online gambling even is.
	"stage1_quiz": {
		"en": [
			{
				"q": "What is 'online gambling' (judol)?",
				"options": [
					"A free game just for fun",
					"Betting real money on games of chance through an app or website",
					"A safe way to invest and grow your money",
					"A normal video game",
				],
				"correct": 1,
				"explain": "Online gambling means betting real money on games of chance in apps or sites. It is dressed up like a game, but it is built to take your money.",
			},
			{
				"q": "The glowing 'Adbots' flash 'FREE CREDITS! GUARANTEED JACKPOT!'. What are they really?",
				"options": [
					"Helpful gifts",
					"Gambling ads, luring people in",
					"Real, guaranteed prizes",
					"Just harmless decorations",
				],
				"correct": 1,
				"explain": "Those flashy promises are gambling ADS. 'Free credit' and 'guaranteed jackpot' are just bait to get you to start.",
			},
			{
				"q": "Can you reliably get rich from online gambling?",
				"options": [
					"Yes, with the right strategy",
					"Yes, if you are lucky enough",
					"No - it is rigged so the house always wins in the end",
					"Yes, everyone wins eventually",
				],
				"correct": 2,
				"explain": "No. The math and design are rigged so the operator - the house - always wins over time. It is not a way to make money.",
			},
		],
		"id": [
			{
				"q": "Apa itu 'judi online' (judol)?",
				"options": [
					"Permainan gratis sekadar hiburan",
					"Bertaruh uang sungguhan pada permainan untung-untungan lewat aplikasi atau situs",
					"Cara aman berinvestasi dan menambah uang",
					"Video game biasa",
				],
				"correct": 1,
				"explain": "Judi online berarti bertaruh uang sungguhan pada permainan untung-untungan di aplikasi atau situs. Dikemas seperti game, tapi dibuat untuk mengambil uangmu.",
			},
			{
				"q": "'Adbot' berkedip 'KREDIT GRATIS! JACKPOT DIJAMIN!'. Sebenarnya itu apa?",
				"options": [
					"Hadiah yang membantu",
					"Iklan judi, yang memancing orang",
					"Hadiah asli yang dijamin",
					"Sekadar hiasan tak berbahaya",
				],
				"correct": 1,
				"explain": "Janji-janji mencolok itu adalah IKLAN judi. 'Kredit gratis' dan 'jackpot dijamin' cuma umpan agar kamu mulai.",
			},
			{
				"q": "Bisakah kamu benar-benar jadi kaya dari judi online?",
				"options": [
					"Ya, dengan strategi yang tepat",
					"Ya, kalau cukup beruntung",
					"Tidak - dicurangi agar bandar selalu menang pada akhirnya",
					"Ya, semua orang akhirnya menang",
				],
				"correct": 2,
				"explain": "Tidak. Matematika dan desainnya dicurangi agar operator - sang bandar - selalu menang dalam jangka panjang. Ini bukan cara mencari uang.",
			},
		],
	},
	# Stage 2 — the bait platforms. 'Free' things are bait.
	"stage2_quiz": {
		"en": [
			{
				"q": "A platform dangles a FREE coin right where you need a step. In gambling, that is a...?",
				"options": [
					"Genuine gift",
					"Bait, to get you to step in and start playing",
					"Reward for your skill",
					"Harmless glitch",
				],
				"correct": 1,
				"explain": "'Free credits' and easy bonuses are bait. They cost the operator almost nothing and get you playing - then take far more back.",
			},
			{
				"q": "You grab one 'free credit', then another, then another. What is really happening?",
				"options": [
					"You are winning",
					"You are being eased into a habit, one 'free' thing at a time",
					"Nothing - it is harmless fun",
					"You are getting ahead",
				],
				"correct": 1,
				"explain": "Each 'free' claim pulls you a little deeper until betting feels normal. Nothing here is truly free - that is how the hook sets.",
			},
		],
		"id": [
			{
				"q": "Sebuah platform menggantung koin GRATIS tepat di tempat kamu butuh pijakan. Dalam judi, itu...?",
				"options": [
					"Hadiah tulus",
					"Umpan, agar kamu masuk dan mulai bermain",
					"Imbalan atas keahlianmu",
					"Bug tak berbahaya",
				],
				"correct": 1,
				"explain": "'Kredit gratis' dan bonus mudah adalah umpan. Bagi operator hampir tanpa biaya, dan membuatmu bermain - lalu mengambil jauh lebih banyak.",
			},
			{
				"q": "Kamu ambil satu 'kredit gratis', lalu lagi, lalu lagi. Apa yang sebenarnya terjadi?",
				"options": [
					"Kamu sedang menang",
					"Kamu perlahan dibiasakan, satu 'gratisan' demi satu",
					"Tidak apa-apa - cuma hiburan",
					"Kamu makin untung",
				],
				"correct": 1,
				"explain": "Tiap klaim 'gratis' menyeretmu sedikit lebih dalam sampai bertaruh terasa biasa. Tidak ada yang benar-benar gratis - begitulah kailnya menancap.",
			},
		],
	},
	# Stage 3 — the rising debt. Debt compounds; loans deepen the trap.
	"stage3_quiz": {
		"en": [
			{
				"q": "Here the DEBT rises the longer you linger. What does that represent?",
				"options": [
					"A time bonus",
					"Interest and debt growing on their own, whether you win or not",
					"Your score climbing",
					"Nothing important",
				],
				"correct": 1,
				"explain": "Gambling debt compounds - the interest grows by itself. Standing still, or borrowing to keep playing, only lets it climb higher.",
			},
			{
				"q": "You are out of money, so the app offers a loan to 'win it back'. The truth?",
				"options": [
					"A helpful lifeline",
					"Borrowing to gamble only deepens the trap - you can't beat a rigged game",
					"A smart way to recover losses",
					"Basically free money",
				],
				"correct": 1,
				"explain": "You cannot win back a rigged game with borrowed money. Lending you more is exactly how it takes everything. The debt is the goal, not a favor.",
			},
		],
		"id": [
			{
				"q": "Di sini UTANG naik semakin lama kamu berdiam. Itu melambangkan apa?",
				"options": [
					"Bonus waktu",
					"Bunga dan utang yang tumbuh sendiri, entah kamu menang atau tidak",
					"Skormu yang naik",
					"Tidak penting",
				],
				"correct": 1,
				"explain": "Utang judi berbunga majemuk - bunganya tumbuh sendiri. Diam saja, atau berutang untuk terus main, hanya membuatnya makin tinggi.",
			},
			{
				"q": "Uangmu habis, lalu aplikasi menawarkan pinjaman untuk 'menang kembali'. Faktanya?",
				"options": [
					"Pertolongan yang membantu",
					"Berutang untuk berjudi hanya memperdalam jebakan - kamu tak bisa mengalahkan permainan curang",
					"Cara cerdas menebus kerugian",
					"Pada dasarnya uang gratis",
				],
				"correct": 1,
				"explain": "Kamu tak bisa memenangkan kembali permainan curang dengan uang pinjaman. Meminjamkanmu lebih banyak justru cara ia mengambil segalanya. Utang adalah tujuannya, bukan bantuan.",
			},
		],
	},
	# Stage 4 — inside the machine / the pull zones. Engineered psychology.
	"stage4_quiz": {
		"en": [
			{
				"q": "The machine shows you 'almost won' over and over. Why?",
				"options": [
					"A big win is about to come",
					"'Near-misses' are engineered to keep you playing",
					"The machine is broken",
					"You are just unlucky",
				],
				"correct": 1,
				"explain": "Near-misses aren't luck - they're designed. Your brain reacts to an almost-win almost like a real win, which keeps you hooked and betting.",
			},
			{
				"q": "The moment you decide to leave, a bonus or free spin appears and tugs you back. Why?",
				"options": [
					"To thank you for playing",
					"The algorithm saw you slowing down and is pulling you back in",
					"Because you earned it fairly",
					"It is completely random",
				],
				"correct": 1,
				"explain": "The system tracks you. The instant you hesitate, it dangles a reward to re-hook you. The timing is deliberate - not generosity. Raising your firewall is choosing to walk anyway.",
			},
		],
		"id": [
			{
				"q": "Mesin terus menunjukkanmu 'nyaris menang' berulang kali. Kenapa?",
				"options": [
					"Kemenangan besar akan datang",
					"'Nyaris menang' dirancang agar kamu terus bermain",
					"Mesinnya rusak",
					"Kamu sedang sial saja",
				],
				"correct": 1,
				"explain": "'Nyaris menang' bukan keberuntungan - itu dirancang. Otakmu bereaksi pada nyaris-menang hampir seperti menang sungguhan, sehingga kamu terus terpancing.",
			},
			{
				"q": "Begitu kamu memutuskan pergi, muncul bonus atau putaran gratis yang menarikmu kembali. Kenapa?",
				"options": [
					"Untuk berterima kasih karena bermain",
					"Algoritma melihatmu melambat dan menarikmu kembali",
					"Karena kamu memang pantas",
					"Itu benar-benar acak",
				],
				"correct": 1,
				"explain": "Sistem melacakmu. Begitu kamu ragu, ia mengumpankan hadiah untuk memancingmu lagi. Waktunya disengaja - bukan kemurahan hati. Menaikkan firewall adalah kamu memilih tetap pergi.",
			},
		],
	},
	# Stage 5 — the final lesson. A must-do gate before the boss. Hardest / synthesis.
	"stage5_quiz": {
		"en": [
			{
				"q": "After all you've seen, what is an online gambling company's real product?",
				"options": [
					"Fun games of chance",
					"Your time, money and attention - engineered into a habit",
					"A fair shot at getting rich",
					"Generous free bonuses",
				],
				"correct": 1,
				"explain": "The house always wins by design. What they truly sell is a habit built to extract your time and money for as long as possible.",
			},
			{
				"q": "A friend says: 'I can stop anytime, I'm just unlucky lately.' The red flag?",
				"options": [
					"Nothing - that's normal",
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
					"Walking away - and helping others do the same",
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
					"Waktu, uang, dan perhatianmu - dirancang jadi kebiasaan",
					"Kesempatan adil untuk jadi kaya",
					"Bonus gratis yang murah hati",
				],
				"correct": 1,
				"explain": "Bandar selalu menang secara desain. Yang mereka jual sebenarnya adalah kebiasaan yang dibuat untuk menguras waktu dan uangmu selama mungkin.",
			},
			{
				"q": "Temanmu berkata: 'Aku bisa berhenti kapan saja, cuma lagi sial.' Tanda bahaya?",
				"options": [
					"Tidak ada - itu wajar",
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
					"Berhenti dan pergi - serta membantu orang lain melakukannya",
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
# Build the quiz UI ahead of time (hidden) so opening it later is instant. Call when
# the player starts a quiz NPC's dialogue — the (heavy) UI is constructed while they
# read, so showing it when the dialogue ends costs nothing.
func preload_ui() -> void:
	if _active:
		return
	_ensure_ui()
	if _layer:
		_layer.visible = false

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

	var _t0 := Time.get_ticks_msec()   # [DBG-TIMING] remove after diagnosis
	_ensure_ui()
	print("[DBG] quiz _begin: _ensure_ui took %dms, showing now @%d" % [Time.get_ticks_msec() - _t0, Time.get_ticks_msec()])
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
	_font = load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf")

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
		AudioManager.play_ui("quiz_correct")
	else:
		AudioManager.play_ui("quiz_wrong")

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
	if passed:
		AudioManager.play_ui("quiz_pass")
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
