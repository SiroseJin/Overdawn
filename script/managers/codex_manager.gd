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
		"img": "res://art/v1.1 dungeon crawler 16X16 pixel pack/props_itens/bag_coins.png",
		"en_d": "TAB opens the Upgrades screen. Spend Skill Points (earned each level) on skills, stats and attacks.",
		"id_d": "TAB membuka layar Peningkatan. Pakai Skill Point (didapat tiap level) untuk skill, stat, dan serangan."},
	"g_quests": {"en": "Quests", "id": "Misi", "default": true,
		"en_d": "NPCs give you quests. Open the Quests menu (pause) to see objectives, hints and rewards. Main quests gate the climb.",
		"id_d": "NPC memberimu misi. Buka menu Misi (jeda) untuk tujuan, petunjuk, dan hadiah. Misi utama membuka jalan."},
	"g_markers": {"en": "NPC Markers", "id": "Tanda NPC", "default": true,
		"en_d": "The ! over an NPC: white = lore, green = quiz/reward, yellow = gimmick/enemy info, red = must talk to progress.",
		"id_d": "Tanda ! di atas NPC: putih = cerita, hijau = kuis/hadiah, kuning = info gimmick/musuh, merah = wajib bicara."},
	# ── Enemies (unlock on first sighting). `img`/`img_frames` = a sheet + how many
	#    horizontal frames it has; the Codex shows the first frame as the portrait. ──
	"g_adbot": {"en": "Adbot", "id": "Adbot", "ev": "enemy_seen", "key": "type", "val": "adbot",
		"img": "res://art/free-drones-pack-pixel-art/1 Drones/1/Idle.png", "img_frames": 4,
		"en_d": "A flashy gambling-ad drone. It flies straight at you when you're in range. Fragile — an arrow or two ends it.",
		"id_d": "Drone iklan judi yang mencolok. Terbang lurus ke arahmu saat dekat. Rapuh — satu-dua panah menamatkannya.",
		"en_dd": "Behaviour: hovers until you enter its range, then charges in a straight line and detonates on contact.\nCounter: it's fragile — shoot it with arrows before it reaches you, or side-step the charge and swing.\nMeaning: the gambling ad itself — loud, everywhere, promising the world. Harmless only if you never let it reach you.",
		"id_dd": "Perilaku: melayang sampai kau masuk jangkauan, lalu menerjang lurus dan meledak saat kena.\nLawan: ia rapuh — panah dari jauh, atau elak terjangannya lalu pukul.\nMakna: iklan judi itu sendiri — berisik, di mana-mana, menjanjikan segalanya. Tak berbahaya jika tak pernah kaubiarkan mendekat."},
	"g_bandit": {"en": "Bandit", "id": "Bandit", "ev": "enemy_seen", "key": "type", "val": "bandit",
		"img": "res://art/craftpix-net-913026-free-gangster-pixel-character-sprite-sheets-pack/Gangsters_2/Idle.png", "img_frames": 7,
		"en_d": "A grounded chaser that rushes in to hit you. Keep moving, punish it between lunges.",
		"id_d": "Pengejar darat yang menyerbu untuk memukulmu. Terus bergerak, serang di antara terjangannya.",
		"en_dd": "Behaviour: runs you down and swings, then waits out a short cooldown before it can hit again.\nCounter: keep moving and strike in the gap after a lunge; a dash attack cuts clean through.\nMeaning: the 'you almost won' rush made flesh — it only keeps coming while you stand and engage.",
		"id_dd": "Perilaku: mengejarmu dan memukul, lalu jeda sebentar sebelum bisa memukul lagi.\nLawan: terus bergerak dan serang di celah setelah terjangan; serangan dash menembusnya.\nMakna: sensasi 'nyaris menang' yang menjelma — ia hanya terus datang selama kau diam melayaninya."},
	"g_collector": {"en": "Collector", "id": "Penagih", "ev": "enemy_seen", "key": "type", "val": "collector",
		"img": "res://art/craftpix-net-516149-city-man-pixel-art-character-sprite-sheets/City_men_2/Idle.png", "img_frames": 6,
		"en_d": "From afar she winds up a ranged shot and hurls a rigged fake coin. Get close and she drops it to rush you — control the distance.",
		"id_d": "Dari jauh ia menyiapkan tembakan dan melempar koin palsu curang. Dekati dan ia beralih menyerbu — atur jarak.",
		"en_dd": "Behaviour: at range she charges a rigged fake coin and throws it; up close she stops throwing and rushes you.\nCounter: don't sit in mid-range — close in during her wind-up, or back off and punish the throw. Never grab the coin.\nMeaning: the debt enforcer. She profits whether you run or fight, so make her fight on your terms.",
		"id_dd": "Perilaku: dari jauh ia menyiapkan koin palsu curang dan melemparnya; dari dekat ia berhenti melempar dan menyerbu.\nLawan: jangan diam di jarak sedang — dekati saat ia bersiap, atau mundur lalu hukum lemparannya. Jangan ambil koinnya.\nMakna: penagih utang. Ia untung entah kau lari atau melawan, jadi paksa ia bertarung dengan caramu."},
	"g_dealer": {"en": "Dealer", "id": "Dealer", "ev": "enemy_seen", "key": "type", "val": "dealer",
		"img": "res://art/EVil Wizard 2/Sprites/Idle.png", "img_frames": 8,
		"en_d": "The House's tough salesman. Fires from range and throws fake coins. The Stage 5 gatekeeper before the House.",
		"id_d": "Penjual tangguh milik Bandar. Menembak dari jarak dan melempar koin palsu. Penjaga Stage 5 sebelum Bandar.",
		"en_dd": "Behaviour: tanky ranged attacker — fires and lobs fake coins from a distance, and slows you with a cursed orb. Guards Stage 5 before the House.\nCounter: use cover, dodge the orbs (never touch the coins), and whittle him down with arrows and dash attacks.\nMeaning: the smooth pitch that sells the whole rigged system — polished, patient, and always closing.",
		"id_dd": "Perilaku: penyerang jarak jauh yang tangguh — menembak dan melempar koin palsu, serta memperlambatmu dengan bola terkutuk. Menjaga Stage 5 sebelum Bandar.\nLawan: pakai perlindungan, elak bolanya (jangan sentuh koinnya), dan kikis dengan panah serta serangan dash.\nMakna: rayuan mulus yang menjual seluruh sistem curang — rapi, sabar, dan selalu menutup penjualan."},
	"g_house": {"en": "The House", "id": "Bandar", "ev": "boss_defeated",
		"en_d": "Shielded and firing. Destroy its Servers to break the shield, then strike while it's down — but it gets back up. Break the machine for good.",
		"id_d": "Berperisai dan menembak. Hancurkan Server-nya untuk memecah perisai, lalu serang saat tumbang — tapi ia bangkit lagi. Hancurkan mesinnya untuk selamanya.",
		"en_dd": "Behaviour: hovers behind a shield spraying bullet spirals. Servers power the shield — smash them to knock it down, then hit the core while it's exposed. It recovers and enters a harder phase each time.\nCounter: prioritise Servers, keep moving through the spirals, raise your Firewall to cross bad patches, and burst the core in every down window.\nMeaning: the operator behind it all. Any single win is bait; the only real victory is breaking the machine and walking away.",
		"id_dd": "Perilaku: melayang di balik perisai sambil menyemprot spiral peluru. Server menyalakan perisai — hancurkan untuk menjatuhkannya, lalu pukul inti saat terbuka. Ia pulih dan masuk fase lebih sulit tiap kali.\nLawan: utamakan Server, terus bergerak menembus spiral, naikkan Firewall untuk melewati bagian berbahaya, dan hantam inti di tiap jeda tumbang.\nMakna: operator di balik semuanya. Kemenangan tunggal apa pun adalah umpan; kemenangan sejati adalah menghancurkan mesin dan pergi."},
	# ── Gimmicks (unlock as you reach them) ──
	"g_fakecoin": {"en": "Fake Coin", "id": "Koin Palsu", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"en_d": "A shiny 'free jackpot' — bait. Touching it slows you, reverses your controls, or robs your coins. Nothing free is really free.",
		"id_d": "'Jackpot gratis' berkilau — umpan. Menyentuhnya memperlambatmu, membalik kontrol, atau mencuri koinmu. Tak ada yang benar-benar gratis."},
	"g_platforms": {"en": "Platforms", "id": "Platform", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"en_d": "Solid platforms hold. Moving ones carry you. Falling ones drop the moment you stand on them — don't linger.",
		"id_d": "Platform padat kokoh. Yang bergerak membawamu. Yang jatuh runtuh begitu kau injak — jangan berlama-lama."},
	"g_key": {"en": "Keys & Doors", "id": "Kunci & Pintu", "ev": "stage_entered", "key": "stage_id", "val": "stage2",
		"img": "res://art/v1.1 dungeon crawler 16X16 pixel pack/props_itens/key_silver.png",
		"en_d": "Locked doors block the exit. Find the matching key — a glowing guide-line points you to it while a quest needs it.",
		"id_d": "Pintu terkunci menghalangi jalan keluar. Temukan kuncinya — garis pemandu bercahaya menunjukkannya saat misi membutuhkannya."},
	"g_debt": {"en": "Rising Debt", "id": "Utang Menanjak", "ev": "stage_entered", "key": "stage_id", "val": "stage3",
		"en_d": "In Stage 3 a debt climbs the longer you linger — like real gambling interest, it grows whether you win or not. Keep moving.",
		"id_d": "Di Stage 3 utang naik makin lama kau berdiam — seperti bunga judi asli, ia tumbuh entah kau menang atau tidak. Terus bergerak."},
	"g_pullzone": {"en": "Pull Zones", "id": "Zona Tarik", "ev": "stage_entered", "key": "stage_id", "val": "stage4",
		"en_d": "Stage 4's currents drag you toward the machine — the tug back the instant you try to leave. Raise your Firewall and walk anyway.",
		"id_d": "Arus Stage 4 menyeretmu ke mesin — tarikan kembali begitu kau coba pergi. Naikkan Firewall dan tetap melangkah.",
		"en_dd": "The gust pulses on and off — the scrolling arrows telegraph the rhythm. Move or platform across during the lull, or punch straight through with a Dash (dashing ignores the pull entirely).\nMeaning: the machine's grip. Fighting it head-on is the slow, losing play; timing and a clean exit win.",
		"id_dd": "Embusan menyala-padam — panah bergerak menandai iramanya. Menyeberang saat reda, atau tembus lurus dengan Dash (dash mengabaikan tarikan sepenuhnya).\nMakna: cengkeraman mesin. Melawan langsung itu lambat dan kalah; ketepatan waktu dan jalan keluar yang bersih menang."},
	# ── More systems (known from the start) ──
	"g_arrows": {"en": "Arrows", "id": "Panah", "default": true,
		"en_d": "Press E to fire an arrow — your ranged option. Arrows auto-refill over time; the stack size and damage grow with upgrades.",
		"id_d": "Tekan E untuk menembak panah — opsi jarak jauhmu. Panah terisi ulang seiring waktu; jumlah dan kerusakannya naik lewat peningkatan.",
		"en_dd": "Ranged pressure lets you kill fragile foes (Adbots) before they reach you and chip tanky ones (Dealer, House) safely. Watch the ammo bar — you can run dry, so don't spam.",
		"id_dd": "Tekanan jarak jauh membunuh musuh rapuh (Adbot) sebelum mendekat dan mengikis yang tangguh (Dealer, Bandar) dengan aman. Perhatikan bilah amunisi — bisa habis, jadi jangan boros."},
	"g_coins": {"en": "Coins", "id": "Koin", "default": true,
		"img": "res://art/v1.1 dungeon crawler 16X16 pixel pack/props_itens/bag_coins.png",
		"en_d": "Real coins dropped by enemies and chests. They're your currency — but the shiny FAKE coins are traps. Learn the difference.",
		"id_d": "Koin asli dijatuhkan musuh dan peti. Itu mata uangmu — tapi koin PALSU yang berkilau adalah jebakan. Kenali bedanya.",
		"en_dd": "Genuine coins add to your total quietly. Fake coins scream 'free jackpot!' and then slow you, scramble your controls, or rob what you have.\nMeaning: the whole con in one object — if a reward is loud and free, ask who profits.",
		"id_dd": "Koin asli menambah totalmu diam-diam. Koin palsu berteriak 'jackpot gratis!' lalu memperlambatmu, mengacau kontrol, atau mencuri milikmu.\nMakna: seluruh tipuan dalam satu benda — jika hadiah berisik dan gratis, tanyakan siapa yang untung."},
	"g_shards": {"en": "Truth Shards", "id": "Pecahan Kebenaran", "default": true,
		"img": "res://art/pickups/shard.png",
		"en_d": "Teal crystals hidden across the stages. Each one you collect unlocks a piece of Lore — the real stories behind online gambling.",
		"id_d": "Kristal biru-hijau tersembunyi di seluruh stage. Tiap yang kaukumpulkan membuka satu Lore — kisah nyata di balik judi online.",
		"en_dd": "Collect them by exploring — off the main path, on hidden ledges. Every shard opens the next shard-gated Lore entry. Once all of those are open, extra shards pay out big EXP and a full heal instead.",
		"id_dd": "Kumpulkan dengan menjelajah — di luar jalur utama, di tepian tersembunyi. Tiap pecahan membuka Lore berikutnya. Setelah semuanya terbuka, pecahan tambahan memberi EXP besar dan penyembuhan penuh."},
	"g_pickups": {"en": "Pickups", "id": "Item", "default": true,
		"img": "res://art/pickups/health.png",
		"en_d": "Red flasks restore health. Blue flasks give a temporary speed boost. Walk into them to use them.",
		"id_d": "Botol merah memulihkan nyawa. Botol biru memberi dorongan kecepatan sementara. Jalan ke arahnya untuk memakainya.",
		"en_dd": "Grab a health flask before a tough fight, not after you're already low. A speed boost helps cross Pull Zones and outrun a Debt Wall. They don't respawn, so spend them wisely.",
		"id_dd": "Ambil botol nyawa sebelum pertarungan berat, bukan setelah sekarat. Dorongan kecepatan membantu melewati Zona Tarik dan mendahului Tembok Utang. Tak muncul lagi, jadi pakai dengan bijak."},
	"g_checkpoints": {"en": "Checkpoints", "id": "Titik Simpan", "default": true,
		"en_d": "A soft glowing beam with a little flag. Pass through it once to set your respawn point and auto-save. It fades after it's set.",
		"id_d": "Sinar lembut bercahaya dengan bendera kecil. Lewati sekali untuk menandai titik respawn dan menyimpan otomatis. Ia memudar setelah aktif.",
		"en_dd": "If you die, the death screen offers 'From Checkpoint' to return to the last one you touched. You can turn checkpoints off in Settings for a harder run.",
		"id_dd": "Jika mati, layar kematian menawarkan 'Dari Titik Simpan' untuk kembali ke yang terakhir kausentuh. Kau bisa mematikan titik simpan di Pengaturan untuk tantangan lebih berat."},
}

# Lore unlocks are MIXED. Each entry declares how it opens via `by`:
#   "default" → known from the start (l_judol).
#   "shard"   → opens by TOTAL Truth Shards collected, in listed order (1st shard-entry
#               at 1 shard, 2nd at 2, …). Its hint is the generic "collect shards" line.
#   "enemy"   → opens when you defeat an enemy of `etype` (adbot/bandit/collector/dealer).
#   "npc"     → opens when you finish talking to the NPC whose id is `npc`.
#   "boss"    → opens when the House is defeated.
# Non-shard entries carry a specific hint (en_h/id_h); shard entries share a generic one.
const SHARD_HINT_EN := "Unlock by collecting Truth Shards."
const SHARD_HINT_ID := "Buka dengan mengumpulkan Pecahan Kebenaran."

const LORE := {
	"l_judol": {"en": "What Is Judol", "id": "Apa Itu Judol", "by": "default",
		"en_d": "'Judi online' (judol) is betting real money on games of chance in apps and sites. It's dressed up like a game, but it's built to take your money.",
		"id_d": "'Judi online' (judol) adalah bertaruh uang sungguhan pada permainan untung-untungan di aplikasi dan situs. Dikemas seperti game, tapi dibuat untuk mengambil uangmu."},
	"l_house": {"en": "The House Always Wins", "id": "Bandar Selalu Menang", "by": "shard",
		"en_d": "The odds are set so the operator — the house — profits over time. It is not a way to make money. Any win is bait to keep you playing.",
		"id_d": "Peluangnya diatur agar operator — sang bandar — untung dalam jangka panjang. Ini bukan cara mencari uang. Kemenangan apa pun adalah umpan agar kau terus main."},
	"l_bait": {"en": "Free Credit Is Bait", "id": "Kredit Gratis Itu Umpan", "by": "shard",
		"en_d": "'Free credits' and 'guaranteed jackpots' cost the operator almost nothing. They get you playing — then take back far more.",
		"id_d": "'Kredit gratis' dan 'jackpot dijamin' hampir tanpa biaya bagi operator. Membuatmu bermain — lalu mengambil jauh lebih banyak."},
	"l_shard": {"en": "Voices of the Hurt", "id": "Suara yang Terluka", "by": "shard",
		"en_d": "Truth Shards are the words of people the machine hurt — savings gone, families strained, time lost. Collecting them carries their stories forward.",
		"id_d": "Pecahan Kebenaran adalah kata-kata orang yang dilukai mesin — tabungan lenyap, keluarga tegang, waktu hilang. Mengumpulkannya membawa kisah mereka."},
	"l_nearmiss": {"en": "Engineered Near-Misses", "id": "Nyaris Menang yang Direkayasa", "by": "enemy", "etype": "bandit",
		"en_d": "'Almost won' isn't luck — it's designed. Your brain treats a near-miss like a real win, and a bonus appears the moment you try to quit.",
		"id_d": "'Nyaris menang' bukan keberuntungan — itu dirancang. Otakmu memperlakukan nyaris-menang seperti menang, dan bonus muncul begitu kau coba berhenti.",
		"en_h": "Defeat a Bandit (the living slot machine) to reveal this.", "id_h": "Kalahkan seorang Bandit (mesin slot hidup) untuk membukanya."},
	"l_debt": {"en": "The Debt Trap", "id": "Jebakan Utang", "by": "enemy", "etype": "collector",
		"en_d": "Losses pile up and the apps offer loans to 'win it back'. Borrowing to chase a rigged game only digs the hole deeper. The debt is the goal.",
		"id_d": "Kekalahan menumpuk dan aplikasi menawarkan pinjaman untuk 'menang kembali'. Berutang mengejar permainan curang hanya memperdalam lubang. Utang adalah tujuannya.",
		"en_h": "Defeat the Collector (the debt enforcer, Stage 3) to reveal this.", "id_h": "Kalahkan Kolektor (penagih utang, Stage 3) untuk membukanya."},
	"l_signs": {"en": "Warning Signs", "id": "Tanda Bahaya", "by": "npc", "npc": "stage4_guntur",
		"en_d": "Chasing losses while insisting 'I can stop anytime' is a classic sign of harm. Recovery starts with honesty and asking for help.",
		"id_d": "Mengejar kekalahan sambil bersikeras 'aku bisa berhenti kapan saja' adalah tanda klasik kecanduan. Pemulihan dimulai dari kejujuran dan meminta bantuan.",
		"en_h": "Talk to Guntur in Stage 4 to reveal this.", "id_h": "Bicara dengan Guntur di Stage 4 untuk membukanya."},
	"l_help": {"en": "Getting Help", "id": "Mencari Bantuan", "by": "npc", "npc": "stage1_ana",
		"en_d": "If gambling has a grip on you or someone you know, help is real. In Indonesia call 119 ext 8 (mental-health line). Talking to someone is the first step out.",
		"id_d": "Jika judi mencengkerammu atau orang yang kau kenal, bantuan itu nyata. Di Indonesia hubungi 119 ext 8 (layanan kesehatan jiwa). Bicara pada seseorang adalah langkah pertama keluar.",
		"en_h": "Talk to Ana in Stage 1 to reveal this.", "id_h": "Bicara dengan Ana di Stage 1 untuk membukanya."},
	"l_odds": {"en": "The Odds Are Fixed", "id": "Peluang Sudah Dicurangi", "by": "shard",
		"en_d": "Every game publishes a 'return' below 100% — and the operator can tune it. Play long enough and the math guarantees you lose. There is no 'due for a win'.",
		"id_d": "Setiap permainan punya 'pengembalian' di bawah 100% — dan operator bisa mengaturnya. Main cukup lama dan matematika menjamin kau kalah. Tak ada istilah 'sudah waktunya menang'."},
	"l_time": {"en": "Time Is the Real Cost", "id": "Waktu Adalah Biaya Nyata", "by": "shard",
		"en_d": "Even 'free' play spends something: your hours and your attention. The app is engineered to keep you scrolling and coming back — that's the product being sold.",
		"id_d": "Bahkan main 'gratis' tetap menghabiskan sesuatu: jam-jammu dan perhatianmu. Aplikasi dirancang agar kau terus menggulir dan kembali — itulah produk yang dijual."},
	"l_family": {"en": "It Hits Families", "id": "Menghantam Keluarga", "by": "shard",
		"en_d": "The damage rarely stops at one person. Borrowed money, hidden losses, and broken trust spread to family and friends. The harm is shared even when the 'game' feels private.",
		"id_d": "Kerusakannya jarang berhenti pada satu orang. Uang pinjaman, kerugian tersembunyi, dan kepercayaan yang retak menyebar ke keluarga dan teman. Dampaknya dibagi walau 'permainan' terasa pribadi."},
	"l_ads": {"en": "Ads That Follow You", "id": "Iklan yang Menguntitmu", "by": "enemy", "etype": "adbot",
		"en_d": "Gambling ads chase you across apps, streams, influencers, and even games. Repetition makes a scam feel normal. Seeing it everywhere is the trick, not a sign it's safe.",
		"id_d": "Iklan judi mengejarmu lintas aplikasi, siaran, influencer, bahkan game. Pengulangan membuat penipuan terasa wajar. Terlihat di mana-mana itu triknya, bukan tanda ia aman.",
		"en_h": "Defeat an Adbot (the ad drone) to reveal this.", "id_h": "Kalahkan Adbot (drone iklan) untuk membukanya."},
	"l_salesman": {"en": "The Friendly Salesman", "id": "Penjual yang Ramah", "by": "enemy", "etype": "dealer",
		"en_d": "The pitch is warm on purpose: bonuses, 'VIP' treatment, a helpful voice. Friendliness is the bait that lowers your guard. Trust is exactly what they're selling.",
		"id_d": "Rayuannya hangat dengan sengaja: bonus, perlakuan 'VIP', suara yang ramah. Keramahan adalah umpan yang melonggarkan kewaspadaanmu. Kepercayaan justru itulah yang mereka jual.",
		"en_h": "Defeat a Dealer (Stage 5 gatekeeper) to reveal this.", "id_h": "Kalahkan Dealer (penjaga Stage 5) untuk membukanya."},
	"l_overdawn": {"en": "Overdawn", "id": "Fajar Menyingsing", "by": "boss",
		"en_d": "No betting system beats a rigged game. The only real win is to walk away — and to help others see the trap too. You made it out. Now help others do the same.",
		"id_d": "Tak ada sistem taruhan yang mengalahkan permainan curang. Kemenangan sejati adalah pergi — dan membantu orang lain melihat jebakannya. Kau berhasil keluar. Kini bantu orang lain melakukannya.",
		"en_h": "Defeat the House (final boss) to reveal this.", "id_h": "Kalahkan Bandar (bos terakhir) untuk membukanya."},
}

# Extra Truth Shards, once every shard-gated lore is already open, pay out big instead.
const SHARD_OVERFLOW_EXP := 150

func _ready() -> void:
	ProgressionManager.game_event.connect(_on_event)

# ─── Queries (for the codex menu) ────────────────────────────────────────────────
# `default` entries are always unlocked (starter knowledge) — computed here rather than
# written into the save, so a New Game (ProgressionManager.reset) can never lose them.

func is_guide_unlocked(id: String) -> bool:
	return GUIDE.get(id, {}).get("default", false) or ProgressionManager.guides.has(id)

func is_lore_unlocked(id: String) -> bool:
	return _is_default(LORE.get(id, {})) or ProgressionManager.lore.has(id)

func guide_count() -> int:
	return _count(ProgressionManager.guides, GUIDE)

func lore_count() -> int:
	return _count(ProgressionManager.lore, LORE)

func _count(store: Dictionary, table: Dictionary) -> int:
	var n := 0
	for id in table:
		if store.has(id) or _is_default(table[id]):
			n += 1
	return n

# An entry is "starter knowledge" (always unlocked) if flagged default either way —
# GUIDE uses `default: true`, LORE uses `by: "default"`.
func _is_default(entry: Dictionary) -> bool:
	return entry.get("default", false) or entry.get("by", "") == "default"

func name_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return e.get("id" if _is_id() else "en", id)

func desc_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return e.get("id_d" if _is_id() else "en_d", "")

## Optional illustration for an entry (res:// path, "" if none). Editable per entry —
## drop an "img" field on any GUIDE/LORE entry and it shows on the card (#8).
func img_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return str(e.get("img", ""))

## How many horizontal frames the entry's `img` sheet has (1 = a plain image). The
## Codex shows the FIRST frame, so a whole spritesheet reads as a clean portrait.
func img_frames_of(kind: String, id: String) -> int:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return int(e.get("img_frames", 1))

## Extra "great detail" shown when a card is expanded (#6). "" if the entry has none.
func detail_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	return str(e.get("id_dd" if _is_id() else "en_dd", ""))

## Hint telling the player how to unlock a still-locked entry (#9). "" if none.
## Shard-gated lore shares one generic line; everything else uses its own en_h/id_h.
func hint_of(kind: String, id: String) -> String:
	var e: Dictionary = (GUIDE if kind == "guide" else LORE).get(id, {})
	if kind == "lore" and e.get("by", "") == "shard":
		return SHARD_HINT_ID if _is_id() else SHARD_HINT_EN
	return e.get("id_h" if _is_id() else "en_h", "")

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
	AudioManager.play_ui("lore_unlock")   # one canonical sound for every unlock path
	_toast(tr("Lore Unlocked") + ": " + name_of("lore", id))

func _on_event(event_name: String, data: Dictionary) -> void:
	for id in GUIDE:
		if _matches(GUIDE[id], event_name, data):
			unlock_guide(id)
	match event_name:
		"collectible":
			# Shard-gated lore opens by count. Once it's all open, extra shards pay out.
			if _all_shard_lore_unlocked():
				_shard_overflow_reward()
			else:
				unlock_shard_lore_by_count(ProgressionManager.collectible_count())
		"enemy_defeated":
			for id in LORE:
				if LORE[id].get("by", "") == "enemy" \
						and str(LORE[id].get("etype", "")) == str(data.get("type", "")):
					unlock_lore(id)
		"npc_talked":
			for id in LORE:
				if LORE[id].get("by", "") == "npc" \
						and str(LORE[id].get("npc", "")) == str(data.get("id", "")):
					unlock_lore(id)
		"boss_defeated":
			for id in LORE:
				if LORE[id].get("by", "") == "boss":
					unlock_lore(id)

# The shard-gated lore ids, in the order they unlock (1 shard → 1st, 2 shards → 2nd, …).
func _shard_lore_order() -> Array:
	var out: Array = []
	for id in LORE:
		if LORE[id].get("by", "") == "shard":
			out.append(id)
	return out

# Unlock the first `count` shard-gated lore entries (already-unlocked ones are skipped).
func unlock_shard_lore_by_count(count: int) -> void:
	var order := _shard_lore_order()
	for i in mini(count, order.size()):
		unlock_lore(order[i])

func _all_shard_lore_unlocked() -> bool:
	for id in _shard_lore_order():
		if not is_lore_unlocked(id):
			return false
	return true

# Once every shard-gated lore is already open, a further shard hands the player a big
# EXP boost and heals them to full instead of unlocking anything.
func _shard_overflow_reward() -> void:
	var p = Global.PlayerBody
	if not is_instance_valid(p):
		return
	AudioManager.play_sfx("shard_overflow")   # big, distinct jackpot — only ever plays here
	if p.has_method("gain_exp"):
		p.gain_exp(SHARD_OVERFLOW_EXP)
	if p.has_method("max_hp"):
		p.health = p.max_hp()
		if p.has_method("update_health_bar"):
			p.update_health_bar()
	elif "health_max" in p:
		p.health = p.health_max
	_toast(tr("All shard lore found! +%d EXP and full heal") % SHARD_OVERFLOW_EXP)

# How many shards the next still-locked SHARD lore entry needs (0 if all are unlocked).
func shards_needed_for_next_lore() -> int:
	var order := _shard_lore_order()
	for i in order.size():
		if not is_lore_unlocked(order[i]):
			return i + 1
	return 0

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
