extends Node

# ─── Collectible Manager (Autoload) — "Truth Shards" (UC-004 + UC-006) ────────────
# Scattered glowing fragments the player gathers across the stages. Each Shard is a
# collectible reward (Deploy/Tools) AND carries a real anti-online-gambling truth it
# reveals on pickup (Educational Content, delivered through play — not a wall of text).
#
# Fully data-driven: every shard is one entry in SHARDS { id -> {stage, pos, en, id} }.
# Edit positions/lore here; stages call CollectibleManager.populate(self, "stageN")
# in _ready to spawn the ones not yet collected. Collected state lives in
# ProgressionManager (persisted), so a grabbed shard stays grabbed after reload.
# ──────────────────────────────────────────────────────────────────────────────────

const SHARD_SCENE := preload("res://scene/pickups/collectible/collectible.tscn")

# pos = world position to spawn at (tunable in-editor feel; collectibles are optional
# so a slightly-off spot is harmless). en/id = the truth revealed on pickup.
const SHARDS := {
	# Stage 1 — what online gambling (judol) is
	"shard_s1_1": {"stage": "stage1", "pos": Vector2(520, 632),
		"en": "Truth: 'Free credits' are bait. If the prize is free, YOU are the product.",
		"id": "Fakta: 'Kredit gratis' itu umpan. Kalau hadiahnya gratis, KAMU produknya."},
	"shard_s1_2": {"stage": "stage1", "pos": Vector2(1620, 600),
		"en": "Truth: The house edge means the machine is built to win. Always.",
		"id": "Fakta: 'House edge' berarti mesin dirancang untuk menang. Selalu."},
	"shard_s1_3": {"stage": "stage1", "pos": Vector2(2900, 590),
		"en": "Truth: Ads promise jackpots to everyone. Almost no one ever collects.",
		"id": "Fakta: Iklan menjanjikan jackpot ke semua orang. Nyaris tak ada yang dapat."},
	# Stage 2 — the bait / near-win
	"shard_s2_1": {"stage": "stage2", "pos": Vector2(500, 600),
		"en": "Truth: A 'near win' is engineered. It isn't luck — it's a hook.",
		"id": "Fakta: 'Nyaris menang' itu direkayasa. Bukan keberuntungan — itu kail."},
	"shard_s2_2": {"stage": "stage2", "pos": Vector2(1700, 560),
		"en": "Truth: The shiniest offer is the trap. Free money has a price.",
		"id": "Fakta: Tawaran paling berkilau itu jebakan. Uang gratis ada harganya."},
	# Stage 3 — debt
	"shard_s3_1": {"stage": "stage3", "pos": Vector2(400, 560),
		"en": "Truth: Chasing losses is the trap. Betting more to win back digs deeper.",
		"id": "Fakta: Mengejar kekalahan itu jebakan. Menambah taruhan menggali lebih dalam."},
	"shard_s3_2": {"stage": "stage3", "pos": Vector2(1500, 480),
		"en": "Truth: Debt from gambling compounds. It grows faster than any 'win'.",
		"id": "Fakta: Utang judi berbunga. Ia tumbuh lebih cepat dari 'kemenangan' apa pun."},
	# Stage 4 — inside the machine
	"shard_s4_1": {"stage": "stage4", "pos": Vector2(500, 600),
		"en": "Truth: Every 'bonus' that pulls you back is designed to keep you playing.",
		"id": "Fakta: Setiap 'bonus' yang menarikmu kembali dirancang agar kamu terus main."},
	"shard_s4_2": {"stage": "stage4", "pos": Vector2(2600, 560),
		"en": "Truth: Walking away IS winning. The only move that beats the machine.",
		"id": "Fakta: Pergi ADALAH menang. Satu-satunya langkah yang mengalahkan mesin."},
	# Stage 5 — the final test
	"shard_s5_1": {"stage": "stage5", "pos": Vector2(500, 560),
		"en": "Truth: If a 'game' asks for money to keep playing, it's not a game.",
		"id": "Fakta: Kalau 'permainan' minta uang agar terus main, itu bukan permainan."},
	"shard_s5_2": {"stage": "stage5", "pos": Vector2(2400, 520),
		"en": "Truth: Real skill can't beat a rigged system. The odds never move for you.",
		"id": "Fakta: Keahlian nyata tak bisa kalahkan sistem curang. Peluang tak berpihak padamu."},
	# Stage 6 — the House / boss
	"shard_s6_1": {"stage": "stage6", "pos": Vector2(500, 560),
		"en": "Truth: The House isn't a person — it's a machine that profits from your loss.",
		"id": "Fakta: Bandar bukan orang — ia mesin yang untung dari kekalahanmu."},
	"shard_s6_2": {"stage": "stage6", "pos": Vector2(2200, 520),
		"en": "Truth: You beat it not by winning, but by helping others walk away too.",
		"id": "Fakta: Kamu menang bukan dengan menang, tapi dengan membantu orang lain pergi juga."},
}

# Spawn every uncollected shard for a stage. Call from the stage's _ready.
func populate(stage_node: Node, stage_id: String) -> void:
	if stage_node == null:
		return
	for sid in SHARDS:
		if SHARDS[sid]["stage"] != stage_id:
			continue
		if ProgressionManager.has_collectible(sid):
			continue
		var shard := SHARD_SCENE.instantiate()
		shard.collectible_id = sid
		stage_node.add_child(shard)
		shard.global_position = SHARDS[sid]["pos"]

# The truth revealed by a shard, localized. Used by the pickup toast + the codex.
func lore_for(collectible_id: String) -> String:
	var e: Dictionary = SHARDS.get(collectible_id, {})
	if e.is_empty():
		return ""
	if TranslationServer.get_locale().begins_with("id"):
		return e.get("id", e.get("en", ""))
	return e.get("en", "")

func total() -> int:
	return SHARDS.size()

func total_for_stage(stage_id: String) -> int:
	var n := 0
	for sid in SHARDS:
		if SHARDS[sid]["stage"] == stage_id:
			n += 1
	return n

func collected_for_stage(stage_id: String) -> int:
	var n := 0
	for sid in SHARDS:
		if SHARDS[sid]["stage"] == stage_id and ProgressionManager.has_collectible(sid):
			n += 1
	return n
