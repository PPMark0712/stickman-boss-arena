class_name ArenaPlayer
extends CharacterBody2D

signal stats_changed
signal died

enum State { IDLE, RUN, AIR, ATTACK, CAST, HEAL, HURT, DEAD }

class Controls extends RefCounted:
	var axis := 0.0
	var jump := false
	var jump_release := false
	var attack := false
	var up := false
	var down := false
	var focus := false
	var focus_release := false

var arena: Node2D
var state := State.IDLE
var state_time := 0.0
var health := ArenaConfig.MAX_HEALTH
var energy := 0
var facing := 1.0
var clock := 0.0
var jumps_used := 0
var coyote := 0.0
var jump_buffer := 0.0
var invulnerable := 0.0
var flash := 0.0
var attack_direction := Vector2.RIGHT
var hit_targets: Array[int] = []
var attack_buffer := 0.0
var attack_queued := false
var combo_step := 0
var combo_grace := 0.0
var slash_emitted := false
var attack_is_air := false
var focus_time := 0.0
var focus_consumed := false
var focus_cancelled := false
var landing_squash := 0.0
var turn_dust_cooldown := 0.0
var was_grounded := false
var controlled := true
var visual: Node2D
var live_controls := Controls.new()
var neutral_controls := Controls.new()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 70)
	collider.shape = shape
	collider.position.y = -35
	add_child(collider)
	visual = Node2D.new()
	visual.draw.connect(_draw_fighter)
	add_child(visual)

func change_state(next: State, restart: bool = false) -> void:
	if state == next and not restart:
		return
	state = next
	state_time = 0.0

func _physics_process(delta: float) -> void:
	if not arena.combat_active:
		return
	step(delta, read_controls() if controlled else neutral_controls)

func read_controls() -> Controls:
	live_controls.axis = Input.get_axis("move_left", "move_right")
	live_controls.jump = Input.is_action_just_pressed("jump")
	live_controls.jump_release = Input.is_action_just_released("jump")
	live_controls.attack = Input.is_action_just_pressed("attack")
	live_controls.up = Input.is_action_pressed("look_up")
	live_controls.down = Input.is_action_pressed("look_down")
	live_controls.focus = Input.is_action_pressed("focus")
	live_controls.focus_release = Input.is_action_just_released("focus")
	return live_controls

func step(delta: float, controls: Controls) -> void:
	clock += delta
	state_time += delta
	invulnerable = maxf(0, invulnerable - delta)
	flash = maxf(0, flash - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	attack_buffer = maxf(0, attack_buffer - delta)
	combo_grace = maxf(0, combo_grace - delta)
	landing_squash = maxf(0, landing_squash - delta * 5.5)
	turn_dust_cooldown = maxf(0, turn_dust_cooldown - delta)
	if combo_grace <= 0 and state != State.ATTACK:
		combo_step = 0
	coyote = ArenaConfig.COYOTE_TIME if is_on_floor() else maxf(0, coyote - delta)
	if is_on_floor():
		jumps_used = 0
	if controls.jump:
		jump_buffer = ArenaConfig.JUMP_BUFFER
	if controls.attack:
		attack_buffer = ArenaConfig.ATTACK_BUFFER
		if state == State.ATTACK:
			attack_queued = true
	if not is_on_floor():
		var gravity := ArenaConfig.FALL_GRAVITY if velocity.y > 0 else ArenaConfig.GRAVITY
		velocity.y = minf(velocity.y + gravity * delta, ArenaConfig.MAX_FALL)
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		move_and_slide()
		visual.queue_redraw()
		return
	if state == State.HURT:
		if controls.focus_release:
			focus_cancelled = false
			focus_consumed = false
			focus_time = 0
		velocity.x = move_toward(velocity.x, 0, 1100 * delta)
		if state_time >= 0.24:
			change_state(State.IDLE if is_on_floor() else State.AIR)
	else:
		handle_focus(delta, controls)
		handle_movement(delta, controls)
		handle_attack(controls)
		if state == State.ATTACK:
			if not slash_emitted and state_time >= current_attack_start():
				slash_emitted = true
				arena.show_slash(position + Vector2(0, -43), attack_world_direction(), combo_step)
				arena.sound("swing%d" % mini(combo_step + 1, 3))
			if state_time >= current_attack_start() and state_time <= current_attack_end():
				arena.resolve_sword(self, sword_rect())
			if state_time >= current_attack_duration():
				finish_sword_attack(controls)
		elif state == State.CAST:
			if state_time >= 0.24:
				change_state(State.IDLE if is_on_floor() else State.AIR)
		elif state != State.HEAL:
			var next := State.AIR
			if is_on_floor():
				next = State.RUN if absf(velocity.x) > 15 else State.IDLE
			if state != next:
				change_state(next)
	var impact_speed := velocity.y
	move_and_slide()
	var grounded_now := is_on_floor()
	if grounded_now and not was_grounded and impact_speed > 250:
		landing_squash = clampf((impact_speed - 200) / 700.0, 0.35, 1.0)
		arena.burst(position + Vector2(0, -2), ArenaConfig.MUTED, 5 + int(landing_squash * 5))
		arena.sound("land")
	was_grounded = grounded_now
	position.x = clampf(position.x, ArenaConfig.LEFT_WALL + 14, ArenaConfig.RIGHT_WALL - 14)
	visual.scale.x = facing
	visual.queue_redraw()

func handle_movement(delta: float, controls: Controls) -> void:
	var axis := controls.axis
	if state == State.HEAL:
		velocity.x = move_toward(velocity.x, 0, ArenaConfig.FRICTION * delta)
		if absf(axis) > 0.1 or controls.jump or controls.attack:
			focus_cancelled = true
			change_state(State.IDLE)
		else:
			return
	if state == State.CAST:
		axis *= 0.35
	elif state == State.ATTACK:
		axis *= 0.38 if is_on_floor() else 0.62
	if axis != 0 and state != State.ATTACK:
		if (
			is_on_floor()
			and signf(axis) != facing
			and absf(velocity.x) > 120
			and turn_dust_cooldown <= 0
		):
			arena.burst(position + Vector2(-facing * 8, -2), ArenaConfig.MUTED, 5)
			turn_dust_cooldown = 0.18
			landing_squash = maxf(landing_squash, 0.22)
		facing = signf(axis)
	var acceleration := ArenaConfig.ACCELERATION if is_on_floor() else ArenaConfig.AIR_ACCELERATION
	if state == State.ATTACK:
		acceleration *= 0.58
	if axis == 0:
		acceleration = ArenaConfig.FRICTION * (0.22 if state == State.ATTACK else 1.0)
	velocity.x = move_toward(velocity.x, axis * ArenaConfig.RUN_SPEED, acceleration * delta)
	if jump_buffer > 0 and (is_on_floor() or coyote > 0 or jumps_used < 2):
		# Walking off an edge consumes the ground jump after the coyote window.
		if not is_on_floor() and coyote <= 0:
			jumps_used = maxi(jumps_used, 1)
		velocity.y = -ArenaConfig.JUMP_SPEED if jumps_used == 0 else -ArenaConfig.DOUBLE_JUMP_SPEED
		jumps_used += 1
		coyote = 0
		jump_buffer = 0
		if state != State.ATTACK:
			change_state(State.AIR)
		elif state_time >= current_attack_end():
			attack_queued = false
			combo_step = 0
			combo_grace = 0
			change_state(State.AIR)
		arena.burst(position, ArenaConfig.TEAL, 7)
		arena.sound("jump")
	if controls.jump_release and velocity.y < -250:
		velocity.y *= 0.48

func handle_attack(controls: Controls) -> void:
	if state == State.ATTACK or attack_buffer <= 0:
		return
	if (
		state == State.CAST
		or state == State.HEAL
		or state == State.HURT
		or state == State.DEAD
	):
		return
	begin_sword_attack(controls)

func begin_sword_attack(controls: Controls) -> void:
	var continuing_ground_combo := (
		state == State.ATTACK and not attack_is_air and attack_direction.y == 0
	)
	attack_is_air = not is_on_floor() and not continuing_ground_combo
	attack_direction = Vector2(facing, 0)
	if attack_is_air:
		combo_step = 0
		if controls.down:
			attack_direction = Vector2.DOWN
		elif controls.up:
			attack_direction = Vector2.UP
		if attack_direction.y != 0:
			velocity.y *= 0.62
		else:
			velocity.x += facing * 45
	else:
		velocity.x = facing * maxf(absf(velocity.x), ArenaConfig.COMBO_LUNGES[combo_step])
	hit_targets.clear()
	attack_buffer = 0
	attack_queued = false
	slash_emitted = false
	change_state(State.ATTACK, true)

func finish_sword_attack(controls: Controls) -> void:
	var can_combo := not attack_is_air and attack_direction.y == 0
	var next_combo := (combo_step + 1) % 3 if can_combo else 0
	if attack_queued or attack_buffer > 0:
		combo_step = next_combo
		begin_sword_attack(controls)
		return
	combo_step = next_combo
	combo_grace = ArenaConfig.COMBO_GRACE if can_combo else 0
	change_state(State.IDLE if is_on_floor() else State.AIR)

func current_attack_duration() -> float:
	if attack_is_air:
		return ArenaConfig.AIR_ATTACK_DURATION
	return ArenaConfig.ATTACK_DURATIONS[combo_step]

func current_attack_start() -> float:
	return ArenaConfig.AIR_ATTACK_START if attack_is_air else ArenaConfig.ATTACK_STARTS[combo_step]

func current_attack_end() -> float:
	return ArenaConfig.AIR_ATTACK_END if attack_is_air else ArenaConfig.ATTACK_ENDS[combo_step]

func attack_world_direction() -> Vector2:
	if attack_direction == Vector2.UP:
		return Vector2.UP
	if attack_direction == Vector2.DOWN:
		return Vector2.DOWN
	return Vector2(facing, 0)

func handle_focus(delta: float, controls: Controls) -> void:
	if state == State.ATTACK or state == State.CAST:
		if controls.focus_release:
			focus_time = 0
			focus_cancelled = false
			focus_consumed = false
			return
	if controls.focus:
		focus_time += delta
		if focus_time >= 0.22 and not focus_consumed and not focus_cancelled:
			if energy < ArenaConfig.ENERGY_COST:
				arena.notify("需要 3 格能量 · 挥剑命中可积攒")
				focus_cancelled = true
			elif health >= ArenaConfig.MAX_HEALTH:
				arena.notify("生命已满 · 短按 A 释放法术")
				focus_cancelled = true
			elif not is_on_floor():
				arena.notify("落地后长按 A 回血")
				focus_cancelled = true
			elif state != State.ATTACK and state != State.CAST:
				if state != State.HEAL:
					change_state(State.HEAL)
				if focus_time >= ArenaConfig.HEAL_TIME:
					energy -= ArenaConfig.ENERGY_COST
					health = mini(health + 1, ArenaConfig.MAX_HEALTH)
					focus_consumed = true
					change_state(State.IDLE)
					arena.burst(position + Vector2(0, -40), ArenaConfig.TEAL, 22)
					arena.sound("heal")
					stats_changed.emit()
	if controls.focus_release:
		if focus_time > 0 and focus_time < 0.22 and not focus_consumed and not focus_cancelled:
			cast_spell()
		if state == State.HEAL:
			change_state(State.IDLE)
		focus_time = 0
		focus_cancelled = false
		focus_consumed = false

func cast_spell() -> bool:
	if (
		state == State.ATTACK
		or state == State.CAST
		or state == State.HURT
		or state == State.DEAD
	):
		return false
	if energy < ArenaConfig.ENERGY_COST:
		arena.notify("需要 3 格能量 · 挥剑命中可积攒")
		return false
	energy -= ArenaConfig.ENERGY_COST
	change_state(State.CAST)
	arena.spawn_spell(position + Vector2(facing * 36, -39), facing)
	arena.sound("spell")
	stats_changed.emit()
	return true

func sword_rect() -> Rect2:
	if attack_direction == Vector2.UP:
		return Rect2(position + Vector2(-31, -139), Vector2(62, 83))
	if attack_direction == Vector2.DOWN:
		return Rect2(position + Vector2(-32, -18), Vector2(64, 85))
	var reach: float = ArenaConfig.COMBO_REACHES[combo_step]
	var height: float = ArenaConfig.COMBO_HEIGHTS[combo_step]
	var top: float = ArenaConfig.COMBO_TOPS[combo_step]
	return Rect2(position + Vector2(8 if facing > 0 else -reach - 8, top), Vector2(reach, height))

func hurtbox() -> Rect2:
	return Rect2(position + Vector2(-12, -70), Vector2(24, 70))

func register_hit(target_id: int) -> bool:
	if hit_targets.has(target_id):
		return false
	hit_targets.append(target_id)
	energy = mini(energy + 1, ArenaConfig.MAX_ENERGY)
	if attack_direction == Vector2.DOWN:
		velocity.y = -610
		jumps_used = 1
	else:
		var recoil: float = 85.0 if not is_on_floor() else ArenaConfig.GROUND_HIT_RECOILS[combo_step]
		velocity.x = -facing * recoil
	stats_changed.emit()
	return true

func restore_practice_stats() -> void:
	if health == ArenaConfig.MAX_HEALTH and energy == ArenaConfig.MAX_ENERGY:
		return
	health = ArenaConfig.MAX_HEALTH
	energy = ArenaConfig.MAX_ENERGY
	stats_changed.emit()

func take_damage(amount: int, from: Vector2) -> bool:
	if invulnerable > 0 or state == State.DEAD:
		return false
	health = maxi(0, health - amount)
	invulnerable = ArenaConfig.INVULNERABILITY
	flash = 0.14
	attack_buffer = 0
	attack_queued = false
	combo_grace = 0
	focus_cancelled = true
	focus_time = 0
	velocity = Vector2(330 if position.x >= from.x else -330, -260)
	change_state(State.HURT if health > 0 else State.DEAD)
	arena.burst(position + Vector2(0, -40), ArenaConfig.DANGER, 20)
	arena.impact(8, 0.07)
	arena.sound("hurt")
	stats_changed.emit()
	if health == 0:
		died.emit()
	return true

func _draw_fighter() -> void:
	var tint := Color.WHITE if flash > 0 else ArenaConfig.INK
	if invulnerable > 0 and fmod(clock, 0.12) < 0.055:
		tint.a = 0.3
	var pose := "idle"
	match state:
		State.RUN: pose = "run"
		State.AIR: pose = "air"
		State.HURT, State.DEAD: pose = "hurt"
		State.HEAL: pose = "heal"
		State.CAST: pose = "cast"
		State.ATTACK:
			if attack_direction == Vector2.DOWN:
				pose = "down"
			elif attack_direction == Vector2.UP:
				pose = "up"
			else:
				pose = "attack"
	var attack_progress := state_time / current_attack_duration() if state == State.ATTACK else 0.0
	BoxArt.fighter(visual, pose, clock, tint, false, attack_progress, combo_step, landing_squash)
	visual.draw_rect(Rect2(-14, -57, 26, 4), ArenaConfig.TEAL)
	BoxArt.bar(
		visual,
		Vector2(-10, -55),
		Vector2(-32 - sin(clock * 8) * 5, -46),
		4,
		ArenaConfig.TEAL,
	)
	if (
		state == State.ATTACK
		and state_time >= current_attack_start()
		and state_time <= current_attack_end()
	):
		var direction := Vector2(attack_direction.x * facing, attack_direction.y)
		for i in 5:
			var angle := direction.angle() + (float(i) - 2) * 0.27
			var center := Vector2(0, -43) + Vector2.from_angle(angle) * (78 + combo_step * 5)
			BoxArt.bar(
				visual,
				center,
				center + Vector2.from_angle(angle + PI * 0.5) * 18,
				3,
				Color(0.75, 1, 0.9, 0.58 - i * 0.07),
			)
	if state == State.HEAL:
		BoxArt.outline(visual, Rect2(-21, -86, 42, 6), ArenaConfig.MUTED, 1)
		visual.draw_rect(
			Rect2(-20, -85, 40 * minf(1, focus_time / ArenaConfig.HEAL_TIME), 4),
			ArenaConfig.TEAL,
		)
