extends SceneTree

class TestArena extends Node2D:
	var combat_active := true
	var spells := 0
	func resolve_sword(_player: Node, _rect: Rect2) -> void: pass
	func burst(_p: Vector2, _c: Color, _n: int) -> void: pass
	func sound(_key: String) -> void: pass
	func notify(_message: String) -> void: pass
	func impact(_power: float, _duration: float) -> void: pass
	func spawn_spell(_p: Vector2, _facing: float) -> void: spells += 1

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

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
	await physics_frame
	for i in 10:
		player.step(1.0 / 120, {})
	check(player.is_on_floor(), "Player lands on arena floor")
	player.step(1.0 / 120, {"jump": true})
	check(player.velocity.y < -600 and player.jumps_used == 1, "Ground jump")
	player.step(1.0 / 120, {"jump": true})
	check(player.jumps_used == 2, "Double jump")
	var before := player.velocity.y
	player.step(1.0 / 120, {"jump": true})
	check(player.jumps_used == 2 and player.velocity.y > before, "No third jump")
	player.step(1.0 / 120, {"attack": true, "down": true})
	check(player.attack_direction == Vector2.DOWN, "Air down slash")
	check(player.register_hit(123), "First sword hit registers")
	check(not player.register_hit(123) and player.energy == 1, "One energy per target per swing")
	check(player.velocity.y == -540 and player.jumps_used == 1, "Pogo restores air jump")
	player.change_state(ArenaPlayer.State.IDLE)
	player.energy = 2
	check(not player.cast_spell() and arena.spells == 0, "Insufficient energy blocks spell")
	player.energy = 3
	check(player.cast_spell() and arena.spells == 1 and player.energy == 0, "Spell costs exactly three")
	check(player.take_damage(1, Vector2.ZERO), "Damage received")
	check(not player.take_damage(1, Vector2.ZERO), "Invulnerability blocks repeat damage")
	check(player.health == 5 and player.state == ArenaPlayer.State.HURT, "Hurt state and health")
	player.invulnerable = 0
	player.position = Vector2(400, ArenaConfig.FLOOR_Y - 1)
	player.velocity = Vector2.ZERO
	player.jump_buffer = 0
	player.change_state(ArenaPlayer.State.AIR)
	player.step(1.0 / 120, {"focus_release": true})
	player.energy = 6
	for i in 20:
		player.step(1.0 / 120, {})
	for i in 185:
		player.step(1.0 / 120, {"focus": true})
	check(player.health == 6 and player.energy == 3, "Holding A heals one health for three energy")
	for i in 200:
		player.step(1.0 / 120, {"focus": true})
	check(player.energy == 3, "One heal per press")
	player.step(1.0 / 120, {"focus_release": true})
	check(arena.spells == 1, "Healing release does not cast")
	player.invulnerable = 0
	player.take_damage(99, Vector2.ZERO)
	check(player.state == ArenaPlayer.State.DEAD and player.health == 0, "Death state clamps health")
	print("PLAYER TESTS: %s checks, %s failures" % [checks, failures])
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
