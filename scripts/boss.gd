class_name ArenaBoss
extends CharacterBody2D

signal defeated
signal phase_changed
signal health_changed

const HAMMER_PHASE_ONE := ["slam", "wave", "jump"]
const HAMMER_PHASE_TWO := ["jump", "combo", "rain", "wave"]
const MIRROR_PHASE_ONE := ["thrust", "boomerang", "dive"]
const MIRROR_PHASE_TWO := ["thrust", "fan", "dive", "blades"]

var arena: Node2D
var kind := 0
var health := 240
var max_health := 240
var phase := 1
var phase_time := 0.0
var phase_pending := false
var facing := -1.0
var clock := 0.0
var flash := 0.0
var cooldown := 1.0
var action := ""
var action_time := 0.0
var event_index := 0
var action_count := 0
var target_x := 0.0
var pose := "idle"
var pose_time := 0.0
var dead := false
var tree: ArenaBT.Selector
var visual: Node2D
var history: Array[String] = []

func _ready() -> void:
	max_health = ArenaConfig.HAMMER_HEALTH if kind == 0 else ArenaConfig.MIRROR_HEALTH
	health = max_health
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(58, 118) if kind == 0 else Vector2(36, 92)
	collider.shape = shape
	collider.position.y = -shape.size.y * 0.5
	add_child(collider)
	visual = Node2D.new()
	visual.draw.connect(_draw_fighter)
	add_child(visual)
	tree = ArenaBT.Selector.new([
		ArenaBT.Sequence.new([
			ArenaBT.Condition.new(func() -> bool: return phase_pending),
			ArenaBT.Action.new(_phase_transition),
		]),
		ArenaBT.Sequence.new([
			ArenaBT.Condition.new(func() -> bool: return cooldown <= 0),
			ArenaBT.Action.new(_perform_attack),
		]),
		ArenaBT.Action.new(_pursue),
	])

func _physics_process(delta: float) -> void:
	if not arena.combat_active or dead:
		return
	clock += delta
	pose_time += delta
	flash = maxf(0, flash - delta)
	cooldown = maxf(0, cooldown - delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + ArenaConfig.BOSS_GRAVITY * delta, 1400)
	tree.tick(delta)
	move_and_slide()
	position.x = clampf(position.x, ArenaConfig.LEFT_WALL + 35, ArenaConfig.RIGHT_WALL - 35)
	if not phase_pending and hurtbox().intersects(arena.player.hurtbox()):
		arena.player.take_damage(1, position)
	visual.scale = Vector2(facing, 1) * (1.65 if kind == 0 else 1.27)
	visual.queue_redraw()

func _phase_transition(delta: float) -> ArenaBT.Status:
	if phase_time == 0:
		action = ""
		phase = 2
		velocity.x = 0
		arena.clear_hazards()
		arena.sound("phase")
		arena.notify("裂岩守卫 · 狂震" if kind == 0 else "折光剑使 · 镜裂", 2.2)
		phase_changed.emit()
		set_pose("windup", true)
	phase_time += delta
	set_pose("windup")
	if phase_time < 1.2:
		return ArenaBT.Status.RUNNING
	phase_pending = false
	cooldown = 0.35
	return ArenaBT.Status.SUCCESS

func _pursue(_delta: float) -> ArenaBT.Status:
	var distance: float = arena.player.position.x - position.x
	if absf(distance) > 5:
		facing = signf(distance)
	var desired := 140.0 if kind == 0 else 195.0
	var speed := 72.0 if kind == 0 else 135.0
	if phase == 2:
		speed *= 1.2
	# Deliberate small retreats during recovery create a readable rhythm.
	velocity.x = facing * speed if absf(distance) > desired else -facing * speed * 0.28
	set_pose("run")
	return ArenaBT.Status.RUNNING

func choose_attack() -> String:
	var pool := HAMMER_PHASE_ONE if kind == 0 else MIRROR_PHASE_ONE
	if phase == 2:
		pool = HAMMER_PHASE_TWO if kind == 0 else MIRROR_PHASE_TWO
	var choice: String = pool[action_count % pool.size()]
	action_count += 1
	return choice

func begin_attack(name_: String) -> void:
	action = name_
	history.append(action)
	action_time = 0
	event_index = 0
	target_x = arena.player.position.x
	if absf(target_x - position.x) > 1:
		facing = signf(target_x - position.x)
	velocity.x = 0
	set_pose("windup")

func _perform_attack(delta: float) -> ArenaBT.Status:
	if action.is_empty():
		begin_attack(choose_attack())
	action_time += delta
	var finished := hammer_attack() if kind == 0 else mirror_attack()
	if not finished:
		return ArenaBT.Status.RUNNING
	action = ""
	velocity.x = 0
	set_pose("idle")
	cooldown = attack_cooldown()
	return ArenaBT.Status.SUCCESS

func at(time: float, index: int) -> bool:
	if event_index == index and action_time >= time:
		event_index += 1
		return true
	return false

func hammer_attack() -> bool:
	match action:
		"slam", "wave":
			if at(windup_duration(), 0):
				slam(false, action == "wave")
			return action_time >= (1.18 if phase == 1 else 0.92)
		"jump":
			if at(windup_duration(), 0):
				launch(-810 if phase == 1 else -900)
			if event_index == 1:
				set_pose("windup")
				if velocity.y > 50:
					velocity.y += 45
				if is_on_floor() and action_time > 0.65:
					event_index = 2
					velocity.x = 0
					slam(phase == 2, phase == 2)
					action_time = 0
			return event_index == 2 and action_time >= 0.50
		"combo":
			if at(0.46, 0):
				slam(false, false)
			if at(0.83, 1):
				face_player()
				slam(false, false)
			if at(1.16, 2):
				launch(-960)
			if event_index == 3:
				set_pose("attack")
				if action_time < 1.9:
					arena.strike(Rect2(position + Vector2(-95, -150), Vector2(190, 155)), position)
				if velocity.y > 0:
					velocity.y += 55
				if is_on_floor() and action_time > 1.40:
					event_index = 4
					velocity.x = 0
					slam(true, true, true)
					action_time = 0
			return event_index == 4 and action_time > 0.65
		"rain":
			for i in 4:
				if at(0.60 + i * 0.46, i):
					facing *= -1
					slam(false, false)
					arena.spawn_rock(clampf(arena.player.position.x + (i % 2 * 2 - 1) * 45, 90, 1190), 0.80)
					arena.spawn_rock(190 + i * 280, 1.05)
			return action_time > 2.9
	return false

func mirror_attack() -> bool:
	match action:
		"thrust":
			if at(windup_duration(), 0):
				set_pose("attack")
				velocity.x = facing * 860
				arena.sound("swing")
			if event_index == 1:
				var first_hit := Rect2(
					position + Vector2(-12 if facing > 0 else -117, -78),
					Vector2(129, 50),
				)
				arena.strike(first_hit, position)
				if action_time >= (0.9 if phase == 1 else 0.76):
					velocity.x = 0
					event_index = 2
					set_pose("windup")
			if phase == 2 and at(1.14, 2):
				face_player()
				velocity.x = facing * 900
				set_pose("attack")
			if event_index == 3:
				var return_hit := Rect2(
					position + Vector2(-12 if facing > 0 else -117, -78),
					Vector2(129, 50),
				)
				arena.strike(return_hit, position)
				if action_time > 1.4:
					velocity.x = 0
			return action_time >= (1.30 if phase == 1 else 1.82)
		"boomerang", "fan":
			if at(0.65, 0):
				set_pose("attack")
				arena.spawn_blade(position + Vector2(facing * 48, -53), Vector2(facing * 380, 0), true)
				if action == "fan":
					arena.spawn_blade(position + Vector2(0, -75), Vector2(facing * 340, -145), false)
					arena.spawn_blade(position + Vector2(0, -100), Vector2(facing * 300, -265), false)
				arena.sound("spell")
			return action_time > 1.25
		"dive":
			if at(0.5, 0):
				launch(-830)
			if event_index == 1 and velocity.y > -90:
				event_index = 2
				target_x = clampf(arena.player.position.x, 100, 1180)
				velocity = Vector2.ZERO
				action_time = 0
			if event_index == 2:
				velocity = Vector2.ZERO
				set_pose("down")
				if action_time > 0.38:
					event_index = 3
					velocity = Vector2((target_x - position.x) * 3.2, 1100)
			if event_index == 3:
				set_pose("down")
				if is_on_floor():
					event_index = 4
					velocity.x = 0
					arena.strike(Rect2(position + Vector2(-82, -75), Vector2(164, 75)), position)
					arena.burst(position, ArenaConfig.VIOLET, 24)
					arena.impact(6, 0.05)
					if phase == 2:
						arena.spawn_wave(position, -1, ArenaConfig.VIOLET)
						arena.spawn_wave(position, 1, ArenaConfig.VIOLET)
					action_time = 0
			return event_index == 4 and action_time > 0.55
		"blades":
			for i in 5:
				if at(0.5 + i * 0.22, i):
					var x := clampf(arena.player.position.x + (i - 2) * 90, 85, 1195)
					arena.spawn_rock(x, 0.8, true)
			return action_time > 2.2
	return false

func launch(upward: float) -> void:
	target_x = clampf(arena.player.position.x, 115, 1165)
	velocity = Vector2(clampf((target_x - position.x) * 1.25, -440, 440), upward)
	set_pose("air")
	arena.burst(position, color(), 10)

func face_player() -> void:
	if absf(arena.player.position.x - position.x) > 1:
		facing = signf(arena.player.position.x - position.x)

func set_pose(next_pose: String, restart: bool = false) -> void:
	if pose == next_pose and not restart:
		return
	pose = next_pose
	pose_time = 0

func slam(both: bool, wave: bool, wide: bool = false) -> void:
	set_pose("slam", true)
	var width := 205.0 if wide else 155.0
	var origin := position + Vector2(0 if facing > 0 else -width, -95)
	arena.strike(Rect2(origin, Vector2(width, 95)), position)
	arena.show_slam(Rect2(origin, Vector2(width, 95)), color())
	arena.burst(position + Vector2(facing * 80, -5), color(), 26)
	arena.impact(10 if wide else 6, 0.045)
	arena.sound("slam")
	if wave:
		arena.spawn_wave(position + Vector2(facing * 70, 0), facing, color())
		if both:
			arena.spawn_wave(position - Vector2(facing * 70, 0), -facing, color())

func hurtbox() -> Rect2:
	if kind == 0:
		return Rect2(position + Vector2(-29, -121), Vector2(58, 121))
	return Rect2(position + Vector2(-19, -96), Vector2(38, 96))

func take_damage(amount: int, from: Vector2) -> bool:
	if dead or phase_pending:
		return false
	health = maxi(0, health - amount)
	flash = 0.12
	if action.is_empty():
		velocity.x += 65 if position.x > from.x else -65
	if health <= max_health / 2 and phase == 1 and health > 0:
		phase_pending = true
		tree.reset()
	health_changed.emit()
	if health == 0:
		dead = true
		set_pose("hurt")
		arena.burst(position + Vector2(0, -65), color(), 65)
		defeated.emit()
	return true

func color() -> Color:
	return ArenaConfig.AMBER if kind == 0 else ArenaConfig.VIOLET

func attack_cooldown() -> float:
	if phase == 2:
		return 0.52
	return 0.80 if kind == 0 else 0.64

func windup_duration() -> float:
	match action:
		"slam", "wave":
			return 0.68 if phase == 1 else 0.5
		"jump":
			return 0.52 if phase == 1 else 0.34
		"combo":
			return 0.46
		"rain":
			return 0.60
		"thrust":
			return 0.62 if phase == 1 else 0.48
		"boomerang", "fan":
			return 0.65
		"dive", "blades":
			return 0.5
	return 0.6

func visual_progress() -> float:
	if phase_pending:
		return clampf(phase_time / 1.2, 0.0, 1.0)
	if action.is_empty():
		return 0.0
	if pose == "windup":
		return clampf(action_time / windup_duration(), 0.0, 1.0)
	if kind == 0 and pose == "slam":
		return clampf(pose_time / 0.18, 0.0, 1.0)
	if pose == "attack" and action == "combo":
		return fmod(action_time * 1.8, 1.0)
	if pose == "attack" or pose == "slam" or pose == "down":
		return 0.88
	return 0.0

func visual_variant() -> int:
	if action == "thrust":
		return 2
	if action == "boomerang" or action == "fan":
		return 1
	return 0

func _draw_fighter() -> void:
	var tint := Color.WHITE if flash > 0 else color()
	if dead:
		tint.a = 0.2
	if phase_pending:
		tint = tint.lerp(Color.WHITE, (sin(clock * 24) + 1) * 0.4)
	BoxArt.fighter(visual, pose, clock, tint, kind == 0, visual_progress(), visual_variant())
	if kind == 1:
		BoxArt.bar(visual, Vector2(-6, -58), Vector2(-31, -16), 5, tint.darkened(0.3))
	if action == "combo" and event_index == 3:
		for i in 6:
			var point := Vector2(0, -42) + Vector2.from_angle(clock * 19 + i * TAU / 6) * 67
			BoxArt.bar(visual, point, point + Vector2(9, 9), 4, tint)
	if pose == "windup" and not phase_pending:
		visual.draw_rect(Rect2(-3, -105, 6, 12), ArenaConfig.DANGER)
		visual.draw_rect(Rect2(-3, -89, 6, 4), ArenaConfig.DANGER)
