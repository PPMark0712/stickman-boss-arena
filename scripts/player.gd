class_name ArenaPlayer
extends CharacterBody2D

signal stats_changed
signal died

enum State { IDLE, RUN, AIR, ATTACK, CAST, HEAL, HURT, DEAD }

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
var focus_time := 0.0
var focus_consumed := false
var focus_cancelled := false
var controlled := true
var visual: Node2D

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

func change_state(next: State) -> void:
	state = next
	state_time = 0.0
	stats_changed.emit()

func _physics_process(delta: float) -> void:
	if not arena.combat_active:
		return
	step(delta, read_controls() if controlled else {})

func read_controls() -> Dictionary:
	return {
		"axis": Input.get_axis("move_left", "move_right"),
		"jump": Input.is_action_just_pressed("jump"),
		"jump_release": Input.is_action_just_released("jump"),
		"attack": Input.is_action_just_pressed("attack"),
		"up": Input.is_action_pressed("look_up"),
		"down": Input.is_action_pressed("look_down"),
		"focus": Input.is_action_pressed("focus"),
		"focus_release": Input.is_action_just_released("focus"),
	}

func step(delta: float, controls: Dictionary) -> void:
	clock += delta
	state_time += delta
	invulnerable = maxf(0, invulnerable - delta)
	flash = maxf(0, flash - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	coyote = ArenaConfig.COYOTE_TIME if is_on_floor() else maxf(0, coyote - delta)
	if is_on_floor():
		jumps_used = 0
	if controls.get("jump", false):
		jump_buffer = ArenaConfig.JUMP_BUFFER
	if not is_on_floor():
		var gravity := ArenaConfig.FALL_GRAVITY if velocity.y > 0 else ArenaConfig.GRAVITY
		velocity.y = minf(velocity.y + gravity * delta, ArenaConfig.MAX_FALL)
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		move_and_slide()
		visual.queue_redraw()
		return
	if state == State.HURT:
		if controls.get("focus_release", false):
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
			if state_time >= ArenaConfig.ATTACK_START and state_time <= ArenaConfig.ATTACK_END:
				arena.resolve_sword(self, sword_rect())
			if state_time >= ArenaConfig.ATTACK_DURATION:
				change_state(State.IDLE if is_on_floor() else State.AIR)
		elif state == State.CAST:
			if state_time >= 0.24:
				change_state(State.IDLE if is_on_floor() else State.AIR)
		elif state != State.HEAL:
			var next := State.AIR if not is_on_floor() else (State.RUN if absf(velocity.x) > 15 else State.IDLE)
			if state != next:
				change_state(next)
	move_and_slide()
	position.x = clampf(position.x, ArenaConfig.LEFT_WALL + 14, ArenaConfig.RIGHT_WALL - 14)
	visual.scale.x = facing
	visual.queue_redraw()

func handle_movement(delta: float, controls: Dictionary) -> void:
	var axis: float = controls.get("axis", 0.0)
	if state == State.HEAL:
		velocity.x = move_toward(velocity.x, 0, ArenaConfig.FRICTION * delta)
		if absf(axis) > 0.1 or controls.get("jump", false) or controls.get("attack", false):
			focus_cancelled = true
			change_state(State.IDLE)
		else:
			return
	if state == State.CAST:
		axis *= 0.35
	if axis != 0 and state != State.ATTACK:
		facing = signf(axis)
	var acceleration := ArenaConfig.ACCELERATION if is_on_floor() else ArenaConfig.AIR_ACCELERATION
	if axis == 0:
		acceleration = ArenaConfig.FRICTION
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
		arena.burst(position, ArenaConfig.TEAL, 7)
		arena.sound("jump")
	if controls.get("jump_release", false) and velocity.y < -250:
		velocity.y *= 0.48

func handle_attack(controls: Dictionary) -> void:
	if not controls.get("attack", false) or state in [State.ATTACK, State.CAST, State.HEAL]:
		return
	attack_direction = Vector2(facing, 0)
	if not is_on_floor():
		if controls.get("down", false):
			attack_direction = Vector2.DOWN
		elif controls.get("up", false):
			attack_direction = Vector2.UP
	hit_targets.clear()
	change_state(State.ATTACK)
	arena.sound("swing")

func handle_focus(delta: float, controls: Dictionary) -> void:
	if controls.get("focus", false):
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
			elif state not in [State.ATTACK, State.CAST]:
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
	if controls.get("focus_release", false):
		if focus_time > 0 and focus_time < 0.22 and not focus_consumed and not focus_cancelled:
			cast_spell()
		if state == State.HEAL:
			change_state(State.IDLE)
		focus_time = 0
		focus_cancelled = false
		focus_consumed = false

func cast_spell() -> bool:
	if state in [State.ATTACK, State.CAST, State.HURT, State.DEAD]:
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
	return Rect2(position + Vector2(10 if facing > 0 else -104, -71), Vector2(94, 62))

func hurtbox() -> Rect2:
	return Rect2(position + Vector2(-12, -70), Vector2(24, 70))

func register_hit(target_id: int) -> bool:
	if hit_targets.has(target_id):
		return false
	hit_targets.append(target_id)
	energy = mini(energy + 1, ArenaConfig.MAX_ENERGY)
	if attack_direction == Vector2.DOWN:
		velocity.y = -540
		jumps_used = 1
	else:
		velocity.x = -facing * 120
	stats_changed.emit()
	return true

func take_damage(amount: int, from: Vector2) -> bool:
	if invulnerable > 0 or state == State.DEAD:
		return false
	health = maxi(0, health - amount)
	invulnerable = ArenaConfig.INVULNERABILITY
	flash = 0.14
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
		State.CAST: pose = "attack"
		State.ATTACK:
			pose = "down" if attack_direction == Vector2.DOWN else ("up" if attack_direction == Vector2.UP else "attack")
	BoxArt.fighter(visual, pose, clock, tint)
	visual.draw_rect(Rect2(-14, -57, 26, 4), ArenaConfig.TEAL)
	BoxArt.bar(visual, Vector2(-10, -55), Vector2(-32 - sin(clock * 8) * 5, -46), 4, ArenaConfig.TEAL)
	if state == State.ATTACK and state_time >= ArenaConfig.ATTACK_START and state_time <= ArenaConfig.ATTACK_END:
		var direction := Vector2(attack_direction.x * facing, attack_direction.y)
		for i in 5:
			var angle := direction.angle() + (float(i) - 2) * 0.27
			var center := Vector2(0, -43) + Vector2.from_angle(angle) * 75
			BoxArt.bar(visual, center, center + Vector2.from_angle(angle + PI * 0.5) * 20, 4, Color(0.65, 1, 0.86, 0.8 - i * 0.1))
	if state == State.HEAL:
		BoxArt.outline(visual, Rect2(-21, -86, 42, 6), ArenaConfig.MUTED, 1)
		visual.draw_rect(Rect2(-20, -85, 40 * minf(1, focus_time / ArenaConfig.HEAL_TIME), 4), ArenaConfig.TEAL)
