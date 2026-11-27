extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const CENTER := 320.0
const FLOOR := 310.0
const SHIELD_CENTER := 273.0
const SHIELD_STEP := 16.0
const BALL_LIMIT := 18
const BOMB_LIMIT := 12
const PRACTICE_BALLS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]
const PRACTICE_READY_TICKS := 60
const PRACTICE_SPEED := 1.80
const PRACTICE_SPEED_STEP := 0.32
const PRACTICE_START_DISTANCE := 296.0
const PRACTICE_START_Y := 246.0
const PRACTICE_BOUNCE_Y := FLOOR - 8.0
const PRACTICE_CONTACT_DISTANCE := 22.0
# Distance from the fighter at floor contact, ordered high, middle, low.
const PRACTICE_BOUNCE_DISTANCES := [147.0, 169.0, 191.0]
const PRACTICE_ARC_CURVATURE := 0.004
const COMPUTER_REACTION_TICKS := 24

var kind := "balls"
var score := 0
var count := 0
var resolved := 0
var level := 0
var finished := false
var survived := false
var x := CENTER
var face := 1
var guard := 0
var kick := 0
var kick_low := false
var last_kick := false
var moving := false
var clock := 0
var spawn_wait := 0
var ball: Dictionary = {}
var outgoing: Array[Dictionary] = []
var bombs: Array = []
var signal_text := ""
var signal_time := 0
var random := RandomNumberGenerator.new()
var guided_balls := false
var ball_practice := false
var launch_wait := 0
var ball_order: Array[Vector2i] = []

func start(mode: String, difficulty: int, preset_paths: bool = false) -> void:
	kind = mode
	level = difficulty
	guided_balls = mode == "balls" and preset_paths
	ball_practice = false
	launch_wait = 0
	score = 0
	count = 0
	resolved = 0
	finished = false
	survived = false
	x = CENTER
	face = 1
	guard = 0
	kick = 0
	kick_low = false
	last_kick = false
	moving = false
	clock = 0
	spawn_wait = 48
	ball.clear()
	ball_order.clear()
	outgoing.clear()
	bombs.clear()
	signal_text = ""
	signal_time = 0
	if guided_balls:
		spawn_practice_ball()

func start_ball_practice() -> void:
	start("balls", 0, true)
	ball_practice = true

func spawn_practice_ball() -> void:
	while ball_order.size() <= count:
		shuffle_ball_group()
	var target := ball_order[count]
	var target_y := SHIELD_CENTER + target.y * SHIELD_STEP
	var speed := PRACTICE_SPEED + mini(count, PRACTICE_BALLS.size() - 1) * PRACTICE_SPEED_STEP
	ball = {"x": CENTER + target.x * PRACTICE_START_DISTANCE, "side": target.x,
		"y": PRACTICE_START_Y, "vx": -speed * target.x, "vy": 0.0,
		"target_y": target_y, "color": 1 - target.y,
		"bounce_distance": PRACTICE_BOUNCE_DISTANCES[target.y + 1]}
	launch_wait = PRACTICE_READY_TICKS
	count += 1

func shuffle_ball_group() -> void:
	var group: Array[Vector2i] = []
	group.assign(PRACTICE_BALLS)
	for i in range(group.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var choice := group[i]
		group[i] = group[j]
		group[j] = choice
	if not ball_order.is_empty() and group[0] == ball_order[-1]:
		var j := random.randi_range(1, group.size() - 1)
		var choice := group[0]
		group[0] = group[j]
		group[j] = choice
	ball_order.append_array(group)

func ball_limit() -> int:
	return PRACTICE_BALLS.size() if ball_practice else BALL_LIMIT

func tick(command: Vector3i) -> void:
	if finished:
		return
	clock += 1
	spawn_wait -= 1
	signal_time = maxi(0, signal_time - 1)
	if command.x != 0 and kick == 0:
		face = command.x
	if kind == "balls":
		aim_shield(command)
		update_balls()
	else:
		update_bombs(command)

func shield_y() -> float:
	return SHIELD_CENTER + guard * SHIELD_STEP

func aim_shield(command: Vector3i) -> void:
	if command.x != 0:
		face = signi(command.x)
	guard = clampi(command.y, -1, 1)

func computer_shield_command() -> Vector3i:
	if ball.is_empty() or launch_wait > 0:
		return Vector3i.ZERO
	var distance := absf(float(ball.x) - CENTER)
	var travel_since_bounce := float(ball.bounce_distance) - distance
	# Horizontal speed is constant, so this is a fixed delay in simulation time.
	if travel_since_bounce < absf(float(ball.vx)) * COMPUTER_REACTION_TICKS:
		return Vector3i.ZERO
	var height := roundi((float(ball.target_y) - SHIELD_CENTER) / SHIELD_STEP)
	return Vector3i(int(ball.side), height, 0)

func practice_ball_y(distance: float, target_y: float, bounce_distance: float) -> float:
	# A parabola through two fixed points, expressed in horizontal distance.
	if distance > bounce_distance:
		var travel := PRACTICE_START_DISTANCE - distance
		var span := PRACTICE_START_DISTANCE - bounce_distance
		return lerpf(PRACTICE_START_Y, PRACTICE_BOUNCE_Y, travel / span) - PRACTICE_ARC_CURVATURE * travel * (span - travel)
	var travel := bounce_distance - distance
	var span := bounce_distance - PRACTICE_CONTACT_DISTANCE
	return lerpf(PRACTICE_BOUNCE_Y, target_y, travel / span) - PRACTICE_ARC_CURVATURE * travel * (span - travel)

func advance_practice_ball() -> void:
	var side: int = ball.side
	var previous_distance := (float(ball.x) - CENTER) * side
	ball.x += ball.vx
	var distance := (float(ball.x) - CENTER) * side
	var target_y: float = ball.target_y
	# A step can cross the shield plane without landing exactly on it.
	var crossed_shield := previous_distance > PRACTICE_CONTACT_DISTANCE and distance <= PRACTICE_CONTACT_DISTANCE
	if crossed_shield and face == side and shield_y() == target_y:
		ball.x = CENTER + side * PRACTICE_CONTACT_DISTANCE
		ball.y = target_y
		deflect_ball()
		return
	ball.y = practice_ball_y(distance, target_y, float(ball.bounce_distance))
	if distance < 7.0:
		var ducked := guard == 1 and target_y < SHIELD_CENTER - 4.0
		if ducked or ball_practice:
			ball.vy = -1.5
			outgoing.append(ball)
			resolve_ball("AUSGEWICHEN" if ducked else "VERPASST")
		else:
			finish(false)

func update_balls() -> void:
	for old in outgoing.duplicate():
		old.x += old.vx
		old.y += old.vy
		old.vy += 0.25
		if old.x < -16 or old.x > 656 or old.y > FLOOR + 15:
			outgoing.erase(old)
	if ball.is_empty() and spawn_wait <= 0 and count < ball_limit():
		if guided_balls:
			spawn_practice_ball()
			return
		var side := -1 if (count == 0 or random.randf() < 0.5) else 1
		var band := count % 3 if count < 3 else random.randi_range(0, 2)
		var speed := minf(4.8 + count * 0.16 + level * 0.23, 9.3)
		ball = {"x": -10.0 if side == -1 else 650.0, "side": side,
			"y": SHIELD_CENTER, "vx": -speed * side, "vy": 0.0,
			"target_y": SHIELD_CENTER + (1 - band) * SHIELD_STEP, "color": band}
		count += 1
	if ball.is_empty():
		return
	if launch_wait > 0:
		launch_wait -= 1
		return
	if guided_balls:
		advance_practice_ball()
		return
	ball.x += ball.vx
	if ball.has("target_y"):
		var distance := absf(float(ball.x) - CENTER)
		var phase := clampf((distance - 13.0) / 306.0, 0.0, 1.0)
		var hops := 1.5 if count % 4 == 0 else 2.0
		var hop := absf(sin(phase * TAU * hops))
		ball.y = lerpf(float(ball.target_y), FLOOR - 7.0 - 70.0 * hop, smoothstep(15.0, 79.0, distance))
	else:
		ball.y += ball.vy
	var from_side := -1 if ball.vx > 0 else 1
	var shield_x := CENTER + face * 15.0
	if from_side == face and absf(float(ball.x) - shield_x) <= 7.0 and absf(float(ball.y) - shield_y()) <= 12.0:
		deflect_ball()
	elif absf(float(ball.x) - CENTER) < 7.0:
		if guard == 1 and ball.y < SHIELD_CENTER - 4.0:
			ball.vy = -1.5
			outgoing.append(ball)
			resolve_ball("AUSGEWICHEN")
		else:
			finish(false)

func deflect_ball() -> void:
	score += 100
	ball.vx = face * 9.0
	ball.vy = -3.0
	outgoing.append(ball)
	resolve_ball("+100")

func resolve_ball(message: String) -> void:
	ball = {}
	resolved += 1
	spawn_wait = 60 if guided_balls else maxi(8, 25 - level * 2)
	feedback(message)
	if resolved >= ball_limit():
		finish(true)

func update_bombs(command: Vector3i) -> void:
	var wants_kick := command.z == Fighter.PAD_KICK if command.z >= Fighter.PAD_MOVE else command.z != 0 or command.y > 0
	moving = false
	if kick > 0:
		kick -= 1
	elif wants_kick and not last_kick:
		kick = 22
		kick_low = command.y > 0
	else:
		x = clampf(x + command.x * 2.35, 28.0, 612.0)
		moving = command.x != 0
	last_kick = wants_kick
	if spawn_wait <= 0 and count < BOMB_LIMIT:
		var side := -1 if count % 4 < 2 else 1
		var spawn_x := clampf(x + side * random.randf_range(58.0, 134.0), 32.0, 608.0)
		bombs.append({"x": spawn_x, "vx": 0.0, "fuse": maxi(100, 197 - count * 6 - level * 5), "blast": 0})
		spawn_wait = maxi(43, 103 - count * 5 - level * 3)
		count += 1
	for bomb in bombs.duplicate():
		if bomb.blast > 0:
			bomb.blast -= 1
			if absf(float(bomb.x) - x) < 31.0:
				finish(false)
				return
			if bomb.blast == 0:
				bombs.erase(bomb)
				resolved += 1
			continue
		var offset := (float(bomb.x) - x) * face
		var reach := 42.0 if kick_low else 34.0
		if kick == 14 and offset >= -6.0 and offset <= reach:
			bomb.vx = face * 10.0
		bomb.x += bomb.vx
		if bomb.x < -10 or bomb.x > 650:
			bombs.erase(bomb)
			resolved += 1
			score += 100
			feedback("+100")
			continue
		bomb.fuse -= 1
		if bomb.fuse <= 0:
			bomb.blast = 19
			if absf(float(bomb.x) - x) < 31.0:
				finish(false)
				return
	if resolved >= BOMB_LIMIT:
		finish(true)

func feedback(message: String) -> void:
	signal_text = message
	signal_time = 34

func finish(success: bool) -> void:
	finished = true
	survived = success
	if success and not ball_practice:
		score += 5000
