extends SceneTree

class TestArena extends Node2D:
	var combat_active := true
	var spells := 0
	var slashes := 0
	func resolve_sword(_player: Node, _rect: Rect2) -> void: pass
	func burst(_p: Vector2, _c: Color, _n: int) -> void: pass
	func sound(_key: String) -> void: pass
	func notify(_message: String) -> void: pass
	func impact(_power: float, _duration: float) -> void: pass
	func spawn_spell(_p: Vector2, _facing: float) -> void: spells += 1
	func show_slash(_p: Vector2, _direction: Vector2, _combo: int) -> void: slashes += 1

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func controls(values: Dictionary = {}) -> ArenaPlayer.Controls:
	var frame := ArenaPlayer.Controls.new()
	frame.axis = values.get("axis", 0.0)
	frame.jump = values.get("jump", false)
	frame.jump_release = values.get("jump_release", false)
	frame.attack = values.get("attack", false)
	frame.up = values.get("up", false)
	frame.down = values.get("down", false)
	frame.dash = values.get("dash", false)
	frame.focus = values.get("focus", false)
	frame.focus_release = values.get("focus_release", false)
	return frame

func run() -> void:
	var arena := TestArena.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1280, 80)
	collider.shape = shape
	floor_body.position = Vector2(640, ArenaConfig.FLOOR_Y + 40)
	floor_body.add_child(collider)
	arena.add_child(floor_body)
	var player := ArenaPlayer.new()
	player.arena = arena
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 2)
	arena.add_child(player)
	player.set_physics_process(false)
	var idle := controls()
	await physics_frame
	for i in 10:
		player.step(1.0 / 120, idle)
	check(player.is_on_floor(), "Player lands on arena floor")
	var stats_events := [0]
	player.stats_changed.connect(func() -> void: stats_events[0] += 1)
	player.change_state(ArenaPlayer.State.AIR)
	player.change_state(ArenaPlayer.State.IDLE)
	check(stats_events[0] == 0, "State transitions do not emit stat updates")
	player.step(1.0 / 120, controls({"attack": true}))
	check(
		player.state == ArenaPlayer.State.ATTACK
		and player.attack_variant == 0
		and player.velocity.x == 0
		and player.attack_movement_locked,
		"Attack starts without forward movement",
	)
	player.step(1.0 / 120, controls({"axis": 1.0}))
	check(player.velocity.x == 0, "A stationary attack locks movement until the swing ends")
	var first_rect := player.sword_rect()
	for i in 8:
		player.step(1.0 / 120, idle)
	player.step(1.0 / 120, controls({"attack": true}))
	check(player.attack_queued, "Attack input buffers during a swing")
	var attack_ticks := 0
	while player.attack_variant == 0 and attack_ticks < 40:
		player.step(1.0 / 120, idle)
		attack_ticks += 1
	check(
		player.state == ArenaPlayer.State.ATTACK and player.attack_variant == 1,
		"Buffered input starts the mirrored swing (state=%d variant=%d ticks=%d)" % [
			player.state, player.attack_variant, attack_ticks
		],
	)
	check(player.sword_rect() == first_rect, "Alternating swings use identical hitboxes")
	check(arena.slashes >= 1, "Attack active frame emits slash feedback")
	for i in 40:
		player.step(1.0 / 120, idle)
	check(player.state == ArenaPlayer.State.IDLE, "Repeated attack has no combo continuation")
	player.attack_buffer = 0
	player.attack_queued = false
	player.velocity = Vector2.ZERO
	player.step(1.0 / 120, controls({"axis": 1.0}))
	check(
		player.velocity.x == ArenaConfig.RUN_SPEED,
		"Horizontal input reaches full speed immediately",
	)
	player.step(1.0 / 120, controls({"axis": -1.0}))
	check(player.velocity.x == -ArenaConfig.RUN_SPEED, "Horizontal reversal is immediate")
	player.step(1.0 / 120, idle)
	check(player.velocity.x == 0, "Horizontal release stops immediately")
	player.step(1.0 / 120, controls({"axis": 1.0, "attack": true}))
	check(
		player.state == ArenaPlayer.State.ATTACK
		and not player.attack_movement_locked
		and player.velocity.x == ArenaConfig.RUN_SPEED,
		"Attacking while moving preserves horizontal speed",
	)
	player.step(1.0 / 120, controls({"axis": -1.0}))
	check(
		player.velocity.x == -ArenaConfig.RUN_SPEED and player.facing < 0,
		"A moving attack continues responding to horizontal direction",
	)
	for i in 45:
		player.step(1.0 / 120, idle)
	check(player.state == ArenaPlayer.State.IDLE, "Moving attack returns to idle normally")
	player.step(1.0 / 120, controls({"up": true, "attack": true}))
	check(
		player.state == ArenaPlayer.State.ATTACK
		and player.attack_direction == Vector2.UP
		and player.is_on_floor(),
		"Up plus X starts an upward slash from the ground",
	)
	player.change_state(ArenaPlayer.State.IDLE)
	player.attack_buffer = 0
	player.attack_queued = false
	player.facing = 1
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.velocity.y < -600 and player.jumps_used == 1, "Ground jump")
	var held_jump_speed := player.velocity.y
	player.step(1.0 / 120, controls({"jump_release": true}))
	check(player.velocity.y > held_jump_speed * 0.6, "Jump release produces a shorter jump")
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.jumps_used == 2, "Double jump")
	var before := player.velocity.y
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.jumps_used == 2 and player.velocity.y > before, "No third jump")
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2(0, 80)
	player.change_state(ArenaPlayer.State.IDLE)
	for i in 3:
		player.step(1.0 / 120, idle)
	player.step(1.0 / 120, controls({"jump": true}))
	var single_jump_apex := player.position.y
	for i in 140:
		player.step(1.0 / 120, idle)
		single_jump_apex = minf(single_jump_apex, player.position.y)
	check(
		ArenaConfig.FLOOR_Y - single_jump_apex <= ArenaConfig.PLAYER_MAX_JUMP_HEIGHT,
		"Single jump stays below the configured 1.8-body ceiling",
	)
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2(0, 80)
	player.change_state(ArenaPlayer.State.IDLE)
	for i in 3:
		player.step(1.0 / 120, idle)
	player.step(1.0 / 120, controls({"jump": true}))
	var double_jump_apex := player.position.y
	for i in 140:
		var jump_again := controls({"jump": true}) if i == 20 else idle
		player.step(1.0 / 120, jump_again)
		double_jump_apex = minf(double_jump_apex, player.position.y)
	check(
		is_equal_approx(
			ArenaConfig.FLOOR_Y - double_jump_apex,
			ArenaConfig.PLAYER_MAX_JUMP_HEIGHT,
		),
		"Double jump reaches but does not exceed the 1.8-body ceiling",
	)
	player.step(1.0 / 120, controls({"axis": 1.0, "attack": true}))
	check(
		player.state == ArenaPlayer.State.ATTACK
		and player.velocity.x == ArenaConfig.RUN_SPEED
		and player.sword_rect().size.x == ArenaConfig.ATTACK_REACH
		and ArenaConfig.ATTACK_REACH > 126
		and player.sword_rect().size.y == ArenaConfig.ATTACK_HEIGHT,
		"Air attack preserves movement and uses the enlarged horizontal hitbox",
	)
	check(player.register_hit(123), "First sword hit registers")
	check(not player.register_hit(123) and player.energy == 1, "One energy per target per swing")
	check(
		player.velocity.x == -ArenaConfig.ATTACK_HIT_RECOIL,
		"Sword hit applies a small backward recoil",
	)
	player.change_state(ArenaPlayer.State.AIR)
	player.position.y -= 100
	player.velocity = Vector2(0, -120)
	player.attack_buffer = 0
	player.step(1.0 / 120, idle)
	player.velocity.y = -120
	player.step(1.0 / 120, controls({"axis": 1.0, "up": true, "attack": true}))
	check(
		player.attack_direction == Vector2.UP
		and player.velocity.x == ArenaConfig.RUN_SPEED
		and is_equal_approx(
			player.velocity.y,
			-120.0 + ArenaConfig.PLAYER_GRAVITY / 120.0,
		)
		and player.sword_rect().position.y < player.position.y - 100,
		"Aerial upward slash preserves horizontal input and vertical momentum",
	)
	player.step(1.0 / 120, controls({"axis": -1.0}))
	check(
		player.velocity.x == -ArenaConfig.RUN_SPEED,
		"Aerial directional slash continues responding to horizontal input",
	)
	player.change_state(ArenaPlayer.State.AIR)
	player.attack_buffer = 0
	player.velocity = Vector2(0, -80)
	player.step(1.0 / 120, controls({"axis": -0.5, "down": true, "attack": true}))
	check(
		player.attack_direction == Vector2.DOWN
		and player.velocity.x == -ArenaConfig.RUN_SPEED * 0.5
		and player.sword_rect().size.x == ArenaConfig.VERTICAL_ATTACK_WIDTH
		and player.sword_rect().size.x > player.hurtbox().size.x
		and player.sword_rect().position.y > player.position.y - 30,
		"Aerial downward slash preserves movement and uses the wider hitbox",
	)
	check(
		player.register_hit(456)
		and player.velocity.y == -ArenaConfig.DOWN_SLASH_BOUNCE
		and player.jumps_used == 1,
		"Downward slash hit rebounds and restores one aerial jump",
	)
	player.change_state(ArenaPlayer.State.IDLE)
	player.energy = 2
	check(not player.cast_spell() and arena.spells == 0, "Insufficient energy blocks spell")
	player.energy = 3
	check(
		player.cast_spell() and arena.spells == 1 and player.energy == 0,
		"Spell costs exactly three",
	)
	var events_before_restore: int = stats_events[0]
	player.restore_practice_stats()
	check(
		player.health == ArenaConfig.MAX_HEALTH
		and player.energy == ArenaConfig.MAX_ENERGY
		and stats_events[0] == events_before_restore + 1,
		"Practice refill emits one stat update",
	)
	player.restore_practice_stats()
	check(stats_events[0] == events_before_restore + 1, "Full practice stats do not emit again")
	player.change_state(ArenaPlayer.State.IDLE)
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2.ZERO
	player.invulnerable = 0
	player.dash_cooldown = 0
	player.facing = 1
	player.step(1.0 / 120, controls({"dash": true}))
	check(
		player.state == ArenaPlayer.State.DASH
		and player.velocity.x == ArenaConfig.DASH_SPEED,
		"C starts a forward dash",
	)
	check(player.take_damage(1, Vector2(800, ArenaConfig.FLOOR_Y)), "Dash collision receives damage")
	check(not player.take_damage(1, Vector2.ZERO), "Invulnerability blocks repeat damage")
	check(
		player.health == 5 and player.state == ArenaPlayer.State.HURT,
		"Damage interrupts dash into hurt state",
	)
	player.invulnerable = 0
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2.ZERO
	player.jump_buffer = 0
	player.change_state(ArenaPlayer.State.IDLE)
	player.step(1.0 / 120, controls({"focus_release": true}))
	for i in 3:
		player.step(1.0 / 120, idle)
	var focus_held := controls({"focus": true})
	player.energy = 6
	var spells_before_tap: int = arena.spells
	for i in 10:
		player.step(1.0 / 120, focus_held)
	player.step(1.0 / 120, controls({"focus_release": true}))
	check(
		arena.spells == spells_before_tap + 1 and player.energy == 3,
		"Releasing A within 0.1 seconds casts a spell",
	)
	for i in 35:
		player.step(1.0 / 120, idle)
	var spells_before_dead_zone: int = arena.spells
	for i in 18:
		player.step(1.0 / 120, focus_held)
	player.step(1.0 / 120, controls({"focus_release": true}))
	check(
		arena.spells == spells_before_dead_zone and player.energy == 3,
		"Releasing A between 0.1 and 0.3 seconds does nothing",
	)
	player.health = 4
	player.energy = 6
	player.focus_cancelled = true
	player.focus_active = false
	for i in 37:
		player.step(1.0 / 120, focus_held)
	check(
		player.state == ArenaPlayer.State.HEAL
		and player.focus_energy_spent == 0
		and player.energy == 6,
		"A fresh first hold clears stale cancellation and starts healing at 0.3 seconds",
	)
	for i in 40:
		player.step(1.0 / 120, focus_held)
	check(
		player.focus_energy_spent == 1 and player.energy == 5,
		"Healing consumes its first energy after one third of the channel",
	)
	for i in 40:
		player.step(1.0 / 120, focus_held)
	check(
		player.focus_energy_spent == 2 and player.energy == 4,
		"Healing consumes one energy per channel third",
	)
	player.step(1.0 / 120, controls({"focus_release": true}))
	check(
		player.state == ArenaPlayer.State.IDLE
		and player.health == 4
		and player.energy == 4,
		"Releasing an incomplete heal cancels without refunding energy",
	)
	player.health = 4
	player.energy = 6
	for i in 157:
		player.step(1.0 / 120, focus_held)
	check(
		player.health == 5
		and player.energy == 3
		and player.focus_consumed
		and player.state == ArenaPlayer.State.HEAL
		and not player.focus_cancelled,
		"Holding A for 1.3 seconds heals once and starts the next cycle",
	)
	for i in 157:
		player.step(1.0 / 120, focus_held)
	check(
		player.health == 6
		and player.energy == 0
		and player.state == ArenaPlayer.State.IDLE
		and player.focus_cancelled,
		"An uninterrupted hold repeats until health is full or energy is insufficient",
	)
	for i in 60:
		player.step(1.0 / 120, focus_held)
	check(player.health == 6 and player.energy == 0, "A stopped heal waits for A to be released")
	player.step(1.0 / 120, controls({"focus_release": true}))
	check(arena.spells == spells_before_dead_zone, "Healing release does not cast")
	player.health = 3
	player.energy = 4
	for i in 157:
		player.step(1.0 / 120, focus_held)
	check(
		player.health == 4
		and player.energy == 1
		and player.state == ArenaPlayer.State.IDLE
		and player.focus_cancelled,
		"A repeating heal stops before a new cycle when fewer than three energy remain",
	)
	player.step(1.0 / 120, controls({"focus_release": true}))
	player.invulnerable = 0
	check(player.take_damage(1, Vector2.ZERO), "Damage prepares an interrupted heal case")
	for i in 40:
		player.step(1.0 / 120, idle)
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2.ZERO
	player.change_state(ArenaPlayer.State.IDLE)
	player.invulnerable = 0
	player.health = 4
	player.energy = 3
	for i in 85:
		player.step(1.0 / 120, focus_held)
	check(
		player.state == ArenaPlayer.State.HEAL and player.energy == 2,
		"Heal spends energy before interruption",
	)
	check(player.take_damage(1, Vector2.ZERO), "Damage interrupts healing")
	check(
		player.state == ArenaPlayer.State.HURT and player.energy == 2,
		"Interrupted healing does not refund consumed energy",
	)
	for i in 50:
		player.step(1.0 / 120, focus_held)
	check(
		player.health == 3
		and player.energy == 2
		and player.focus_cancelled,
		"Holding A after damage cannot silently restart an interrupted heal",
	)
	player.step(1.0 / 120, controls({"focus_release": true}))
	player.invulnerable = 0
	player.take_damage(99, Vector2.ZERO)
	check(player.state == ArenaPlayer.State.DEAD and player.health == 0, "Death state clamps health")
	print("PLAYER TESTS: %s checks, %s failures" % [checks, failures])
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
