extends Node

# ─── Codex Manager (Autoload) — Guide + Lore ──────────────────────────────────────
# Two unlockable info databases surfaced in the Codex menu (pause → Guide):
#   GUIDE — how the game works: controls, combat, enemies, gimmicks. Some entries are
#           unlocked from the start; the rest unlock the first time you MEET the thing
#           (an enemy, a gimmick, an upgrade screen…).
#   LORE  — the story of online gambling and the people it hurt. Unlocked by playing:
#           clearing stages, passing quizzes, collecting Truth Shards, beating the House.
#
# Unlock state lives in ProgressionManager (guides / lore dicts) so it persists in saves.
# Entries auto-unlock by matching a ProgressionManager.game_event; `default` entries are
# granted immediately. Each unlock fires a "Guide Unlocked" / "Lore Unlocked" toast, and
# unlocking every guide awards the "Well Read" badge.
# ──────────────────────────────────────────────────────────────────────────────────────

signal codex_unlocked(kind: String, id: String)   # kind = "guide" | "lore"

# entry: { en, id, en_d, id_d, default?, ev?, key?, val? }
#   default = true          → unlocked from the start
#   ev / key / val          → unlock when game_event `ev` fires with data[key] == val
#                             (omit key/val to unlock on the event regardless of data)
const GUIDE := {
	# ── Controls & core mechanics (known from the start) ──
	"g_move": {"en": "Movement", "id": "Gerak", "default": true,
		"en_d": "Move with A / D. Jump with Space; press it again in mid-air to Double Jump.",
		"id_d": "Gerak dengan A / D. Lompat dengan Space; tekan lagi di udara untuk Lompat Ganda."},
	"g_combat": {"en": "Combat", "id": "Tempur", "default": true,
		"en_d": "Left-Click: basic attack. Right-Click: heavy attack. E: fire an arrow. Attacks scale with your Strength.",
		"id_d": "Klik-Kiri: serangan dasar. Klik-Kanan: serangan berat. E: tembak panah. Serangan mengikuti Kekuatanmu."},
	"g_dash": {"en": "Dash", "id": "Dash", "default": true,
		"en_d": "Shift dashes you a short distance — cross gaps and dodge. Click during a dash for a Dash Attack.",
		"id_d": "Shift membuatmu dash sejenak — lewati jurang dan mengelak. Klik saat dash untuk Serangan Dash."},
	"g_firewall": {"en": "Firewall", "id": "Firewall", "default": true,
		"en_d": "Q raises a Firewall that blocks incoming hits for a moment — a shield against the machine's pull.",
		"id_d": "Q menaikkan Firewall yang menahan serangan sesaat — tameng dari tarikan mesin."},
	"g_upgrades": {"en": "Upgrades", "id": "Peningkatan", "default": true,
		"en_d": "TAB opens the Upgrades screen. Spend Skill Points (earned each level) on skills, stats and attacks.",
		"id_d": "TAB membuka layar Peningkatan. Pakai Skill Point (didapat tiap level) untuk skill, stat, dan serangan."},
	"g_quests": {"en": "Quests", "id": "Misi", "default": true,
		"en_d": "NPCs give you quests. Open the Quests menu (pause) to see objectives, hints and rewards. Main quests gate the climb.",
		"id_d": "NPC memberimu misi. Buka menu Misi (jeda) untuk tujuan, petunjuk, dan hadiah. Misi utama membuka jalan."},
	"g_markers": {"en": "NPC Markers", "id": "Tanda NPC", "default": true,
		"en_d": "The ! over an NPC: white = lore, green = quiz/reward, yellow = gimmick/enemy info, red = must talk to progress.",
		"id_d": "Tanda ! di atas NPC: putih = cerita, hijau = kuis/hadiah, kuning = info gimmick/musuh, merah = wajib bicara."},
	# ── Enemies (unlock on first sighting) ──
	"g_adbot": {"en": "Adbot", "id": "Adbot", "ev": "enemy_seen", "key": "type", "val": "adbot",
		"en_d": "A flashy gambling-ad drone. It flies straight at you when you're in range. Fragile — an arrow or two ends it.",
		"id_d": "Drone iklan judi yang mencolok. Terbang lurus ke arahmu saat dekat. Rapuh — satu-dua panah menamatkannya."},
	"g_bandit": {"en": "Bandit", "id": "Bandit", "ev": "enemy_seen", "key": "type", "val": "bandit",
		"en_d": "A grounded chaser that rushes in to hit you. Keep moving, punish it between lunges.",
		"id_d": "Pengejar darat yang menyerbu untuk memukulmu. Terus bergerak, serang di antara terjangannya."},
	"g_collector": {"en": "Collector", "id": "Penagih", "ev": "enemy_seen", "key": "type", "val": "collector",
		"en_d": "From afar she winds up a ranged shot and hurls a rigged fake coin. Get close and she drops it to rush you — control the distance.",
		"id_d": "Dari jauh ia menyiapkan tembakan dan melempar koin palsu curang. Dekati dan ia beralih menyerbu — atur jarak."},
	"g_dealer": {"en": "Dealer", "id": "Dealer", "ev": "enemy_seen", "key": "type", "val": "dealer",
		"en_d": "The House's tough salesman. Fires from range and throws fake coins. The Stage 5 gatekeeper before the House.",
		"id_d": "Penjual tangguh milik Bandar. Menembak dari jarak dan melempar koin palsu. Penjaga Stage 5 sebelum Bandar."},
	"g_house": {"en": "The House", "id": "Bandar", "ev": "boss_defeated",
		"en_d": "Shielded and firing. Destroy its Servers to break the shield, then strike while it's down — but it gets back up. Break the machine for good.",
		"id_d": "Berperisai dan menembak. Hancurkan Server-nya untuk memecah perisai, lalu serang saat tumbang — tapi ia bangkit lagi. Hancurkan mesinnya untuk selamanya."},
	# ── Gimmicks (unlock as you reach them) ──
	"g_fakecoin": {"en": "Fake Coin", "id": "Koin Palsu", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"en_d": "A shiny 'free jackpot' — bait. Touching it slows you, reverses your controls, or robs your coins. Nothing free is really free.",
		"id_d": "'Jackpot gratis' berkilau — umpan. Menyentuhnya memperlambatmu, membalik kontrol, atau mencuri koinmu. Tak ada yang benar-benar gratis."},
	"g_platforms": {"en": "Platforms", "id": "Platform", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"en_d": "Solid platforms hold. Moving ones carry you. Falling ones drop the moment you stand on them — don't linger.",
		"id_d": "Platform padat kokoh. Yang bergerak membawamu. Yang jatuh runtuh begitu kau injak — jangan berlama-lama."},
	"g_key": {"en": "Keys & Doors", "id": "Kunci & Pintu", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"en_d": "Locked doors block the exit. Find the matching key — a glowing guide-line points you to it while a quest needs it.",
		"id_d": "Pintu terkunci menghalangi jalan keluar. Temukan kuncinya — garis pemandu bercahaya menunjukkannya saat misi membutuhkannya."},
	"g_debt": {"en": "Rising Debt", "id": "Utang Menanjak", "ev": "stage_entered", "key": "stage_id", "val": "stage3",
		"en_d": "In Stage 3 a debt climbs the longer you linger — like real gambling interest, it grows whether you win or not. Keep moving.",
		"id_d": "Di Stage 3 utang naik makin lama kau berdiam — seperti bunga judi asli, ia tumbuh entah kau menang atau tidak. Terus bergerak."},
	"g_pullzone": {"en": "Pull Zones", "id": "Zona Tarik", "ev": "stage_entered", "key": "stage_id", "val": "stage4",
		"en_d": "Stage 4's currents drag you toward the machine — the tug back the instant you try to leave. Raise your Firewall and walk anyway.",
		"id_d": "Arus Stage 4 menyeretmu ke mesin — tarikan kembali begitu kau coba pergi. Naikkan Firewall dan tetap melangkah."},
}

const LORE := {
	"l_judol": {"en": "What Is Judol", "id": "Apa Itu Judol", "default": true,
		"en_d": "'Judi online' (judol) is betting real money on games of chance in apps and sites. It's dressed up like a game, but it's built to take your money.",
		"id_d": "'Judi online' (judol) adalah bertaruh uang sungguhan pada permainan untung-untungan di aplikasi dan situs. Dikemas seperti game, tapi dibuat untuk mengambil uangmu."},
	"l_house": {"en": "The House Always Wins", "id": "Bandar Selalu Menang", "ev": "stage_cleared", "key": "stage_id", "val": "stage1",
		"en_d": "The odds are set so the operator — the house — profits over time. It is not a way to make money. Any win is bait to keep you playing.",
		"id_d": "Peluangnya diatur agar operator — sang bandar — untung dalam jangka panjang. Ini bukan cara mencari uang. Kemenangan apa pun adalah umpan agar kau terus main."},
	"l_bait": {"en": "Free Credit Is Bait", "id": "Kredit Gratis Itu Umpan", "ev": "stage_cleared", "key": "stage_id", "val": "stage2",
		"en_d": "'Free credits' and 'guaranteed jackpots' cost the operator almost nothing. They get you playing — then take back far more.",
		"id_d": "'Kredit gratis' dan 'jackpot dijamin' hampir tanpa biaya bagi operator. Membuatmu bermain — lalu mengambil jauh lebih banyak."},
	"l_debt": {"en": "The Debt Trap", "id": "Jebakan Utang", "ev": "stage_cleared", "key": "stage_id", "val": "stage3",
		"en_d": "Losses pile up and the apps offer loans to 'win it back'. Borrowing to chase a rigged game only digs the hole deeper. The debt is the goal.",
		"id_d": "Kekalahan menumpuk dan aplikasi menawarkan pinjaman untuk 'menang kembali'. Berutang mengejar permainan curang hanya memperdalam lubang. Utang adalah tujuannya."},
	"l_nearmiss": {"en": "Engineered Near-Misses", "id": "Nyaris Menang yang Direkayasa", "ev": "stage_cleared", "key": "stage_id", "val": "stage4",
		"en_d": "'Almost won' isn't luck — it's designed. Your brain treats a near-miss like a real win, and a bonus appears the moment you try to quit.",
		"id_d": "'Nyaris menang' bukan keberuntungan — itu dirancang. Otakmu memperlakukan nyaris-menang seperti menang, dan bonus muncul begitu kau coba berhenti."},
	"l_signs": {"en": "Warning Signs", "id": "Tanda Bahaya", "ev": "quiz_passed", "key": "quiz_id", "val": "stage5_quiz",
		"en_d": "Chasing losses while insisting 'I can stop anytime' is a classic sign of harm. Recovery starts with honesty and asking for help.",
		"id_d": "Mengejar kekalahan sambil bersikeras 'aku bisa berhenti kapan saja' adalah tanda klasik kecanduan. Pemulihan dimulai dari kejujuran dan meminta bantuan."},
	"l_shard": {"en": "Voices of the Hurt", "id": "Suara yang Terluka", "ev": "collectible",
		"en_d": "Truth Shards are the words of people the machine hurt — savings gone, families strained, time lost. Collecting them carries their stories forward.",
		"id_d": "Pecahan Kebenaran adalah kata-kata orang yang dilukai mesin — tabungan lenyap, keluarga tegang, waktu hilang. Mengumpulkannya membawa kisah mereka."},
	"l_help": {"en": "Getting Help", "id": "Mencari Bantuan", "ev": "quiz_passed",
		"en_d": "If gambling has a grip on you or someone you know, help is real. In Indonesia call 119 ext 8 (mental-health line). Talking to someone is the first step out.",
		"id_d": "Jika judi mencengkerammu atau orang yang kau kenal, bantuan itu nyata. Di Indonesia hubungi 119 ext 8 (layanan kesehatan jiwa). Bicara pada seseorang adalah langkah pertama keluar."},
	"l_overdawn": {"en": "Overdawn", "id": "Fajar Menyingsing", "ev": "boss_defeated",
		"en_d": "No betting system beats a rigged game. The only real win is to walk away — and to help others see the trap too. You made it out. Now help others do the same.",
		"id_d": "Tak ada sistem taruhan yang mengalahkan permainan curang. Kemenangan sejati adalah pergi — dan membantu orang lain melihat jebakannya. Kau berhasil keluar. Kini bantu orang lain melakukannya."},
}

func _ready() -> void:
	ProgressionManager.game_event.connect(_on_event)

# ─── Queries (for the codex menu) ────────────────────────────────────────────────
# `default` entries are always unlocked (starter knowledge) — computed here rather than
# written into the save, so a New Game (ProgressionManager.reset) can never lose them.

func is_guide_unlocked(id: String) -> bool:
	return GUIDE.get(id, {}).get("default", false) or ProgressionManager.guides.has(id)

func is_lore_unlocked(id: String) -> bool:
	return LORE.get(id, {}).get("default", false) or ProgressionManager.lore.has(id)

func guide_count() -> int:
	return _count(ProgressionManager.guides, GUIDE)

func lore_count() -> int:
	return _count(ProgressionManager.lore, LORE)

func _count(store: Dictionary, table: Dictionary) -> int:
	var n := 0
	for id in table:
		if store.has(id) or table[id].get("default", false):
			n += 1
	return n

func name_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return e.get("id" if _is_id() else "en", id)

func desc_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return e.get("id_d" if _is_id() else "en_d", "")

# ─── Unlocking ────────────────────────────────────────────────────────────────────

func unlock_guide(id: String) -> void:
	if not GUIDE.has(id) or ProgressionManager.guides.has(id):
		return
	ProgressionManager.guides[id] = true
	codex_unlocked.emit("guide", id)
	_toast(tr("Guide Unlocked") + ": " + name_of("guide", id))
	if guide_count() >= GUIDE.size():
		ProgressionManager.notify("all_guides_unlocked", {})   # BadgeManager → "Well Read"

func unlock_lore(id: String) -> void:
	if not LORE.has(id) or ProgressionManager.lore.has(id):
		return
	ProgressionManager.lore[id] = true
	codex_unlocked.emit("lore", id)
	_toast(tr("Lore Unlocked") + ": " + name_of("lore", id))

func _on_event(event_name: String, data: Dictionary) -> void:
	for id in GUIDE:
		if _matches(GUIDE[id], event_name, data):
			unlock_guide(id)
	for id in LORE:
		if _matches(LORE[id], event_name, data):
			unlock_lore(id)

func _matches(entry: Dictionary, event_name: String, data: Dictionary) -> bool:
	if entry.get("ev", "") != event_name:
		return false
	var key: String = entry.get("key", "")
	if key == "":
		return true
	return str(data.get(key, "")) == str(entry.get("val", ""))

func _toast(msg: String) -> void:
	var p = Global.PlayerBody
	if is_instance_valid(p) and p.has_method("show_toast"):
		p.show_toast(msg)

func _is_id() -> bool:
	return TranslationServer.get_locale().begins_with("id")
