extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const TITLES := ["Fässer", "Pfeile", "Teller", "Granaten"]
const KEYS := ["barrels", "arrows", "plates", "grenades"]
const HINTS := [
	"Spring über die Fässer oder tritt sie weg.",
	"Hohe Pfeile ducken, tiefe Pfeile überspringen.",
	"Zerschlage die Teller auf drei Höhen.",
	"Tritt die Granaten weg, bevor die Zündschnur abbrennt.",
]
const FLOOR := 310.0
const START_X := 404.0
const KICKS := ["shin", "sweep", "turn_sweep", "body", "high", "turn_kick", "flying", "double"]
const RECORD_PATH := "user://training-times.cfg"

var fighter := Fighter.new()
var mode := 0
var ticks := 0
var spawn_wait := 0
var finished := false
var record := false
var records := ConfigFile.new()
var record_path := RECORD_PATH
var hazards: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var spawn_count := 0
var cleared := 0

func load_records() -> void:
	records.load(record_path)

func best_time(discipline: int) -> int:
	return int(records.get_value("times", KEYS[discipline], 0))

static func time_text(frames: int) -> String:
	var seconds := frames / 60
	return "%02d:%02d.%02d" % [seconds / 60, seconds % 60, frames % 60 * 100 / 60]

func start(discipline: int) -> void:
	mode = discipline
	ticks = 0
	spawn_wait = 55
	finished = false
	record = false
	cleared = 0
	spawn_count = 0
	hazards.clear()
	effects.clear()
	fighter.reset(START_X, -1)
	fighter.footwork_scale = 0.85

func tick(command: Vector3i) -> void:
	if finished:
		return
	ticks += 1
	if mode == 1 and command.y == 1 and command.z < Fighter.PAD_MOVE:
		command = Fighter.DUCK_COMMAND
	fighter.step(command, false)
	fighter.x = clampf(fighter.x, 295.0, 542.0)
	spawn_wait -= 1
	if spawn_wait <= 0:
		spawn()
	for effect in effects.duplicate():
		effect.life -= 1
		if effect.life == 0:
			effects.erase(effect)
	for hazard in hazards.duplicate():
		var previous: float = hazard.x
		hazard.x += hazard.speed
		hazard.age += 1
		if hazard.deflected:
			if hazard.x < -20.0 or hazard.x > 670.0:
				hazards.erase(hazard)
			continue
		if mode == 3:
			hazard.fuse -= 1
			if hazard.fuse == 0:
				effects.append({"x": hazard.x, "y": hazard.y, "life": 18})
				hazards.erase(hazard)
				if absf(float(hazard.x) - fighter.x) < 58.0:
					end_run()
					return
				continue
		if can_break(hazard):
			cleared += 1
			effects.append({"x": hazard.x, "y": hazard.y, "life": 18})
			if mode == 2:
				hazards.erase(hazard)
			else:
				hazard.deflected = true
				hazard.speed = 6.0 * fighter.face
			continue
		if mode != 3:
			var low_x := minf(previous, float(hazard.x))
			var high_x := maxf(previous, float(hazard.x))
			if low_x < fighter.x + 12.0 and high_x > fighter.x - 12.0 and (mode == 2 or hits_body(hazard)):
				end_run()
				return
		if hazard.x > 660.0:
			hazards.erase(hazard)

func spawn() -> void:
	var seconds := ticks / 60.0
	var speeds := [2.0, 3.5, 2.6, 2.2]
	var intervals := [136, 124, 125, 150]
	var minimums := [29, 39, 42, 52]
	var speed: float = speeds[mode] + minf(4.3, seconds * 0.058)
	var x := 62.0
	var y := FLOOR - 12.0
	var fuse := 0
	if mode == 1:
		y = FLOOR - 53.0 if spawn_count % 2 == 0 else FLOOR - 11.0
	elif mode == 2:
		y = FLOOR - [50.0, 34.0, 16.0][random.randi_range(0, 2)]
	elif mode == 3:
		x = fighter.x - random.randf_range(115.0, 175.0)
		fuse = ceili((fighter.x - x) / speed) + 14
	hazards.append({"x": x, "y": y, "speed": speed, "age": 0, "fuse": fuse, "deflected": false})
	spawn_count += 1
	spawn_wait = maxi(minimums[mode], int(intervals[mode] - seconds * 2.0))

func hits_body(hazard: Dictionary) -> bool:
	var feet := FLOOR - fighter.lift
	var crouched := fighter.action in Fighter.CROUCHED
	var head := feet - (31.0 if crouched else 59.0)
	var radius: float = [12.0, 2.0, 7.0, 6.0][mode]
	return hazard.y + radius > head and hazard.y - radius < feet

func can_break(hazard: Dictionary) -> bool:
	if mode == 1 or not fighter.attack_live:
		return false
	if mode in [0, 3] and fighter.action not in KICKS:
		return false
	var attack: Array = Fighter.ATTACKS[fighter.action]
	var distance := float(hazard.x - fighter.x)
	if fighter.action != "double" and distance * fighter.face <= 0.0:
		return false
	var reach := float(attack[0])
	var margin := 11.0 if mode == 0 else 7.0
	if absf(distance) > reach + margin or absf(distance) < float(Fighter.MIN_REACH.get(fighter.action, 0.0)) - margin:
		return false
	if mode == 2:
		var height := {"high": 50.0, "mid": 34.0, "low": 16.0, "air": 30.0}
		return absf(float(hazard.y) - (FLOOR - fighter.lift - float(height[attack[1]]))) <= 11.0
	return fighter.lift < 23.0

func end_run() -> void:
	finished = true
	var previous_time := best_time(mode)
	if ticks <= previous_time:
		return
	var key: String = KEYS[mode]
	records.set_value("times", key, ticks)
	record = records.save(record_path) == OK
	if not record:
		if previous_time > 0:
			records.set_value("times", key, previous_time)
		else:
			records.erase_section_key("times", key)
