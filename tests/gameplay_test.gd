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
		ArenaBoss.COMBO_APEX_HOLD >= 0.2
		and ArenaBoss.COMBO_DIVE_SPEED > absf(ArenaBoss.COMBO_LAUNCH_SPEED),
		"Quarry holds the overhead warning at the apex before a faster dive",
	)
	var quarry_idle: Dictionary = BoxArt.heavy_rig_snapshot("idle", 0.0)
	var quarry_windup: Dictionary = BoxArt.heavy_rig_snapshot("windup", 1.0)
	var quarry_impact: Dictionary = BoxArt.heavy_rig_snapshot("slam", 1.0)
	var quarry_recover_start: Dictionary = BoxArt.heavy_rig_snapshot("recover", 0.0)
	var quarry_recover_end: Dictionary = BoxArt.heavy_rig_snapshot("recover", 1.0)
	var quarry_spin_start: Dictionary = BoxArt.heavy_rig_snapshot("attack", 0.0)
	var quarry_spin_end: Dictionary = BoxArt.heavy_rig_snapshot("attack", 1.0)
	check(
		quarry_idle.left_grip.x > quarry_idle.right_grip.x
		and quarry_idle.hammer_center.x < quarry_idle.right_grip.x
		and quarry_idle.hammer_center.y < quarry_idle.right_grip.y,
		"Quarry idle keeps the left hand on the forward handle end and hammer behind the head",
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
		quarry_windup.hammer_center.y < quarry_idle.hammer_center.y,
		"Quarry windup raises the hammer above its idle position",
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
		and quarry_spin_start.hammer_center.is_equal_approx(quarry_spin_end.hammer_center),
		"Quarry combo transitions preserve hammer continuity at impact, raise, and apex",
	)
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
		first_slash_start.hand.x < first_slash_finish.hand.x
		and first_slash_start.hand.y < first_slash_finish.hand.y
		and second_slash_start.hand.x > second_slash_finish.hand.x
		and second_slash_start.hand.y < second_slash_finish.hand.y,
		"Player alternates two broad top-to-bottom diagonal sword paths",
	)
	for variant in 2:
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
			cleared_hazard.size.y > ArenaConfig.PLAYER_HEIGHT
				and cleared_hazard.size.x == ArenaHazard.WAVE_WIDTH
				and cleared_hazard.size.x > cleared_hazard.size.y,
				"Ground wave is slightly wider than its player-tall height",
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
	var combo_dive_ticks := 0
	var combo_shock_seen := false
	var combo_target_recorded := false
	var combo_target_stayed_locked := true
	var combo_dive_aimed_at_lock := false
	var combo_locked_target := 0.0
	var waves_before: int = room.attacks_spawned.wave
	while not room.boss.action.is_empty() and ticks < 1100:
		await physics_frame
		ticks += 1
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
				combo_target_stayed_locked = (
					combo_target_stayed_locked
					and is_equal_approx(room.boss.target_x, combo_locked_target)
				)
			elif room.boss.event_index == 7:
				combo_dive_ticks += 1
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
	if attack == "combo":
		check(
			combo_ascent_spin_ticks >= 35 and combo_descent_spin_ticks == 0,
			"Quarry spins only while ascending",
		)
		check(combo_apex_ticks >= 20, "Quarry holds the raised hammer at the apex")
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
			combo_shock_seen
			and room.attacks_spawned.wave - waves_before == 2,
			"Quarry finisher creates a red shock effect and two ground waves",
		)
	room.boss.cooldown = 1000
