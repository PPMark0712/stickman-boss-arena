extends SceneTree
## Rebuild scenes/fighter_visual.tscn with editable procedural animation tracks.

const OUTPUT := "res://scenes/fighter_visual.tscn"
const VISUAL_SCRIPT := preload("res://scripts/fighter_visual.gd")
const LOOPING := {"idle": true, "run": true, "air": true, "heal": true}
const SPECS := {
	"idle": ["idle", 1.0, [0.0, 1.0]],
	"run": ["run", 0.45, [0.0, 1.0]],
	"air": ["air", 0.6, [0.0, 1.0]],
	"attack_a": ["attack", 0.32, [0.0, 0.16, 0.72, 1.0]],
	"attack_b": ["attack", 0.32, [0.0, 0.16, 0.72, 1.0]],
	"up": ["up", 0.34, [0.0, 0.16, 0.74, 1.0]],
	"down": ["down", 0.34, [0.0, 0.16, 0.74, 1.0]],
	"dash": ["dash", 0.14, [0.0, 1.0]],
	"cast": ["cast", 0.24, [0.0, 1.0]],
	"heal": ["heal", 1.0, [0.0, 1.0]],
	"hurt": ["hurt", 0.24, [0.0, 1.0]],
	"windup": ["windup", 0.68, [0.0, 0.35, 1.0]],
	"slam": ["slam", 0.18, [0.0, 0.25, 1.0]],
	"recover": ["recover", 0.56, [0.0, 1.0]],
	"apex": ["apex", 0.3, [0.0, 1.0]],
	"dive": ["dive", 0.3, [0.0, 0.65, 1.0]],
	"impact": ["impact", 0.5, [0.0, 1.0]],
	"attack": ["attack", 0.5, [0.0, 0.25, 0.5, 0.75, 1.0]],
	"settle": ["settle", 0.32, [0.0, 1.0]],
}

func _init() -> void:
	var root: Node2D = VISUAL_SCRIPT.new()
	root.name = "FighterVisual"
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	library.add_animation("RESET", make_animation("idle", 0.0, [0.0]))
	for animation_name in SPECS:
		var spec: Array = SPECS[animation_name]
		var animation := make_animation(spec[0], spec[1], spec[2])
		if animation_name in ["attack_a", "attack_b"]:
			# Anticipation, fast cut, held follow-through, then a soft recovery.
			animation.track_set_key_time(1, 1, 0.055)
			animation.track_set_key_time(1, 2, 0.17)
			var variant_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(variant_track, NodePath(".:variant"))
			animation.value_track_set_update_mode(variant_track, Animation.UPDATE_DISCRETE)
			animation.track_insert_key(variant_track, 0.0, 1 if animation_name == "attack_b" else 0)
		if LOOPING.has(animation_name):
			animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(animation_name, animation)
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	if error != OK:
		push_error("Could not create %s: %s" % [OUTPUT, error_string(error)])
	root.free()
	quit(error)

func make_animation(pose_name: String, duration: float, progress_keys: Array) -> Animation:
	var animation := Animation.new()
	animation.length = maxf(duration, 0.001)
	var pose_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(pose_track, NodePath(".:pose"))
	animation.value_track_set_update_mode(pose_track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(pose_track, 0.0, pose_name)
	var progress_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(progress_track, NodePath(".:animation_progress"))
	for value in progress_keys:
		var progress: float = value
		animation.track_insert_key(progress_track, progress * animation.length, progress)
	var clock_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(clock_track, NodePath(".:animation_clock"))
	animation.track_insert_key(clock_track, 0.0, 0.0)
	animation.track_insert_key(clock_track, animation.length, animation.length)
	return animation
