extends Node

var room: ArenaRoom
var ui: Control
var overlay: Control
var hud: Control
var menu: Control
var health_label: Label
var energy_label: Label
var boss_bar: ProgressBar
var phase_label: Label
var time_label: Label
var toast: Label
var toast_time := 0.0
var current_kind := 0
var practice := false
var paused := false
var records := ConfigFile.new()
var theme_: Theme
var menu_clock := 0.0
var previews: Array[Node2D] = []
var mute_button: Button
var result_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ArenaConfig.install_input()
	records.load("user://records.cfg")
	build_theme()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = theme_
	layer.add_child(ui)
	show_menu()

func build_theme() -> void:
	theme_ = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/ArenaSans.ttf"):
		theme_.default_font = load("res://assets/fonts/ArenaSans.ttf")
	theme_.default_font_size = 17
	theme_.set_color("font_color", "Label", ArenaConfig.INK)
	for state_ in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#14232b") if state_ == "normal" else Color("#233d43")
		style.border_color = ArenaConfig.TEAL if state_ in ["hover", "focus"] else Color("#34454d")
		style.set_border_width_all(2 if state_ == "focus" else 1)
		style.content_margin_left = 18
		style.content_margin_right = 18
		theme_.set_stylebox(state_, "Button", style)
	theme_.set_color("font_color", "Button", ArenaConfig.INK)
	theme_.set_color("font_hover_color", "Button", Color.WHITE)
	theme_.set_color("font_focus_color", "Button", ArenaConfig.TEAL)

func panel(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func label(parent: Node, text: String, pos: Vector2, font_size: int = 18, tint: Color = ArenaConfig.INK) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(func() -> void:
		Sfx.play("select")
		callback.call()
	)
	parent.add_child(node)
	return node

func clear_ui() -> void:
	for child in ui.get_children():
		child.queue_free()
	previews.clear()
	menu = null
	hud = null
	overlay = null
	toast = null

func show_menu() -> void:
	get_tree().paused = false
	paused = false
	result_open = false
	if is_instance_valid(room):
		room.queue_free()
		room = null
	clear_ui()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	panel(menu, Rect2(0, 0, 1280, 720), ArenaConfig.BACKGROUND)
	panel(menu, Rect2(48, 81, 1184, 1), Color("#2b3943"))
	label(menu, "S T I C K M A N   /   B O S S  A R E N A", Vector2(48, 28), 20)
	label(menu, "01 — 02    /    DUEL COLLECTION", Vector2(844, 35), 13, ArenaConfig.MUTED)
	top_buttons(menu)
	label(menu, "一柄剑。两场决斗。", Vector2(48, 105), 43)
	label(menu, "读懂前摇，抓住空档。选择你的对手。", Vector2(51, 170), 17, ArenaConfig.MUTED)
	boss_card(0, Vector2(48, 229))
	boss_card(1, Vector2(652, 229))
	var practice_button := CheckButton.new()
	practice_button.text = "练习模式  ·  无限生命与能量，成绩不计入纪录"
	practice_button.position = Vector2(48, 561)
	practice_button.size = Vector2(650, 40)
	practice_button.button_pressed = practice
	practice_button.toggled.connect(func(enabled: bool) -> void: practice = enabled)
	menu.add_child(practice_button)
	label(menu, "键盘操作  /  支持全屏", Vector2(1011, 573), 15, ArenaConfig.MUTED)
	controls_footer(menu)
	menu.get_node("Boss0").grab_focus()

func boss_card(kind: int, pos: Vector2) -> void:
	var accent := ArenaConfig.AMBER if kind == 0 else ArenaConfig.VIOLET
	panel(menu, Rect2(pos, Vector2(580, 312)), Color("#111c27"))
	panel(menu, Rect2(pos, Vector2(3, 312)), accent)
	label(menu, "0%d  /  %s" % [kind + 1, "THE QUARRY" if kind == 0 else "THE PRISM"], pos + Vector2(24, 20), 14, accent)
	label(menu, "裂岩守卫" if kind == 0 else "折光剑使", pos + Vector2(24, 52), 31)
	label(menu, "重锤 · 地震波 · 落石" if kind == 0 else "突刺 · 回旋刃 · 折光落剑", pos + Vector2(25, 109), 16, ArenaConfig.MUTED)
	label(menu, "越过地震，反击重锤的间隙。" if kind == 0 else "跟上剑锋，识破折返的节奏。", pos + Vector2(25, 141), 15, ArenaConfig.MUTED)
	var record_key := str(kind)
	var best: float = records.get_value("best", record_key, 0.0)
	label(menu, "最佳  %s" % format_time(best) if best > 0 else "尚未征服", pos + Vector2(25, 192), 14, accent)
	var start := button(menu, "进入决斗    →", Rect2(pos + Vector2(24, 242), Vector2(532, 46)), start_fight.bind(kind))
	start.name = "Boss%d" % kind
	var art := Node2D.new()
	art.position = pos + Vector2(451, 238 if kind == 0 else 219)
	art.scale = Vector2.ONE * (1.85 if kind == 0 else 1.7)
	art.draw.connect(func() -> void: BoxArt.fighter(art, "idle", menu_clock, accent, kind == 0))
	menu.add_child(art)
	previews.append(art)

func controls_footer(parent: Node) -> void:
	panel(parent, Rect2(48, 620, 1184, 1), Color("#2b3943"))
	var items := [
		["← →", "即时移动"], ["Z", "跳跃 / 二段跳"], ["X", "交替挥砍"],
		["↑/↓ + X", "上劈 / 空中下劈"], ["C", "向前冲刺"],
		["A", "短按法术 / 长按回血"],
	]
	var positions := [48, 204, 384, 546, 760, 913]
	for i in items.size():
		label(parent, items[i][0], Vector2(positions[i], 642), 19, ArenaConfig.TEAL)
		label(parent, items[i][1], Vector2(positions[i], 675), 13, ArenaConfig.MUTED)

func top_buttons(parent: Node) -> void:
	mute_button = button(parent, "静音" if not Sfx.muted else "声音关", Rect2(1080, 24, 72, 34), toggle_sound)
	button(parent, "全屏", Rect2(1162, 24, 70, 34), toggle_fullscreen)

func toggle_sound() -> void:
	Sfx.toggle_mute()
	mute_button.text = "声音关" if Sfx.muted else "静音"

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func start_fight(kind: int) -> void:
	get_tree().paused = false
	paused = false
	result_open = false
	current_kind = kind
	if is_instance_valid(room):
		room.queue_free()
	clear_ui()
	room = ArenaRoom.new()
	room.kind = kind
	room.practice = practice
	# The parent UI processes during pause; the room must explicitly be pausable.
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	room.finished.connect(show_result)
	room.message.connect(show_toast)
	build_hud()
	room.player.stats_changed.connect(refresh_player_hud)
	room.boss.health_changed.connect(refresh_boss_hud)
	room.boss.phase_changed.connect(refresh_boss_hud)
	refresh_player_hud()
	refresh_boss_hud()
	show_toast(
		"练习模式 · 无限生命与能量"
		if practice
		else "X 交替挥砍 · ↑ + X 上劈 · 空中 ↓ + X 下劈",
		3,
	)

func build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	panel(hud, Rect2(0, 0, 1280, 117), Color("#0b111b"))
	label(hud, "WANDERER  /  旅者", Vector2(48, 18), 14, ArenaConfig.TEAL)
	health_label = label(hud, "", Vector2(48, 43), 24, ArenaConfig.INK)
	energy_label = label(hud, "", Vector2(48, 79), 16, ArenaConfig.TEAL)
	var title := "裂岩守卫  /  THE QUARRY" if current_kind == 0 else "折光剑使  /  THE PRISM"
	label(hud, title, Vector2(431, 18), 19, room.boss.color())
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(432, 59)
	boss_bar.size = Vector2(540, 12)
	boss_bar.max_value = room.boss.max_health
	boss_bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#24303a")
	var fill := StyleBoxFlat.new()
	fill.bg_color = room.boss.color()
	boss_bar.add_theme_stylebox_override("background", back)
	boss_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(boss_bar)
	phase_label = label(hud, "PHASE  I", Vector2(432, 82), 12, ArenaConfig.MUTED)
	time_label = label(hud, "", Vector2(880, 82), 13, ArenaConfig.MUTED)
	button(hud, "暂停  Esc", Rect2(1080, 72, 152, 34), toggle_pause)
	top_buttons(hud)
	label(
		hud,
		"← → 即时移动    Z 二段跳    X 交替挥砍    ↑ + X 上劈    空中 ↓ + X 下劈    C 冲刺    A 法术 / 回血",
		Vector2(141, 656),
		15,
		ArenaConfig.MUTED,
	)
	label(hud, "R  重新挑战", Vector2(1073, 687), 12, ArenaConfig.MUTED)
	toast = label(hud, "", Vector2(220, 136), 18, ArenaConfig.TEAL)
	toast.size.x = 840
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	menu_clock += delta
	for art in previews:
		if is_instance_valid(art):
			art.queue_redraw()
	if is_instance_valid(room) and is_instance_valid(hud):
		var current_time := format_time(room.elapsed)
		if time_label.text != current_time:
			time_label.text = current_time
		if not paused:
			toast_time -= delta
			toast.modulate.a = clampf(toast_time * 3, 0, 1)

func refresh_player_hud() -> void:
	if not is_instance_valid(room) or not is_instance_valid(health_label):
		return
	health_label.text = "■ ".repeat(room.player.health) + "□ ".repeat(
		ArenaConfig.MAX_HEALTH - room.player.health
	)
	var energy := room.player.energy
	energy_label.text = "能量  " + "▰".repeat(energy) + "▱".repeat(
		ArenaConfig.MAX_ENERGY - energy
	) + "   %d / 9" % energy

func refresh_boss_hud() -> void:
	if not is_instance_valid(room) or not is_instance_valid(boss_bar):
		return
	boss_bar.value = room.boss.health
	phase_label.text = "PHASE  %s    ·    %d / %d" % [
		"II" if room.boss.phase == 2 else "I",
		room.boss.health,
		room.boss.max_health,
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and is_instance_valid(room) and not result_open:
		toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("retry") and is_instance_valid(room):
		start_fight(current_kind)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(room) and room.combat_active and not paused:
			toggle_pause()

func show_toast(text: String, duration: float = 1.6) -> void:
	if is_instance_valid(toast):
		toast.text = text
		toast_time = duration

func make_overlay() -> void:
	overlay = Control.new()
	ui.add_child(overlay)
	panel(overlay, Rect2(0, 0, 1280, 720), Color(0.02, 0.04, 0.07, 0.88))
	panel(overlay, Rect2(390, 207, 500, 318), Color("#14212c"))
	panel(overlay, Rect2(390, 207, 500, 3), ArenaConfig.TEAL)

func toggle_pause() -> void:
	if not is_instance_valid(room) or not room.combat_active or result_open:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		make_overlay()
		label(overlay, "暂停  /  PAUSED", Vector2(432, 237), 30)
		label(overlay, "留一点时间，读懂下一击。", Vector2(433, 292), 17, ArenaConfig.MUTED)
		var resume_ := button(overlay, "继续决斗", Rect2(432, 344, 416, 45), toggle_pause)
		button(overlay, "重新挑战", Rect2(432, 404, 199, 43), start_fight.bind(current_kind))
		button(overlay, "返回选关", Rect2(649, 404, 199, 43), show_menu)
		label(overlay, "Esc 继续   ·   R 重试", Vector2(433, 478), 13, ArenaConfig.MUTED)
		resume_.grab_focus()
	elif is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
		# A held across focus loss must never complete an unintended heal.
		room.player.focus_time = 0
		room.player.focus_cancelled = Input.is_action_pressed("focus")
		if room.player.state == ArenaPlayer.State.HEAL:
			room.player.change_state(ArenaPlayer.State.IDLE)

func show_result(won: bool, elapsed: float) -> void:
	result_open = true
	var record_save_failed := false
	if won and not practice:
		var best: float = records.get_value("best", str(current_kind), 0.0)
		if best == 0 or elapsed < best:
			records.set_value("best", str(current_kind), elapsed)
			var error := records.save("user://records.cfg")
			if error != OK:
				record_save_failed = true
	make_overlay()
	label(overlay, "挑战完成" if won else "再试一次", Vector2(432, 238), 36, ArenaConfig.TEAL if won else ArenaConfig.DANGER)
	label(overlay, "DUEL WON" if won else "FALL. LEARN. RETURN.", Vector2(434, 295), 13, ArenaConfig.MUTED)
	var detail := "用时  %s%s" % [format_time(elapsed), "   ·   练习模式" if practice else ""]
	label(overlay, detail, Vector2(434, 333), 19)
	var retry := button(overlay, "再次挑战   R", Rect2(432, 394, 199, 46), start_fight.bind(current_kind))
	button(overlay, "返回选关", Rect2(649, 394, 199, 46), show_menu)
	label(
		overlay,
		"纪录保存失败，本次成绩仍可查看" if record_save_failed else "每次挥剑，离胜利更近一步。",
		Vector2(434, 475),
		14,
		ArenaConfig.DANGER if record_save_failed else ArenaConfig.MUTED,
	)
	retry.grab_focus()

func format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]
