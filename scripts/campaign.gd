extends RefCounted

const LOCATIONS := ["Japan · Küstendojo", "Marokko · Kasbah"]
const ROUNDS_PER_LOCATION := 3

var active := false
var location := 0
var round := 1
var deciding := false
var contenders: Array[int] = []
var roster: Array[int] = []
var wins: Array[int] = []
var winner := -1
var finished := false
var qualified := false

func start() -> void:
	active = true
	location = 0
	start_location()

func start_location() -> void:
	round = 1
	deciding = false
	finished = false
	qualified = false
	winner = -1
	roster.assign([0, 1, 2])
	contenders.clear()
	wins.assign([0, 0, 0])

func record_round(round_winners: Array[int], human_slots: Array[bool]) -> void:
	if deciding:
		if round_winners.size() == 1:
			complete_location(roster[round_winners[0]], human_slots)
		return
	if round_winners.size() == 1:
		wins[roster[round_winners[0]]] += 1
	if round < ROUNDS_PER_LOCATION:
		return
	var best: int = wins.max()
	for slot in wins.size():
		if wins[slot] == best:
			contenders.append(slot)
	if contenders.size() == 1:
		complete_location(contenders[0], human_slots)

func complete_location(slot: int, human_slots: Array[bool]) -> void:
	winner = slot
	finished = true
	qualified = location + 1 < LOCATIONS.size() and human_slots[winner]

func next_round() -> void:
	if not deciding and round == ROUNDS_PER_LOCATION:
		deciding = true
		roster.assign(contenders)
	round += 1

func next_location() -> void:
	location += 1
	start_location()
