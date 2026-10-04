class_name ArenaRoom
extends Node2D

signal finished(won: bool, elapsed: float)
signal message(text: String, duration: float)

class ParticleEffect extends RefCounted:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var size: float
	var color: Color

	func _init(
		at_position: Vector2,
		initial_velocity: Vector2,
		duration: float,
		edge: float,
		tint: Color,
	) -> void:
		position = at_position
		velocity = initial_velocity
		life = duration
		size = edge
		color = tint

class SlamEffect extends RefCounted:
	var rect: Rect2
	var color: Color
	var life := 0.18

	func _init(area: Rect2, tint: Color) -> void:
		rect = area
		color = tint

class ShockEffect extends RefCounted:
	var position: Vector2
	var color: Color
	var radius: float
	var life := 0.34
	var max_life := 0.34

	func _init(origin: Vector2, tint: Color, max_radius: float) -> void:
		position = origin
		color = tint
		radius = max_radius

class SlashEffect extends RefCounted:
	var position: Vector2
	var direction: Vector2
	var variant: int
	var color: Color
	var life: float
	var max_life: float

	func _init(
		origin: Vector2,
		heading: Vector2,
		swing_variant: int,
		tint: Color,
		duration: float,
	) -> void:
		position = origin
		direction = heading.normalized()
		variant = swing_variant
		color = tint
		life = duration
		max_life = duration

class MotionEcho extends RefCounted:
	var origin := Vector2.ZERO
	var facing := 1.0
	var rig: Dictionary = {}
	var life := 0.13

class ContactSpark extends RefCounted:
	var origin := Vector2.ZERO
	var direction := Vector2.RIGHT
	var life := 0.13

class HammerTrace extends RefCounted:
	var point := Vector2.ZERO
	var life := 0.12

var kind := 0
var practice := false
var player: ArenaPlayer
var boss: ArenaBoss
var combat_active := true
var elapsed := 0.0
var particles: Array[ParticleEffect] = []
var slams: Array[SlamEffect] = []
var shocks: Array[ShockEffect] = []
var slashes: Array[SlashEffect] = []
var echoes: Array[MotionEcho] = []
var sparks: Array[ContactSpark] = []
var hammer_traces: Array[HammerTrace] = []
var echo_timer := 0.0
var feedback_clock := 0.0
var shake := 0.0
var hitstop := 0.0
var previous_time_scale := 1.0
var owns_time_scale := false
var rng := RandomNumberGenerator.new()
var backdrop: Node2D
var effects: Node2D
var hazards: Node2D
var attacks_spawned := {"wave": 0, "rock": 0, "blade": 0, "spell": 0}

func _ready() -> void:
	rng.seed = 2026
	backdrop = Node2D.new()
	backdrop.draw.connect(draw_room)
	add_child(backdrop)
	make_wall(Vector2(640, ArenaConfig.FLOOR_Y + 50), Vector2(1280, 100))
	make_wall(Vector2(24, 310), Vector2(48, 620))
	make_wall(Vector2(1256, 310), Vector2(48, 620))
	hazards = Node2D.new()
	add_child(hazards)
	player = ArenaPlayer.new()
	player.arena = self
	player.position = Vector2(290, ArenaConfig.FLOOR_Y)
	add_child(player)
	boss = ArenaBoss.new()
	boss.arena = self
	boss.kind = kind
	boss.position = Vector2(945, ArenaConfig.FLOOR_Y)
	add_child(boss)
	effects = Node2D.new()
	effects.draw.connect(draw_effects)
	add_child(effects)
	player.died.connect(func() -> void: end_fight(false))
	boss.defeated.connect(func() -> void: end_fight(true))

func make_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	feedback_clock += real_delta
	if hitstop > 0:
		hitstop -= real_delta
		if hitstop <= 0:
			restore_time_scale()
	if combat_active:
		elapsed += delta
		if practice:
			player.restore_practice_stats()
	for i in range(particles.size() - 1, -1, -1):
		var particle := particles[i]
		particle.life -= delta
		particle.position += particle.velocity * delta
		particle.velocity.y += 650 * delta
		if particle.life <= 0:
			particles.remove_at(i)
	for i in range(slams.size() - 1, -1, -1):
		slams[i].life -= delta
		if slams[i].life <= 0:
			slams.remove_at(i)
	for i in range(shocks.size() - 1, -1, -1):
		shocks[i].life -= real_delta
		if shocks[i].life <= 0:
			shocks.remove_at(i)
	for i in range(slashes.size() - 1, -1, -1):
		slashes[i].life -= delta
		if slashes[i].life <= 0:
			slashes.remove_at(i)
	for i in range(echoes.size() - 1, -1, -1):
		echoes[i].life -= delta
		if echoes[i].life <= 0:
			echoes.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].life -= real_delta
		if sparks[i].life <= 0:
			sparks.remove_at(i)
	for i in range(hammer_traces.size() - 1, -1, -1):
		hammer_traces[i].life -= delta
		if hammer_traces[i].life <= 0:
			hammer_traces.remove_at(i)
	echo_timer -= delta
	if combat_active and echo_timer <= 0:
		echo_timer = 0.022
		if player.state == ArenaPlayer.State.DASH and echoes.size() < 8:
			var echo := MotionEcho.new()
			echo.origin = player.position
			echo.facing = player.facing
			echo.rig = player.visual.blended_rig.duplicate()
			echoes.append(echo)
		if kind == 0 and not boss.dead and boss.pose in ["slam", "dive", "attack"]:
			var trace := HammerTrace.new()
			trace.point = boss.hammer_head_center()
			hammer_traces.append(trace)
	shake *= exp(-real_delta * 18.0)
	if shake < 0.05:
		shake = 0
	position = Vector2(sin(feedback_clock * 103.0), sin(feedback_clock * 137.0) * 0.55) * shake
	effects.queue_redraw()

func resolve_sword(source: ArenaPlayer, rect: Rect2) -> void:
	if source.attack_direction == Vector2.UP:
		for child in hazards.get_children():
			var hazard := child as ArenaHazard
			if (
				hazard
				and hazard.can_reflect_upward()
				and rect.intersects(hazard.hitbox())
			):
				hazard.reflect_upward()
				var contact := hazard.position - Vector2(0, hazard.size.y * 0.5)
				burst(contact, ArenaConfig.TEAL, 14)
				sound("hit")
				impact(3.5, 0.035)
	if boss.dead or boss.phase_pending or not rect.intersects(boss.hurtbox()):
		return
	if source.register_hit(boss.get_instance_id()):
		boss.take_damage(ArenaConfig.SWORD_DAMAGE, source.position)
		var contact := rect.intersection(boss.hurtbox()).get_center()
		var spark := ContactSpark.new()
		spark.origin = contact
		spark.direction = source.attack_world_direction()
		sparks.append(spark)
		for i in 10:
			var direction := spark.direction.rotated(rng.randf_range(-0.75, 0.75))
			particles.append(ParticleEffect.new(contact, direction * rng.randf_range(100, 350), rng.randf_range(0.12, 0.28), rng.randf_range(2, 4), ArenaConfig.AMBER if kind == 0 else Color.WHITE))
		sound("hit")
		impact(3.2, 0.042)

func strike(rect: Rect2, from: Vector2) -> void:
	if combat_active and rect.intersects(player.hurtbox()):
		player.take_damage(1, from)

func spawn_spell(at_position: Vector2, direction: float) -> void:
	var projectile := new_hazard("spell", at_position, ArenaConfig.TEAL)
	projectile.velocity.x = direction * 760
	projectile.size = Vector2(62, 38)
	projectile.lifetime = 1.8
	attacks_spawned.spell += 1

func spawn_wave(at_position: Vector2, direction: float, tint: Color) -> void:
	var projectile := new_hazard("wave", Vector2(at_position.x, ArenaConfig.FLOOR_Y), tint)
	projectile.velocity.x = direction * (300 if boss.phase == 1 else 370)
	projectile.size = Vector2(ArenaHazard.WAVE_WIDTH, ArenaHazard.WAVE_MAX_HEIGHT)
	attacks_spawned.wave += 1

func spawn_rock(x: float, delay: float, blade: bool = false) -> void:
	var projectile := new_hazard("sword_rain" if blade else "rock", Vector2(x, 90), boss.color())
	projectile.warning = delay
	projectile.velocity.y = 430
	projectile.size = Vector2(18, 62) if blade else Vector2(42, 42)
	attacks_spawned.rock += 1

func spawn_blade(at_position: Vector2, speed: Vector2, returning: bool) -> void:
	var projectile := new_hazard("blade", at_position, ArenaConfig.VIOLET)
	projectile.velocity = speed
	projectile.returning = returning
	projectile.size = Vector2(40, 36)
	projectile.lifetime = 2.4
	attacks_spawned.blade += 1

func new_hazard(type: String, at_position: Vector2, tint: Color) -> ArenaHazard:
	var projectile := ArenaHazard.new()
	projectile.arena = self
	projectile.kind = type
	projectile.position = at_position
	projectile.tint = tint
	hazards.add_child(projectile)
	return projectile

func clear_hazards() -> void:
	for child in hazards.get_children():
		var hazard := child as ArenaHazard
		if hazard:
			hazard.deactivate()

func burst(at_position: Vector2, tint: Color, count: int) -> void:
	for i in count:
		particles.append(ParticleEffect.new(
			at_position,
			Vector2(rng.randf_range(-260, 260), rng.randf_range(-290, 80)),
			rng.randf_range(0.18, 0.55),
			rng.randf_range(2, 6),
			tint,
		))

func show_slam(rect: Rect2, tint: Color) -> void:
	slams.append(SlamEffect.new(rect, tint))

func show_shock(at_position: Vector2, tint: Color, radius: float) -> void:
	shocks.append(ShockEffect.new(at_position, tint, radius))

func show_slash(
	origin: Vector2,
	direction: Vector2,
	variant: int,
	tint: Color = ArenaConfig.TEAL,
	life: float = 0.14,
) -> void:
	slashes.append(SlashEffect.new(origin, direction, variant, tint, life))

func impact(power: float, duration: float) -> void:
	shake = maxf(shake, power)
	hitstop = maxf(hitstop, duration)
	if not owns_time_scale:
		previous_time_scale = Engine.time_scale
		owns_time_scale = true
	Engine.time_scale = ArenaConfig.HITSTOP_SCALE

func restore_time_scale() -> void:
	hitstop = 0
	if owns_time_scale and is_equal_approx(Engine.time_scale, ArenaConfig.HITSTOP_SCALE):
		Engine.time_scale = previous_time_scale
	owns_time_scale = false

func sound(key: String) -> void:
	var audio := get_node_or_null("/root/Sfx")
	if audio:
		audio.play(key)

func notify(text: String, duration: float = 1.6) -> void:
	message.emit(text, duration)

func end_fight(won: bool) -> void:
	if not combat_active:
		return
	combat_active = false
	clear_hazards()
	restore_time_scale()
	sound("win" if won else "hurt")
	finished.emit(won, elapsed)

func _exit_tree() -> void:
	restore_time_scale()

func draw_room() -> void:
	var accent := ArenaConfig.AMBER if kind == 0 else ArenaConfig.VIOLET
	backdrop.draw_rect(Rect2(0, 0, 1280, 720), ArenaConfig.BACKGROUND)
	# Rectangular masonry, inset door and staggered foreground tiles.
	for i in 9:
		var x := 45 + i * 148
		backdrop.draw_rect(Rect2(x, 171, 48, 422), Color("#101a26"))
		BoxArt.outline(backdrop, Rect2(x + 8, 188, 32, 370), Color("#1c2a35"), 2)
		backdrop.draw_rect(Rect2(x - 6, 165, 60, 8), Color("#25323b"))
		backdrop.draw_rect(Rect2(x - 6, 570, 60, 22), Color("#1d2932"))
	BoxArt.outline(backdrop, Rect2(478, 202, 324, 392), Color("#23303c"), 4)
	BoxArt.outline(backdrop, Rect2(496, 221, 288, 373), Color("#182430"), 3)
	backdrop.draw_rect(Rect2(511, 241, 258, 353), Color("#080e17"))
	for i in 6:
		backdrop.draw_rect(Rect2(527 + i * 44, 252, 3, 342), Color("#14212c"))
	for x in [195, 1085]:
		backdrop.draw_rect(Rect2(x - 8, 311, 16, 45), accent.darkened(0.4))
		backdrop.draw_rect(Rect2(x - 3, 302, 6, 24), accent)
		BoxArt.outline(backdrop, Rect2(x - 15, 295, 30, 40), Color(accent, 0.18), 2)
	backdrop.draw_rect(Rect2(48, 594, 1184, 3), accent.darkened(0.25))
	backdrop.draw_rect(Rect2(0, 598, 1280, 122), Color("#101923"))
	for i in 17:
		BoxArt.outline(backdrop, Rect2(i * 80 + 3, 606, 74, 28), Color("#1e2b35"), 1)
		BoxArt.outline(backdrop, Rect2(i * 80 - 37, 642, 74, 26), Color("#18242f"), 1)
	for x in [48, 1226]:
		backdrop.draw_rect(Rect2(x, 145, 6, 449), Color(accent, 0.3))

func draw_effects() -> void:
	for echo in echoes:
		# BoxArt uses local transforms internally, so a single outer transform is
		# insufficient. Draw a compact silhouette from the sampled world joints.
		for limb in [["chest", "hip"], ["hip", "left_knee"], ["left_knee", "left_foot"], ["hip", "right_knee"], ["right_knee", "right_foot"], ["front_shoulder", "front_elbow"], ["front_elbow", "front_hand"]]:
			if echo.rig.is_empty():
				continue
			var a: Vector2 = echo.rig[limb[0]]
			var b: Vector2 = echo.rig[limb[1]]
			BoxArt.bar(effects, echo.origin + a * Vector2(echo.facing, 1), echo.origin + b * Vector2(echo.facing, 1), 5, Color(ArenaConfig.TEAL, echo.life / 0.13 * 0.22))
		effects.draw_set_transform(Vector2.ZERO)
	for i in range(1, hammer_traces.size()):
		var a := hammer_traces[i - 1]
		var b := hammer_traces[i]
		if a.point.distance_to(b.point) < 150:
			BoxArt.bar(effects, a.point, b.point, 12, Color(ArenaConfig.AMBER, b.life / 0.12 * 0.16))
			BoxArt.bar(effects, a.point, b.point, 3, Color(ArenaConfig.AMBER, b.life / 0.12 * 0.40))
	for spark in sparks:
		var progress := 1.0 - spark.life / 0.13
		var alpha := 1.0 - progress
		for i in 6:
			var ray := spark.direction.rotated(i * TAU / 6.0 + 0.23)
			var reach := (30.0 if i % 2 == 0 else 19.0) * (0.55 + progress)
			BoxArt.bar(effects, spark.origin + ray * progress * 12, spark.origin + ray * reach, 3.0 * alpha + 1, Color(Color.WHITE, alpha))
		effects.draw_circle(spark.origin, 5 * alpha, Color(ArenaConfig.AMBER, alpha))
	for particle in particles:
		var tint: Color = particle.color
		tint.a = minf(particle.life * 4, 1)
		effects.draw_rect(Rect2(particle.position, Vector2.ONE * particle.size), tint)
	for slam_ in slams:
		var tint: Color = slam_.color
		var progress := 1.0 - slam_.life / 0.18
		tint.a = (1.0 - progress) * 0.55
		var ground := slam_.rect.end.y
		effects.draw_rect(Rect2(slam_.rect.position.x, ground - 4, slam_.rect.size.x, 5), tint)
		for i in 7:
			var x := slam_.rect.position.x + (i + 0.5) * slam_.rect.size.x / 7.0
			var height := (18 + (i * 17 % 35)) * sin((progress * 0.8 + 0.2) * PI)
			effects.draw_colored_polygon(PackedVector2Array([
				Vector2(x - 10, ground), Vector2(x + 5, ground - height), Vector2(x + 12, ground)
			]), tint)
	for shock in shocks:
		var progress := 1.0 - shock.life / shock.max_life
		var current_radius := lerpf(shock.radius * 0.22, shock.radius, progress)
		var alpha := (1.0 - progress) * 0.92
		for band in 3:
			var radius := current_radius - band * 20.0
			if radius > 0:
				effects.draw_arc(
					shock.position,
					radius,
					PI,
					TAU,
					40,
					Color(shock.color, alpha * (1.0 - band * 0.24)),
					7.0 - band * 1.5,
				)
		effects.draw_rect(
			Rect2(
				shock.position + Vector2(-current_radius, -3),
				Vector2(current_radius * 2.0, 4),
			),
			Color(shock.color, alpha * 0.72),
		)
	for slash in slashes:
		var alpha: float = slash.life / slash.max_life
		var reach := (140.0 if absf(slash.direction.x) > 0.5 else 128.0) * lerpf(1.08, 0.85, alpha)
		BoxArt.slash_arc(
			effects,
			slash.position,
			slash.direction,
			slash.variant,
			slash.color,
			alpha * 0.48,
			reach,
		)
	# Falling hazards and the Prism keep explicit targeting cues. The Quarry
	# communicates its first hit through the raised hammer silhouette instead.
	if combat_active and not boss.dead:
		if boss.pose == "windup" and boss.kind == 1 and not boss.action.is_empty():
			var pulse := 0.48 + sin(boss.clock * 18) * 0.14
			var origin := boss.position + Vector2(boss.facing * 34, -58)
			if boss.action == "thrust":
				var finish := origin + Vector2(boss.facing * 205, 0)
				BoxArt.bar(effects, origin, finish, 3, Color(ArenaConfig.DANGER, pulse))
				BoxArt.bar(
					effects,
					finish - Vector2(0, 13),
					finish + Vector2(0, 13),
					2,
					Color(ArenaConfig.DANGER, pulse),
				)
			elif boss.action == "boomerang" or boss.action == "fan":
				var count := 3 if boss.action == "fan" else 1
				for i in count:
					var angle := lerpf(-0.42, 0.24, float(i) / maxf(1, count - 1))
					var direction := Vector2(boss.facing, 0).rotated(angle * boss.facing)
					var tint := Color(ArenaConfig.VIOLET, pulse * 0.72)
					BoxArt.bar(effects, origin, origin + direction * 88, 2, tint)
		if boss.kind == 1 and boss.action == "dive" and boss.event_index == 2:
			effects.draw_rect(Rect2(boss.target_x - 65, 588, 130, 6), ArenaConfig.VIOLET)
