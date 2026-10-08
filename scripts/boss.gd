class_name ArenaBoss
extends CharacterBody2D

const FIGHTER_VISUAL_SCENE := preload("res://scenes/fighter_visual.tscn")

signal defeated
signal phase_changed
signal health_changed

const HAMMER_PHASE_ONE := ["slam", "wave", "jump"]
const HAMMER_PHASE_TWO := ["jump", "combo", "rain", "wave"]
const MIRROR_PHASE_ONE := ["thrust", "boomerang", "dive"]
const MIRROR_PHASE_TWO := ["thrust", "fan", "dive", "blades"]
const COMBO_FIRST_SLAM := 0.72
const COMBO_SECOND_WINDUP := 0.92
const COMBO_SECOND_SLAM := 1.48
const COMBO_LAUNCH_WINDUP := 1.68
const COMBO_LAUNCH := 2.24
const COMBO_RECOVER_DURATION := COMBO_SECOND_SLAM - COMBO_SECOND_WINDUP
const JUMP_LAUNCH_SPEED_PHASE_ONE := -870.0
const JUMP_LAUNCH_SPEED_PHASE_TWO := -960.0
const COMBO_LAUNCH_SPEED := -930.0
const COMBO_APEX_HOLD := 0.30
const COMBO_DIVE_SPEED := 1080.0
const COMBO_FINISH_RADIUS := 185.0
const HEAVY_VISUAL_SCALE := 1.65
const HAMMER_SWING_TIME := 0.16
const HAMMER_SETTLE_TIME := 0.32

var arena: Node2D
var kind := 0
var health := ArenaConfig.HAMMER_HEALTH
var max_health := ArenaConfig.HAMMER_HEALTH
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
var jump_apex_y := ArenaConfig.FLOOR_Y
var pose := "idle"
var pose_time := 0.0
var dead := false
var tree: ArenaBT.Selector
var visual: ProceduralFighterVisual
var history: Array[String] = []
var step_dust_timer := 0.0
var hit_reaction := 0.0

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
	visual = FIGHTER_VISUAL_SCENE.instantiate()
	visual.fighter_kind = (
		ProceduralFighterVisual.FighterKind.QUARRY
		if kind == 0
		else ProceduralFighterVisual.FighterKind.PRISM
	)
	add_child(visual)
	visual.draw.connect(_draw_fighter)
	sync_visual()
	tree = ArenaBT.Selector.new([
		ArenaBT.Sequence.new([
			ArenaBT.Condition.new(can_start_phase_transition),
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
	hit_reaction *= exp(-delta * 24.0)
	cooldown = maxf(0, cooldown - delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + ArenaConfig.BOSS_GRAVITY * delta, 1400)
	tree.tick(delta)
	move_and_slide()
	if kind == 0:
		resolve_landing()
		step_dust_timer -= delta
		if pose == "run" and is_on_floor() and absf(velocity.x) > 10 and step_dust_timer <= 0:
			step_dust_timer = PI / 8.5
			arena.burst(position + Vector2(-facing * 18, -3), ArenaConfig.MUTED.darkened(0.25), 3)
	position.x = clampf(position.x, ArenaConfig.LEFT_WALL + 35, ArenaConfig.RIGHT_WALL - 35)
	sync_visual()
	resolve_hammer_hit()
	if hurtbox().intersects(arena.player.hurtbox()):
		arena.player.take_damage(1, position)
	visual.scale = Vector2(facing, 1) * (HEAVY_VISUAL_SCALE if kind == 0 else 1.27)
	visual.queue_redraw()

func can_start_phase_transition() -> bool:
	# Finish the Quarry's committed attack, including its landing and recovery.
	return phase_pending and (kind != 0 or (action.is_empty() and is_on_floor()))

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
	jump_apex_y = ArenaConfig.FLOOR_Y
	if absf(target_x - position.x) > 1:
		facing = signf(target_x - position.x)
	velocity.x = 0
	set_pose("windup")

func _perform_attack(delta: float) -> ArenaBT.Status:
	if action.is_empty():
		begin_attack(choose_attack())
	action_time += delta
	var finished := hammer_attack(delta) if kind == 0 else mirror_attack()
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

func hammer_attack(delta: float = 1.0 / 120.0) -> bool:
	match action:
		"slam", "wave":
			if event_index == 0 and action_time >= windup_duration() - HAMMER_SWING_TIME:
				set_pose("slam")
			if at(windup_duration(), 0):
				slam(false, action == "wave")
			if event_index == 1 and action_time >= windup_duration() + 0.12:
				set_pose("settle")
			return (
				action_time >= (1.18 if phase == 1 else 0.92)
				and pose == "settle" and pose_time >= HAMMER_SETTLE_TIME
			)
		"jump":
			if at(windup_duration(), 0):
				launch(
					JUMP_LAUNCH_SPEED_PHASE_ONE
					if phase == 1
					else JUMP_LAUNCH_SPEED_PHASE_TWO
				)
				set_pose("apex", true)
			if event_index == 1:
				set_pose("apex")
				if velocity.y >= 0:
					event_index = 2
					jump_apex_y = position.y
					set_pose("dive", true)
			if event_index == 2:
				set_pose("dive")
				if velocity.y > 50:
					velocity.y += 360.0 * delta
			if event_index == 3 and action_time >= 0.15:
				set_pose("settle")
			return event_index == 3 and action_time >= 0.50
		"combo":
			if event_index == 0 and action_time >= COMBO_FIRST_SLAM - HAMMER_SWING_TIME:
				set_pose("slam")
			if at(COMBO_FIRST_SLAM, 0):
				slam(false, false)
			if at(COMBO_SECOND_WINDUP, 1):
				face_player()
				set_pose("recover", true)
			if event_index == 2 and action_time >= COMBO_SECOND_SLAM - HAMMER_SWING_TIME:
				set_pose("slam")
			if at(COMBO_SECOND_SLAM, 2):
				slam(false, false)
			if at(COMBO_LAUNCH_WINDUP, 3):
				set_pose("recover", true)
			if at(COMBO_LAUNCH, 4):
				launch(COMBO_LAUNCH_SPEED)
			if event_index == 5:
				set_pose("attack")
				if velocity.y >= -15.0:
					event_index = 6
					jump_apex_y = position.y
					velocity = Vector2.ZERO
					set_pose("apex", true)
			if event_index == 6:
				velocity = Vector2.ZERO
				if pose_time >= COMBO_APEX_HOLD:
					event_index = 7
					velocity = Vector2(
						clampf((target_x - position.x) * 3.0, -520, 520),
						COMBO_DIVE_SPEED,
					)
					set_pose("dive", true)
			if event_index == 7:
				set_pose("dive")
			if event_index == 8 and action_time >= 0.18:
				set_pose("settle")
			return event_index == 8 and action_time > 0.58
		"rain":
			for i in 4:
				var strike_time := 0.60 + i * 0.46
				if event_index == i and action_time >= strike_time - 0.34 and pose == "impact":
					facing *= -1
					set_pose("recover", true)
				if event_index == i and action_time >= strike_time - HAMMER_SWING_TIME:
					set_pose("slam")
				if at(0.60 + i * 0.46, i):
					slam(false, false)
					arena.spawn_rock(clampf(arena.player.position.x + (i % 2 * 2 - 1) * 45, 90, 1190), 0.80)
					arena.spawn_rock(190 + i * 280, 1.05)
			if event_index == 4 and pose_time > 0.15:
				set_pose("settle")
			return action_time > 2.9
	return false

func resolve_landing() -> void:
	# move_and_slide() is the authority for this tick's landing. Resolving before
	# it leaves one grounded frame with the hammer still in its airborne state.
	if not is_on_floor():
		return
	if action == "jump" and event_index == 2:
		event_index = 3
		velocity.x = 0
		action_time = 0
		slam(phase == 2, phase == 2)
	elif action == "combo" and event_index == 7:
		event_index = 8
		velocity.x = 0
		action_time = 0
		combo_finisher()

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
	if kind == 0 and is_instance_valid(arena):
		if next_pose == "slam":
			arena.sound("hammer_swing")
		elif next_pose == "recover" or next_pose == "windup":
			arena.sound("hammer_lift")
		elif next_pose == "apex" and action == "combo":
			arena.sound("hammer_apex")

func slam(both: bool, wave: bool, wide: bool = false) -> void:
	set_pose("impact", true)
	var width := 205.0 if wide else 155.0
	var origin := position + Vector2(0 if facing > 0 else -width, -95)
	arena.strike(Rect2(origin, Vector2(width, 95)), position)
	arena.show_slam(Rect2(origin, Vector2(width, 95)), color())
	arena.show_shock(Vector2(hammer_head_center().x, position.y - 3), color(), 105.0 if not wide else 160.0)
	arena.burst(position + Vector2(facing * 80, -5), color(), 26)
	arena.impact(10 if wide else 6, 0.045)
	arena.sound("slam")
	if wave:
		arena.spawn_wave(position + Vector2(facing * 70, 0), facing, color())
		if both:
			arena.spawn_wave(position - Vector2(facing * 70, 0), -facing, color())

func combo_finisher() -> void:
	set_pose("impact", true)
	var rect := Rect2(
		position + Vector2(-COMBO_FINISH_RADIUS, -112),
		Vector2(COMBO_FINISH_RADIUS * 2.0, 112),
	)
	arena.strike(rect, position)
	arena.show_slam(rect, ArenaConfig.DANGER)
	arena.show_shock(position + Vector2(0, -3), ArenaConfig.DANGER, COMBO_FINISH_RADIUS)
	arena.burst(position + Vector2(0, -8), ArenaConfig.DANGER, 46)
	arena.impact(14, 0.07)
	arena.sound("slam")
	arena.spawn_wave(position + Vector2(-70, 0), -1, ArenaConfig.DANGER)
	arena.spawn_wave(position + Vector2(70, 0), 1, ArenaConfig.DANGER)

func hammer_head_center() -> Vector2:
	# Also used by tools/tests between physics ticks; sample current state first.
	if is_instance_valid(visual):
		sync_visual()
	var sampled_pose := visual.pose if is_instance_valid(visual) else pose
	var sampled_progress := visual.animation_progress if is_instance_valid(visual) else visual_progress()
	var sampled_clock := visual.animation_clock if is_instance_valid(visual) else clock
	var rig := BoxArt.heavy_rig_snapshot(
		sampled_pose, sampled_progress, sampled_clock,
		visual.squash if is_instance_valid(visual) else 0.0,
		visual.variant if is_instance_valid(visual) else visual_variant(),
	)
	var local_center: Vector2 = rig.hammer_center
	return position + visual.position + Vector2(local_center.x * facing, local_center.y) * HEAVY_VISUAL_SCALE

func hammer_head_hitbox() -> Rect2:
	var radius := BoxArt.HEAVY_HAMMER_HEAD_RADIUS * HEAVY_VISUAL_SCALE
	return Rect2(hammer_head_center() - Vector2.ONE * radius, Vector2.ONE * radius * 2)

func hammer_hitbox_active() -> bool:
	return kind == 0 and not dead

func resolve_hammer_hit() -> void:
	if not hammer_hitbox_active():
		return
	arena.strike(hammer_head_hitbox(), hammer_head_center())

func hurtbox() -> Rect2:
	if kind == 0:
		return Rect2(position + Vector2(-29, -121), Vector2(58, 121))
	return Rect2(position + Vector2(-19, -96), Vector2(38, 96))

func take_damage(amount: int, from: Vector2) -> bool:
	if dead or phase_pending:
		return false
	health = maxi(0, health - amount)
	flash = 0.075 if kind == 0 else 0.12
	if kind == 0:
		hit_reaction = (1.0 if position.x >= from.x else -1.0) * 4.0
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
	sync_visual()
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
			return COMBO_FIRST_SLAM
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
	if phase_pending and phase_time > 0:
		return clampf(phase_time / 1.2, 0.0, 1.0)
	if action.is_empty():
		return 0.0
	if pose == "windup":
		var duration := windup_duration()
		if kind == 0 and action in ["slam", "wave", "combo", "rain"]:
			duration -= HAMMER_SWING_TIME
		return clampf(pose_time / duration, 0.0, 1.0)
	if pose == "recover":
		var duration := COMBO_RECOVER_DURATION
		if action == "rain":
			duration = 0.18
		elif action == "combo" and event_index == 2:
			duration -= HAMMER_SWING_TIME
		return clampf(pose_time / duration, 0.0, 1.0)
	if kind == 0 and pose == "slam":
		return clampf(pose_time / HAMMER_SWING_TIME, 0.0, 1.0)
	if pose == "settle":
		return clampf(pose_time / HAMMER_SETTLE_TIME, 0.0, 1.0)
	if pose == "attack" and action == "combo":
		return clampf(
			1.0 - absf(minf(velocity.y, 0.0)) / absf(COMBO_LAUNCH_SPEED),
			0.0,
			1.0,
		)
	if pose == "dive" and action in ["jump", "combo"]:
		return clampf(
			(position.y - jump_apex_y)
			/ maxf(ArenaConfig.FLOOR_Y - jump_apex_y, 1.0),
			0.0,
			1.0,
		)
	if pose == "attack" or pose == "slam" or pose == "down":
		return 0.88
	return 0.0

func visual_variant() -> int:
	if action == "combo" and pose in ["attack", "apex", "dive"]:
		return 1
	if action == "thrust":
		return 2
	if action == "boomerang" or action == "fan":
		return 1
	return 0

func sync_visual() -> void:
	var tint := Color.WHITE if flash > 0 else color()
	if dead:
		tint.a = 0.2
	if phase_pending and phase_time > 0:
		tint = tint.lerp(Color.WHITE, (sin(clock * 24) + 1) * 0.4)
	visual.tint = tint
	visual.variant = visual_variant()
	visual.weapon_in_front = facing > 0
	visual.position.x = hit_reaction if kind == 0 else 0.0
	if kind == 1:
		# Prism choreography is outside this iteration; retain its original sampling.
		visual.pose = pose
		visual.animation_progress = visual_progress()
		visual.animation_clock = clock
		return
	if pose == "idle" or pose == "run" or pose == "air":
		visual.sample_loop(pose, clock, pose)
	else:
		visual.sample(pose, visual_progress(), pose)

func _draw_fighter() -> void:
	if kind == 0 and not dead and pose in ["windup", "recover", "apex"]:
		var rig := BoxArt.heavy_rig_snapshot(
			visual.pose, visual.animation_progress, visual.animation_clock, visual.squash,
			visual.variant,
		)
		var head: Vector2 = rig.hammer_center
		var charge := visual.animation_progress if pose != "apex" else 1.0
		var glow := 0.12 + charge * 0.33
		visual.draw_arc(head, 33, -PI * 0.9, PI * 0.7, 24, Color(ArenaConfig.AMBER, glow), 2)
		if charge > 0.8:
			BoxArt.bar(visual, head - Vector2(9, 0), head + Vector2(9, 0), 2, Color(Color.WHITE, (charge - 0.8) * 4))
			BoxArt.bar(visual, head - Vector2(0, 9), head + Vector2(0, 9), 2, Color(Color.WHITE, (charge - 0.8) * 4))
	if kind == 1:
		BoxArt.bar(visual, Vector2(-6, -58), Vector2(-31, -16), 5, visual.tint.darkened(0.3))
	if action == "combo" and event_index == 5:
		for i in 6:
			var point := Vector2(0, -42) + Vector2.from_angle(clock * 19 + i * TAU / 6) * 67
			BoxArt.bar(visual, point, point + Vector2(9, 9), 4, visual.tint)
	if (pose == "windup" or pose == "apex") and not (phase_pending and phase_time > 0):
		visual.draw_rect(Rect2(-3, -105, 6, 12), ArenaConfig.DANGER)
		visual.draw_rect(Rect2(-3, -89, 6, 4), ArenaConfig.DANGER)
