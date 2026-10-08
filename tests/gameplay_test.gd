extends SceneTree
## Real scene/physics integration; run with --fixed-fps 120.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	check(
		ArenaConfig.SWORD_DAMAGE == 10
		and ArenaConfig.SPELL_DAMAGE == ArenaConfig.SWORD_DAMAGE * 3,
		"Spell damage equals three sword hits",
	)
	check(
		ArenaConfig.HAMMER_HEALTH == 400 and ArenaConfig.MIRROR_HEALTH == 300,
		"Boss health matches the intended encounter lengths",
	)
	check(
		ArenaBoss.COMBO_FIRST_SLAM >= 0.70
		and ArenaBoss.COMBO_SECOND_WINDUP - ArenaBoss.COMBO_FIRST_SLAM >= 0.18
		and ArenaBoss.COMBO_SECOND_SLAM - ArenaBoss.COMBO_SECOND_WINDUP >= 0.50,
		"Quarry links the first impact directly into a readable second raise",
	)
	check(
		ArenaBoss.COMBO_LAUNCH_WINDUP - ArenaBoss.COMBO_SECOND_SLAM >= 0.18
		and is_equal_approx(
			ArenaBoss.COMBO_LAUNCH - ArenaBoss.COMBO_LAUNCH_WINDUP,
			ArenaBoss.COMBO_RECOVER_DURATION,
		),
		"Quarry flows from the second impact into the launch raise",
	)
	check(
		ArenaBoss.COMBO_LAUNCH_SPEED == -930.0
		and ArenaBoss.COMBO_APEX_HOLD == 0.3
		and ArenaBoss.COMBO_DIVE_SPEED == 1080.0,
		"Quarry animation refinement preserves launch, apex hold, and dive timing",
	)
	var quarry_idle: Dictionary = BoxArt.heavy_rig_snapshot("idle", 0.0)
	var quarry_windup: Dictionary = BoxArt.heavy_rig_snapshot("windup", 1.0)
	var quarry_impact: Dictionary = BoxArt.heavy_rig_snapshot("slam", 1.0)
	var quarry_recover_start: Dictionary = BoxArt.heavy_rig_snapshot("recover", 0.0)
	var quarry_recover_end: Dictionary = BoxArt.heavy_rig_snapshot("recover", 1.0)
	var quarry_spin_start := BoxArt.heavy_rig_snapshot("attack", 0.0, 0, 0, 1)
	var quarry_spin_end := BoxArt.heavy_rig_snapshot("attack", 1.0, 0, 0, 1)
	var combo_apex := BoxArt.heavy_rig_snapshot("apex", 0.0, 0, 0, 1)
	var quarry_settle_middle: Dictionary = BoxArt.heavy_rig_snapshot("settle", 0.5)
	var quarry_settle_end: Dictionary = BoxArt.heavy_rig_snapshot("settle", 1.0)
	check(quarry_settle_middle.hammer_center.y < -90 and quarry_settle_end.hammer_center.is_equal_approx(quarry_idle.hammer_center), "Quarry recovery lifts the hammer above ground before returning to rest")
	check(absf(quarry_impact.hammer_center.y + BoxArt.HEAVY_HAMMER_HEAD_RADIUS) < 1.0, "Quarry impact puts the hammer rim on the floor")
	check(
		quarry_idle.left_grip.x > quarry_idle.right_grip.x
		and quarry_idle.hammer_center.x < quarry_idle.right_grip.x
		and quarry_idle.hammer_center.y < quarry_idle.right_grip.y,
		"Quarry idle keeps the left hand on the forward handle end and hammer behind the head",
	)
	check(
		absf(quarry_idle.hammer_center.y - quarry_idle.head_center.y) <= 2.0
		and quarry_idle.hammer_angle < -2.75,
		"Quarry carries the shallow diagonal hammer at head height",
	)
	check(
		is_equal_approx(
			quarry_idle.right_grip.distance_to(quarry_idle.hammer_center),
			BoxArt.HEAVY_HAMMER_REACH,
		)
		and BoxArt.HEAVY_HAMMER_REACH < 80,
		"Quarry hammer uses the shortened shared weapon reach",
	)
	check(
		BoxArt.HEAVY_HAMMER_SILVER.get_luminance()
		> ArenaConfig.BACKGROUND.get_luminance() + 0.35,
		"Quarry silver hammer remains distinct from the dark arena",
	)
	check(
		quarry_idle.hammer_center.y - quarry_windup.hammer_center.y > 5
		and quarry_idle.hammer_center.y - quarry_windup.hammer_center.y < 22
		and quarry_windup.hammer_center.x < quarry_windup.head_center.x - 25,
		"Quarry anticipation lifts the shoulder carry slightly and keeps the head behind",
	)
	var quarry_apex := BoxArt.heavy_rig_snapshot("apex", 0.0)
	check(
		quarry_apex.hammer_center.is_equal_approx(quarry_windup.hammer_center)
		and BoxArt.heavy_rig_snapshot("air", 0.0).hammer_center.is_equal_approx(quarry_apex.hammer_center),
		"Ground and airborne raises share the same shallow shoulder hold",
	)
	for swing_pose in ["slam", "dive"]:
		var previous_angle: float = quarry_windup.hammer_angle
		var forward_arc := true
		var clears_floor := true
		var passes_overhead := false
		for i in 41:
			var rig := BoxArt.heavy_rig_snapshot(swing_pose, i / 40.0)
			forward_arc = forward_arc and rig.hammer_angle >= previous_angle
			clears_floor = clears_floor and rig.hammer_center.y + rig.hammer_radius <= 1.0
			passes_overhead = passes_overhead or (
				absf(rig.hammer_center.x - rig.right_grip.x) < 8
				and rig.hammer_center.y < rig.right_grip.y - 55
			)
			previous_angle = rig.hammer_angle
		check(
			forward_arc and clears_floor and passes_overhead,
			"Quarry sweeps over the head toward impact without reversing through the floor: " + swing_pose,
		)
	check(
		quarry_impact.hammer_center.x > quarry_impact.right_grip.x
		and quarry_impact.hammer_center.y > quarry_impact.right_grip.y,
		"Quarry impact drives the hammer forward and down",
	)
	check(
		quarry_recover_start.hammer_center.is_equal_approx(quarry_impact.hammer_center)
		and quarry_recover_end.hammer_center.is_equal_approx(quarry_windup.hammer_center)
		and quarry_recover_end.hammer_center.is_equal_approx(quarry_spin_start.hammer_center)
		and quarry_spin_end.hammer_center.is_equal_approx(combo_apex.hammer_center)
		and BoxArt.heavy_rig_snapshot("dive", 0.0, 0, 0, 1).hammer_center.is_equal_approx(combo_apex.hammer_center)
		and BoxArt.heavy_rig_snapshot("dive", 1.0, 0, 0, 1).hammer_center.is_equal_approx(quarry_impact.hammer_center),
		"Quarry combo transitions preserve hammer continuity at impact, raise, and apex",
	)
	check(
		combo_apex.hammer_center.y < combo_apex.head_center.y - 60
		and absf(combo_apex.hammer_center.x - combo_apex.right_grip.x) < 3,
		"Combo ascent finishes with the hammer overhead",
	)
	var early_spin := BoxArt.heavy_rig_snapshot("attack", 0.25, 0, 0, 1)
	var late_spin := BoxArt.heavy_rig_snapshot("attack", 0.75, 0, 0, 1)
	check(
		early_spin.hammer_angle - quarry_spin_start.hammer_angle > PI
		and early_spin.hammer_angle - quarry_spin_start.hammer_angle
			> quarry_spin_end.hammer_angle - late_spin.hammer_angle
		and quarry_spin_end.hammer_angle - quarry_spin_start.hammer_angle > TAU * 2,
		"Combo spins faster early in the ascent and brakes into the overhead hold",
	)
	var combo_arms_connected := true
	for air_pose in ["attack", "apex", "dive"]:
		for i in 101:
			var snapshot := BoxArt.heavy_rig_snapshot(air_pose, i / 100.0, 0, 0, 1)
			for arm in ["left", "right"]:
				var shoulder: Vector2 = snapshot["%s_shoulder" % arm]
				var elbow: Vector2 = snapshot["%s_elbow" % arm]
				var grip: Vector2 = snapshot["%s_grip" % arm]
				combo_arms_connected = combo_arms_connected and (
					is_equal_approx(shoulder.distance_to(elbow), 27.0)
					and is_equal_approx(elbow.distance_to(grip), 27.0)
				)
	check(combo_arms_connected, "Fast spin and overhead dive preserve both arm lengths")
	for arm in ["left", "right"]:
		var shoulder: Vector2 = quarry_idle["%s_shoulder" % arm]
		var elbow: Vector2 = quarry_idle["%s_elbow" % arm]
		var grip: Vector2 = quarry_idle["%s_grip" % arm]
		check(
			is_equal_approx(shoulder.distance_to(elbow), 27.0)
			and is_equal_approx(elbow.distance_to(grip), 27.0),
			"Quarry %s arm uses equal upper and lower segments" % arm,
		)
	check(
		quarry_idle.right_elbow.x > quarry_idle.right_shoulder.x
		and quarry_idle.right_elbow.y > quarry_idle.right_grip.y,
		"Quarry right elbow bends forward and down from the shoulder grip",
	)
	for heavy_pose in [
		"idle", "run", "windup", "slam", "recover", "attack", "apex",
		"dive", "impact", "air", "hurt",
	]:
		for sample in [0.0, 0.5, 1.0]:
			var snapshot: Dictionary = BoxArt.heavy_rig_snapshot(heavy_pose, sample)
			for arm in ["left", "right"]:
				var shoulder: Vector2 = snapshot["%s_shoulder" % arm]
				var elbow: Vector2 = snapshot["%s_elbow" % arm]
				var grip: Vector2 = snapshot["%s_grip" % arm]
				check(
					is_equal_approx(shoulder.distance_to(elbow), 27.0)
					and is_equal_approx(elbow.distance_to(grip), 27.0),
					"Quarry IK remains equal-length in %s at %.1f" % [heavy_pose, sample],
				)
	check(
		quarry_idle.hammer_center.x < quarry_idle.right_grip.x
		and (-quarry_idle.hammer_center.x) > (-quarry_idle.right_grip.x),
		"Quarry hammer stays behind the head in both mirrored directions",
	)
	var first_slash_start: Dictionary = BoxArt.player_attack_rig_snapshot(0.15, 0)
	var first_slash_finish: Dictionary = BoxArt.player_attack_rig_snapshot(0.70, 0)
	var second_slash_start: Dictionary = BoxArt.player_attack_rig_snapshot(0.15, 1)
	var second_slash_finish: Dictionary = BoxArt.player_attack_rig_snapshot(0.70, 1)
	check(
		first_slash_start.hand.x > first_slash_finish.hand.x
		and first_slash_start.hand.y < first_slash_finish.hand.y
		and second_slash_start.hand.x < second_slash_finish.hand.x
		and second_slash_start.hand.y < second_slash_finish.hand.y,
		"Player alternates near-shoulder to far-hip and far-shoulder to near-hip cuts",
	)
	check(
		first_slash_start.sword_vector.length() > first_slash_finish.sword_vector.length()
		and second_slash_start.sword_vector.length() < second_slash_finish.sword_vector.length(),
		"Blade foreshortening follows the hand across the player's body",
	)
	for variant in 2:
		var shallow_slash := true
		var forward_blade := true
		for i in 101:
			var progress := i / 100.0
			var point := BoxArt.player_slash_point(progress, variant, ArenaConfig.ATTACK_REACH)
			var blade: Vector2 = BoxArt.player_attack_rig_snapshot(
				lerpf(0.15, 0.70, progress), variant,
			).sword_vector
			shallow_slash = shallow_slash and (
				point.x >= 0 and point.x <= ArenaConfig.ATTACK_REACH
				and absf(point.y) + 6.0 <= ArenaConfig.ATTACK_HEIGHT * 0.5
			)
			forward_blade = forward_blade and (
				blade.x > 0 and absf(blade.y) <= 12.01 and blade.length() <= 66.01
			)
		check(shallow_slash, "Slash %d stays within the existing shallow attack rectangle" % variant)
		check(forward_blade, "Slash %d keeps the projected blade forward and nearly horizontal" % variant)
		for sample in [0.0, 0.15, 0.35, 0.55, 0.70, 1.0]:
			var attack_rig: Dictionary = BoxArt.player_attack_rig_snapshot(sample, variant)
			var upper_arm: Vector2 = attack_rig.elbow - attack_rig.shoulder
			var lower_arm: Vector2 = attack_rig.hand - attack_rig.elbow
			check(
				is_equal_approx(upper_arm.length(), 18.0)
				and is_equal_approx(lower_arm.length(), 18.0)
				and upper_arm.cross(lower_arm) < 0,
				"Player right elbow keeps one natural IK branch in slash %d at %.2f"
				% [variant, sample],
			)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(is_instance_valid(game.menu), "Selection menu exists")
	for kind in 2:
		game.practice = true
		game.start_fight(kind)
		await frames(4)
		var room: ArenaRoom = game.room
		room.player.controlled = false
		room.player.invulnerable = 0
		room.player.position = Vector2(800, ArenaConfig.FLOOR_Y)
		room.boss.position = Vector2(845, ArenaConfig.FLOOR_Y)
		room.boss.cooldown = 1000
		room.player.facing = 1
		room.player.begin_dash(ArenaPlayer.Controls.new())
		await frames(3)
		check(room.player.state == ArenaPlayer.State.HURT, "Boss contact interrupts dash")
		room.restore_time_scale()
		room.player.change_state(ArenaPlayer.State.IDLE)
		room.player.position = Vector2(290, ArenaConfig.FLOOR_Y)
		room.player.velocity = Vector2.ZERO
		room.boss.position = Vector2(945, ArenaConfig.FLOOR_Y)
		room.player.invulnerable = 1000
		await frames(2)
		check(room.player.is_on_floor(), "Player grounded at fight start")
		check(room.boss.health == room.boss.max_health, "Boss starts at full health")
		if kind == 0:
			room.boss.action = "slam"
			room.boss.set_pose("slam", true)
			room.boss.pose_time = 0.12
			room.boss.facing = 1
			var right_hammer_box := room.boss.hammer_head_hitbox()
			room.boss.facing = -1
			var left_hammer_box := room.boss.hammer_head_hitbox()
			var hitbox_edge := (
				BoxArt.HEAVY_HAMMER_HEAD_RADIUS
				* ArenaBoss.HEAVY_VISUAL_SCALE
				* 2
			)
			check(
				is_equal_approx(
					right_hammer_box.get_center().x - room.boss.position.x,
					-(left_hammer_box.get_center().x - room.boss.position.x),
				)
				and is_equal_approx(
					right_hammer_box.get_center().y,
					left_hammer_box.get_center().y,
				)
				and right_hammer_box.size.is_equal_approx(Vector2.ONE * hitbox_edge),
				"Quarry hammer hitbox mirrors with the rendered spiked head",
			)
			room.boss.facing = 1
			room.player.invulnerable = 0
			room.player.health = ArenaConfig.MAX_HEALTH
			room.player.position = right_hammer_box.get_center() + Vector2(0, 35)
			check(room.boss.hammer_hitbox_active(), "Quarry slam enables its hammer hitbox")
			room.boss.resolve_hammer_hit()
			check(
				room.player.health == ArenaConfig.MAX_HEALTH - 1,
				"Quarry hammer head collision damages the player",
			)
			room.restore_time_scale()
			room.player.restore_practice_stats()
			room.player.change_state(ArenaPlayer.State.IDLE)
			room.player.velocity = Vector2.ZERO
			room.player.position = Vector2(290, ArenaConfig.FLOOR_Y)
			room.player.invulnerable = 1000
			room.boss.action = "combo"
			room.boss.event_index = 5
			room.boss.set_pose("attack", true)
			check(
				room.boss.hammer_hitbox_active(),
				"Quarry airborne spin enables its hammer hitbox",
			)
			room.boss.action = ""
			room.boss.set_pose("idle", true)
			check(room.boss.hammer_hitbox_active(), "Quarry hammer remains dangerous while idle")
			room.player.invulnerable = 0
			room.player.health = ArenaConfig.MAX_HEALTH
			room.player.position = (
				room.boss.hammer_head_hitbox().get_center()
				+ Vector2(0, 35)
			)
			room.boss.resolve_hammer_hit()
			check(
				room.player.health == ArenaConfig.MAX_HEALTH - 1,
				"Idle Quarry hammer contact damages the player",
			)
			room.restore_time_scale()
			room.player.restore_practice_stats()
			room.player.change_state(ArenaPlayer.State.IDLE)
			room.player.position = Vector2(290, ArenaConfig.FLOOR_Y)
			room.player.velocity = Vector2.ZERO
			room.player.invulnerable = 1000
			var rock := room.new_hazard(
				"rock",
				room.player.position + Vector2(0, -96),
				room.boss.color(),
			)
			rock.warning = 0
			rock.age = 0.1
			rock.size = Vector2(42, 42)
			room.player.attack_direction = Vector2.UP
			rock.position = (
				room.player.sword_rect().get_center()
				+ Vector2(0, rock.size.y * 0.5)
			)
			room.resolve_sword(room.player, room.player.sword_rect())
			var reflected_y := rock.position.y
			check(
				rock.reflected
				and is_zero_approx(rock.velocity.x)
				and rock.velocity.y == -ArenaHazard.ROCK_REFLECT_SPEED,
				"Upward slash reflects a rock straight upward",
			)
			await frames(3)
			check(
				rock.position.y < reflected_y
				and rock.velocity.y == -ArenaHazard.ROCK_REFLECT_SPEED,
				"Reflected rock keeps flying vertically out of the arena",
			)
		room.spawn_wave(Vector2(640, ArenaConfig.FLOOR_Y), 1, room.boss.color())
		var cleared_hazard := room.hazards.get_child(
			room.hazards.get_child_count() - 1
		) as ArenaHazard
		check(
			is_equal_approx(cleared_hazard.size.y, ArenaConfig.PLAYER_JUMP_HEIGHT * 0.6)
			and cleared_hazard.size.x == ArenaHazard.WAVE_WIDTH
			and is_equal_approx(cleared_hazard.hitbox().size.y, ArenaHazard.WAVE_MAX_HEIGHT),
			"Ground wave and hitbox use 60 percent of a full first jump",
		)
		var shock := ArenaRoom.ShockEffect.new(Vector2.ZERO, room.boss.color(), 185.0)
		check(
			is_equal_approx(shock.height, cleared_hazard.size.y) and shock.radius == 185,
			"Impact shock keeps its horizontal range with the same low wave height",
		)
		room.clear_hazards()
		check(
			not cleared_hazard.active
			and not cleared_hazard.visible
			and not cleared_hazard.is_physics_processing(),
			"Hazard cleanup deactivates immediately",
		)
		Engine.time_scale = 0.8
		room.impact(2, 0.02)
		check(
			is_equal_approx(Engine.time_scale, ArenaConfig.HITSTOP_SCALE),
			"Impact applies configured hitstop scale",
		)
		room.restore_time_scale()
		check(is_equal_approx(Engine.time_scale, 0.8), "Hitstop restores previous time scale")
		Engine.time_scale = 1.0
		await frames(1)
		var phase1: Array = (
			["slam", "wave", "jump"] if kind == 0 else ["thrust", "boomerang", "dive"]
		)
		for attack: String in phase1:
			await verify_attack(room, attack)
		room.boss.take_damage(room.boss.max_health / 2, room.player.position)
		check(room.boss.phase_pending, "Half-health starts phase transition")
		check(not room.boss.take_damage(10, room.player.position), "Transition is invulnerable")
		await frames(180)
		check(room.boss.phase == 2 and not room.boss.phase_pending, "Phase two completes")
		check(game.phase_label.text.contains("II"), "Phase signal refreshes HUD")
		var phase2: Array = (
			["jump", "combo", "rain", "wave"]
			if kind == 0
			else ["thrust", "fan", "dive", "blades"]
		)
		for attack: String in phase2:
			await verify_attack(room, attack)
		if kind == 0:
			check(room.attacks_spawned.wave >= 5, "Hammer generates bilateral waves")
			check(room.attacks_spawned.rock >= 8, "Hammer generates rock rain")
		else:
			check(room.attacks_spawned.blade >= 4, "Prism generates returning and fan blades")
			check(room.attacks_spawned.rock >= 5, "Prism generates falling swords")
		room.boss.cooldown = 1000
		room.boss.action = ""
		room.boss.tree.reset()
		room.boss.set_physics_process(false)
		room.boss.position = Vector2(600, ArenaConfig.FLOOR_Y)
		room.player.position = Vector2(535, ArenaConfig.FLOOR_Y)
		room.player.facing = 1
		room.player.attack_variant = 0
		room.player.hit_targets.clear()
		room.player.energy = 0
		room.player.stats_changed.emit()
		check(game.energy_label.text.ends_with("0 / 9"), "Player stat signal refreshes HUD")
		var hp := room.boss.health
		room.resolve_sword(room.player, room.player.sword_rect())
		room.resolve_sword(room.player, room.player.sword_rect())
		check(room.boss.health == hp - ArenaConfig.SWORD_DAMAGE, "Sword damages once per swing")
		check(
			game.energy_label.text.ends_with("1 / 9")
			and int(game.boss_bar.value) == room.boss.health,
			"Combat signals update HUD without polling",
		)
		room.spawn_spell(Vector2(540, ArenaConfig.FLOOR_Y - 35), 1)
		await frames(45)
		check(
			room.boss.health == hp - ArenaConfig.SWORD_DAMAGE - ArenaConfig.SPELL_DAMAGE,
			"Spell damages boss",
		)
		game.toggle_pause()
		var saved_time := room.elapsed
		var saved_position := room.player.position
		for i in 15:
			await process_frame
		check(
			paused and room.elapsed == saved_time and room.player.position == saved_position,
			"Pause freezes combat",
		)
		game.toggle_pause()
		check(not paused, "Resume unpauses")
		room.boss.take_damage(999, room.player.position)
		await frames(3)
		check(game.result_open and not room.combat_active, "Victory stops combat and opens result")
		check(room.hazards.get_child_count() == 0, "Victory clears hazards")
		game.start_fight(kind)
		await frames(4)
		check(
			not game.result_open and game.room.player.health == ArenaConfig.MAX_HEALTH,
			"Retry resets fight",
		)
		game.room.player.invulnerable = 0
		game.room.player.take_damage(99, Vector2.ZERO)
		await frames(3)
		check(game.result_open and not game.room.combat_active, "Defeat opens result")
		game.show_menu()
		await frames(3)
		check(not is_instance_valid(game.room) and is_instance_valid(game.menu), "Return to menu")
	game.queue_free()
	await frames(3)
	await verify_spell_paths()
	await verify_airborne_transition()
	print("GAMEPLAY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_attack(room: ArenaRoom, attack: String) -> void:
	room.clear_hazards()
	room.boss.position = Vector2(880, ArenaConfig.FLOOR_Y)
	room.boss.velocity = Vector2.ZERO
	room.player.position = Vector2(350, ArenaConfig.FLOOR_Y)
	room.player.velocity = Vector2.ZERO
	room.boss.cooldown = 1000
	room.boss.action = ""
	room.boss.tree.reset()
	await frames(3)
	room.boss.cooldown = 0
	room.boss.begin_attack(attack)
	var ticks := 0
	var combo_ascent_spin_ticks := 0
	var combo_descent_spin_ticks := 0
	var combo_apex_ticks := 0
	var combo_overhead_hold := true
	var combo_hammer_matches_visual := true
	var combo_dive_ticks := 0
	var combo_shock_seen := false
	var combo_target_recorded := false
	var combo_target_stayed_locked := true
	var combo_dive_aimed_at_lock := false
	var combo_locked_target := 0.0
	var highest_boss_y := room.boss.position.y
	var jump_dive_seen := false
	var jump_dive_started_airborne := false
	var jump_dive_monotonic := true
	var jump_last_dive_progress := 0.0
	var jump_air_dive_progress := 0.0
	var jump_landed_in_impact := false
	var was_airborne := false
	var landed := false
	var impact_on_landing := false
	var combo_last_dive_progress := 0.0
	var combo_dive_monotonic := true
	var combo_midair_arc_seen := false
	var waves_before: int = room.attacks_spawned.wave
	var ground_swing_seen := false
	var ground_impact_seen := false
	var ground_settle_seen := false
	var ground_swing_before_impact := true
	while not room.boss.action.is_empty() and ticks < 1100:
		await physics_frame
		ticks += 1
		highest_boss_y = minf(highest_boss_y, room.boss.position.y)
		if room.kind == 0 and attack in ["jump", "combo"]:
			if not room.boss.is_on_floor():
				was_airborne = true
			elif was_airborne and not landed:
				landed = true
				impact_on_landing = (
					room.boss.pose == "impact"
					and room.boss.event_index == (3 if attack == "jump" else 8)
					and is_zero_approx(room.boss.action_time)
				)
		if room.kind == 0 and attack in ["slam", "wave"]:
			if room.boss.pose == "slam":
				ground_swing_seen = true
				ground_swing_before_impact = ground_swing_before_impact and room.boss.event_index == 0
			if room.boss.event_index == 1 and room.boss.pose == "impact":
				ground_impact_seen = true
			ground_settle_seen = ground_settle_seen or room.boss.pose == "settle"
		if room.kind == 0 and attack == "jump":
			if room.boss.event_index == 2:
				var dive_progress := room.boss.visual_progress()
				jump_dive_seen = true
				jump_dive_started_airborne = (
					jump_dive_started_airborne or not room.boss.is_on_floor()
				)
				jump_dive_monotonic = (
					jump_dive_monotonic
					and dive_progress + 0.001 >= jump_last_dive_progress
				)
				jump_last_dive_progress = dive_progress
				if not room.boss.is_on_floor():
					jump_air_dive_progress = maxf(jump_air_dive_progress, dive_progress)
			elif room.boss.event_index == 3:
				jump_landed_in_impact = (
					jump_landed_in_impact or room.boss.pose == "impact"
				)
		if attack == "combo":
			if room.boss.event_index == 5:
				if not combo_target_recorded:
					combo_target_recorded = true
					combo_locked_target = room.boss.target_x
					room.player.position.x = 1180 if combo_locked_target < 640 else 100
				else:
					combo_target_stayed_locked = (
						combo_target_stayed_locked
						and is_equal_approx(room.boss.target_x, combo_locked_target)
					)
				if room.boss.velocity.y < 0:
					combo_ascent_spin_ticks += 1
				else:
					combo_descent_spin_ticks += 1
			elif room.boss.event_index == 6:
				combo_apex_ticks += 1
				var visual := room.boss.visual
				var rig := BoxArt.heavy_rig_snapshot(
					visual.pose, visual.animation_progress,
					visual.animation_clock, visual.squash, visual.variant,
				)
				combo_overhead_hold = combo_overhead_hold and (
					visual.variant == 1 and rig.hammer_center.y < rig.head_center.y - 60
				)
				var expected_head: Vector2 = (
					room.boss.position + visual.position
					+ rig.hammer_center * Vector2(room.boss.facing, 1) * ArenaBoss.HEAVY_VISUAL_SCALE
				)
				combo_hammer_matches_visual = combo_hammer_matches_visual and (
					room.boss.hammer_head_center().is_equal_approx(expected_head)
				)
				combo_target_stayed_locked = (
					combo_target_stayed_locked
					and is_equal_approx(room.boss.target_x, combo_locked_target)
				)
			elif room.boss.event_index == 7:
				combo_dive_ticks += 1
				var progress := room.boss.visual_progress()
				combo_dive_monotonic = combo_dive_monotonic and progress >= combo_last_dive_progress
				combo_midair_arc_seen = combo_midair_arc_seen or (progress > 0.25 and progress < 0.75)
				combo_last_dive_progress = progress
				combo_target_stayed_locked = (
					combo_target_stayed_locked
					and is_equal_approx(room.boss.target_x, combo_locked_target)
				)
				var locked_direction := signf(combo_locked_target - room.boss.position.x)
				combo_dive_aimed_at_lock = (
					combo_dive_aimed_at_lock
					or is_zero_approx(locked_direction)
					or signf(room.boss.velocity.x) == locked_direction
				)
			combo_shock_seen = combo_shock_seen or not room.shocks.is_empty()
	check(ticks < 1100, "Attack completes: %d / %s" % [room.kind, attack])
	check(room.boss.position.y <= ArenaConfig.FLOOR_Y + 1, "Boss stays above floor: " + attack)
	if room.kind == 0 and attack in ["slam", "wave"]:
		check(ground_swing_seen and ground_swing_before_impact and ground_impact_seen, "Quarry swings down before ground impact is emitted: " + attack)
		check(ground_settle_seen, "Quarry lifts its hammer through a recovery pose: " + attack)
	if room.kind == 0 and attack == "jump":
		var minimum_jump_height := 190.0 if room.boss.phase == 1 else 230.0
		check(
			ArenaConfig.FLOOR_Y - highest_boss_y >= minimum_jump_height,
			"Quarry phase %d jump slam reaches its raised apex" % room.boss.phase,
		)
		check(
			jump_dive_seen
			and jump_dive_started_airborne
			and jump_dive_monotonic
			and jump_air_dive_progress >= 0.75
			and jump_landed_in_impact,
			"Quarry completes its downward hammer arc exactly as the jump lands",
		)
	if room.kind == 0 and attack in ["jump", "combo"]:
		check(landed and impact_on_landing, "Quarry resolves impact on the first grounded frame: " + attack)
	if attack == "combo":
		check(
			ArenaConfig.FLOOR_Y - highest_boss_y >= 220.0,
			"Quarry combo reaches its raised apex",
		)
		check(
			combo_ascent_spin_ticks >= 35 and combo_descent_spin_ticks == 0,
			"Quarry spins only while ascending",
		)
		check(combo_apex_ticks >= 20, "Quarry holds the raised hammer at the apex")
		check(combo_overhead_hold and combo_hammer_matches_visual, "Live combo samples the overhead pose for both rendering and hammer collision")
		check(
			combo_target_recorded
			and combo_target_stayed_locked
			and combo_dive_aimed_at_lock,
			"Quarry dive stays aimed at the player's launch-time position",
		)
		check(
			combo_dive_ticks >= 8 and combo_dive_ticks <= 30,
			"Quarry uses a distinct fast non-spinning descent",
		)
		check(
			combo_dive_monotonic and combo_midair_arc_seen and combo_last_dive_progress > 0.8,
			"Combo hammer follows actual descent distance through the entire downward arc",
		)
		check(
			combo_shock_seen
			and room.attacks_spawned.wave - waves_before == 2,
			"Quarry finisher creates a red shock effect and two ground waves",
		)
	room.boss.cooldown = 1000

func verify_spell_paths() -> void:
	var room := ArenaRoom.new()
	root.add_child(room)
	room.set_process(false)
	room.player.set_physics_process(false)
	room.boss.set_physics_process(false)
	room.boss.phase = 2
	room.boss.position = Vector2(640, ArenaConfig.FLOOR_Y)
	for direction in [-1.0, 1.0]:
		room.boss.health = room.boss.max_health
		var start := Vector2(640 - direction * 220, ArenaConfig.FLOOR_Y - 35)
		room.spawn_spell(start, direction)
		var spell := room.hazards.get_child(-1) as ArenaHazard
		spell.velocity.x = direction * 4000
		spell._physics_process(0.12)
		check(
			not spell.active and room.boss.health == room.boss.max_health - ArenaConfig.SPELL_DAMAGE,
			"Fast spell hits a crossed target in direction %.0f" % direction,
		)
		spell._physics_process(0.12)
		check(
			room.boss.health == room.boss.max_health - ArenaConfig.SPELL_DAMAGE,
			"A consumed spell cannot damage twice",
		)
		room.restore_time_scale()
		room.spawn_spell(Vector2(640, ArenaConfig.FLOOR_Y - 35), direction)
		spell = room.hazards.get_child(-1) as ArenaHazard
		spell._physics_process(0.12)
		check(
			not spell.active and room.boss.health == room.boss.max_health - ArenaConfig.SPELL_DAMAGE * 2,
			"Spell spawned overlapping a boss still lands before leaving the target",
		)
		room.restore_time_scale()
	room.boss.phase_pending = true
	var health := room.boss.health
	var pulse_count := room.spell_pulses.size()
	room.spawn_spell(Vector2(600, ArenaConfig.FLOOR_Y - 35), 1)
	var blocked := room.hazards.get_child(-1) as ArenaHazard
	blocked._physics_process(0.06)
	check(
		not blocked.active and room.boss.health == health
		and room.spell_pulses.size() == pulse_count + 2 and room.hitstop == 0,
		"Phase shield consumes a spell with visible feedback and no damage or hitstop",
	)
	room.boss.phase_pending = false
	for direction in [-1.0, 1.0]:
		room.spawn_spell(Vector2(640, 200), direction)
		var missed := room.hazards.get_child(-1) as ArenaHazard
		missed._physics_process(0.80)
		check(
			not missed.active and room.boss.health == health,
			"A vertically missed spell dissipates at the arena wall",
		)
	room.boss.health = ArenaConfig.SPELL_DAMAGE
	Engine.time_scale = 0.8
	room.spawn_spell(Vector2(600, ArenaConfig.FLOOR_Y - 35), 1)
	var lethal := room.hazards.get_child(-1) as ArenaHazard
	lethal._physics_process(0.06)
	check(
		room.boss.dead and not room.combat_active and not room.owns_time_scale
		and is_equal_approx(Engine.time_scale, 0.8),
		"Lethal spell feedback cannot reactivate hitstop after victory",
	)
	Engine.time_scale = 1.0
	room.queue_free()
	await frames(2)

func verify_airborne_transition() -> void:
	for attack in ["jump", "combo"]:
		var room := ArenaRoom.new()
		root.add_child(room)
		room.player.controlled = false
		room.player.invulnerable = 1000
		room.boss.cooldown = 1000
		await frames(4)
		room.boss.cooldown = 0
		room.boss.begin_attack(attack)
		var ticks := 0
		var ascent_event := 1 if attack == "jump" else 5
		while (room.boss.event_index != ascent_event or room.boss.is_on_floor()) and ticks < 500:
			await physics_frame
			ticks += 1
		check(ticks < 500, "Transition scenario reaches ascent: " + attack)
		room.boss.take_damage(room.boss.max_health / 2, room.player.position)
		var locked_target := room.boss.target_x
		room.player.position.x = 1100
		var stayed_committed := true
		var landing_seen := false
		ticks = 0
		while room.boss.phase == 1 and ticks < 500:
			await physics_frame
			ticks += 1
			if not room.boss.action.is_empty():
				stayed_committed = stayed_committed and (
					room.boss.action == attack
					and is_equal_approx(room.boss.target_x, locked_target)
					and room.boss.phase_time == 0
				)
			landing_seen = landing_seen or (
				room.boss.is_on_floor() and room.boss.pose == "impact"
			)
		check(
			stayed_committed and landing_seen and room.boss.phase == 2
			and room.boss.is_on_floor(),
			"Half-health waits for committed landing/recovery before transitioning: " + attack,
		)
		await frames(180)
		check(not room.boss.phase_pending, "Deferred phase transition completes: " + attack)
		room.queue_free()
		await frames(2)
