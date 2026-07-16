extends CharacterBody2D

class_name Player

# ─── Node References ───────────────────────────────────────────────────────────

@onready var animated_sprite_2d   = $AnimatedSprite2D
@onready var deal_damage_zone     = $DealDamageZone
@onready var projectile_output    = $ProjectileOutput

@onready var audio_walk = $AudioStreamPlayer_walk
@onready var audio_dash = $AudioStreamPlayer_dash

@onready var score_label = $CanvasLayer/Control/ScoreLabel

@onready var health_bar   = $CanvasLayer/Control/HealthBar
@onready var health_label = $CanvasLayer/Control/HealthBar/HealthLabel

@onready var level_label = $CanvasLayer/Control/LevelLabel

@onready var dash_cd       = $CanvasLayer/Control/DashCD
@onready var dash_cd_label = $CanvasLayer/Control/DashCD/Label

@onready var arrow_cd           = $CanvasLayer/Control/ArrowCD
@onready var arrow_refill_label = $CanvasLayer/Control/ArrowCD/ArrowRefillCD
@onready var arrow_count_label  = $CanvasLayer/Control/ArrowCD/ArrowCount

@onready var exp_bar   = $CanvasLayer/Control/EXPBar
@onready var exp_label = $CanvasLayer/Control/EXPBar/EXPLabel

@onready var pause_menu  = $CanvasLayer/PauseMenu
@onready var stats_menu  = $CanvasLayer/stats_menu
@onready var skip_button:   Button  = $CanvasLayer/SkipButton
@onready var death_screen          = $CanvasLayer/DeathScreen
@onready var dbjump_cd   = $CanvasLayer/Control/DBJumpCD
@onready var firewall_cd       = $CanvasLayer/Control/FirewallCD
@onready var firewall_cd_label = $CanvasLayer/Control/FirewallCD/Label
@onready var status_container  = $CanvasLayer/Control/StatusEffects

# Active timed status effects shown under the HP/Level HUD. id -> {name, remaining,
# color, label, on_expire}. Driven by push_status()/_tick_statuses().
var _statuses: Dictionary = {}

var _dialogue_skipping := false
var _toast_label: Label
var _float_tween: Tween

# ─── Stats ─────────────────────────────────────────────────────────────────────

# Health
var health: int     = 100
var health_max: int = 100
var health_min: int = 0
var dead: bool

# Movement
var SPEED: int
const NORMAL_SPEED: int = 100
const DASH_SPEED:   int = int(NORMAL_SPEED * 3.2)

# Effective walking speed = NORMAL_SPEED × speed_multiplier (boosts) × slow_factor
# (enemy slows). Both default to 1.0 and are combined by _recompute_speed().
var speed_multiplier: float    = 1.0
var slow_factor: float         = 1.0

# Left/right input flip (fake-coin "rigged controls" debuff). While true, horizontal
# input is negated. Toggled by reverse_controls() and its status expiry.
var _controls_reversed: bool = false

# Hit feedback: a brief knockback impulse (input is suppressed while it decays) plus
# a red flash/blink, so taking damage reads as a real hit.
const KNOCKBACK_SPEED: float = 170.0
const KNOCKBACK_LIFT: float  = 140.0
const KNOCKBACK_TIME: float  = 0.18
var _knockback_time: float = 0.0
var _hit_tween: Tween

# Constant external velocity applied by pull zones (Stage 4 gimmick). Set/cleared
# by the zone on enter/exit; added to horizontal movement each frame.
var external_push: Vector2 = Vector2.ZERO

# Gravity & Jump
const GRAVITY: float       = 900.0   # Downward acceleration in pixels/s²
const FALL_GRAVITY_MULT: float = 1.1 # Falling accelerates 10% faster than rising (snappier fall)
const JUMP_FORCE: float    = -342.0  # Initial upward velocity on jump (negative = up). ~10% lower peak than before.
const MAX_FALL_SPEED: float = 800.0  # Terminal velocity cap

# Combat
var strength: int = 11

# ─── Levelling ─────────────────────────────────────────────────────────────────

var level: int             = 1
var exp: int               = 0
var exp_to_next_level: int = 10

# ─── Attack State ──────────────────────────────────────────────────────────────

var attack_type: String
var current_attack: bool  # True while an attack animation is playing
var weapon_equip: bool

# ─── Dash ──────────────────────────────────────────────────────────────────────

var DASH: bool          = false  # True during the active dash window
var dash_cooldown: bool = false  # True while the dash cooldown is ticking
const DASH_COOLDOWN: float = 1.0 # Seconds before dash can be used again
var _dash_cd_remaining: float = 0.0
var _dash_cd_total: float = DASH_COOLDOWN

# ─── Double Jump ───────────────────────────────────────────────────────────────

var _dbjump_cd_remaining: float = 0.0
var can_double_jump: bool    = true   # Resets on landing
var double_jump_cooldown: bool = false # True while the cooldown is ticking
const DOUBLE_JUMP_FORCE: float = -288.0  # Slightly weaker than the first jump (~10% lower)
const DOUBLE_JUMP_COOLDOWN: float = 1.0  # Seconds before the skill is available again
var _dbjump_cd_total: float = DOUBLE_JUMP_COOLDOWN

# ─── Firewall (defensive skill) ──────────────────────────────────────────────────
# A gambling-reference shield: raise a firewall to block all incoming damage for
# a short window. Unlocked by an NPC; upgrade level extends the shield duration.

const FIREWALL_COOLDOWN: float = 6.0
var firewall_active: bool     = false
var firewall_cooldown: bool   = false
var _firewall_active_remaining: float = 0.0
var _firewall_cd_remaining: float     = 0.0

# True while talking to an NPC / taking a quiz — the player can't be hurt so
# conversations always happen in a safe zone.
var conversation_safe: bool = false

# ─── Debug toggles (set from the Debug panel) ───────────────────────────────────
var god_mode: bool       = false   # ignore all incoming damage
var infinite_arrows: bool = false  # never run out of arrows
var noclip: bool         = false   # debug: pass through terrain
var fly_mode: bool       = false   # debug: free vertical flight (no gravity)
const FLY_SPEED: float   = 220.0

func _flying() -> bool:
	return fly_mode or noclip

# Coin counter shown on the HUD.
var _coin_label: Label

# ─── Arrows ────────────────────────────────────────────────────────────────────

var max_arrows: int              = 2
var arrows_held: int             = 2
var arrow_refill_time: float     = 1.0
var current_arrow_refill_time: float = 0.0

# ─── Misc ──────────────────────────────────────────────────────────────────────

var attack_radius: float  = 12
var can_take_damage: bool
var score: int            = 0
var is_game_paused: bool
var _last_safe_pos: Vector2   # last non-NaN position, for the moving-platform NaN guard

# Particle trails (added in _ready). Toggled on during a dash / speed boost.
const _TRAIL := preload("res://scene/system/vfx/particle_trail.tscn")
const _FIREWALL_FX := preload("res://scene/system/vfx/firewall_shield.tscn")
var _dash_fx: CPUParticles2D
var _speed_fx: CPUParticles2D
var _firewall_fx: Sprite2D   # looping shield shown while the firewall is up

# ───────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ───────────────────────────────────────────────────────────────────────────────

func _ready():
	Global.PlayerBody  = self
	current_attack     = false
	dead               = false
	can_take_damage    = true
	Global.playerAlive = true
	SPEED              = NORMAL_SPEED

	# Carry RPG progress (level/exp/health/strength/score) over from the previous
	# stage. On the first spawn this seeds the record from these defaults instead.
	ProgressionManager.restore_player(self)

	update_health_bar()
	update_dash_cd(0)
	update_dbjump_cd(0)
	update_firewall_cd(0)
	update_exp_lvl_label()
	update_score_label()

	pause_menu.hide()
	stats_menu.hide()
	skip_button.hide()
	is_game_paused = false
	add_to_group("player")

	$Camera2D.enabled = true
	skip_button.pressed.connect(_on_skip_pressed)
	Dialogic.timeline_ended.connect(func(): _dialogue_skipping = false)

	_setup_toast()
	_setup_coin_hud()
	_setup_fx()
	ProgressionManager.skill_unlocked.connect(_on_skill_unlocked)
	ProgressionManager.coins_changed.connect(_on_coins_changed)
	refresh_stats_from_skills()
	_refresh_skill_huds()
	_setup_skill_key_hints()

func _physics_process(delta):
	if is_game_paused:
		return

	weapon_equip            = Global.PlayerWeaponEquip
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox     = $PlayerHitbox

	if dead:
		move_and_slide()
		return

	# ── Debug noclip ─────────────────────────────────────────────────────────────
	# Disable the body's collision shape so the player passes through terrain.
	if $CollisionShape2D.disabled != noclip:
		$CollisionShape2D.set_deferred("disabled", noclip)

	# ── Gravity ────────────────────────────────────────────────────────────────
	# Gravity is suppressed during a dash so it doesn't drag the player down
	# mid-air and make the dash feel heavy. Resumes the moment the dash ends.
	# Also suppressed while flying (debug).
	if not DASH and not _flying():
		if not is_on_floor():
			# Falling accelerates faster than rising, so the arc feels less floaty.
			var g: float = GRAVITY * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0)
			velocity.y = min(velocity.y + g * delta, MAX_FALL_SPEED)
		elif _knockback_time > 0.0:
			# Let a hit's upward pop lift the player instead of snapping to the floor.
			velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		else:
			velocity.y = 0
			# Restore double jump when the player lands (only if not on cooldown)
			if not double_jump_cooldown:
				can_double_jump = true

	# ── Horizontal movement ────────────────────────────────────────────────────
	# Only apply normal input when not in a dash (dash sets its own velocity)
	if not DASH:
		if _knockback_time > 0.0:
			# Ride the knockback impulse and let it decay; input is suppressed briefly.
			_knockback_time -= delta
			velocity.x = move_toward(velocity.x, external_push.x, 500.0 * delta)
		else:
			var direction_x = Input.get_axis("left", "right")
			if _controls_reversed:
				direction_x = -direction_x
			velocity.x = direction_x * SPEED + external_push.x

	# ── Debug flight ────────────────────────────────────────────────────────────
	# Free vertical movement from up/down, no gravity.
	if _flying():
		velocity.y = Input.get_axis("up", "down") * FLY_SPEED

	# ── Jump & Double Jump ─────────────────────────────────────────────────────
	if not _flying() and Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_FORCE
		elif can_double_jump and not double_jump_cooldown and ProgressionManager.is_skill_unlocked("double_jump"):
			velocity.y      = DOUBLE_JUMP_FORCE
			can_double_jump = false
			# "Second chance" flourish — a puff of air kicked down beneath the feet.
			Global.spawn_fx("poof", global_position + Vector2(0, 8), 0.22, Color(0.85, 0.92, 1.0))
			start_double_jump_cooldown()

	# ── Melee attacks (unarmed, not mid-attack) ────────────────────────────────
	if not weapon_equip and not current_attack:
		if DASH:
			if Input.is_action_just_pressed("left_click") or Input.is_action_just_pressed("right_click"):
				current_attack = true
				attack_type    = "dash"
				set_damage(attack_type)
				handle_attack_animation(attack_type)
		else:
			if Input.is_action_just_pressed("left_click"):
				current_attack = true
				attack_type    = "normal"
				set_damage(attack_type)
				handle_attack_animation(attack_type)
			elif Input.is_action_just_pressed("right_click"):
				current_attack = true
				attack_type    = "special"
				set_damage(attack_type)
				handle_attack_animation(attack_type)

	handle_movement_animation(velocity)
	check_hitbox()

	if Input.is_action_just_pressed("dash") and not dash_cooldown and ProgressionManager.is_skill_unlocked("dash"):
		start_dash()

	if Input.is_action_just_pressed("firewall") and not firewall_active and not firewall_cooldown and ProgressionManager.is_skill_unlocked("firewall"):
		activate_firewall()

	if Input.is_action_just_pressed("shoot"):
		shoot_arrow()

	if Input.is_action_just_pressed("pause"):
		pause_menu_screen()

	if Input.is_action_just_pressed("stats"):
		stats_menu_screen()

	update_deal_damage_zone()
	update_player_sprite_orientation()

	move_and_slide()

	# NaN guard: standing on an AnimatableBody2D (moving platform) that resumes from a
	# time_scale=0 pause can hand the body a divide-by-zero platform velocity, poisoning
	# the player's position with NaN. That makes the camera + every parallax scroll NaN,
	# so the whole world stops rendering = grey screen. Catch it and snap back.
	if is_nan(global_position.x) or is_nan(global_position.y) \
			or is_nan(velocity.x) or is_nan(velocity.y):
		velocity = Vector2.ZERO
		external_push = Vector2.ZERO
		global_position = _last_safe_pos
	else:
		_last_safe_pos = global_position

func _process(delta):
	if not _dialogue_skipping:
		skip_button.visible = (
			not is_game_paused
			and Dialogic.Styles.has_active_layout_node()
			and Dialogic.Styles.get_layout_node().visible
		)

	if arrows_held < max_arrows:
		current_arrow_refill_time += delta
		if current_arrow_refill_time >= arrow_refill_time:
			arrows_held               += 1
			current_arrow_refill_time  = 0.0
	update_arrow_cd()

	# Count down every active status effect and refresh the HUD.
	_tick_statuses(delta)

	# Tick the ability cooldowns down smoothly so their HUD bars/labels animate
	if _dash_cd_remaining > 0.0:
		_dash_cd_remaining = max(0.0, _dash_cd_remaining - delta)
		if _dash_cd_remaining == 0.0:
			dash_cooldown = false
		update_dash_cd(_dash_cd_remaining)

	if _dbjump_cd_remaining > 0.0:
		_dbjump_cd_remaining = max(0.0, _dbjump_cd_remaining - delta)
		if _dbjump_cd_remaining == 0.0:
			double_jump_cooldown = false
		update_dbjump_cd(_dbjump_cd_remaining)

	# Firewall: active shield window, then cooldown
	if _firewall_active_remaining > 0.0:
		_firewall_active_remaining -= delta
		if _firewall_active_remaining <= 0.0:
			firewall_active = false
			modulate = Color.WHITE
			if _firewall_fx: _firewall_fx.visible = false   # shield down
			Global.spawn_fx("poof", global_position + Vector2(0, -8), 0.18, Color(0.6, 0.8, 1.0))  # shield-drop puff
			show_toast(tr("Firewall down."))
			firewall_cooldown = true
			_firewall_cd_remaining = FIREWALL_COOLDOWN
			update_firewall_cd(_firewall_cd_remaining)
	elif _firewall_cd_remaining > 0.0:
		_firewall_cd_remaining -= delta
		if _firewall_cd_remaining <= 0.0:
			_firewall_cd_remaining = 0.0
			firewall_cooldown = false
			show_toast(tr("Firewall ready"))
		update_firewall_cd(_firewall_cd_remaining)

# ───────────────────────────────────────────────────────────────────────────────
# Pause / Menu
# ───────────────────────────────────────────────────────────────────────────────

func _on_skip_pressed():
	_dialogue_skipping = true
	skip_button.hide()
	if Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.get_layout_node().hide()
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()

func pause_menu_screen():
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
		if Dialogic.Styles.has_active_layout_node():
			Dialogic.Styles.get_layout_node().hide()
	is_game_paused = true
	pause_menu.show()
	pause_game()

func stats_menu_screen():
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	is_game_paused = true
	stats_menu.show()
	pause_game()

func pause_game():
	Engine.time_scale = 0 if is_game_paused else 1

# ───────────────────────────────────────────────────────────────────────────────
# Ranged Attack – Arrows
# ───────────────────────────────────────────────────────────────────────────────

func shoot_arrow():
	if not ProgressionManager.is_skill_unlocked("arrows"):
		return
	if not infinite_arrows and arrows_held <= 0:
		return

	# Muzzle anchored to the player's OWN world position (+ a hand-height offset that
	# flips with facing). Using global_position directly means the arrow always spawns
	# on the player — the old code wrote a global value into the arrow's LOCAL position,
	# which placed it off in the world when the parent stage wasn't at the origin.
	var facing: float   = -1.0 if animated_sprite_2d.flip_h else 1.0
	var muzzle: Vector2 = global_position + Vector2(6.0 * facing, -16.0)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var aim: Vector2       = mouse_pos - muzzle
	aim = aim.normalized() if aim.length() > 0.01 else Vector2(facing, 0.0)

	var arrow_scene    = preload("res://scene/actors/player/arrow.tscn")
	var arrow_instance = arrow_scene.instantiate()
	get_parent().add_child(arrow_instance)
	arrow_instance.global_position = muzzle
	arrow_instance.direction       = aim
	arrow_instance.rotation        = aim.angle() + PI / 2.0

	if not infinite_arrows:
		arrows_held -= 1
	update_arrow_cd()

func update_arrow_cd():
	arrow_cd.value     = current_arrow_refill_time
	arrow_cd.max_value = arrow_refill_time
	arrow_count_label.text = str(arrows_held) + "/" + str(max_arrows)

	if arrows_held < max_arrows:
		arrow_refill_label.text    = str(round(arrow_refill_time - current_arrow_refill_time))
		arrow_refill_label.visible = true
	else:
		arrow_refill_label.visible = false

# ───────────────────────────────────────────────────────────────────────────────
# Hit Detection
# ───────────────────────────────────────────────────────────────────────────────

func check_hitbox():
	var hitbox_areas = $PlayerHitbox.get_overlapping_areas()
	if hitbox_areas.is_empty():
		return

	var damage: int = 0
	var hitbox = hitbox_areas.front()
	var parent = hitbox.get_parent()

	if   parent is AdbotEnemy:   damage = Global.adbotDamageAmount
	elif parent is BanditEnemy:  damage = Global.banditDamageAmount
	elif parent is CollectorEnemy: damage = Global.collectorDamageAmount
	elif parent is DealerEnemy: damage = Global.dealerDamageAmount

	if can_take_damage:
		take_damage(damage)

# ───────────────────────────────────────────────────────────────────────────────
# Levelling & Score
# ───────────────────────────────────────────────────────────────────────────────

func gain_exp(amount):
	exp += amount
	if exp >= exp_to_next_level:
		level_up()
	update_exp_lvl_label()
	ProgressionManager.capture_player(self)

func level_up():
	level             += 1
	exp               -= exp_to_next_level
	exp_to_next_level  = int(exp_to_next_level * 1.1)
	health_max        += 1
	health            += 1
	strength           = int(strength + 0.6)
	health             = min(health, health_max)
	update_health_bar()
	# RPG: each level grants a skill point to spend in the stat screen
	ProgressionManager.add_skill_points(1)
	ProgressionManager.notify("level_up", {"level": level})   # feeds level badges
	show_toast(tr("Level up! +1 Skill Point"))

func update_exp_lvl_label():
	if exp_label:
		exp_bar.value     = exp
		exp_bar.max_value = exp_to_next_level
		exp_label.text    = "EXP: " + str(round(exp)) + " / " + str(round(exp_to_next_level))
	level_label.text = "LVL: " + str(level)

func gain_score(amount):
	score += amount
	update_score_label()
	ProgressionManager.capture_player(self)

func update_score_label():
	score_label.text = "Score: " + str(score)

# ───────────────────────────────────────────────────────────────────────────────
# Health
# ───────────────────────────────────────────────────────────────────────────────

# `source_pos` (optional) is the hit's origin — the player is knocked away from it.
# When omitted, the knockback is simply opposite the player's facing.
func take_damage(damage: int, source_pos: Vector2 = Vector2.INF):
	if damage == 0 or health <= 0:
		return
	# Blocked by an active firewall, safe during a conversation/quiz, or god mode
	if firewall_active or conversation_safe or god_mode:
		return

	health -= damage
	update_health_bar()
	ProgressionManager.notify("player_damaged", {"amount": damage})   # feeds no-hit challenges
	Global.spawn_damage_number(global_position + Vector2(0, -24), damage, Color(1, 0.4, 0.4))

	if health <= 0:
		health             = 0
		dead               = true
		Global.playerAlive = false
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		animated_sprite_2d.modulate = Color.WHITE
		handle_death_animation()
	else:
		_apply_hit_feedback(source_pos)   # flash + knockback only while still alive

	take_damage_cooldown(1.0)
	health = min(health, health_max)
	ProgressionManager.capture_player(self)

# Red flash + blink and a short knockback so a hit genuinely reads as a hit.
func _apply_hit_feedback(source_pos: Vector2) -> void:
	Global.spawn_fx("splosion", global_position, 0.4, Color(1, 0.55, 0.55))   # red impact burst
	# Knockback direction: away from the source, else opposite the way we're facing.
	var kb_dir: float = 1.0 if animated_sprite_2d.flip_h else -1.0
	if source_pos != Vector2.INF:
		var d := signf(global_position.x - source_pos.x)
		if d != 0.0:
			kb_dir = d
	velocity.x = kb_dir * KNOCKBACK_SPEED
	velocity.y = -KNOCKBACK_LIFT
	_knockback_time = KNOCKBACK_TIME

	# Flash red, then blink in/out a few times, ending back to normal.
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	var spr: AnimatedSprite2D = animated_sprite_2d
	spr.modulate = Color(1.0, 0.25, 0.25, 1.0)
	_hit_tween = create_tween()
	for i in 3:
		_hit_tween.tween_property(spr, "modulate", Color(1.0, 1.0, 1.0, 0.2), 0.08)
		_hit_tween.tween_property(spr, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.08)
	_hit_tween.tween_property(spr, "modulate", Color.WHITE, 0.1)

func heal_player(amount: int):
	health = min(health + amount, health_max)
	update_health_bar()
	ProgressionManager.capture_player(self)

func update_health_bar():
	health_bar.value     = health
	health_bar.max_value = health_max
	health_label.text    = str(health) + "/" + str(health_max)

# Prevent damage for a short window after being hit (i-frames)
func take_damage_cooldown(_wait_time: float):
	can_take_damage = false
	await get_tree().create_timer(0.5).timeout
	can_take_damage = true

# ───────────────────────────────────────────────────────────────────────────────
# Death
# ───────────────────────────────────────────────────────────────────────────────

func die():
	if dead:
		return
	if god_mode or _flying():   # debug: don't die to death-zones while cheating
		return
	health             = 0
	dead               = true
	Global.playerAlive = false
	handle_death_animation()

func handle_death_animation():
	velocity = Vector2.ZERO
	$CollisionShape2D.disabled = true
	animated_sprite_2d.play("dead")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom = Vector2(4, 4)
	await get_tree().create_timer(1.5).timeout
	death_screen.show_screen()

# ───────────────────────────────────────────────────────────────────────────────
# Animation
# ───────────────────────────────────────────────────────────────────────────────

# Play the correct idle / run / jump / dash animation when not attacking
func handle_movement_animation(_vel: Vector2):
	if weapon_equip or current_attack:
		return

	if DASH:
		animated_sprite_2d.play("dash")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("fall")
	elif velocity.x == 0:
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("run")

# Flip sprite and reposition projectile origin based on mouse side
func update_player_sprite_orientation():
	var dir = (get_global_mouse_position() - global_position).normalized()
	animated_sprite_2d.flip_h    = dir.x < 0
	$ProjectileOutput.position.x = -5 if dir.x < 0 else 5

func handle_attack_animation(type: String):
	animated_sprite_2d.play(str(type, "_attack"))
	toggle_damage_collision(type)

func _on_animated_sprite_2d_animation_finished():
	current_attack = false

func toggle_damage_collision(type: String):
	var damage_col = deal_damage_zone.get_node("CollisionShape2D")
	var wait_time: float

	match type:
		"normal":  wait_time = 0.5
		"special": wait_time = 0.8
		"dash":    wait_time = 0.3
		_:         wait_time = 0.5

	damage_col.disabled = false
	await get_tree().create_timer(wait_time).timeout
	damage_col.disabled = true

# ───────────────────────────────────────────────────────────────────────────────
# Combat – Damage Output
# ───────────────────────────────────────────────────────────────────────────────

func set_damage(type: String):
	var multiplier: float

	match type:
		"normal":  multiplier = 1.0
		"special": multiplier = 1.5
		"dash":    multiplier = 2.5
		_:         multiplier = 1.0

	Global.playerDamageAmount = int(strength * multiplier)

func update_deal_damage_zone():
	var dir = (get_global_mouse_position() - global_position).normalized()
	deal_damage_zone.position = dir * attack_radius

# ───────────────────────────────────────────────────────────────────────────────
# Dash
# ───────────────────────────────────────────────────────────────────────────────

func _setup_fx() -> void:
	_dash_fx = _TRAIL.instantiate()
	_dash_fx.color = Color(0.85, 0.85, 0.95, 0.7)   # dust kicked up on dash
	_dash_fx.position = Vector2(0, -4)
	add_child(_dash_fx)
	_speed_fx = _TRAIL.instantiate()
	_speed_fx.color = Color(0.4, 0.85, 1.0, 0.85)   # cyan speed streaks
	_speed_fx.position = Vector2(0, -8)
	add_child(_speed_fx)
	_firewall_fx = _FIREWALL_FX.instantiate()
	_firewall_fx.position = Vector2(0, -10)
	_firewall_fx.visible = false
	add_child(_firewall_fx)

func start_dash():
	DASH = true
	if _dash_fx: _dash_fx.emitting = true
	audio_dash.play()
	$PlayerHitbox/CollisionShape2D.disabled = true
	can_take_damage = false

	# Dash in the direction of keyboard input; fall back to sprite facing if no input
	var input_x  = Input.get_axis("left", "right")
	var dash_dir = sign(input_x) if input_x != 0 else (-1.0 if animated_sprite_2d.flip_h else 1.0)
	velocity.x   = dash_dir * DASH_SPEED
	velocity.y   = 0.0

	animated_sprite_2d.play("dash")
	await get_tree().create_timer(0.25).timeout  # Dash active window

	DASH          = false
	if _dash_fx: _dash_fx.emitting = false
	dash_cooldown = true
	# Higher dash level shortens the cooldown
	_dash_cd_total     = max(0.4, DASH_COOLDOWN - 0.25 * (_skill_level("dash") - 1))
	_dash_cd_remaining = _dash_cd_total
	$PlayerHitbox/CollisionShape2D.disabled = false
	can_take_damage = true
	update_dash_cd(_dash_cd_remaining)

# Bar fills up as the cooldown recovers (full = ready); the label counts the
# remaining seconds down and hides once the dash is available again.
func update_dash_cd(remaining: float):
	dash_cd.max_value = _dash_cd_total
	dash_cd.value     = _dash_cd_total - remaining
	if remaining > 0.0:
		dash_cd_label.text    = "%.1f" % remaining
		dash_cd_label.visible = true
	else:
		dash_cd_label.text    = ""
		dash_cd_label.visible = false

# ───────────────────────────────────────────────────────────────────────────────
# Double Jump
# ───────────────────────────────────────────────────────────────────────────────

# Trigger the cooldown after a double jump is consumed; _process ticks it down.
func start_double_jump_cooldown():
	double_jump_cooldown = true
	can_double_jump      = false
	# Higher double-jump level shortens the cooldown
	_dbjump_cd_total     = max(0.3, DOUBLE_JUMP_COOLDOWN - 0.25 * (_skill_level("double_jump") - 1))
	_dbjump_cd_remaining = _dbjump_cd_total
	update_dbjump_cd(_dbjump_cd_remaining)

# Bar fills up as the cooldown recovers (full = ready again).
func update_dbjump_cd(remaining: float):
	dbjump_cd.max_value = _dbjump_cd_total
	dbjump_cd.value     = _dbjump_cd_total - remaining

# ───────────────────────────────────────────────────────────────────────────────
# Firewall (defensive skill)
# ───────────────────────────────────────────────────────────────────────────────

func activate_firewall():
	var lvl := _skill_level("firewall")
	var duration := 1.5 + 0.5 * (lvl - 1)   # upgrades extend the shield window
	firewall_active            = true
	_firewall_active_remaining = duration
	modulate = Color(0.45, 0.75, 1.0)        # blue shielded tint
	var _pillar := Global.spawn_fx("pillar", global_position + Vector2(0, 10), 0.4, Color(0.6, 0.85, 1.0)) as Sprite2D
	if _pillar:
		# Rotated 180° but still growing up from the feet (offset flips it back above origin).
		_pillar.offset = Vector2(0, _pillar.texture.get_height() / 2.0)
		_pillar.rotation_degrees = 180
	if _firewall_fx: _firewall_fx.visible = true   # persistent shield while active
	show_toast(tr("Firewall up!"))
	push_status("firewall", "Firewall", duration, Color(0.45, 0.75, 1.0))

# Bar fills up as the cooldown recovers (full = ready); label counts down.
func update_firewall_cd(remaining: float):
	firewall_cd.max_value = FIREWALL_COOLDOWN
	firewall_cd.value     = FIREWALL_COOLDOWN - remaining
	if remaining > 0.0:
		firewall_cd_label.text    = "%.1f" % remaining
		firewall_cd_label.visible = true
	else:
		firewall_cd_label.text    = ""
		firewall_cd_label.visible = false

# ───────────────────────────────────────────────────────────────────────────────
# RPG stats derived from skill levels
# ───────────────────────────────────────────────────────────────────────────────

func _skill_level(skill_name: String) -> int:
	return max(1, ProgressionManager.get_skill_level(skill_name))

# Recompute stats that depend on skill upgrade levels. Called on spawn and
# whenever a skill is upgraded in the stat screen.
func refresh_stats_from_skills():
	max_arrows  = 1 + _skill_level("arrows")   # lvl1→2, lvl2→3, lvl3→4 arrows
	arrows_held = min(arrows_held, max_arrows)
	update_arrow_cd()

# ───────────────────────────────────────────────────────────────────────────────
# Speed Modifiers (used by enemy effects)
# ───────────────────────────────────────────────────────────────────────────────

# Recalculate SPEED from the base speed and every active modifier.
func _recompute_speed():
	SPEED = int(NORMAL_SPEED * speed_multiplier * slow_factor)

# Temporarily reduce movement speed by a fractional factor (e.g. 0.6 = 40% slow)
func slow_down(factor: float):
	slow_factor = factor
	_recompute_speed()

func restore_speed():
	slow_factor = 1.0
	_recompute_speed()

# Timed slow (fake-coin "rigged" outcome). Unlike slow_down (enemy slows, no timer),
# this shows a HUD status and auto-restores when it expires.
func apply_slow(factor: float, duration: float):
	slow_factor = factor
	_recompute_speed()
	push_status("slow", "Slowed", duration, Color(1, 0.55, 0.2),
		func(): restore_speed())

# Flip left/right input for a while (fake-coin "rigged controls" debuff).
func reverse_controls(duration: float):
	_controls_reversed = true
	push_status("reverse", "Reversed", duration, Color(1, 0.35, 0.5),
		func():
			_controls_reversed = false
			show_toast(tr("Controls back to normal.")))

# Grant a timed movement-speed boost (used by speed pickups).
func apply_speed_boost(multiplier: float, duration: float):
	speed_multiplier = multiplier
	_recompute_speed()
	if _speed_fx: _speed_fx.emitting = true
	push_status("speed_boost", "Speed Boost", duration, Color(0.4, 1, 0.5),
		func():
			speed_multiplier = 1.0
			_recompute_speed()
			if _speed_fx: _speed_fx.emitting = false
			show_toast(tr("The rush fades.")))

# ───────────────────────────────────────────────────────────────────────────────
# Status Effect HUD (timed buffs/debuffs listed under the HP/Level HUD)
# ───────────────────────────────────────────────────────────────────────────────

# Add (or refresh) a timed status shown below the HP/Level HUD. Re-adding an id
# that's already active keeps the longer remaining time. on_expire runs once when
# the timer reaches zero (used to undo the effect).
func push_status(id: String, display_name: String, duration: float,
		color: Color = Color.WHITE, on_expire: Callable = Callable()) -> void:
	if _statuses.has(id):
		var e: Dictionary = _statuses[id]
		e["remaining"] = max(e["remaining"], duration)
		e["name"]      = display_name
		if on_expire.is_valid():
			e["on_expire"] = on_expire
	else:
		var lbl := Label.new()
		var f: Font = level_label.get_theme_font("font")
		if f:
			lbl.add_theme_font_override("font", f)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate = color
		status_container.add_child(lbl)
		_statuses[id] = {
			"name": display_name, "remaining": duration,
			"label": lbl, "on_expire": on_expire,
		}
	_refresh_status_label(id)

func _refresh_status_label(id: String) -> void:
	var e: Dictionary = _statuses[id]
	e["label"].text = "%s  %.1fs" % [e["name"], max(e["remaining"], 0.0)]

# Count down every status each frame; drop and undo any that expire.
func _tick_statuses(delta: float) -> void:
	for id in _statuses.keys():
		var e: Dictionary = _statuses[id]
		e["remaining"] -= delta
		if e["remaining"] <= 0.0:
			var cb: Callable = e["on_expire"]
			e["label"].queue_free()
			_statuses.erase(id)
			if cb.is_valid():
				cb.call()
		else:
			_refresh_status_label(id)

# ───────────────────────────────────────────────────────────────────────────────
# Skill HUD & Unlock Feedback
# ───────────────────────────────────────────────────────────────────────────────

# Show/hide ability cooldown indicators based on what's currently unlocked.
func _refresh_skill_huds():
	dash_cd.visible     = ProgressionManager.is_skill_unlocked("dash")
	arrow_cd.visible    = ProgressionManager.is_skill_unlocked("arrows")
	dbjump_cd.visible   = ProgressionManager.is_skill_unlocked("double_jump")
	firewall_cd.visible = ProgressionManager.is_skill_unlocked("firewall")

# Stamp the activation key onto each skill's HUD bar (read from the input map so
# it follows any rebinds). The label is a child of the bar, so it hides/shows
# with the bar automatically.
func _setup_skill_key_hints():
	_add_key_hint(dash_cd,     "dash")     # dash
	_add_key_hint(dbjump_cd,   "jump")     # double jump = jump again in mid-air
	_add_key_hint(arrow_cd,    "shoot")    # fire arrow
	_add_key_hint(firewall_cd, "firewall") # raise shield

func _add_key_hint(bar: Control, action: String):
	if bar == null or bar.has_node("KeyHint"):
		return
	var l := Label.new()
	l.name = "KeyHint"
	l.text = _key_hint(action)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"))
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 1, 0.7))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top    = 0.0
	l.offset_bottom = 15.0
	bar.add_child(l)

# Readable name of the first keyboard key bound to an action (e.g. "Shift", "E").
func _key_hint(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var t: String = ev.as_text_physical_keycode()
			if t.is_empty():
				t = ev.as_text_keycode()
			return t
	return ""

func _on_skill_unlocked(skill_name: String):
	_refresh_skill_huds()
	show_toast(_skill_display_name(skill_name) + " " + tr("Unlocked!"))

func _skill_display_name(skill_name: String) -> String:
	match skill_name:
		"double_jump": return tr("Double Jump")
		"dash":        return tr("Dash")
		"arrows":      return tr("Arrows")
		"firewall":    return tr("Firewall")
		_:             return skill_name

# ───────────────────────────────────────────────────────────────────────────────
# Coin HUD
# ───────────────────────────────────────────────────────────────────────────────

func _setup_coin_hud():
	_coin_label = Label.new()
	_coin_label.anchor_left  = 0.0
	_coin_label.anchor_right = 0.0
	_coin_label.offset_left  = 16.0
	_coin_label.offset_top   = 52.0
	_coin_label.add_theme_font_override("font", load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"))
	_coin_label.add_theme_font_size_override("font_size", 16)
	_coin_label.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	_coin_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_coin_label.add_theme_constant_override("outline_size", 4)
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer/Control.add_child(_coin_label)
	_on_coins_changed(ProgressionManager.coins)

func _on_coins_changed(total: int):
	if _coin_label:
		_coin_label.text = tr("Coins") + ": " + str(total)

# ───────────────────────────────────────────────────────────────────────────────
# Toast (transient on-screen notification)
# ───────────────────────────────────────────────────────────────────────────────

func _setup_toast():
	_toast_label = Label.new()
	# Span the FULL viewport width and sit in the upper-middle (above the player,
	# who's centred by the camera). Parenting to the CanvasLayer (not the offset HUD
	# Control) makes the anchors map to the whole screen so text never gets cut off.
	_toast_label.anchor_left   = 0.0
	_toast_label.anchor_right  = 1.0
	_toast_label.anchor_top    = 0.32
	_toast_label.anchor_bottom = 0.32
	_toast_label.offset_left   = 0.0
	_toast_label.offset_right  = 0.0
	_toast_label.offset_top    = 0.0
	_toast_label.offset_bottom = 48.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_override("font", load("res://art/Fonts/DepartureMono-1.500/DepartureMono-Regular.otf"))
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(_toast_label)

func show_toast(text: String):
	# Route to the stacked NotificationList HUD if present; else the fallback float label.
	var hud := get_node_or_null("CanvasLayer/Control")
	if hud and hud.has_method("push_notification"):
		hud.push_notification(text)
		return
	if _toast_label == null:
		return
	_toast_label.text       = text
	_toast_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(_toast_label, "modulate:a", 0.0, 0.8)
