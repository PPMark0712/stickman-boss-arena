class_name ArenaConfig
extends RefCounted
## All feel/balance values live here; units are pixels and seconds.

const FLOOR_Y := 594.0
const LEFT_WALL := 48.0
const RIGHT_WALL := 1232.0
const PLAYER_GRAVITY := 2200.0
const PLAYER_FALL_GRAVITY := 2850.0
const BOSS_GRAVITY := 1900.0
const MAX_FALL := 1200.0
const PLAYER_HEIGHT := 70.0
const PLAYER_JUMP_HEIGHT := PLAYER_HEIGHT * 1.8
const RUN_SPEED := 350.0
const JUMP_SPEED := 736.0
const DOUBLE_JUMP_SPEED := JUMP_SPEED
const COYOTE_TIME := 0.11
const JUMP_BUFFER := 0.14
const ATTACK_BUFFER := 0.16
const DASH_BUFFER := 0.12
const HURT_DURATION := 0.24
const CAST_DURATION := 0.24
const CAST_CANCEL_TIME := 0.16
const ATTACK_DURATION := 0.32
const ATTACK_START := 0.07
const ATTACK_END := 0.22
const ATTACK_REACH := 142.0
const ATTACK_HEIGHT := 56.0
const ATTACK_TOP := -73.0
const AIR_ATTACK_DURATION := 0.34
const AIR_ATTACK_START := 0.065
const AIR_ATTACK_END := 0.235
const VERTICAL_ATTACK_WIDTH := 112.0
const UP_ATTACK_REACH := 128.0
const DOWN_ATTACK_REACH := 132.0
const ATTACK_HIT_RECOIL := 105.0
const ATTACK_HIT_RECOIL_TIME := 0.075
const DOWN_SLASH_BOUNCE := 610.0
const DASH_SPEED := 790.0
const DASH_DURATION := 0.14
const DASH_COOLDOWN := 0.42
const HITSTOP_SCALE := 0.12
const SWORD_DAMAGE := 10
const SPELL_DAMAGE := SWORD_DAMAGE * 3
const MAX_HEALTH := 6
const MAX_ENERGY := 9
const ENERGY_COST := 3
const FOCUS_TAP_TIME := 0.10
const HEAL_START_TIME := 0.30
const HEAL_CHANNEL_TIME := 1.0
const HEAL_DRAIN_INTERVAL := HEAL_CHANNEL_TIME / ENERGY_COST
const HEAL_COMPLETE_TIME := HEAL_START_TIME + HEAL_CHANNEL_TIME
const INVULNERABILITY := 0.9
const HAMMER_HEALTH := 400
const MIRROR_HEALTH := 300
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
		"dash": [KEY_C],
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
