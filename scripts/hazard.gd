class_name ArenaHazard
extends Node2D

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

func _ready() -> void:
	origin_x = position.x
	add_to_group("hazards")

func _physics_process(delta: float) -> void:
	if not arena.combat_active:
		return
	age += delta
	if launch_direction == 0:
		launch_direction = signf(velocity.x)
	if age >= lifetime:
		queue_free()
		return
	if kind in ["rock", "sword_rain"] and age < warning:
		queue_redraw()
		return
	if kind in ["rock", "sword_rain"]:
		velocity.y += 1600 * delta
	if kind == "blade" and returning:
		velocity.x -= launch_direction * 520 * delta
	position += velocity * delta
	var rect := hitbox()
	if kind == "spell":
		if not triggered and not arena.boss.dead and rect.intersects(arena.boss.hurtbox()):
			if arena.boss.take_damage(ArenaConfig.SPELL_DAMAGE, position):
				triggered = true
				arena.burst(position, tint, 20)
				arena.sound("hit")
				arena.impact(4, 0.04)
				queue_free()
	else:
		if rect.intersects(arena.player.hurtbox()):
			arena.player.take_damage(1, position)
	if kind in ["rock", "sword_rain"] and position.y >= ArenaConfig.FLOOR_Y:
		arena.burst(Vector2(position.x, ArenaConfig.FLOOR_Y), tint, 12)
		arena.show_slam(Rect2(position.x - 26, ArenaConfig.FLOOR_Y - 12, 52, 12), tint)
		queue_free()
	if position.x < -100 or position.x > 1380 or position.y > 800 or position.y < -500:
		queue_free()
	queue_redraw()

func hitbox() -> Rect2:
	return Rect2(position - Vector2(size.x * 0.5, size.y), size)

func _draw() -> void:
	match kind:
		"wave":
			# Uneven half-dome silhouette assembled from rectangular columns.
			for i in 7:
				var height: int = [17, 31, 47, 54, 43, 29, 12][i]
				draw_rect(Rect2(-25 + i * 7, -height, 5, height), Color(tint, 0.68))
				draw_rect(Rect2(-25 + i * 7, -height, 5, 4), tint)
		"spell":
			for i in 5:
				draw_rect(Rect2(-26 - i * signf(velocity.x) * 10, -30 + i * 3, 44, 24 - i * 4), Color(tint, 0.85 - i * 0.15))
		"blade":
			var direction := Vector2.from_angle(age * 16)
			BoxArt.bar(self, -direction * 25 + Vector2(0, -16), direction * 25 + Vector2(0, -16), 6, tint)
			direction = direction.rotated(PI * 0.5)
			BoxArt.bar(self, -direction * 12 + Vector2(0, -16), direction * 12 + Vector2(0, -16), 4, tint)
		"rock", "sword_rain":
			if age < warning:
				var ground := ArenaConfig.FLOOR_Y - position.y
				draw_rect(Rect2(-size.x * 0.5, ground - 5, size.x, 5), tint)
				for i in 6:
					draw_rect(Rect2(-1, ground - 28 - i * 50, 2, 18), Color(tint, 0.18 + age / warning * 0.4))
				BoxArt.outline(self, Rect2(-17, ground - 33, 34, 27), Color(tint, 0.4), 1)
			else:
				draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), tint.darkened(0.6))
				BoxArt.outline(self, Rect2(-size.x * 0.5, -size.y, size.x, size.y), tint, 3)
				if kind == "sword_rain":
					draw_rect(Rect2(-18, -size.y + 14, 36, 5), tint)
