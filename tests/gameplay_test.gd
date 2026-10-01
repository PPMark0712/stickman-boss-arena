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
		room.player.invulnerable = 1000
		check(room.player.is_on_floor(), "Player grounded at fight start")
		check(room.boss.health == room.boss.max_health, "Boss starts at full health")
		room.spawn_wave(Vector2(640, ArenaConfig.FLOOR_Y), 1, room.boss.color())
		var cleared_hazard := room.hazards.get_child(
			room.hazards.get_child_count() - 1
		) as ArenaHazard
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
		room.player.attack_direction = Vector2.RIGHT
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
	while not room.boss.action.is_empty() and ticks < 1100:
		await physics_frame
		ticks += 1
	check(ticks < 1100, "Attack completes: %d / %s" % [room.kind, attack])
	check(room.boss.position.y <= ArenaConfig.FLOOR_Y + 1, "Boss stays above floor: " + attack)
	room.boss.cooldown = 1000
