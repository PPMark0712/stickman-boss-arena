class_name BoxArt
extends RefCounted
## Procedural geometric art shared by fighters and combat effects.

const HEAVY_HAMMER_REACH := 64.0
const HEAVY_HAMMER_HEAD_RADIUS := 30.0
const HEAVY_HAMMER_SILVER := Color("#b8c3cb")
const HEAVY_HAMMER_SILVER_DARK := Color("#66737d")
const HEAVY_HAMMER_SILVER_HIGHLIGHT := Color("#edf2f5")

class HeavyPose extends RefCounted:
	var body_lean := 0.0
	var body_lift := 0.0
	var hammer_angle := -2.22
	var right_grip := Vector2(27, -28)
	var left_foot := Vector2(-17, -2)
	var right_foot := Vector2(17, -2)

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

static func slash_arc(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	variant: int,
	color: Color,
	alpha: float,
	reach: float,
) -> void:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var start_angle := -1.16 if variant == 0 else -0.76
	var end_angle := 0.76 if variant == 0 else 1.16
	var radii := [reach, reach - 11.0, reach - 23.0]
	var widths := [5.0, 11.0, 3.0]
	var highlight := Color.WHITE if color == ArenaConfig.INK else color.lightened(0.28)
	var colors := [
		Color(color.darkened(0.72), alpha * 0.62),
		Color(color, alpha * 0.86),
		Color(highlight, alpha),
	]
	for band in 3:
		var previous := Vector2.ZERO
		for i in 12:
			var phase := float(i) / 11.0
			var angle := lerpf(start_angle, end_angle, phase)
			var radius: float = radii[band]
			var point := (
				origin
				+ forward * cos(angle) * radius
				+ side * sin(angle) * radius * 0.68
			)
			if i > 0:
				bar(canvas, previous, point, widths[band], colors[band])
			previous = point
	for phase in [0.08, 0.50, 0.92]:
		var angle := lerpf(start_angle, end_angle, phase)
		var inner := (
			origin
			+ forward * cos(angle) * (reach - 25.0)
			+ side * sin(angle) * (reach - 25.0) * 0.68
		)
		var outer := (
			origin
			+ forward * cos(angle) * reach
			+ side * sin(angle) * reach * 0.68
		)
		bar(canvas, inner, outer, 3.0, Color(color, alpha * 0.48))

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
			front_hand = _player_attack_hand(chest, progress, variant)
			front_elbow = _two_bone_elbow(front_shoulder, front_hand, 18, 1)
			rear_elbow = rear_shoulder + Vector2(-11, 8)
			rear_hand = rear_elbow + Vector2(-9, 7)
			sword_angle = _player_sword_angle(pose, progress, variant)
		"up":
			var strike := _ease_segment(progress, 0.14, 0.72)
			front_hand = chest + Vector2(-10, 12).lerp(Vector2(15, -13), strike)
			front_elbow = _two_bone_elbow(front_shoulder, front_hand, 18, 1)
			rear_elbow = rear_shoulder + Vector2(-12, 8)
			rear_hand = rear_elbow + Vector2(-8, 7)
			sword_angle = _player_sword_angle(pose, progress, variant)
		"down":
			var strike := _ease_segment(progress, 0.14, 0.72)
			front_hand = chest + Vector2(-10, -13).lerp(Vector2(16, 13), strike)
			front_elbow = _two_bone_elbow(front_shoulder, front_hand, 18, -1)
			rear_elbow = rear_shoulder + Vector2(-12, 5)
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
		_draw_player_sword(
			canvas,
			pose,
			color,
			chest,
			front_hand,
			sword_angle,
			progress,
			variant,
		)

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

static func _player_attack_hand(chest: Vector2, progress: float, variant: int) -> Vector2:
	var strike := _ease_segment(progress, 0.15, 0.70)
	var recover := _ease_segment(progress, 0.76, 1.0)
	var hand_start := Vector2(-15, -17) if variant == 0 else Vector2(22, -17)
	var hand_control := Vector2(7, -7) if variant == 0 else Vector2(5, -5)
	var hand_finish := Vector2(24, 14) if variant == 0 else Vector2(-14, 14)
	var first_half := hand_start.lerp(hand_control, strike)
	var second_half := hand_control.lerp(hand_finish, strike)
	var hand := chest + first_half.lerp(second_half, strike)
	return hand.lerp(chest + Vector2(14, 9), recover)

static func _player_sword_angle(pose: String, progress: float, variant: int) -> float:
	if pose == "up":
		if progress < 0.16:
			return lerp_angle(-0.45, 2.10, _ease_segment(progress, 0.0, 0.16))
		if progress < 0.74:
			return lerp_angle(2.10, -1.18, _ease_segment(progress, 0.16, 0.74))
		return lerp_angle(-1.18, -0.45, _ease_segment(progress, 0.74, 1.0))
	if pose == "down":
		if progress < 0.16:
			return lerp_angle(-0.45, -2.10, _ease_segment(progress, 0.0, 0.16))
		if progress < 0.74:
			return lerp_angle(-2.10, 1.18, _ease_segment(progress, 0.16, 0.74))
		return lerp_angle(1.18, -0.45, _ease_segment(progress, 0.74, 1.0))
	var windup := -2.12 if variant == 0 else -0.78
	var finish := 0.74 if variant == 0 else 2.30
	if progress < 0.17:
		return lerp_angle(-0.62, windup, _ease_segment(progress, 0.0, 0.17))
	if progress < 0.72:
		return lerp_angle(windup, finish, _ease_segment(progress, 0.17, 0.72))
	return lerp_angle(finish, -0.62, _ease_segment(progress, 0.72, 1.0))

static func _draw_player_sword(
	canvas: CanvasItem,
	pose: String,
	color: Color,
	chest: Vector2,
	hand: Vector2,
	angle: float,
	progress: float,
	variant: int,
) -> void:
	if pose == "attack":
		for i in range(3, 0, -1):
			var old_progress := maxf(0.0, progress - i * 0.035)
			var old_angle := _player_sword_angle(pose, old_progress, variant)
			var old_hand := _player_attack_hand(chest, old_progress, variant)
			var old_tip := old_hand + Vector2.from_angle(old_angle) * 66
			bar(
				canvas,
				old_hand,
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
	var motion := _heavy_motion(pose, progress, clock)
	var stride := sin(gait) * 8.0 if pose == "run" else 0.0
	var bounce := absf(cos(gait)) * 1.2 if pose == "run" else sin(clock * 2.4) * 0.45
	var body_center := Vector2(
		motion.body_lean * 0.35,
		-48 + bounce + squash * 5 + motion.body_lift,
	)
	var body_rect := Rect2(body_center - Vector2(23, 28), Vector2(46, 56))
	var left_hip := body_center + Vector2(-12, 27)
	var right_hip := body_center + Vector2(12, 27)
	var left_foot := motion.left_foot + Vector2(-stride, 0)
	var right_foot := motion.right_foot + Vector2(stride, 0)
	var left_knee := left_hip.lerp(left_foot, 0.52) + Vector2(-5, 1)
	var right_knee := right_hip.lerp(right_foot, 0.52) + Vector2(5, 1)
	_limb(canvas, left_hip, left_knee, left_foot, 8, Color(color, color.a * 0.78))
	_limb(canvas, right_hip, right_knee, right_foot, 8, color)

	var shaft_direction := Vector2.from_angle(motion.hammer_angle)
	var right_grip := body_center + motion.right_grip
	var left_grip := right_grip - shaft_direction * 34
	var shaft_start := left_grip - shaft_direction * 5
	var hammer_center := right_grip + shaft_direction * HEAVY_HAMMER_REACH
	var left_shoulder := body_center + Vector2(8, -15)
	var right_shoulder := body_center + Vector2(18, -21)
	var left_elbow := _two_bone_elbow(left_shoulder, left_grip, 27, 1)
	var right_elbow := _two_bone_elbow(right_shoulder, right_grip, 27, 1)
	var rear_color := Color(color, color.a * 0.68)
	if not weapon_in_front:
		_draw_heavy_hammer(canvas, shaft_start, hammer_center, motion.hammer_angle, color)
	if weapon_in_front:
		_limb(canvas, left_shoulder, left_elbow, left_grip, 7, rear_color)
		canvas.draw_rect(Rect2(left_grip - Vector2(4, 4), Vector2(8, 8)), rear_color)
	else:
		_limb(canvas, right_shoulder, right_elbow, right_grip, 7, rear_color)
		canvas.draw_rect(Rect2(right_grip - Vector2(4, 4), Vector2(8, 8)), rear_color)

	canvas.draw_rect(body_rect, Color("#202a33"))
	outline(canvas, body_rect, color, 4)
	var head_center := body_center + Vector2(motion.body_lean * 0.12, -42)
	var head := Rect2(head_center - Vector2(12, 11), Vector2(24, 22))
	canvas.draw_rect(head, Color("#101c27"))
	outline(canvas, head, color, 4)
	canvas.draw_rect(Rect2(head_center + Vector2(3, -3), Vector2(10, 4)), color)

	if weapon_in_front:
		_draw_heavy_hammer(canvas, shaft_start, hammer_center, motion.hammer_angle, color)
	if weapon_in_front:
		_limb(canvas, right_shoulder, right_elbow, right_grip, 7, color)
		canvas.draw_rect(Rect2(right_grip - Vector2(4, 4), Vector2(8, 8)), color)
	else:
		_limb(canvas, left_shoulder, left_elbow, left_grip, 7, color)
		canvas.draw_rect(Rect2(left_grip - Vector2(4, 4), Vector2(8, 8)), color)

static func _heavy_motion(pose: String, progress: float, clock: float) -> HeavyPose:
	var rest := _heavy_key_pose("rest")
	match pose:
		"run":
			rest.body_lift = sin(clock * 8.5) * 1.5
			rest.hammer_angle += sin(clock * 8.5) * 0.045
			rest.right_grip += Vector2(0, cos(clock * 8.5) * 1.5)
			return rest
		"windup":
			return _blend_heavy_poses(rest, _heavy_key_pose("raised"), _ease_in_out(progress))
		"slam":
			return _blend_heavy_poses(
				_heavy_key_pose("raised"),
				_heavy_key_pose("impact"),
				_ease_in(progress),
			)
		"recover":
			return _blend_heavy_poses(
				_heavy_key_pose("impact"),
				_heavy_key_pose("raised"),
				_ease_in_out(progress),
			)
		"attack":
			var spin := _heavy_key_pose("overhead_air")
			var rotation := progress * TAU
			spin.body_lean += sin(rotation) * 7.0
			spin.right_grip += Vector2(
				sin(rotation) * 4.0,
				sin(rotation) * 5.0 + sin(progress * PI) * 15.0,
			)
			spin.hammer_angle += rotation
			return spin
		"apex":
			return _heavy_key_pose("overhead_air")
		"dive":
			return _blend_heavy_poses(
				_heavy_key_pose("overhead_air"),
				_heavy_key_pose("impact"),
				_ease_in(progress),
			)
		"impact":
			return _heavy_key_pose("impact")
		"air":
			return _heavy_key_pose("airborne")
		"hurt":
			return _heavy_key_pose("hurt")
	return rest

static func _heavy_key_pose(name: String) -> HeavyPose:
	var key := HeavyPose.new()
	match name:
		"raised":
			key.body_lean = -7.0
			key.body_lift = -1.0
			key.hammer_angle = -1.55
			key.right_grip = Vector2(24, -45)
			key.left_foot = Vector2(-22, -2)
			key.right_foot = Vector2(22, -2)
		"impact":
			key.body_lean = 12.0
			key.body_lift = 3.0
			key.hammer_angle = 0.78
			key.right_grip = Vector2(32, -4)
			key.left_foot = Vector2(-26, -2)
			key.right_foot = Vector2(25, -2)
		"overhead_air":
			key.body_lean = -7.0
			key.body_lift = -1.0
			key.hammer_angle = -1.55
			key.right_grip = Vector2(24, -45)
			key.left_foot = Vector2(-21, -10)
			key.right_foot = Vector2(20, -7)
		"airborne":
			key.body_lean = 4.0
			key.body_lift = -6.0
			key.hammer_angle = -1.90
			key.right_grip = Vector2(26, -32)
			key.left_foot = Vector2(-21, -10)
			key.right_foot = Vector2(20, -7)
		"hurt":
			key.body_lean = -10.0
			key.body_lift = 2.0
			key.hammer_angle = 0.42
			key.right_grip = Vector2(22, -17)
			key.left_foot = Vector2(-20, -2)
			key.right_foot = Vector2(13, -2)
	return key

static func _blend_heavy_poses(from: HeavyPose, to: HeavyPose, weight: float) -> HeavyPose:
	var blend := HeavyPose.new()
	blend.body_lean = lerpf(from.body_lean, to.body_lean, weight)
	blend.body_lift = lerpf(from.body_lift, to.body_lift, weight)
	blend.hammer_angle = lerp_angle(from.hammer_angle, to.hammer_angle, weight)
	blend.right_grip = from.right_grip.lerp(to.right_grip, weight)
	blend.left_foot = from.left_foot.lerp(to.left_foot, weight)
	blend.right_foot = from.right_foot.lerp(to.right_foot, weight)
	return blend

static func heavy_rig_snapshot(
	pose: String,
	progress: float,
	clock: float = 0.0,
) -> Dictionary:
	var motion := _heavy_motion(pose, progress, clock)
	var body_center := Vector2(motion.body_lean * 0.35, -48 + motion.body_lift)
	var shaft_direction := Vector2.from_angle(motion.hammer_angle)
	var right_grip := body_center + motion.right_grip
	var left_grip := right_grip - shaft_direction * 34
	var hammer_center := right_grip + shaft_direction * HEAVY_HAMMER_REACH
	var left_shoulder := body_center + Vector2(8, -15)
	var right_shoulder := body_center + Vector2(18, -21)
	return {
		"body_center": body_center,
		"hammer_center": hammer_center,
		"hammer_radius": HEAVY_HAMMER_HEAD_RADIUS,
		"left_grip": left_grip,
		"right_grip": right_grip,
		"left_shoulder": left_shoulder,
		"right_shoulder": right_shoulder,
		"left_elbow": _two_bone_elbow(left_shoulder, left_grip, 27, 1),
		"right_elbow": _two_bone_elbow(right_shoulder, right_grip, 27, 1),
	}

static func player_attack_rig_snapshot(progress: float, variant: int) -> Dictionary:
	var chest := Vector2(0, -51)
	var shoulder := chest + Vector2(3, 3)
	var hand := _player_attack_hand(chest, progress, variant)
	return {
		"shoulder": shoulder,
		"elbow": _two_bone_elbow(shoulder, hand, 18, 1),
		"hand": hand,
		"sword_angle": _player_sword_angle("attack", progress, variant),
	}

static func _ease_in(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t

static func _ease_in_out(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _two_bone_elbow(
	shoulder: Vector2,
	hand: Vector2,
	segment_length: float,
	bend_side: float,
) -> Vector2:
	var span := hand - shoulder
	var distance := span.length()
	if distance <= 0.001:
		return shoulder + Vector2(segment_length * bend_side, 0)
	var half_span := minf(distance, segment_length * 2.0) * 0.5
	var bend := sqrt(maxf(segment_length * segment_length - half_span * half_span, 0.0))
	var normal := Vector2(-span.y, span.x).normalized() * bend_side
	return shoulder.lerp(hand, 0.5) + normal * bend

static func _draw_heavy_hammer(
	canvas: CanvasItem,
	shaft_start: Vector2,
	hammer_center: Vector2,
	angle: float,
	color: Color,
) -> void:
	var silver := Color(HEAVY_HAMMER_SILVER, color.a)
	var silver_dark := Color(HEAVY_HAMMER_SILVER_DARK, color.a)
	var silver_highlight := Color(HEAVY_HAMMER_SILVER_HIGHLIGHT, color.a)
	var gold := Color(ArenaConfig.AMBER, color.a)
	bar(canvas, shaft_start, hammer_center, 8, silver_dark)
	bar(canvas, shaft_start, hammer_center, 5, silver)
	canvas.draw_set_transform(hammer_center, angle)
	for i in 8:
		var spike_angle := i * TAU / 8.0
		var direction := Vector2.from_angle(spike_angle)
		var normal := Vector2(-direction.y, direction.x)
		var base := direction * 21
		canvas.draw_colored_polygon(PackedVector2Array([
			base - normal * 4,
			direction * HEAVY_HAMMER_HEAD_RADIUS,
			base + normal * 4,
		]), gold)
	canvas.draw_circle(Vector2.ZERO, 24, silver_dark)
	canvas.draw_circle(Vector2.ZERO, 19, silver)
	canvas.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, silver_highlight, 3)
	for stud_angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var stud := Vector2.from_angle(stud_angle) * 10
		canvas.draw_circle(stud, 2.5, gold)
	canvas.draw_circle(Vector2.ZERO, 5, gold)
	canvas.draw_set_transform(Vector2.ZERO)
