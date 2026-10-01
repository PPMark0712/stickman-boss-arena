class_name ArenaConfig
extends RefCounted
## All feel/balance values live here; units are pixels and seconds.

const FLOOR_Y := 594.0
const LEFT_WALL := 48.0
const RIGHT_WALL := 1232.0
const GRAVITY := 1900.0
const FALL_GRAVITY := 2450.0
const MAX_FALL := 1100.0
const RUN_SPEED := 350.0
const ACCELERATION := 3500.0
const FRICTION := 4300.0
const AIR_ACCELERATION := 2200.0
const JUMP_SPEED := 710.0
const DOUBLE_JUMP_SPEED := 635.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER := 0.14
const ATTACK_BUFFER := 0.16
const COMBO_GRACE := 0.30
const ATTACK_DURATIONS := [0.25, 0.27, 0.34]
const ATTACK_STARTS := [0.045, 0.055, 0.075]
const ATTACK_ENDS := [0.145, 0.165, 0.225]
const COMBO_LUNGES := [105.0, 135.0, 190.0]
const COMBO_REACHES := [96.0, 104.0, 122.0]
const COMBO_HEIGHTS := [64.0, 82.0, 54.0]
const COMBO_TOPS := [-72.0, -91.0, -66.0]
const GROUND_HIT_RECOILS := [48.0, 34.0, 18.0]
const AIR_ATTACK_DURATION := 0.29
const AIR_ATTACK_START := 0.05
const AIR_ATTACK_END := 0.19
const HITSTOP_SCALE := 0.12
const SWORD_DAMAGE := 10
const SPELL_DAMAGE := 24
const MAX_HEALTH := 6
const MAX_ENERGY := 9
const ENERGY_COST := 3
const HEAL_TIME := 1.5
const INVULNERABILITY := 0.9
const HAMMER_HEALTH := 240
const MIRROR_HEALTH := 200
const INK := Color("#e5ede7")
const MUTED := Color("#82939d")
const TEAL := Color("#83e7c2")
const AMBER := Color("#efb76b")
const VIOLET := Color("#b6a1f0")
const DANGER := Color("#f17d7d")
const BACKGROUND := Color("#0b111b")

static func install_input() -> void:
	var actions := {
		"move_left": [KEY_LEFT],
		"move_right": [KEY_RIGHT],
		"look_up": [KEY_UP],
		"look_down": [KEY_DOWN],
		"jump": [KEY_Z],
		"attack": [KEY_X],
		"focus": [KEY_A],
		"pause": [KEY_ESCAPE],
		"retry": [KEY_R],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
