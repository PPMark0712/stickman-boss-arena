class_name BoxArt
extends RefCounted
## Even diagonals, particles and curved-looking effects are made of rectangles.

static func bar(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	canvas.draw_set_transform((a + b) * 0.5, (b - a).angle())
	canvas.draw_rect(Rect2(-a.distance_to(b) * 0.5, -width * 0.5, a.distance_to(b), width), color)
	canvas.draw_set_transform(Vector2.ZERO)

static func outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float = 2.0) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	var bottom := Rect2(
		rect.position + Vector2(0, rect.size.y - width),
		Vector2(rect.size.x, width),
	)
	canvas.draw_rect(bottom, color)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color)
	var right := Rect2(
		rect.position + Vector2(rect.size.x - width, 0),
		Vector2(width, rect.size.y),
	)
	canvas.draw_rect(right, color)

static func fighter(
	canvas: CanvasItem,
	pose: String,
	clock: float,
	color: Color,
	heavy: bool = false,
	progress: float = 0.0,
	variant: int = 0,
	squash: float = 0.0,
) -> void:
	progress = clampf(progress, 0.0, 1.0)
	squash = clampf(squash, 0.0, 1.0)
	var stride := sin(clock * 16.0) * (13.0 if pose == "run" else 1.5)
	var bounce := absf(cos(clock * 16.0)) * 2.0 if pose == "run" else sin(clock * 3.2) * 0.8
	var swing := _swing_curve(progress)
	var lean := 0.0
	if pose == "hurt":
		lean = -14.0
	elif pose == "air":
		lean = 6.0
	elif pose == "heal":
		lean = -5.0
	elif pose == "cast":
		lean = 8.0
	elif pose in ["attack", "up", "down"]:
		lean = lerpf(-6.0, 10.0, swing)
	elif pose == "windup":
		lean = -8.0
	elif pose == "slam":
		lean = 12.0
	var hip := Vector2(lean * 0.22, -26 + bounce + squash * 6)
	var shoulder := Vector2(lean, -52 + bounce + squash * 10)
	var head_center := Vector2(lean, -66 + bounce + squash * 12)
	var head := Rect2(head_center - Vector2(10, 10), Vector2(20, 20))

	var left_foot := Vector2(-13 - stride, -2)
	var right_foot := Vector2(13 + stride, -2)
	if pose == "air":
		left_foot = Vector2(-17, -13)
		right_foot = Vector2(18, -7)
	elif pose in ["attack", "up", "down", "cast", "windup", "slam"]:
		left_foot = Vector2(-18, -2)
		right_foot = Vector2(19, -2)
	if squash > 0:
		left_foot.x -= squash * 6
		right_foot.x += squash * 6

	var rear_hand := Vector2(-19, -34 - stride * 0.25)
	if pose == "cast":
		rear_hand = Vector2(31, -44)
	bar(canvas, shoulder + Vector2(-2, 2), rear_hand, 4, Color(color, color.a * 0.72))
	bar(canvas, hip, left_foot, 5, color)
	bar(canvas, hip, right_foot, 5, color)
	bar(canvas, shoulder, hip, 6, color)
	canvas.draw_rect(head, Color("#101c27"))
	outline(canvas, head, color, 3)
	canvas.draw_rect(Rect2(head_center + Vector2(4, -3), Vector2(9, 3)), color)

	if heavy:
		_draw_hammer(canvas, pose, clock, color, shoulder, lean, progress)
	else:
		_draw_sword(canvas, pose, color, shoulder, progress, variant)

static func _swing_curve(progress: float) -> float:
	var value := clampf((progress - 0.08) / 0.52, 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)

static func _weapon_angle(pose: String, progress: float, variant: int) -> float:
	var swing := _swing_curve(progress)
	if pose == "up":
		return lerp_angle(0.65, -PI * 0.54, swing)
	if pose == "down":
		return lerp_angle(-0.7, PI * 0.52, swing)
	if pose == "attack":
		match variant % 3:
			0:
				return lerp_angle(-2.25, 0.28, swing)
			1:
				return lerp_angle(2.15, -0.48, swing)
			_:
				return lerp_angle(-1.05, -0.02, swing)
	if pose == "windup":
		return -2.05
	if pose == "hurt":
		return 0.8
	if pose == "cast":
		return -0.08
	return -0.72

static func _draw_sword(
	canvas: CanvasItem,
	pose: String,
	color: Color,
	shoulder: Vector2,
	progress: float,
	variant: int,
) -> void:
	if pose == "heal":
		var hands := shoulder.lerp(Vector2(5, -39), 0.75)
		bar(canvas, shoulder, hands, 4, color)
		bar(canvas, shoulder + Vector2(-2, 3), hands + Vector2(-7, 2), 4, color)
		return
	var angle := _weapon_angle(pose, progress, variant)
	var extension := 1.0
	if pose == "attack" and variant % 3 == 2:
		extension = 0.75 + _swing_curve(progress) * 0.45
	var hand := shoulder + Vector2.from_angle(angle) * 31.0 * extension
	var tip := hand + Vector2.from_angle(angle) * 48.0
	if pose in ["attack", "up", "down"]:
		for i in range(3, 0, -1):
			var old_progress := maxf(0.0, progress - i * 0.045)
			var old_angle := _weapon_angle(pose, old_progress, variant)
			var old_hand := shoulder + Vector2.from_angle(old_angle) * 31.0
			var old_tip := old_hand + Vector2.from_angle(old_angle) * 48.0
			var trail_color := Color(ArenaConfig.TEAL, 0.08 + (3 - i) * 0.08)
			bar(canvas, old_hand, old_tip, 5.0 - i, trail_color)
	bar(canvas, shoulder, hand, 4, color)
	bar(canvas, hand, tip, 4, color)
	var normal := Vector2.from_angle(angle + PI * 0.5)
	bar(canvas, hand - normal * 7, hand + normal * 7, 4, ArenaConfig.AMBER)

static func _draw_hammer(
	canvas: CanvasItem,
	pose: String,
	clock: float,
	color: Color,
	shoulder: Vector2,
	lean: float,
	progress: float,
) -> void:
	outline(canvas, Rect2(lean - 19, shoulder.y - 4, 38, 15), color, 3)
	var angle := -0.85
	if pose == "windup":
		var anticipation := clampf(progress * 1.7, 0.0, 1.0)
		angle = lerp_angle(-0.85, -2.12, anticipation) + sin(clock * 4.0) * 0.035
	elif pose == "slam":
		angle = lerp_angle(-2.12, 0.20, _swing_curve(progress))
	elif pose == "attack":
		angle = progress * TAU * 1.8
	var hand := shoulder + Vector2.from_angle(angle) * 36
	var tip := hand + Vector2.from_angle(angle) * 39
	bar(canvas, shoulder, hand, 5, color)
	bar(canvas, hand, tip, 6, color)
	canvas.draw_set_transform(tip, angle)
	canvas.draw_rect(Rect2(-19, -13, 38, 26), Color("#27303a"))
	outline(canvas, Rect2(-19, -13, 38, 26), color, 3)
	canvas.draw_set_transform(Vector2.ZERO)
