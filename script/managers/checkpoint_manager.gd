extends Node

# ─── Checkpoint Manager (Autoload) ────────────────────────────────────────────────
# Mid-stage respawn points. When the player first walks through a Checkpoint area it
# becomes the active respawn point: we snapshot the FULL progression state and auto-save.
# If the player then dies (with checkpoints enabled), we roll progression back to that
# snapshot and reload the stage, dropping them at the checkpoint — so anything gained
# AFTER the checkpoint (score, XP, levels, skill points, skill unlocks) is not kept.
#
# The snapshot is an in-session rollback point (not itself saved); the auto-save fired at
# the checkpoint is what persists across quits. Checkpoints are per-stage: a checkpoint
# only applies while you're still in the scene that set it.
# ──────────────────────────────────────────────────────────────────────────────────────

signal checkpoint_set(position: Vector2)

var active: bool = false
var position: Vector2 = Vector2.ZERO
var scene_path: String = ""
var _snapshot: Dictionary = {}
var _pending_respawn: bool = false

# Record a new active checkpoint at `pos` in scene `scene`. Snapshots progression as the
# roll-back point (capturing the player's live stats first so it's accurate).
func set_checkpoint(pos: Vector2, scene: String) -> void:
	if is_instance_valid(Global.PlayerBody):
		ProgressionManager.capture_player(Global.PlayerBody)
	active = true
	position = pos
	scene_path = scene
	_snapshot = ProgressionManager.to_dict()
	checkpoint_set.emit(pos)

# A checkpoint at (about) this position is already the active one — used so a checkpoint
# doesn't re-fire when the player respawns standing inside it.
func is_active_at(pos: Vector2) -> bool:
	return active and position.distance_to(pos) < 2.0

# Can we respawn at a checkpoint right now? Needs the setting on, an active checkpoint,
# and the player still in the scene that set it.
func can_respawn() -> bool:
	if not Global.checkpoints_enabled or not active:
		return false
	var cs := get_tree().current_scene
	return cs != null and cs.scene_file_path == scene_path

# Roll progression back to the snapshot and reload the stage at the checkpoint.
func respawn() -> void:
	if not can_respawn():
		return
	ProgressionManager.from_dict(_snapshot)               # drop everything gained since
	ProgressionManager.player_health = ProgressionManager.player_health_max   # revive at full
	_pending_respawn = true
	Global.playerAlive = true
	Engine.time_scale = 1.0
	get_tree().call_deferred("reload_current_scene")

# Called from the player's _ready (after restore) — drop it at the checkpoint if a
# respawn is pending. One-shot.
func apply_respawn(player: Node) -> void:
	if _pending_respawn and is_instance_valid(player):
		player.global_position = position
		_pending_respawn = false

# Wipe checkpoint state (e.g. a fresh new game). Called from ProgressionManager.reset
# is overkill; callers can use this if they ever need a hard clear.
func clear() -> void:
	active = false
	scene_path = ""
	position = Vector2.ZERO
	_snapshot = {}
	_pending_respawn = false
