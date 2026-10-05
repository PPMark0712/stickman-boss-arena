@tool
class_name ProceduralFighterVisual
extends Node2D
## Editable AnimationPlayer front-end for the code-drawn fighters.

enum FighterKind { PLAYER, QUARRY, PRISM }

@export_enum("Player", "The Quarry", "The Prism") var fighter_kind: int = FighterKind.PLAYER:
	set(value):
		fighter_kind = value
		queue_redraw()
@export_enum(
	"idle", "run", "air", "attack", "up", "down", "dash", "cast", "heal",
	"hurt", "windup", "slam", "recover", "apex", "dive", "impact", "settle"
) var pose := "idle":
	set(value):
		pose = value
		queue_redraw()
@export_range(0.0, 1.0, 0.001) var animation_progress := 0.0:
	set(value):
		animation_progress = value
		queue_redraw()
@export var animation_clock := 0.0:
	set(value):
		animation_clock = value
		queue_redraw()
@export_range(0, 2, 1) var variant := 0:
	set(value):
		variant = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var squash := 0.0:
	set(value):
		squash = value
		queue_redraw()
@export var airborne := false:
	set(value):
		airborne = value
		queue_redraw()
@export_range(-1200.0, 1200.0, 1.0) var vertical_velocity := 0.0:
	set(value):
		vertical_velocity = value
		queue_redraw()
@export_range(-800.0, 800.0, 1.0) var horizontal_velocity := 0.0:
	set(value):
		horizontal_velocity = value
		queue_redraw()
@export var weapon_in_front := true:
	set(value):
		weapon_in_front = value
		queue_redraw()
@export var tint := ArenaConfig.INK:
	set(value):
		tint = value
		queue_redraw()

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var blended_rig: Dictionary = {}
var blend_from: Dictionary = {}
var last_pose := ""
var blend_elapsed := 1.0
var blend_duration := 0.06

func restart_pose_blend() -> void:
	# A new swing may use the same pose name as the previous swing.
	last_pose = ""

func advance_pose_blend(delta: float) -> void:
	if fighter_kind != FighterKind.PLAYER:
		return
	if pose != last_pose:
		blend_from = blended_rig.duplicate()
		blend_elapsed = 0.0
		blend_duration = 0.035 if pose in ["attack", "up", "down", "hurt", "dash"] else 0.075
		last_pose = pose
	blend_elapsed += delta
	var target := BoxArt.player_rig(pose, animation_clock, animation_progress, variant, squash, airborne, vertical_velocity, horizontal_velocity)
	var weight := smoothstep(0.0, blend_duration, blend_elapsed)
	blended_rig = target
	if weight < 1.0 and not blend_from.is_empty():
		for key in target:
			if key == "sword_angle":
				blended_rig[key] = lerp_angle(blend_from[key], target[key], weight)
			else:
				blended_rig[key] = (blend_from[key] as Vector2).lerp(target[key], weight)
		# Keep the sword attached to the hand while interpolating the shoulder.
		if pose in ["attack", "up", "down"]:
			blended_rig.front_elbow = BoxArt._two_bone_elbow(blended_rig.front_shoulder, blended_rig.front_hand, 18, -1 if pose == "down" else 1)
	queue_redraw()

func sample(animation_name: StringName, normalized_time: float, fallback_pose: String) -> void:
	if not is_instance_valid(animation_player):
		pose = fallback_pose
		animation_progress = clampf(normalized_time, 0.0, 1.0)
		return
	if not animation_player.has_animation(animation_name):
		pose = fallback_pose
		animation_progress = clampf(normalized_time, 0.0, 1.0)
		return
	var animation := animation_player.get_animation(animation_name)
	if animation_player.assigned_animation != animation_name:
		animation_player.play(animation_name)
		animation_player.pause()
	animation_player.seek(clampf(normalized_time, 0.0, 1.0) * animation.length, true)

func sample_loop(animation_name: StringName, elapsed: float, fallback_pose: String) -> void:
	if not is_instance_valid(animation_player) or not animation_player.has_animation(animation_name):
		pose = fallback_pose
		animation_clock = elapsed
		return
	var animation := animation_player.get_animation(animation_name)
	var local_time := fmod(maxf(elapsed, 0.0), maxf(animation.length, 0.001))
	sample(animation_name, local_time / maxf(animation.length, 0.001), fallback_pose)
	# Procedural sin/cos cycles need an unbroken phase; clip lengths are arbitrary.
	animation_clock = elapsed

func _draw() -> void:
	if fighter_kind == FighterKind.PLAYER:
		BoxArt.player_fighter(
			self,
			pose,
			animation_clock,
			tint,
			animation_progress,
			variant,
			squash,
			airborne,
			{} if Engine.is_editor_hint() else blended_rig,
			vertical_velocity,
			horizontal_velocity,
		)
		return
	BoxArt.fighter(
		self,
		pose,
		animation_clock,
		tint,
		fighter_kind == FighterKind.QUARRY,
		animation_progress,
		variant,
		squash,
		weapon_in_front,
	)
