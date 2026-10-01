class_name BoxArt
extends RefCounted
## Even diagonals, particles and curved-looking effects are made of rectangles.

static func bar(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var delta := b - a
	var length := delta.length()
	canvas.draw_set_transform((a + b) * 0.5, delta.angle())
	canvas.draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), color)
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

static func player_fighter(
	canvas: CanvasItem,
	pose: String,
	clock: float,
	color: Color,
	progress: float = 0.0,
	variant: int = 0,
	squash: float = 0.0,
	airborne: bool = false,
) -> void:
	progress = clampf(progress, 0.0, 1.0)
	squash = clampf(squash, 0.0, 1.0)
	var gait := clock * 14.0
	var stride := sin(gait) if pose == "run" else 0.0
	var bounce := absf(cos(gait)) * 1.7 if pose == "run" else sin(clock * 3.2) * 0.7
	var lean := 0.0
	match pose:
		"run": lean = 5.0
		"air": lean = 3.0
		"attack": lean = lerpf(-4.0, 8.0, _ease_segment(progress, 0.16, 0.56))
		"up": lean = lerpf(3.0, -2.0, _ease_segment(progress, 0.12, 0.58))
		"down": lean = lerpf(-2.0, 7.0, _ease_segment(progress, 0.12, 0.58))
		"dash": lean = 18.0
		"cast": lean = 7.0
		"heal": lean = -4.0
		"hurt": lean = -13.0

	var hip := Vector2(lean * 0.22, -26 + bounce + squash * 6)
	var chest := Vector2(lean, -51 + bounce + squash * 9)
	var head_center := Vector2(lean + 1, -67 + bounce + squash * 11)
	if pose == "dash":
		hip += Vector2(-5, 1)
		chest += Vector2(2, 5)
		head_center += Vector2(5, 7)

	var left_foot := Vector2(-12 + stride * 14, -2 - maxf(0, cos(gait)) * 5)
	var right_foot := Vector2(12 - stride * 14, -2 - maxf(0, -cos(gait)) * 5)
	if pose == "air" or airborne:
		left_foot = Vector2(-15, -13)
		right_foot = Vector2(17, -8)
	if pose == "dash":
		left_foot = Vector2(-24, -5)
		right_foot = Vector2(5, -2)
	elif pose == "attack" and not airborne:
		left_foot = Vector2(-17, -2)
		right_foot = Vector2(19, -2)
	elif pose == "hurt":
		left_foot = Vector2(-19, -2)
		right_foot = Vector2(10, -3)
	if squash > 0:
		left_foot.x -= squash * 5
		right_foot.x += squash * 5
	var left_knee := hip.lerp(left_foot, 0.52) + Vector2(-5, 0)
	var right_knee := hip.lerp(right_foot, 0.52) + Vector2(5, 0)

	var rear_shoulder := chest + Vector2(-3, 3)
	var front_shoulder := chest + Vector2(3, 3)
	var rear_elbow := Vector2(-12 - stride * 6, -39)
	var rear_hand := Vector2(-18 - stride * 10, -29)
	var front_elbow := Vector2(10 + stride * 6, -38)
	var front_hand := Vector2(17 + stride * 10, -29)
	var sword_angle := -0.62

	match pose:
		"attack":
			var strike := _ease_segment(progress, 0.16, 0.55)
			var recover := _ease_segment(progress, 0.68, 1.0)
			var strike_y := -4.0 if variant == 0 else 7.0
			front_hand = chest + Vector2(lerpf(-3, 24, strike), lerpf(8, strike_y, strike))
			front_hand = front_hand.lerp(chest + Vector2(14, 10), recover)
			front_elbow = front_shoulder.lerp(front_hand, 0.54)
			front_elbow += Vector2(2, -6 if variant == 0 else 6)
			rear_elbow = rear_shoulder + Vector2(-11, 8)
			rear_hand = rear_elbow + Vector2(-10, 9)
			sword_angle = _player_sword_angle(pose, progress, variant)
		"up":
			var strike := _ease_segment(progress, 0.12, 0.58)
			front_hand = chest + Vector2(lerpf(8, 17, strike), lerpf(10, -9, strike))
			front_elbow = front_shoulder.lerp(front_hand, 0.48) + Vector2(5, 3)
			rear_elbow = rear_shoulder + Vector2(-10, 7)
			rear_hand = rear_elbow + Vector2(-8, 8)
			sword_angle = _player_sword_angle(pose, progress, variant)
		"down":
			var strike := _ease_segment(progress, 0.12, 0.58)
			front_hand = chest + Vector2(lerpf(7, 18, strike), lerpf(-8, 11, strike))
			front_elbow = front_shoulder.lerp(front_hand, 0.5) + Vector2(4, -3)
			rear_elbow = rear_shoulder + Vector2(-11, 5)
			rear_hand = rear_elbow + Vector2(-8, 9)
			sword_angle = _player_sword_angle(pose, progress, variant)
		"air":
			rear_elbow = rear_shoulder + Vector2(-12, 5)
			rear_hand = rear_elbow + Vector2(-8, 10)
			front_elbow = front_shoulder + Vector2(10, 6)
			front_hand = front_elbow + Vector2(8, 9)
			sword_angle = -0.42
		"dash":
			rear_elbow = rear_shoulder + Vector2(-15, 1)
			rear_hand = rear_elbow + Vector2(-13, 4)
			front_elbow = front_shoulder + Vector2(-12, 7)
			front_hand = front_elbow + Vector2(-12, 5)
			sword_angle = -2.88
		"cast":
			front_elbow = front_shoulder + Vector2(14, -2)
			front_hand = front_elbow + Vector2(13, 0)
			sword_angle = -0.08
		"heal":
			rear_elbow = rear_shoulder + Vector2(-8, 8)
			rear_hand = Vector2(1, -38)
			front_elbow = front_shoulder + Vector2(9, 8)
			front_hand = Vector2(6, -38)
		"hurt":
			rear_elbow = rear_shoulder + Vector2(-13, -2)
			rear_hand = rear_elbow + Vector2(-9, -5)
			front_elbow = front_shoulder + Vector2(8, 11)
			front_hand = front_elbow + Vector2(7, 8)
			sword_angle = 0.75

	_limb(canvas, hip + Vector2(-3, 0), left_knee, left_foot, 5, Color(color, color.a * 0.78))
	_limb(canvas, hip + Vector2(3, 0), right_knee, right_foot, 5, color)
	_limb(canvas, rear_shoulder, rear_elbow, rear_hand, 4, Color(color, color.a * 0.68))
	bar(canvas, chest, hip, 6, color)
	var head := Rect2(head_center - Vector2(10, 10), Vector2(20, 20))
	canvas.draw_rect(head, Color("#101c27"))
	outline(canvas, head, color, 3)
	canvas.draw_rect(Rect2(head_center + Vector2(4, -3), Vector2(9, 3)), color)
	_limb(canvas, front_shoulder, front_elbow, front_hand, 4, color)
	if pose != "heal":
		_draw_player_sword(canvas, pose, color, front_hand, sword_angle, progress, variant)

static func _limb(
	canvas: CanvasItem,
	root: Vector2,
	joint: Vector2,
	end: Vector2,
	width: float,
	color: Color,
) -> void:
	bar(canvas, root, joint, width, color)
	bar(canvas, joint, end, width, color)

static func _ease_segment(value: float, start: float, finish: float) -> float:
	var t := clampf((value - start) / maxf(finish - start, 0.001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _player_sword_angle(pose: String, progress: float, variant: int) -> float:
	if pose == "up":
		if progress < 0.14:
			return lerp_angle(-0.45, 0.62, _ease_segment(progress, 0.0, 0.14))
		if progress < 0.65:
			return lerp_angle(0.62, -1.34, _ease_segment(progress, 0.14, 0.65))
		return lerp_angle(-1.34, -0.45, _ease_segment(progress, 0.65, 1.0))
	if pose == "down":
		if progress < 0.14:
			return lerp_angle(-0.45, -0.92, _ease_segment(progress, 0.0, 0.14))
		if progress < 0.65:
			return lerp_angle(-0.92, 1.18, _ease_segment(progress, 0.14, 0.65))
		return lerp_angle(1.18, -0.45, _ease_segment(progress, 0.65, 1.0))
	var windup := -0.78 if variant == 0 else 0.78
	var finish := 0.30 if variant == 0 else -0.30
	if progress < 0.16:
		return lerp_angle(-0.62, windup, _ease_segment(progress, 0.0, 0.16))
	if progress < 0.62:
		return lerp_angle(windup, finish, _ease_segment(progress, 0.16, 0.62))
	return lerp_angle(finish, -0.62, _ease_segment(progress, 0.62, 1.0))

static func _draw_player_sword(
	canvas: CanvasItem,
	pose: String,
	color: Color,
	hand: Vector2,
	angle: float,
	progress: float,
	variant: int,
) -> void:
	if pose == "attack":
		for i in range(3, 0, -1):
			var old_progress := maxf(0.0, progress - i * 0.035)
			var old_angle := _player_sword_angle(pose, old_progress, variant)
			var old_tip := hand + Vector2.from_angle(old_angle) * 66
			bar(
				canvas,
				hand,
				old_tip,
				5.0 - i,
				Color(ArenaConfig.TEAL, 0.08 + (3 - i) * 0.08),
			)
	elif pose == "up" or pose == "down":
		for i in range(3, 0, -1):
			var old_progress := maxf(0.0, progress - i * 0.035)
			var old_angle := _player_sword_angle(pose, old_progress, variant)
			var old_tip := hand + Vector2.from_angle(old_angle) * 66
			bar(
				canvas,
				hand,
				old_tip,
				5.0 - i,
				Color(ArenaConfig.TEAL, 0.08 + (3 - i) * 0.08),
			)
	var direction := Vector2.from_angle(angle)
	var normal := Vector2.from_angle(angle + PI * 0.5)
	var tip := hand + direction * 66
	bar(canvas, hand, tip, 7, Color("#27303a"))
	bar(canvas, hand + normal, tip + normal, 4, color)
	bar(canvas, hand + normal * 2, tip + normal * 2, 1, Color(color, color.a * 0.72))
	bar(canvas, hand - direction * 8, hand, 4, ArenaConfig.AMBER.darkened(0.28))
	bar(canvas, hand - normal * 7, hand + normal * 7, 4, ArenaConfig.AMBER)

static func fighter(
	canvas: CanvasItem,
	pose: String,
	clock: float,
	color: Color,
	heavy: bool = false,
	progress: float = 0.0,
	variant: int = 0,
	squash: float = 0.0,
	weapon_in_front: bool = true,
) -> void:
	if heavy:
		_draw_heavy_fighter(canvas, pose, clock, color, progress, squash, weapon_in_front)
		return
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
	elif pose == "attack" or pose == "up" or pose == "down":
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
	elif (
		pose == "attack"
		or pose == "up"
		or pose == "down"
		or pose == "cast"
		or pose == "windup"
		or pose == "slam"
	):
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
	if pose == "attack" or pose == "up" or pose == "down":
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

static func _draw_heavy_fighter(
	canvas: CanvasItem,
	pose: String,
	clock: float,
	color: Color,
	progress: float,
	squash: float,
	weapon_in_front: bool,
) -> void:
	progress = clampf(progress, 0.0, 1.0)
	var gait := clock * 8.5
	var stride := sin(gait) * (8.0 if pose == "run" else 0.0)
	var bounce := absf(cos(gait)) * 1.2 if pose == "run" else sin(clock * 2.4) * 0.45
	var lean := 0.0
	if pose == "windup":
		lean = lerpf(0.0, -7.0, _ease_segment(progress, 0.0, 0.72))
	elif pose == "slam":
		lean = lerpf(-5.0, 11.0, _ease_segment(progress, 0.0, 0.72))
	elif pose == "attack":
		lean = sin(progress * TAU) * 7.0
	elif pose == "air":
		lean = 4.0
	elif pose == "hurt":
		lean = -10.0

	var body_center := Vector2(lean * 0.35, -48 + bounce + squash * 5)
	var body_rect := Rect2(body_center - Vector2(23, 28), Vector2(46, 56))
	var left_hip := body_center + Vector2(-12, 27)
	var right_hip := body_center + Vector2(12, 27)
	var left_foot := Vector2(-17 - stride, -2)
	var right_foot := Vector2(17 + stride, -2)
	if pose == "air":
		left_foot = Vector2(-21, -10)
		right_foot = Vector2(20, -7)
	elif pose == "slam":
		left_foot = Vector2(-23, -2)
		right_foot = Vector2(24, -2)
	var left_knee := left_hip.lerp(left_foot, 0.52) + Vector2(-5, 1)
	var right_knee := right_hip.lerp(right_foot, 0.52) + Vector2(5, 1)
	_limb(canvas, left_hip, left_knee, left_foot, 8, Color(color, color.a * 0.78))
	_limb(canvas, right_hip, right_knee, right_foot, 8, color)

	var angle := -2.24
	if pose == "run":
		angle += sin(gait) * 0.08
	elif pose == "windup":
		angle = lerp_angle(-2.24, -1.72, _ease_segment(progress, 0.0, 0.82))
	elif pose == "slam":
		angle = lerp_angle(-1.72, 0.60, _ease_segment(progress, 0.0, 0.72))
	elif pose == "attack":
		angle = -1.72 + progress * TAU * 1.8
	elif pose == "air":
		angle = -1.96
	elif pose == "hurt":
		angle = 0.35

	var shaft_direction := Vector2.from_angle(angle)
	var right_grip := body_center + Vector2(18, -17)
	if pose == "windup":
		right_grip += Vector2(0, -5)
	elif pose == "slam":
		right_grip += Vector2(6, 14)
	var left_grip := right_grip - shaft_direction * 34
	var shaft_start := left_grip - shaft_direction * 12
	var hammer_center := right_grip + shaft_direction * 80
	if not weapon_in_front:
		_draw_heavy_hammer(canvas, shaft_start, hammer_center, angle, color)

	canvas.draw_rect(body_rect, Color("#202a33"))
	outline(canvas, body_rect, color, 4)
	var head_center := body_center + Vector2(lean * 0.12, -42)
	var head := Rect2(head_center - Vector2(12, 11), Vector2(24, 22))
	canvas.draw_rect(head, Color("#101c27"))
	outline(canvas, head, color, 4)
	canvas.draw_rect(Rect2(head_center + Vector2(3, -3), Vector2(10, 4)), color)

	if weapon_in_front:
		_draw_heavy_hammer(canvas, shaft_start, hammer_center, angle, color)
	var left_shoulder := body_center + Vector2(-18, -13)
	var right_shoulder := body_center + Vector2(20, -18)
	var left_elbow := left_shoulder.lerp(left_grip, 0.52) + Vector2(-6, 5)
	var right_elbow := right_shoulder.lerp(right_grip, 0.5) + Vector2(5, -4)
	_limb(canvas, left_shoulder, left_elbow, left_grip, 7, Color(color, color.a * 0.82))
	_limb(canvas, right_shoulder, right_elbow, right_grip, 7, color)
	canvas.draw_rect(Rect2(left_grip - Vector2(4, 4), Vector2(8, 8)), color)
	canvas.draw_rect(Rect2(right_grip - Vector2(4, 4), Vector2(8, 8)), color)

static func _draw_heavy_hammer(
	canvas: CanvasItem,
	shaft_start: Vector2,
	hammer_center: Vector2,
	angle: float,
	color: Color,
) -> void:
	bar(canvas, shaft_start, hammer_center, 7, color.darkened(0.16))
	bar(canvas, shaft_start, hammer_center, 3, color.darkened(0.34))
	canvas.draw_set_transform(hammer_center, angle + PI * 0.5)
	canvas.draw_rect(Rect2(-25, -17, 50, 34), Color("#27303a"))
	outline(canvas, Rect2(-25, -17, 50, 34), color, 4)
	canvas.draw_rect(Rect2(-17, -11, 34, 5), color.darkened(0.38))
	canvas.draw_set_transform(Vector2.ZERO)
