class_name ArenaConfig
extends RefCounted
## All feel/balance values live here; units are pixels and seconds.

const FLOOR_Y := 594.0
const LEFT_WALL := 48.0
const RIGHT_WALL := 1232.0
const GRAVITY := 1900.0
const FALL_GRAVITY := 2450.0
const MAX_FALL := 1100.0
const RUN_SPEED := 330.0
const ACCELERATION := 2600.0
const FRICTION := 3200.0
const AIR_ACCELERATION := 1900.0
const JUMP_SPEED := 690.0
const DOUBLE_JUMP_SPEED := 610.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const ATTACK_DURATION := 0.30
const ATTACK_START := 0.055
const ATTACK_END := 0.19
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
