extends RefCounted

const NORMAL := ["turn_punch", "jump", "punch", "back", "idle", "walk", "duck_punch", "sweep", "shin"]
const MODIFIED := ["double", "flying", "headbutt", "flip", "idle", "body", "turn_kick", "turn_sweep", "high"]
const WALK_SPEED := 1.35
const BACK_SPEED := 1.15
const LEFT_EDGE := 28.0
const RIGHT_EDGE := 612.0
const JUMP_FRAMES := 36
const FALL_FRAMES := 12
const DOWN_FRAMES := 61
const RISE_FRAMES := 12
const TURN_COMMAND := Vector3i(0, 0, 2)
const DUCK_COMMAND := Vector3i(0, 0, 3)
const PAD_MOVE := 4
const PAD_PUNCH := 5
const PAD_KICK := 6
const PAD_JUMP := 7
const PAD_TURN := 8
const INPUT_BUFFER_FRAMES := 6
const ROLL_FRAMES := 32
const ROLL_SPEED := 2.65
const TURN_ATTACKS := ["turn_punch", "turn_kick", "turn_sweep", "turn_duck_punch"]
const CROUCHED := ["duck", "sweep", "turn_sweep", "duck_punch", "turn_duck_punch", "roll_forward", "roll_back"]
const PLAYER_ATTACKS := [
	["turn_punch", "headbutt", "punch", "turn_punch", "idle", "punch", "turn_duck_punch", "duck_punch", "duck_punch"],
	["turn_kick", "high", "high", "turn_kick", "idle", "body", "turn_sweep", "sweep", "shin"],
	["double", "jump", "double", "flip", "idle", "flying", "roll_back", "jump", "roll_forward"],
]
const MIN_REACH := {"body": 24.0, "high": 24.0, "turn_kick": 24.0, "flying": 22.0, "double": 22.0, "shin": 19.0}
# Reach, height class, points, active frame, duration, forward drift per frame.
const ATTACKS := {
	"punch": [31, "high", 800, 13, 27, 0.29],
	"turn_punch": [31, "high", 800, 14, 29, 0.22],
	"duck_punch": [29, "mid", 400, 13, 28, 0.12],
	"turn_duck_punch": [29, "mid", 400, 13, 28, 0.12],
	"shin": [32, "low", 400, 14, 30, 0.16],
	"sweep": [41, "low", 400, 17, 35, 0.0],
	"turn_sweep": [40, "low", 400, 17, 35, 0.0],
	"flying": [38, "air", 800, 18, 40, 1.18],
	"double": [37, "air", 1000, 16, 37, 0.0],
	"headbutt": [24, "high", 1000, 15, 32, 0.37],
	"body": [35, "mid", 200, 14, 29, 0.18],
	"high": [37, "high", 800, 16, 34, 0.22],
	"turn_kick": [37, "high", 800, 17, 34, 0.08],
}

var x := 320.0
var previous_x := 320.0
var face := 1
var points := 0
var round_score := 0
var total := 0
var down := 0
var protection := 0
var knockback := 0
var fall_height := 0.0
var action := "idle"
var age := 0
var lift := 0.0
var previous_lift := 0.0
var last_move := "idle"
var queued_move := "idle"
var attack_live := false
var extra_windup := 0
var footwork_scale := 1.0
var blocking := false
var hit_frames := 0
var hit_label := ""
var committed := false
var buffered_action := ""
var buffer_left := 0

static func select_move(direction: Vector2i, modifier: bool, facing: int) -> String:
	var index := (direction.y + 1) * 3 + direction.x * facing + 1
	return MODIFIED[index] if modifier else NORMAL[index]

static func player_move(direction: Vector2i, group: int, facing: int) -> String:
	if group == PAD_TURN:
		return "turn"
	if group == PAD_MOVE:
		if direction.y > 0:
			return "duck"
		if direction.x == 0:
			return "idle"
		return "walk" if direction.x == facing else "back"
	var index := (direction.y + 1) * 3 + direction.x * facing + 1
	return PLAYER_ATTACKS[group - PAD_PUNCH][index]

func clear_buffer() -> void:
	buffered_action = ""
	buffer_left = 0

func reset(at: float, facing: int) -> void:
	x = at
	previous_x = at
	face = facing
	points = 0
	round_score = 0
	down = 0
	protection = 0
	knockback = 0
	lift = 0
	previous_lift = 0
	action = "idle"
	age = 0
	last_move = "idle"
	queued_move = "idle"
	attack_live = false
	blocking = false
	hit_frames = 0
	committed = false
	clear_buffer()

func step(command: Vector3i, threat_in_front: bool) -> void:
	previous_x = x
	previous_lift = lift
	attack_live = false
	blocking = false
	protection = maxi(0, protection - 1)
	hit_frames = maxi(0, hit_frames - 1)
	buffer_left = maxi(0, buffer_left - 1)
	if buffer_left == 0:
		buffered_action = ""
	if down > 0:
		clear_buffer()
		down -= 1
		age = DOWN_FRAMES - down
		if age <= FALL_FRAMES:
			var time := float(age) / FALL_FRAMES
			x += knockback * lerpf(1.2, 0.15, time)
			lift = fall_height * (1.0 - time * time)
			limit_position()
		last_move = "idle"
		queued_move = "idle"
		if down == 0:
			action = "idle"
			protection = 21
		return
	var selected := select_move(Vector2i(command.x, command.y), command.z == 1, face)
	var player_input := command.z >= PAD_MOVE
	if player_input:
		var direction := Vector2i(command.x, command.y)
		selected = player_move(direction, PAD_MOVE, face)
		if command.z > PAD_MOVE:
			var requested := player_move(direction, command.z, face)
			if requested != "idle":
				buffered_action = requested
				buffer_left = INPUT_BUFFER_FRAMES
	elif command == TURN_COMMAND:
		selected = "turn"
	elif command == DUCK_COMMAND:
		selected = "duck"
	var changed := selected != last_move
	last_move = selected
	if ATTACKS.has(action):
		var move: Array = ATTACKS[action]
		var impact := impact_frame()
		var duration := int(move[4]) + extra_windup
		if age < impact and changed and not committed:
			action = "idle"
			if lift > 0.0:
				action = "landing"
		else:
			if changed and not committed:
				queued_move = selected
			age += 1
			attack_live = age == impact
			var turning := action in TURN_ATTACKS
			if attack_live and turning:
				face *= -1
				last_move = select_move(Vector2i(command.x, command.y), command.z != 0, face)
			if not turning or age >= impact:
				x += float(move[5]) * face
			if move[1] == "air":
				lift = arc(maxi(0, age - extra_windup), int(move[4]), 25.0)
			if age < duration:
				limit_position()
				return
			action = "idle"
			lift = 0.0
			committed = false
			changed = changed or queued_move == selected
			queued_move = "idle"
			if not player_input and buffer_left == 0 and selected not in ["walk", "back", "idle"] and not changed:
				return
	if action == "landing":
		lift = maxf(0.0, lift - 2.8)
		if lift > 0.0:
			return
		action = "idle"
		changed = true
	if action in ["jump", "flip"]:
		age += 1
		lift = arc(age, JUMP_FRAMES, 32.0)
		if action == "flip":
			x -= 1.55 * face
		limit_position()
		if age < JUMP_FRAMES:
			return
		action = "idle"
		lift = 0.0
		committed = false
	if action in ["roll_forward", "roll_back"]:
		age += 1
		x += ROLL_SPEED * face * (1 if action == "roll_forward" else -1)
		lift = 0.0
		limit_position()
		if age < ROLL_FRAMES:
			return
		action = "idle"
		committed = false
	if buffer_left > 0:
		selected = buffered_action
		clear_buffer()
		changed = true
		committed = true
	if selected == "turn":
		face *= -1
		action = "idle"
		age = 0
		committed = false
	elif selected in ["idle", "walk", "back", "duck"]:
		if action != selected:
			age = 0
		age += 1
		action = selected
		if selected == "walk":
			x += WALK_SPEED * face * footwork_scale
		elif selected == "back":
			blocking = threat_in_front
			if not blocking:
				x -= BACK_SPEED * face * footwork_scale
	elif changed:
		action = selected
		age = 0
		queued_move = "idle"
	limit_position()

func impact_frame() -> int:
	return int(ATTACKS[action][3]) + extra_windup

static func arc(frame: int, duration: int, height: float) -> float:
	return sin(clampf(float(frame) / duration, 0.0, 1.0) * PI) * height

func limit_position() -> void:
	x = clampf(x, LEFT_EDGE, RIGHT_EDGE)

func can_hit(target) -> bool:
	if not attack_live or target.down > 0 or target.protection > 0:
		return false
	var move: Array = ATTACKS[action]
	var distance: float = target.x - x
	var side := 1 if distance > 0 else -1
	if absf(distance) < float(MIN_REACH.get(action, 0.0)) or absf(distance) > float(move[0]):
		return false
	if side != face and action != "double":
		return false
	if target.blocking and target.face == -side and move[1] != "low":
		return false
	if target.lift > 12.0 and move[1] in ["low", "mid"]:
		return false
	if target.action in CROUCHED and move[1] == "high":
		return false
	return absf(lift - float(target.lift)) <= 32.0

func knock_down(from_x: float) -> void:
	committed = false
	clear_buffer()
	down = DOWN_FRAMES
	age = 0
	action = "down"
	fall_height = lift
	face = 1 if from_x >= x else -1
	knockback = -face
