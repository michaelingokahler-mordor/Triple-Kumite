extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const ROUND_FRAMES := 30 * 60
const REACTION_TICKS := 28
const ATTACK_RANGE := 32.0
const WINDUP_TICKS := 6
const DEFENSE_CHANCE := 0.72
const FOOTWORK := 0.85
const RESET_DISTANCE := 108.0
const RESET_FRAMES := 72

class ComputerState:
	var command := Vector3i.ZERO
	var wait := 0
	var target := -1
	var observation := Vector3i.ZERO
	var react_at := 0
	var threat := Vector2i(-1, -1)
	var defend_at := 0
	var defense := Vector3i.ZERO

var fighters: Array = []
var humans: Array[bool] = []
var winners: Array[int] = []
var places: Array[int] = []
var frames_left := ROUND_FRAMES
var finished := false
var match_over := false
var elimination_enabled := true
var sudden_death := false
var eliminated := -1
var round_number := 1
var hits := 0
var time_bonus := 0
var computers: Array[ComputerState] = []
var reset_left := 0
var reset_slots: Array[int] = []
var reset_from: Array[float] = []
var reset_to: Array[float] = []
var random := RandomNumberGenerator.new()

func start(slots: int, people: int, eliminate_each_round: bool = true) -> void:
	elimination_enabled = eliminate_each_round
	sudden_death = false
	fighters.clear()
	humans.clear()
	for i in slots:
		fighters.append(Fighter.new())
		humans.append(i < people)
	round_number = 1
	reset_round()

func reset_round() -> void:
	var positions := [243.0, 397.0] if fighters.size() == 2 else [201.0, 320.0, 439.0]
	computers.clear()
	for i in fighters.size():
		fighters[i].reset(positions[i], -1 if i == fighters.size() - 1 else 1)
		fighters[i].extra_windup = WINDUP_TICKS if not humans[i] else 0
		fighters[i].footwork_scale = FOOTWORK
		computers.append(ComputerState.new())
	reset_left = 0
	reset_slots.clear()
	winners.clear()
	places.clear()
	frames_left = ROUND_FRAMES
	finished = false
	match_over = false
	eliminated = -1
	time_bonus = 0

func tick(commands: Array) -> void:
	if finished:
		return
	hits = 0
	var resetting := reset_left > 0
	if resetting:
		step_reposition()
	if resetting and fighters.size() == 2:
		return
	frames_left -= 1
	for i in fighters.size():
		if resetting and i in reset_slots:
			continue
		var fighter = fighters[i]
		var threatened := false
		for j in fighters.size():
			if i == j or (resetting and j in reset_slots):
				continue
			var opponent = fighters[j]
			var distance: float = opponent.x - fighter.x
			if absf(distance) <= 40.0 and distance * fighter.face > 0 and Fighter.ATTACKS.has(opponent.action):
				threatened = true
		fighter.step(commands[i], threatened)
	separate_fighters()
	var strikes: Array[Vector3i] = []
	for i in fighters.size():
		if resetting and i in reset_slots:
			continue
		var attacker = fighters[i]
		for j in fighters.size():
			if i == j or (resetting and j in reset_slots) or not attacker.can_hit(fighters[j]):
				continue
			var target = fighters[j]
			var front: bool = (attacker.x - target.x) * target.face >= 0.0
			strikes.append(Vector3i(i, j, 2 if front else 1))
	var hit_targets: Array[int] = []
	var involved: Array[int] = []
	for strike in strikes:
		if strike.y in hit_targets:
			continue
		var attacker = fighters[strike.x]
		var target = fighters[strike.y]
		var earned: int = Fighter.ATTACKS[attacker.action][2]
		if strike.z == 1 and attacker.action != "double":
			earned = earned >> 1
		attacker.points += strike.z
		attacker.round_score += earned
		attacker.total += earned
		target.hit_label = "+%d" % earned
		target.hit_frames = 42
		hit_targets.append(strike.y)
		if strike.x not in involved:
			involved.append(strike.x)
		if strike.y not in involved:
			involved.append(strike.y)
		hits += 1
	for strike in strikes:
		if strike.y in hit_targets:
			fighters[strike.y].knock_down(fighters[strike.x].x)
			hit_targets.erase(strike.y)
	for fighter in fighters:
		if fighter.points >= 6 or frames_left <= 0 or (sudden_death and hits > 0):
			finish_round()
			break
	if hits > 0 and not finished:
		start_reposition(involved)

func is_repositioning(index: int) -> bool:
	return reset_left > 0 and index in reset_slots

func start_reposition(involved: Array[int]) -> void:
	reset_left = RESET_FRAMES
	reset_slots.assign(involved)
	reset_slots.sort_custom(func(a: int, b: int) -> bool: return fighters[a].x < fighters[b].x)
	reset_from.clear()
	reset_to.clear()
	for slot in reset_slots:
		reset_from.append(fighters[slot].x)
		computers[slot] = ComputerState.new()
	var span := RESET_DISTANCE * (reset_slots.size() - 1)
	var start_x := clampf((reset_from[0] + reset_from[-1] - span) * 0.5,
		Fighter.LEFT_EDGE, Fighter.RIGHT_EDGE - span)
	for i in reset_slots.size():
		reset_to.append(start_x + i * RESET_DISTANCE)

func step_reposition() -> void:
	reset_left -= 1
	var elapsed := RESET_FRAMES - reset_left
	var progress := smoothstep(0.0, float(RESET_FRAMES), float(elapsed))
	for i in reset_slots.size():
		var fighter = fighters[reset_slots[i]]
		fighter.step(Vector3i.ZERO, false)
		fighter.x = lerpf(reset_from[i], reset_to[i], progress)
		if i == 0:
			fighter.face = 1
		elif i == reset_slots.size() - 1:
			fighter.face = -1
		if fighter.down == 0 and fighter.lift == 0.0:
			fighter.action = "idle" if reset_left == 0 else "back"
			fighter.age = elapsed

func separate_fighters() -> void:
	var correction := PackedFloat32Array()
	correction.resize(fighters.size())
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a = fighters[i]
			var b = fighters[j]
			var a_locked := is_repositioning(i)
			var b_locked := is_repositioning(j)
			if a_locked and b_locked:
				continue
			if a.down > 0 or b.down > 0 or a.lift > 13.0 or b.lift > 13.0:
				continue
			var distance: float = b.x - a.x
			if absf(distance) < 19.0:
				var side := 1.0 if distance >= 0.0 else -1.0
				if absf(distance) < 0.05 and b.previous_x < a.previous_x:
					side = -1.0
				var shift := (19.0 - absf(distance)) * 0.5 * side
				if not a_locked:
					correction[i] -= shift
				if not b_locked:
					correction[j] += shift
	for i in fighters.size():
		fighters[i].x += clampf(correction[i], -1.5, 1.5)
		fighters[i].limit_position()

func finish_round() -> void:
	finished = true
	for i in fighters.size():
		places.append(i)
	places.sort_custom(func(a: int, b: int) -> bool:
		var first = fighters[a]
		var second = fighters[b]
		if first.points == second.points:
			return first.round_score > second.round_score
		return first.points > second.points)
	var leader = fighters[places[0]]
	for i in places:
		if fighters[i].points == leader.points and fighters[i].round_score == leader.round_score:
			winners.append(i)
	if leader.points >= 6:
		time_bonus = int(ceil(frames_left / 60.0)) * 100
		for i in winners:
			fighters[i].total += time_bonus
	if fighters.size() == 3 and elimination_enabled:
		var last := places[2]
		var next = fighters[places[1]]
		var loser = fighters[last]
		if humans[last] and (loser.points != next.points or loser.round_score != next.round_score):
			humans[last] = false
			eliminated = last
			match_over = not humans.has(true)

func computer_command(index: int) -> Vector3i:
	if is_repositioning(index):
		return Vector3i.ZERO
	var fighter = fighters[index]
	var cpu := computers[index]
	if fighter.down > 0:
		cpu.observation = Vector3i.ZERO
		cpu.wait = REACTION_TICKS
		return Vector3i.ZERO
	if fighter.action in ["jump", "flip", "landing"]:
		return Vector3i.ZERO

	var tick_index := ROUND_FRAMES - frames_left
	var opponent_index := -1
	var threat_index := -1
	var opponent_distance := INF
	var threat_distance := INF
	for other in fighters.size():
		if other == index or is_repositioning(other) or fighters[other].down > 0:
			continue
		var opponent = fighters[other]
		var distance := float(opponent.x - fighter.x)
		if opponent.protection == 0 and absf(distance) < absf(opponent_distance):
			opponent_index = other
			opponent_distance = distance
		if absf(distance) < absf(threat_distance) and is_attack_threat(opponent, distance):
			threat_index = other
			threat_distance = distance

	var defense := defensive_command(cpu, fighter, threat_index, threat_distance, tick_index)
	if defense != Vector3i.ZERO:
		if not Fighter.ATTACKS.has(fighter.action) or fighter.age < fighter.impact_frame():
			cpu.wait = 0
			return defense
	if Fighter.ATTACKS.has(fighter.action):
		return cpu.command if fighter.age < fighter.impact_frame() else Vector3i.ZERO
	if opponent_index < 0:
		cpu.observation = Vector3i.ZERO
		return Vector3i.ZERO

	# Keep pursuing the same opponent when distances are nearly equal.
	if cpu.target >= 0 and not is_repositioning(cpu.target):
		var previous_target = fighters[cpu.target]
		var previous_distance := float(previous_target.x - fighter.x)
		if previous_target.down == 0 and previous_target.protection == 0 and absf(previous_distance) <= absf(opponent_distance) + 12.0:
			opponent_index = cpu.target
			opponent_distance = previous_distance
	cpu.target = opponent_index
	var side := 1 if opponent_distance > 0.0 else -1
	var close := absf(opponent_distance) <= ATTACK_RANGE
	var observation := Vector3i(opponent_index + 1, side, int(close))
	if observation != cpu.observation:
		cpu.observation = observation
		cpu.react_at = tick_index + REACTION_TICKS
	if cpu.wait > 0:
		cpu.wait -= 1
		return Vector3i.ZERO
	if tick_index < cpu.react_at:
		return Vector3i.ZERO
	if side != fighter.face:
		return Fighter.TURN_COMMAND
	if not close:
		return Vector3i(side, 0, 0)

	var choices := [Vector3i(side, -1, 0), Vector3i(side, 1, 0), Vector3i(0, 1, 0)]
	if absf(opponent_distance) >= 27.0:
		choices.append_array([Vector3i(side, 1, 1), Vector3i(side, 0, 1)])
	else:
		choices.append(Vector3i(side, -1, 1))
	cpu.command = choices[random.randi_range(0, choices.size() - 1)]
	cpu.wait = random.randi_range(24, 42)
	return cpu.command

func is_attack_threat(opponent, distance: float) -> bool:
	if absf(distance) > 49.0 or not Fighter.ATTACKS.has(opponent.action):
		return false
	if opponent.age > opponent.impact_frame() + 3:
		return false
	var attack_face: int = opponent.face
	if opponent.action in Fighter.TURN_ATTACKS and opponent.age < opponent.impact_frame():
		attack_face *= -1
	return opponent.action == "double" or distance * attack_face < 0.0

func defensive_command(cpu: ComputerState, fighter, threat_index: int, distance: float, tick_index: int) -> Vector3i:
	if threat_index < 0:
		cpu.threat = Vector2i(-1, -1)
		return Vector3i.ZERO
	var target = fighters[threat_index]
	var threat := Vector2i(threat_index, tick_index - int(target.age))
	if cpu.threat != threat:
		cpu.threat = threat
		cpu.defend_at = tick_index + random.randi_range(10, 15)
		cpu.defense = Vector3i.ZERO
		if random.randf() < DEFENSE_CHANCE:
			var height: String = Fighter.ATTACKS[target.action][1]
			if height == "high" and (random.randf() < 0.65 or distance * fighter.face < 0.0):
				cpu.defense = Fighter.DUCK_COMMAND
			elif height == "low":
				cpu.defense = Vector3i(-fighter.face, 0, 1) if distance * fighter.face > 0.0 else Vector3i(0, -1, 0)
			elif distance * fighter.face > 0.0:
				cpu.defense = Vector3i(-fighter.face, 0, 0)
	if tick_index < cpu.defend_at:
		return Vector3i.ZERO
	return cpu.defense
