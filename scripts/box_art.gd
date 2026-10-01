class_name BoxArt
extends RefCounted
## Even diagonals, particles and curved-looking effects are made of rectangles.

static func bar(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	canvas.draw_set_transform((a + b) * 0.5, (b - a).angle())
	canvas.draw_rect(Rect2(-a.distance_to(b) * 0.5, -width * 0.5, a.distance_to(b), width), color)
	canvas.draw_set_transform(Vector2.ZERO)

static func outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float = 2.0) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), color)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y)), color)

static func fighter(canvas: CanvasItem, pose: String, clock: float, color: Color, heavy: bool = false) -> void:
	var stride := sin(clock * 15.0) * (12.0 if pose == "run" else 2.0)
	var lean := 0.0
	if pose == "hurt":
		lean = -13.0
	elif pose == "air":
		lean = 5.0
	elif pose == "heal":
		lean = -5.0
	var hip := Vector2(lean * 0.25, -26)
	var shoulder := Vector2(lean, -52)
	var head := Rect2(lean - 10, -76, 20, 20)
	canvas.draw_rect(head, Color("#101c27"))
	outline(canvas, head, color, 3)
	canvas.draw_rect(Rect2(lean + 4, -69, 9, 3), color)
	bar(canvas, shoulder, hip, 6, color)
	bar(canvas, hip, Vector2(-13 - stride, -2), 5, color)
	bar(canvas, hip, Vector2(13 + stride, -2), 5, color)
	var hand := Vector2(25, -32)
	if pose == "attack":
		hand = Vector2(42, -44)
	elif pose == "up":
		hand = Vector2(6, -86)
	elif pose == "down":
		hand = Vector2(10, -12)
	elif pose == "heal":
		hand = Vector2(4, -39)
	elif pose == "windup":
		hand = Vector2(-22, -83)
	elif pose == "slam":
		hand = Vector2(38, -12)
	bar(canvas, shoulder, hand, 4, color)
	bar(canvas, shoulder + Vector2(-2, 2), Vector2(-19, -34 - stride * 0.3), 4, color)
	if heavy:
		# Broad shoulder plate and a large rectangular hammer.
		outline(canvas, Rect2(lean - 19, -56, 38, 15), color, 3)
		var tip := hand + Vector2(25, -32)
		if pose == "slam":
			tip = hand + Vector2(24, 4)
		elif pose == "windup":
			tip = hand + Vector2(-12, -29)
		bar(canvas, hand, tip, 5, color)
		canvas.draw_rect(Rect2(tip - Vector2(18, 12), Vector2(36, 24)), Color("#27303a"))
		outline(canvas, Rect2(tip - Vector2(18, 12), Vector2(36, 24)), color, 3)
	else:
		var tip := hand + Vector2(30, -28)
		if pose == "attack":
			tip = hand + Vector2(49, 0)
		elif pose == "up":
			tip = hand + Vector2(0, -38)
		elif pose == "down":
			tip = hand + Vector2(0, 42)
		bar(canvas, hand, tip, 4, color)
		bar(canvas, hand + Vector2(-5, -4), hand + Vector2(6, 6), 4, ArenaConfig.AMBER)
