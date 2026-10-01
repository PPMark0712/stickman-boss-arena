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
		and player.combo_step == 0
		and not player.attack_is_air,
		"Ground attack starts on input",
	)
	for i in 8:
		player.step(1.0 / 120, idle)
	player.step(1.0 / 120, controls({"attack": true}))
	check(player.attack_queued, "Attack input buffers during a swing")
	var combo_ticks := 0
	while player.combo_step == 0 and combo_ticks < 40:
		player.step(1.0 / 120, idle)
		combo_ticks += 1
	check(
		player.state == ArenaPlayer.State.ATTACK and player.combo_step == 1,
		"Buffered input chains next attack (state=%d combo=%d air=%s queued=%s ticks=%d)" % [
			player.state, player.combo_step, player.attack_is_air, player.attack_queued, combo_ticks
		],
	)
	check(arena.slashes >= 1, "Attack active frame emits slash feedback")
	player.combo_step = 2
	player.attack_is_air = false
	player.attack_direction = Vector2.RIGHT
	check(player.sword_rect().size.x == 122, "Combo finisher has extended reach")
	player.change_state(ArenaPlayer.State.IDLE)
	player.combo_step = 0
	player.combo_grace = 0
	player.attack_buffer = 0
	player.attack_queued = false
	player.velocity = Vector2.ZERO
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.velocity.y < -600 and player.jumps_used == 1, "Ground jump")
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.jumps_used == 2, "Double jump")
	var before := player.velocity.y
	player.step(1.0 / 120, controls({"jump": true}))
	check(player.jumps_used == 2 and player.velocity.y > before, "No third jump")
	player.step(1.0 / 120, controls({"attack": true, "down": true}))
	check(player.attack_direction == Vector2.DOWN, "Air down slash")
	check(player.register_hit(123), "First sword hit registers")
	check(not player.register_hit(123) and player.energy == 1, "One energy per target per swing")
	check(player.velocity.y == -610 and player.jumps_used == 1, "Pogo restores air jump")
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
	check(player.take_damage(1, Vector2.ZERO), "Damage received")
	check(not player.take_damage(1, Vector2.ZERO), "Invulnerability blocks repeat damage")
	check(player.health == 5 and player.state == ArenaPlayer.State.HURT, "Hurt state and health")
	player.invulnerable = 0
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2.ZERO
	player.jump_buffer = 0
	player.change_state(ArenaPlayer.State.AIR)
	player.step(1.0 / 120, controls({"focus_release": true}))
	player.energy = 6
	for i in 20:
		player.step(1.0 / 120, idle)
	var focus_held := controls({"focus": true})
	for i in 185:
		player.step(1.0 / 120, focus_held)
	check(player.health == 6 and player.energy == 3, "Holding A heals one health for three energy")
	for i in 200:
		player.step(1.0 / 120, focus_held)
	check(player.energy == 3, "One heal per press")
	player.step(1.0 / 120, controls({"focus_release": true}))
	check(arena.spells == 1, "Healing release does not cast")
	player.invulnerable = 0
	player.take_damage(99, Vector2.ZERO)
	check(player.state == ArenaPlayer.State.DEAD and player.health == 0, "Death state clamps health")
	print("PLAYER TESTS: %s checks, %s failures" % [checks, failures])
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
