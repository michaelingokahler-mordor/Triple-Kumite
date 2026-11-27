extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const BAG_X := 355.0
const BAG_DISTANCE := 23.0
const NEXT_DELAY := 42
# Move, display name, direction, keyboard combination, action modifier.
const LESSONS := [
	["walk", "Vorwärts gehen", "→", "D", false],
	["back", "Zurückweichen", "←", "A", false],
	["jump", "Sprung", "↑ + X / LT", "W", false],
	["punch", "Fauststoß", "↗ + A / RB", "W + D", false],
	["shin", "Schienbeintritt", "↘ + B / RT", "S + D", false],
	["sweep", "Fußfeger", "↓ + B / RT", "S", false],
	["body", "Bauchtritt", "→ + B / RT", "D", true],
	["headbutt", "Kopfstoß", "↑ + A / RB", "W + D", true],
	["high", "Hoher Tritt", "↗ + B / RT", "S + D", true],
	["flying", "Sprungtritt", "→ + X / LT", "W", true],
	["flip", "Rückwärtssalto", "← + X / LT", "A", true],
	["double", "Split / Doppelkick", "↖ + X / LT", "W + A", true],
	["turn_punch", "Fauststoß mit Drehung", "↖ + A / RB", "W + A", false],
	["duck_punch", "Tiefer Fauststoß", "↘ + A / RB", "S + A", false],
	["turn_sweep", "Rückwärtsfeger", "↙ + B / RT", "S", true],
	["turn_kick", "Tritt mit Drehung", "← + B / RT", "S + A", true],
]
const TURN_ATTACKS := Fighter.TURN_ATTACKS

var fighter := Fighter.new()
var bag := Fighter.new()
var guided := false
var finished := false
var lesson_index := 0
var next_wait := 0
var hits := 0
var swing_frames := 0
var swing_direction := 1

func start(with_lessons: bool) -> void:
	guided = with_lessons
	finished = false
	lesson_index = 0
	next_wait = 0
	hits = 0
	bag.reset(BAG_X, -1)
	fighter.footwork_scale = 0.85
	reset_stance()

func reset_stance() -> void:
	var move: String = LESSONS[lesson_index][0] if guided else ""
	var side := 1.0 if move in TURN_ATTACKS else -1.0
	var distance := BAG_DISTANCE
	if Fighter.MIN_REACH.has(move):
		distance = maxf(distance, float(Fighter.MIN_REACH[move]) + 6.0)
		if move == "flying":
			distance += 18.0
	fighter.reset(BAG_X + side * distance, 1)
	swing_frames = 0

func tick(command: Vector3i) -> void:
	if finished:
		return
	swing_frames = maxi(0, swing_frames - 1)
	if next_wait > 0:
		fighter.step(Vector3i.ZERO, false)
		next_wait -= 1
		if next_wait == 0:
			lesson_index += 1
			finished = lesson_index == LESSONS.size()
			if not finished:
				reset_stance()
		return

	fighter.step(command, false)
	var contact := fighter.can_hit(bag)
	if contact:
		hits += 1
		swing_frames = 32
		swing_direction = 1 if bag.x > fighter.x else -1
	if not guided:
		return
	var goal: String = LESSONS[lesson_index][0]
	if fighter.action != goal:
		return
	if Fighter.ATTACKS.has(goal):
		if contact:
			next_wait = NEXT_DELAY
	elif fighter.age >= 8:
		next_wait = NEXT_DELAY
