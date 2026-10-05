extends SceneTree
## Deterministic rendered review: run with a display, not --headless.

func _initialize() -> void:
	call_deferred("run")

func caption(parent: Node, text: String, at: Vector2, size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func capture(name_: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/" + name_ + ".png"))
	assert(error == OK)
	print("RENDERED: " + name_)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var room := ArenaRoom.new()
	root.add_child(room)
	room.set_process(false)
	room.player.set_physics_process(false)
	room.boss.set_physics_process(false)
	room.player.position = Vector2(610, ArenaConfig.FLOOR_Y)
	room.boss.position = Vector2(765, ArenaConfig.FLOOR_Y)
	room.boss.facing = -1
	room.boss.visual.scale = Vector2(-1.65, 1.65)
	room.player.state = ArenaPlayer.State.ATTACK
	room.player.state_time = 0.12
	room.player.attack_direction = Vector2.RIGHT
	room.player.sync_visual()
	room.player.visual.airborne = false
	room.player.visual.advance_pose_blend(1.0)
	room.boss.sync_visual()
	room.resolve_sword(room.player, room.player.sword_rect())
	room.effects.queue_redraw()
	caption(room, "COMBAT FEEL / sword impact - dash echo - hammer shock", Vector2(65, 60))
	await capture("feel-player-hit")
	room.sparks.clear()
	room.particles.clear()
	room.player.state = ArenaPlayer.State.DASH
	room.player.sync_visual()
	room.player.visual.advance_pose_blend(1.0)
	for i in 4:
		room.player.position.x = 475 - i * 24
		room._process(0.024)
	room.boss.slam(false, true)
	room.boss.flash = 0
	room.boss.hit_reaction = 0
	room.boss.sync_visual()
	room.boss.visual.queue_redraw()
	room.effects.queue_redraw()
	await capture("feel-quarry-impact")
	room.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	var sheet := Node2D.new()
	root.add_child(sheet)
	caption(sheet, "PLAYER / anticipation - cut - follow-through - recovery", Vector2(55, 35))
	for i in 5:
		var visual: ProceduralFighterVisual = ArenaPlayer.FIGHTER_VISUAL_SCENE.instantiate()
		sheet.add_child(visual)
		visual.position = Vector2(140 + i * 245, 290)
		visual.scale = Vector2.ONE * 1.55
		var time: float = [0.0, 0.055, 0.12, 0.20, 0.32][i]
		visual.sample("attack_a", time / 0.32, "attack")
		visual.advance_pose_blend(1.0)
		caption(sheet, "%.3f s" % time, Vector2(105 + i * 245, 312), 17)
	caption(sheet, "QUARRY / raise - downswing - impact - lift - rest", Vector2(55, 382))
	for i in 5:
		var visual: ProceduralFighterVisual = ArenaBoss.FIGHTER_VISUAL_SCENE.instantiate()
		sheet.add_child(visual)
		visual.fighter_kind = 1
		visual.tint = ArenaConfig.AMBER
		visual.position = Vector2(140 + i * 245, 650)
		visual.scale = Vector2.ONE * 1.32
		var pose: String = ["windup", "slam", "impact", "settle", "idle"][i]
		visual.sample(pose, [1.0, 0.65, 1.0, 0.5, 0.0][i], pose)
		caption(sheet, pose, Vector2(105 + i * 245, 673), 17)
	await capture("feel-motion-sheet")
	sheet.queue_free()
	await process_frame
	await preview_spell()
	await preview_cast_and_dive()
	quit()

func preview_spell() -> void:
	var room := ArenaRoom.new()
	root.add_child(room)
	room.set_process(false)
	room.player.set_physics_process(false)
	room.boss.set_physics_process(false)
	room.player.position.x = 400
	room.boss.position.x = 800
	room.boss.phase = 2
	room.boss.visual.scale = Vector2(-1.65, 1.65)
	room.player.change_state(ArenaPlayer.State.CAST)
	room.player.state_time = 0.08
	room.player.sync_visual()
	room.player.visual.airborne = false
	room.player.visual.advance_pose_blend(1)
	room.spawn_spell(room.player.position + Vector2(36, -39), 1)
	var spell := room.hazards.get_child(-1) as ArenaHazard
	spell.set_physics_process(false)
	spell.position.x = 670
	spell.age = 0.2
	spell.queue_redraw()
	room.effects.queue_redraw()
	caption(room, "SPELL / lowered sword - free-hand cast - luminous projectile", Vector2(65, 60))
	await capture("feel-spell-flight")
	spell._physics_process(0.12)
	room.restore_time_scale()
	room._process(0.035)
	room.boss.sync_visual()
	await capture("feel-spell-impact")
	room.queue_free()
	await process_frame

func preview_cast_and_dive() -> void:
	var sheet := Node2D.new()
	root.add_child(sheet)
	caption(sheet, "CAST / release - recoil - recovery - ready", Vector2(55, 35))
	for i in 4:
		var visual: ProceduralFighterVisual = ArenaPlayer.FIGHTER_VISUAL_SCENE.instantiate()
		sheet.add_child(visual)
		visual.position = Vector2(170 + i * 300, 235)
		visual.scale = Vector2.ONE * 1.6
		visual.sample("cast", [0.0, 0.32, 0.68, 1.0][i], "cast")
		visual.advance_pose_blend(1)
		caption(sheet, ["release", "recoil", "recover", "ready"][i], Vector2(130 + i * 300, 255), 17)
	caption(sheet, "QUARRY / actual descent distance drives the hammer into the floor", Vector2(55, 315))
	for i in 5:
		var visual: ProceduralFighterVisual = ArenaBoss.FIGHTER_VISUAL_SCENE.instantiate()
		sheet.add_child(visual)
		visual.fighter_kind = 1
		visual.tint = ArenaConfig.AMBER
		var progress := i / 4.0
		visual.position = Vector2(140 + i * 245, 650 - (1 - progress) * 110)
		visual.scale = Vector2.ONE * 1.1
		var pose := "dive" if i < 4 else "impact"
		visual.sample(pose, progress, pose)
		caption(sheet, "%d%% descent" % int(progress * 100), Vector2(80 + i * 245, 677), 17)
	await capture("feel-cast-dive-sheet")
	sheet.queue_free()
	await process_frame
