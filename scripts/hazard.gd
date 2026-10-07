class_name ArenaHazard
extends Node2D

const WAVE_PROFILE := [0.23, 0.40, 0.59, 0.78, 0.94, 1.0, 0.95, 0.81, 0.62, 0.41, 0.23]
const WAVE_WIDTH := 86.0
const WAVE_MAX_HEIGHT := ArenaConfig.PLAYER_JUMP_HEIGHT * 0.7
const ROCK_REFLECT_SPEED := 1100.0

var arena: Node2D
var kind := "wave"
var velocity := Vector2.ZERO
var tint := ArenaConfig.AMBER
var age := 0.0
var lifetime := 4.0
var warning := 0.0
var returning := false
var triggered := false
var size := Vector2(42, 50)
var origin_x := 0.0
var launch_direction := 0.0
var active := true
var reflected := false

func _ready() -> void:
	origin_x = position.x
	add_to_group("hazards")

func _physics_process(delta: float) -> void:
	if not active or not arena.combat_active:
		return
	age += delta
	if launch_direction == 0:
		launch_direction = signf(velocity.x)
	if age >= lifetime:
		deactivate()
		return
	var falling := kind == "rock" or kind == "sword_rain"
	if falling and age < warning:
		queue_redraw()
		return
	if falling and not reflected:
		velocity.y += 1600 * delta
	if kind == "blade" and returning:
		velocity.x -= launch_direction * 520 * delta
	var previous_box := hitbox()
	position += velocity * delta
	var rect := hitbox()
	if kind == "spell":
		# Spells travel horizontally: merging endpoint boxes covers the full path,
		# including targets already overlapping the muzzle on the launch frame.
		var swept := previous_box.merge(rect)
		var target: Rect2 = arena.boss.hurtbox()
		var direction := Vector2(launch_direction, 0)
		if not triggered and not arena.boss.dead and swept.intersects(target):
			triggered = true
			var overlap := swept.intersection(target)
			var contact := Vector2(
				overlap.position.x if launch_direction > 0 else overlap.end.x,
				overlap.get_center().y,
			)
			var damaged: bool = arena.boss.take_damage(ArenaConfig.SPELL_DAMAGE, contact)
			arena.spell_impact(contact, direction, damaged)
			deactivate()
			return
		if rect.position.x <= ArenaConfig.LEFT_WALL or rect.end.x >= ArenaConfig.RIGHT_WALL:
			var wall_x := ArenaConfig.LEFT_WALL if launch_direction < 0 else ArenaConfig.RIGHT_WALL
			arena.spell_impact(Vector2(wall_x, rect.get_center().y), direction, false)
			deactivate()
			return
	else:
		if not reflected and rect.intersects(arena.player.hurtbox()):
			arena.player.take_damage(1, position)
	if falling and not reflected and position.y >= ArenaConfig.FLOOR_Y:
		arena.burst(Vector2(position.x, ArenaConfig.FLOOR_Y), tint, 12)
		arena.show_slam(Rect2(position.x - 26, ArenaConfig.FLOOR_Y - 12, 52, 12), tint)
		deactivate()
		return
	if position.x < -100 or position.x > 1380 or position.y > 800 or position.y < -500:
		deactivate()
		return
	queue_redraw()

func deactivate() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	visible = false
	queue_free()

func hitbox() -> Rect2:
	return Rect2(position - Vector2(size.x * 0.5, size.y), size)

func can_reflect_upward() -> bool:
	return active and kind == "rock" and age >= warning and not reflected

func reflect_upward() -> void:
	if not can_reflect_upward():
		return
	reflected = true
	velocity = Vector2(0, -ROCK_REFLECT_SPEED)
	queue_redraw()

func _draw() -> void:
	match kind:
		"wave":
			# Uneven half-dome silhouette assembled from rectangular columns.
			for i in WAVE_PROFILE.size():
				var height: float = WAVE_PROFILE[i] * WAVE_MAX_HEIGHT
				var x := -WAVE_WIDTH * 0.5 + i * 8.0
				draw_rect(Rect2(x, -height, 6, height), Color(tint, 0.68))
				draw_rect(Rect2(x, -height, 6, 4), tint)
		"spell":
			var center := Vector2(0, -size.y * 0.5)
			var heading := Vector2(signf(velocity.x), 0)
			var side := Vector2.UP
			# The bright body fits its damage box; the fading tail is decorative.
			for i in range(5, 0, -1):
				var trail := center - heading * (15 + i * 9)
				draw_circle(trail, 12 - i * 1.7, Color(tint, 0.23 - i * 0.035))
			var body := PackedVector2Array()
			for i in 24:
				var angle := i * TAU / 24.0
				body.append(center + Vector2(cos(angle) * 29, sin(angle) * 17))
			draw_colored_polygon(body, Color(tint, 0.28))
			draw_circle(center, 13, Color(tint, 0.85))
			draw_circle(center + heading * 7, 8, Color("#ecfff8"))
			BoxArt.bar(self, center - heading * 25, center + heading * 25, 4, Color.WHITE)
			var flutter := sin(age * 45) * 2
			for edge in [-1.0, 1.0]:
				BoxArt.bar(self, center - heading * 34 + side * (10 + flutter) * edge, center + heading * 7 + side * 13 * edge, 2, Color(tint, 0.7))
		"blade":
			var direction := Vector2.from_angle(age * 16)
			BoxArt.bar(self, -direction * 25 + Vector2(0, -16), direction * 25 + Vector2(0, -16), 6, tint)
			direction = direction.rotated(PI * 0.5)
			BoxArt.bar(self, -direction * 12 + Vector2(0, -16), direction * 12 + Vector2(0, -16), 4, tint)
		"rock":
			if age < warning:
				var ground := ArenaConfig.FLOOR_Y - position.y
				draw_rect(Rect2(-size.x * 0.5, ground - 5, size.x, 5), tint)
				for i in 6:
					draw_rect(Rect2(-1, ground - 28 - i * 50, 2, 18), Color(tint, 0.18 + age / warning * 0.4))
				draw_arc(
					Vector2(0, ground - size.y * 0.5),
					size.x * 0.5,
					0,
					TAU,
					24,
					Color(tint, 0.48),
					2,
				)
			else:
				var center := Vector2(0, -size.y * 0.5)
				if reflected:
					for i in 3:
						draw_rect(
							Rect2(-4 + i, 5 + i * 13, 8 - i * 2, 10),
							Color(ArenaConfig.TEAL, 0.42 - i * 0.1),
						)
				draw_circle(center, size.x * 0.5, Color("#11161b"))
				draw_arc(center, size.x * 0.5 - 1, 0, TAU, 28, tint, 3)
				draw_circle(center + Vector2(-7, -5), 3, tint.darkened(0.2))
				draw_circle(center + Vector2(6, 6), 2, tint.darkened(0.35))
		"sword_rain":
			if age < warning:
				var ground := ArenaConfig.FLOOR_Y - position.y
				draw_rect(Rect2(-size.x * 0.5, ground - 5, size.x, 5), tint)
				for i in 6:
					draw_rect(
						Rect2(-1, ground - 28 - i * 50, 2, 18),
						Color(tint, 0.18 + age / warning * 0.4),
					)
				BoxArt.outline(self, Rect2(-17, ground - 33, 34, 27), Color(tint, 0.4), 1)
			else:
				draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), tint.darkened(0.6))
				BoxArt.outline(self, Rect2(-size.x * 0.5, -size.y, size.x, size.y), tint, 3)
				draw_rect(Rect2(-18, -size.y + 14, 36, 5), tint)
