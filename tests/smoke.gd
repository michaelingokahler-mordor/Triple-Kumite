extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func run() -> void:
	for suite in ["tournament", "fighter", "bonus_round", "local_input"]:
		check(ResourceLoader.exists("res://scripts/%s.gd" % suite), "Missing implementation: " + suite)
	if failures.is_empty():
		test_fight()
		test_fight_pacing()
		test_duel_reactions()
		test_duel_defense_and_reach()
		test_duel_reset()
		test_triad_pacing()
		test_training_sequence()
		test_bonus()
		test_ball_practice()
		test_practice_lanes()
		test_ball_shuffle()
		test_input()
		test_survival()
		test_survival_save_failure()
		await test_game()
		await test_computer_ball_practice()
	for failure in failures:
		printerr(failure)
	print("Triple Kumite smoke tests: %d failures" % failures.size())
	quit(int(not failures.is_empty()))

func test_fight() -> void:
	var tournament = load("res://scripts/tournament.gd").new()
	var fighter = load("res://scripts/fighter.gd")
	tournament.start(3, 2)
	var a = tournament.fighters[0]
	var b = tournament.fighters[1]
	var c = tournament.fighters[2]
	check(fighter.select_move(Vector2i(1, -1), false, 1) == "punch", "Punch to the right")
	check(fighter.select_move(Vector2i(-1, -1), false, -1) == "punch", "Mirrored punch")
	a.x = 320.0
	b.x = 345.0
	c.x = 295.0
	a.face = 1
	b.face = -1
	c.face = -1
	var action := Vector3i(-1, -1, 1)
	for i in 18:
		tournament.tick([action, Vector3i.ZERO, Vector3i.ZERO])
	check(a.points == 3 and a.total == 2000, "Double kick must hit both sides and score 3 combat points")
	check(b.down > 0 and c.down > 0, "Both targets are knocked down")
	for i in 70:
		tournament.tick([action, Vector3i.ZERO, Vector3i.ZERO])
	check(a.points == 3, "Holding the pose must not hit again after the targets recover")
	var chain = fighter.new()
	chain.step(Vector3i(1, -1, 0), false)
	for i in 15:
		chain.step(Vector3i(1, -1, 0), false)
	for i in 13:
		chain.step(Vector3i(1, 1, 0), false)
	check(chain.action == "shin", "A second attack held during recovery starts at the first opportunity")
	var cancel = fighter.new()
	cancel.step(Vector3i(-1, -1, 0), false)
	cancel.step(Vector3i.ZERO, false)
	check(cancel.action == "idle" and cancel.face == 1, "Releasing a turn attack before its active frame cancels the attack and turn")
	tournament.start(2, 1)
	tournament.frames_left = 1
	tournament.tick([Vector3i.ZERO, Vector3i.ZERO])
	check(tournament.finished and tournament.winners.size() == 2, "A scoreless timed duel is a draw")
	tournament.start(3, 3)
	tournament.fighters[0].points = 2
	tournament.fighters[1].points = 2
	tournament.fighters[1].round_score = 800
	tournament.fighters[2].round_score = 1000
	tournament.frames_left = 1
	tournament.tick([Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO])
	check(tournament.winners == [1], "Combat points rank first, then round score")
	check(tournament.humans == [true, true, false], "Third-place human is eliminated from the tournament")
	tournament.start(2, 1)
	tournament.fighters[0].points = 6
	tournament.frames_left = 600
	tournament.tick([Vector3i.ZERO, Vector3i.ZERO])
	check(tournament.finished and tournament.time_bonus == 1000, "Six combat points end the fight with a time bonus")

func test_bonus() -> void:
	var bonus = load("res://scripts/bonus_round.gd").new()
	for direction in [-1, 1]:
		bonus.start("balls", 0)
		bonus.ball = {"x": 320.0 + 20.0 * direction, "y": 273.0, "vx": -4.0 * direction, "vy": 0.0}
		bonus.spawn_wait = 100
		bonus.tick(Vector3i(direction, 0, 0))
		check(bonus.score == 100, "Facing the incoming side deflects the ball")
	bonus.start("balls", 0)
	bonus.ball = {"x": 300.0, "y": 273.0, "vx": 4.0, "vy": 0.0}
	for i in 6:
		bonus.tick(Vector3i(1, 0, 0))
	check(bonus.finished and bonus.score == 0, "Shield on wrong side misses the ball")
	bonus.start("bombs", 0)
	bonus.spawn_wait = 200
	bonus.bombs = [{"x": 342.0, "vx": 0.0, "fuse": 60, "blast": 0}]
	for i in 90:
		bonus.tick(Vector3i(1, 0, 1))
	check(bonus.score == 100 and bonus.bombs.is_empty(), "A kick sends the bomb off the arena and scores")
	bonus.start("bombs", 0)
	bonus.bombs = [{"x": 320.0, "vx": 0.0, "fuse": 1, "blast": 0}]
	bonus.tick(Vector3i.ZERO)
	check(bonus.finished and bonus.score == 0, "A close explosion ends the bonus")
	bonus.start("balls", 0)
	bonus.random.seed = 82
	for i in 3000:
		if bonus.finished:
			break
		var defense := Vector3i.ZERO
		if not bonus.ball.is_empty():
			defense.x = bonus.ball.side
			defense.y = int((bonus.ball.target_y - 273.0) / 16.0)
		bonus.tick(defense)
	check(bonus.survived and bonus.score == 6800, "All generated ball paths can be deflected for the clear bonus")
	bonus.start("bombs", 0)
	bonus.resolved = 11
	bonus.spawn_wait = 40
	bonus.bombs = [{"x": 370.0, "vx": 0.0, "fuse": 1, "blast": 0}]
	for i in 20:
		bonus.tick(Vector3i.ZERO)
	check(bonus.survived and bonus.score == 5000, "A distant final explosion is survivable")

func test_fight_pacing() -> void:
	var tournament = load("res://scripts/tournament.gd").new()
	var fighter = load("res://scripts/fighter.gd").new()
	fighter.x = 320.0
	fighter.lift = 25.0
	fighter.knock_down(350.0)
	check(fighter.x == 320.0 and fighter.lift == 25.0, "A hit does not instantly move or ground the fighter")
	for i in 12:
		fighter.step(Vector3i.ZERO, false)
	check(fighter.x < 315.0 and fighter.lift == 0.0, "Knockback and fall play out over several frames")
	tournament.start(3, 3)
	for participant in tournament.fighters:
		participant.x = 320.0
	tournament.tick([Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO])
	for participant in tournament.fighters:
		check(absf(participant.x - 320.0) <= 2.0, "Overlap correction is bounded per tick")
	var first_hit := -1
	var round_end := -1
	tournament.random.seed = 3
	tournament.start(2, 1)
	for frame in 1800:
		tournament.tick([Vector3i.ZERO, tournament.computer_command(1)])
		if first_hit == -1 and tournament.fighters[0].down > 0:
			first_hit = frame
		if tournament.finished:
			round_end = frame
			break
	check(first_hit >= 115, "Opening CPU attack leaves about two seconds to react")
	check(round_end >= 450 and round_end < 1799, "A passive player loses after several exchanges, even at the slower pace")

func test_duel_reactions() -> void:
	var match_state = load("res://scripts/tournament.gd").new()
	match_state.random.seed = 4
	match_state.start(2, 1)
	var player = match_state.fighters[0]
	var cpu = match_state.fighters[1]
	var first_walk := -1
	var close_tick := -1
	var first_attack := -1
	var first_strike := -1
	for tick in 360:
		if close_tick < 0 and cpu.x - player.x <= 32.0:
			close_tick = tick
		match_state.tick([Vector3i.ZERO, match_state.computer_command(1)])
		if cpu.action == "walk" and first_walk < 0:
			first_walk = tick
		if cpu.action in ["punch", "shin", "sweep", "high", "body"] and first_attack < 0:
			first_attack = tick
		if cpu.attack_live:
			first_strike = tick
			break
	check(first_walk in range(23, 30), "CPU takes roughly 0.4 seconds to begin closing the distance")
	check(close_tick > 0 and first_attack - close_tick in range(23, 30),
		"CPU takes roughly 0.4 seconds to act on the opponent entering range")
	check(first_strike - first_attack in range(19, 24), "CPU visibly winds up before a strike")

	match_state.start(2, 1)
	player = match_state.fighters[0]
	cpu = match_state.fighters[1]
	player.x = cpu.x - 30.0
	for tick in 20:
		match_state.tick([Vector3i.ZERO, match_state.computer_command(1)])
	player.x = cpu.x + 30.0
	var still_waiting := true
	for tick in 23:
		still_waiting = still_waiting and match_state.computer_command(1) == Vector3i.ZERO
		match_state.tick([Vector3i.ZERO, Vector3i.ZERO])
	check(still_waiting, "Crossing behind the CPU restarts its reaction time")

func test_duel_defense_and_reach() -> void:
	var match_state = load("res://scripts/tournament.gd").new()
	var high_defenses := 0
	var low_evasions := 0
	for seed in 24:
		for low in [false, true]:
			match_state.random.seed = seed
			match_state.start(2, 1)
			var player = match_state.fighters[0]
			var cpu = match_state.fighters[1]
			player.x = cpu.x - 25.0
			var attack := Vector3i(0, 1, 0) if low else Vector3i(1, -1, 0)
			for tick in 20:
				var command: Vector3i = match_state.computer_command(1)
				if tick < 10:
					check(command == Vector3i.ZERO, "CPU cannot defend instantly on seeing an attack")
				match_state.tick([attack, command])
				if low and cpu.action == "flip" and cpu.lift > 12.0 and player.attack_live:
					low_evasions += 1
				elif not low and (cpu.action == "duck" or cpu.blocking) and player.attack_live:
					high_defenses += 1
	check(high_defenses > 0 and high_defenses < 24 and low_evasions > 0, "CPU sometimes avoids high and low attacks")
	print("Duel defense: ", high_defenses, "/24 high, ", low_evasions, "/24 low")
	var fighter = load("res://scripts/fighter.gd").new()
	var target = load("res://scripts/fighter.gd").new()
	fighter.reset(300.0, 1)
	target.reset(319.0, -1)
	fighter.attack_live = true
	fighter.action = "punch"
	check(fighter.can_hit(target), "Punch can hit in close quarters")
	fighter.action = "high"
	check(not fighter.can_hit(target), "High kick needs room to extend")
	target.x = 334.0
	check(fighter.can_hit(target), "High kick hits at longer range")
	fighter.action = "punch"
	check(not fighter.can_hit(target), "Punch cannot reach as far as a high kick")
	fighter.action = "idle"
	fighter.step(fighter.TURN_COMMAND, false)
	check(fighter.face == -1 and fighter.x == 300.0, "Dedicated turn changes facing in place")

func test_duel_reset() -> void:
	var match_state = load("res://scripts/tournament.gd").new()
	for attacker_at in [28.0, 320.0, 586.0]:
		match_state.start(2, 2)
		var attacker = match_state.fighters[0]
		var defender = match_state.fighters[1]
		attacker.x = attacker_at
		defender.x = attacker_at + 24.0
		var punch := Vector3i(1, -1, 0)
		for frame in 20:
			match_state.tick([punch, Vector3i.ZERO])
			if match_state.hits > 0:
				break
		check(match_state.reset_left > 0, "A non-final duel hit starts a break")
		var timer: int = match_state.frames_left
		var largest_step := 0.0
		for frame in 80:
			if match_state.reset_left == 0:
				break
			var last := Vector2(attacker.x, defender.x)
			match_state.tick([punch, Vector3i(-1, -1, 0)])
			largest_step = maxf(largest_step, maxf(absf(attacker.x - last.x), absf(defender.x - last.y)))
		check(defender.x - attacker.x >= 107.0 and attacker.x >= 28.0 and defender.x <= 612.0,
			"Duel reset leaves space between both fighters even at the arena edge")
		check(largest_step <= 3.0 and defender.down == 0 and attacker.points == 2 and defender.points == 0
			and match_state.frames_left == timer, "Duel reset moves smoothly and prevents follow-up hits")

func test_training_sequence() -> void:
	var training = load("res://scripts/training.gd").new()
	training.start(true)
	var commands := [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(1, -1, 0),
		Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 1), Vector3i(1, -1, 1),
		Vector3i(1, 1, 1), Vector3i(0, -1, 1), Vector3i(-1, 0, 1), Vector3i(-1, -1, 1),
		Vector3i(-1, -1, 0), Vector3i(-1, 1, 0), Vector3i(0, 1, 1), Vector3i(-1, 1, 1),
	]
	for i in commands.size():
		for frame in 100:
			if training.lesson_index != i:
				break
			training.tick(commands[i])
		check(training.lesson_index == i + 1, "Training maneuver %d is achievable using its displayed input" % (i + 1))
	check(training.finished and training.hits == 12, "Guided training completes after all 16 maneuvers")
	training.start(false)
	for frame in 30:
		training.tick(Vector3i(1, -1, 0))
	check(training.hits == 1 and not training.finished, "Free training counts bag hits without ending the session")

func test_triad_pacing() -> void:
	var match_state = load("res://scripts/tournament.gd").new()
	match_state.start(3, 1)
	var player = match_state.fighters[0]
	var red = match_state.fighters[1]
	var blue = match_state.fighters[2]
	check(red.extra_windup > 0 and blue.extra_windup == red.extra_windup and player.footwork_scale < 1.0,
		"Triad shares duel footwork and CPU windup")
	for frame in 40:
		match_state.tick([Vector3i.ZERO, match_state.computer_command(1), match_state.computer_command(2)])
		if frame < 28:
			check(red.action == "idle" and blue.action == "idle", "Both triad CPUs observe before acting")
	check(red.x < 320.0 and blue.x < 439.0 and match_state.computers[1].target == 0
		and match_state.computers[2].target == 1, "Both triad CPUs pursue their own opponents")
	var defensive_runs := 0
	for seed in 24:
		match_state.random.seed = seed
		match_state.start(3, 1)
		player = match_state.fighters[0]
		red = match_state.fighters[1]
		blue = match_state.fighters[2]
		player.x = 295.0
		red.face = -1
		blue.x = 415.0
		for frame in 20:
			var red_command: Vector3i = match_state.computer_command(1)
			var blue_command: Vector3i = match_state.computer_command(2)
			check(blue_command == Vector3i.ZERO, "The distant third CPU does not copy the nearby CPU's defense")
			match_state.tick([Vector3i(1, -1, 0), red_command, blue_command])
			if player.attack_live and (red.action == "duck" or red.blocking):
				defensive_runs += 1
	check(defensive_runs > 0, "Triad CPU defends against a nearby attack")

	match_state.start(3, 3)
	player = match_state.fighters[0]
	red = match_state.fighters[1]
	blue = match_state.fighters[2]
	player.x = 290.0
	red.x = 315.0
	blue.x = 365.0
	var punch := Vector3i(1, -1, 0)
	for frame in 20:
		match_state.tick([punch, Vector3i.ZERO, Vector3i.ZERO])
		if match_state.hits > 0:
			break
	check(match_state.is_repositioning(0) and match_state.is_repositioning(1)
		and not match_state.is_repositioning(2), "Triad resets only the fighters involved in the hit")
	var timer: int = match_state.frames_left
	var third_x: float = blue.x
	for frame in 72:
		match_state.tick([punch, Vector3i.ZERO, Vector3i(-1, 0, 0)])
	check(blue.x < third_x and match_state.frames_left == timer - 72,
		"The third fighter and triad clock continue during repositioning")
	check(player.points == 1 and red.down == 0 and absf(red.x - player.x) >= 105.0,
		"The triad pair gets space to restart without a follow-up hit")

	match_state.start(3, 3)
	player = match_state.fighters[0]
	red = match_state.fighters[1]
	blue = match_state.fighters[2]
	player.x = 320.0
	red.x = 295.0
	blue.x = 345.0
	for frame in 20:
		match_state.tick([Vector3i(-1, -1, 1), Vector3i.ZERO, Vector3i.ZERO])
		if match_state.hits > 0:
			break
	check(match_state.hits == 2 and match_state.reset_slots.size() == 3,
		"A double kick can reposition all three involved fighters")
	match_state.start(2, 2, false)
	match_state.sudden_death = true
	match_state.fighters[0].x = 300.0
	match_state.fighters[1].x = 325.0
	for frame in 25:
		match_state.tick([punch, Vector3i.ZERO])
	check(match_state.finished and match_state.winners == [0] and match_state.fighters[0].points == 2,
		"The first hit wins a deciding round before the usual six points")

func test_ball_practice() -> void:
	var practice = load("res://scripts/bonus_round.gd").new()
	practice.start("balls", 0)
	if not practice.has_method("start_ball_practice"):
		check(false, "Guided ball practice can be started")
		return
	practice.start_ball_practice()
	check(not practice.ball.is_empty() and practice.ball.x in [24.0, 616.0], "First ball is fully inside the arena before flight")
	var defense := Vector3i(practice.ball.side, roundi((practice.ball.target_y - 273.0) / 16.0), 0)
	var start_x: float = practice.ball.x
	for i in 59:
		practice.tick(defense)
	check(practice.face == defense.x and practice.ball.x == start_x, "Shield responds while first ball waits")
	for i in 145:
		practice.tick(defense)
	check(practice.score == 0, "First ball gives at least 2.4 seconds of visible flight")
	for i in 28:
		practice.tick(defense)
	check(practice.score == 100 and practice.resolved == 1, "First ball is deflected at the slower speed")
	for i in 300:
		if practice.resolved >= 2:
			break
		var wrong := Vector3i.ZERO
		if not practice.ball.is_empty():
			wrong.x = -int(practice.ball.side)
		practice.tick(wrong)
	check(not practice.finished and practice.resolved == 2 and practice.score == 100, "Missing ball two allows another attempt")
	for i in 1500:
		var wrong := Vector3i.ZERO
		if not practice.ball.is_empty():
			wrong.x = -int(practice.ball.side)
		practice.tick(wrong)
		if practice.finished:
			break
	check(practice.finished and practice.resolved == 6 and practice.score == 100, "Practice finishes after six balls and preserves successful catches")

func test_input() -> void:
	var controls = load("res://scripts/local_input.gd").new()
	var dpad := InputEventJoypadButton.new()
	dpad.device = 7
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	controls.receive(dpad)
	dpad = InputEventJoypadButton.new()
	dpad.device = 2
	dpad.button_index = JOY_BUTTON_DPAD_LEFT
	dpad.pressed = true
	controls.receive(dpad)
	var axis := InputEventJoypadMotion.new()
	axis.device = 3
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = -0.63
	controls.receive(axis)
	check(controls.combat_command(3) == Vector3i(0, -1, 4), "Up alone is movement input without an automatic jump")
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.28
	controls.receive(axis)
	check(controls.combat_command(3) == Vector3i(1, -1, 4), "An uneven stick diagonal is recognized as movement input")
	var diagnostics: Dictionary = controls.pad_diagnostics(3)
	check(diagnostics.stick.is_equal_approx(Vector2(0.28, -0.63))
		and diagnostics.recognized == Vector3i(1, -1, 0) and diagnostics.dpad.is_empty(),
		"Diagnostics show the raw stick values and the actual recognized diagonal")
	dpad.device = 3
	controls.receive(dpad)
	controls.combat_command(3)
	diagnostics = controls.pad_diagnostics(3)
	check(diagnostics.dpad == "←" and diagnostics.stick_direction == Vector2i(1, -1)
		and diagnostics.recognized == Vector3i(-1, 0, 0), "Diagnostics distinguish D-pad override from stick direction")
	check(controls.pad_command(2) == Vector3i(-1, 0, 0), "Gamepad inputs stay separate")
	controls.forget(7)
	check(controls.pad_command(7) == Vector3i.ZERO, "Disconnected pad cannot leave a stuck direction")

func test_practice_lanes() -> void:
	var practice = load("res://scripts/bonus_round.gd").new()
	var targets: Array[float] = []
	var previous_speed := 0.0
	var impact_distances := [{}, {}]
	for index in 6:
		practice.random.seed = 29
		practice.start_ball_practice()
		practice.count = index
		practice.spawn_practice_ball()
		var direction: int = practice.ball.side
		targets.append(float(practice.ball.target_y))
		var correct_height := int((targets[index] - 273.0) / 16.0)
		var speed := absf(float(practice.ball.vx))
		check(speed > previous_speed, "Practice ball %d is faster than the previous ball" % (index + 1))
		previous_speed = speed
		var last_y: float = practice.ball.y
		var last_distance := absf(float(practice.ball.x) - 320.0)
		var was_falling := false
		var bounces := 0
		var falls_toward_shield := true
		for frame in 260:
			practice.tick(Vector3i(direction, correct_height, 0))
			if practice.resolved > 0:
				break
			var next_y: float = practice.ball.y
			var next_distance := absf(float(practice.ball.x) - 320.0)
			if was_falling and next_y < last_y and last_y >= 298.0:
				bounces += 1
				impact_distances[(direction + 1) >> 1][correct_height] = last_distance
			if last_distance < 38.0:
				falls_toward_shield = falls_toward_shield and next_y > last_y
			was_falling = next_y > last_y
			last_y = next_y
			last_distance = next_distance
		check(bounces == 1, "Practice ball %d visibly bounces once" % (index + 1))
		check(falls_toward_shield, "Practice ball %d continues its arc all the way to the shield" % (index + 1))
		check(practice.score == 100 and practice.outgoing.size() == 1
			and is_equal_approx(float(practice.outgoing[0].y), targets[index]),
			"Practice ball %d is caught exactly at its matching shield height" % (index + 1))
		for wrong_height in [-1, 0, 1]:
			if wrong_height == correct_height:
				continue
			practice.random.seed = 29
			practice.start_ball_practice()
			practice.count = index
			practice.spawn_practice_ball()
			for frame in 260:
				if practice.resolved > 0:
					break
				practice.tick(Vector3i(direction, wrong_height, 0))
			check(practice.score == 0, "Practice ball %d cannot be caught in adjacent shield lane %d" % [index, wrong_height])
	for side in impact_distances:
		check(side.size() == 3 and side[-1] < side[0] and side[0] < side[1],
			"Each side has three distinct impact locations, earlier for lower arrivals")

func test_ball_shuffle() -> void:
	var bonus = load("res://scripts/bonus_round.gd").new()
	bonus.random.seed = 26
	bonus.start_ball_practice()
	var first: Array = bonus.ball_order.duplicate()
	bonus.start("balls", 0, true)
	var second: Array = bonus.ball_order.duplicate()
	check(first != second, "A new round shuffles the ball paths")
	for i in 2:
		bonus.shuffle_ball_group()
	for group in 3:
		var seen := {}
		for i in 6:
			var path: Vector2i = bonus.ball_order[group * 6 + i]
			seen[path] = true
		check(seen.size() == 6, "Each shuffled group contains all six ball paths")
	print("Shuffled ball orders: ", first, " / ", second)

func test_survival() -> void:
	var state = load("res://scripts/survival.gd").new()
	state.record_path = "user://test-survival-%d.cfg" % OS.get_process_id()
	for mode in 4:
		state.start(mode)
		for frame in 450:
			state.tick(Vector3i.ZERO)
			if state.finished:
				break
		check(state.finished and state.best_time(mode) > 0, "Idle run ends and saves a record in discipline %d" % mode)
	var replay = load("res://scripts/survival.gd").new()
	replay.record_path = state.record_path
	replay.load_records()
	for mode in 4:
		var best: int = replay.best_time(mode)
		check(best == state.best_time(mode), "Best times are stored separately across sessions")
		replay.start(mode)
		replay.ticks = best - 1
		replay.end_run()
		check(replay.best_time(mode) == best and not replay.record, "A shorter run preserves the record")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.record_path))
	state.record_path = "user://invalid-smoke-directory/times.cfg"
	state.start(0)
	state.spawn()
	var early_speed: float = state.hazards[-1].speed
	var early_interval: int = state.spawn_wait
	state.ticks = 2400
	state.spawn()
	check(state.hazards.size() == 2 and state.hazards[-1].speed > early_speed and state.spawn_wait < early_interval,
		"Later barrels are faster, more frequent and can overlap")
	state.start(0)
	state.spawn_wait = 10000
	state.hazards.append({"x": 385.0, "y": 298.0, "speed": 2.0, "age": 0, "fuse": 0, "deflected": false})
	state.fighter.action = "jump"
	state.fighter.age = 9
	for frame in 17:
		state.tick(Vector3i.ZERO)
	check(not state.finished and state.hazards[0].x > state.fighter.x + 12.0, "A barrel can pass under a jumping fighter")
	state.start(1)
	state.spawn_wait = 10000
	state.hazards.append({"x": 385.0, "y": 257.0, "speed": 3.5, "age": 0, "fuse": 0, "deflected": false})
	for frame in 14:
		state.tick(Vector3i(0, 1, 0))
	check(not state.finished, "A high arrow passes a crouching fighter")
	for mode in [0, 2, 3]:
		var moves := [Vector3i(0, 1, 0)]
		var heights := [298.0]
		if mode == 2:
			moves = [Vector3i(-1, -1, 0), Vector3i(-1, 0, 1), Vector3i(0, 1, 0)]
			heights = [260.0, 276.0, 294.0]
		for i in moves.size():
			state.start(mode)
			state.spawn_wait = 10000
			state.hazards.append({"x": 366.0, "y": heights[i], "speed": 0.5, "age": 0, "fuse": 44, "deflected": false})
			for frame in 26:
				state.tick(moves[i])
			check(not state.finished and state.cleared == 1, "Intended attack clears obstacle %d at height %d" % [mode, i])

func test_survival_save_failure() -> void:
	var state = load("res://scripts/survival.gd").new()
	var path := "user://test-survival-recovery-%d.cfg" % OS.get_process_id()
	state.record_path = path
	state.start(0)
	state.ticks = 480
	state.end_run()
	check(state.record, "Initial survival record can be saved")

	# The saved file cannot serve as a parent directory.
	state.record_path = path.path_join("times.cfg")
	state.start(0)
	state.ticks = 600
	state.end_run()
	check(not state.record and state.best_time(0) == 480, "Save failure preserves the previous best time")

	state.record_path = path
	state.start(0)
	state.ticks = 540
	state.end_run()
	var reloaded = load("res://scripts/survival.gd").new()
	reloaded.record_path = path
	reloaded.load_records()
	check(state.record and state.best_time(0) == 540 and reloaded.best_time(0) == 540,
		"A shorter run can set a new record once saving is possible again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_game() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.menu_buttons.size() == 5, "New main menu exposes tournament, training and testing")
	if game.menu_buttons.size() != 5:
		game.queue_free()
		await process_frame
		return
	var buttons := [game.MenuItem.TOURNAMENT, game.MenuItem.TRAINING, game.MenuItem.TESTS]
	var phases := ["tournament_menu", "training_menu", "test_menu"]
	for i in buttons.size():
		game.show_menu()
		game.menu_buttons[buttons[i]].pressed.emit()
		check(game.phase == phases[i], "The three main modes are reachable")
	var devices: Array[int] = [7, 9, 12]
	check(game.seat_devices(devices, Vector2i(1, 2)) == [-1, 7, 9], "One keyboard and two pads occupy distinct slots")
	check(game.seat_devices(devices, Vector2i(0, 3)) == [7, 9, 12], "Three pads can play without a keyboard")
	check(game.seat_devices(devices, Vector2i(1, 0)) == [-1, -2, -2], "Unassigned seats become CPU fighters")
	game.show_tournament_setup()
	game.setup_index = 0
	game.overlay_buttons[1].pressed.emit()
	check(game.phase == "fight" and game.campaign.active and game.pads == [-1, -2, -2], "Tournament starts as 1:1:1")
	for i in 3:
		close_campaign_round(game, i)
		if i < 2:
			game.advance()
			check(game.phase == "fight" and game.campaign.round == i + 2, "Normal tournament rounds advance directly to combat")
	check(game.campaign.wins == [1, 1, 1] and not game.campaign.finished, "A three-way tie calls for a deciding round")
	game.advance()
	check(game.campaign.deciding and game.tournament.sudden_death and game.tournament.fighters.size() == 3,
		"Three tied fighters enter sudden death")
	close_campaign_round(game, 0)
	check(game.campaign.qualified and game.overlay_buttons[0].text == "Nach Marokko",
		"A local winner in Japan can continue to Morocco")
	game.advance()
	check(game.campaign.location == 1 and game.campaign.round == 1 and game.campaign.wins == [0, 0, 0],
		"Morocco starts a fresh set of three rounds")
	for i in 3:
		close_campaign_round(game, 0 if i < 2 else 1)
		if i < 2:
			game.advance()
	check(game.campaign.finished and game.campaign.qualified and game.overlay_buttons[0].text == "Nach Brasilien",
		"A local winner in Morocco can continue to Brazil")
	if game.campaign.qualified:
		game.advance()
		check(game.phase == "fight" and game.campaign.location == 2 and game.campaign.round == 1
			and game.campaign.wins == [0, 0, 0] and game.pads == [-1, -2, -2],
			"Rio starts a fresh set with the returning player and two CPU fighters")
		check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
			"Rio renders its high-resolution background at window resolution")
		for i in 3:
			close_campaign_round(game, 0 if i < 2 else 2)
			if i < 2:
				game.advance()
		check(game.campaign.finished and game.campaign.winner == 0 and not game.campaign.qualified
			and game.overlay_buttons[0].text == "Hauptmenü", "Rio concludes the tournament")
	game.advance()
	check(game.phase == "menu" and root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT,
		"Tournament final leads back to the main menu at the original display scale")
	game.show_tournament_setup()
	game.start_campaign()
	for winner in [0, 0, 1, 1, 1, 2]:
		close_campaign_round(game, winner)
		if not game.campaign.finished or game.campaign.qualified:
			game.advance()
	check(game.campaign.location == 1 and game.campaign.finished and game.campaign.winner == 1
		and not game.campaign.qualified and game.overlay_buttons[0].text == "Hauptmenü",
		"A CPU win in Morocco ends the tournament")
	game.advance()
	check(game.phase == "menu", "Losing in Morocco leads back to the main menu")
	game.show_tournament_setup()
	game.start_campaign()
	for winner in [0, 1, -1]:
		close_campaign_round(game, winner)
		game.advance()
	check(game.campaign.deciding and game.campaign.roster == [0, 1] and game.tournament.fighters.size() == 2,
		"Only the two leaders contest a two-way tie")
	game.show_training_menu()
	check(game.overlay_buttons.size() == 6, "Training offers five separately selectable disciplines")
	game.overlay_buttons[4].pressed.emit()
	check(game.phase == "fight" and game.solo_duel and game.tournament.fighters.size() == 2, "Fifth discipline is a classic duel")
	game.banner = 0
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	game.pads[0] = 7
	Input.parse_input_event(key)
	var previous_x: float = game.tournament.fighters[0].x
	game._physics_process(1.0 / 60.0)
	check(game.tournament.fighters[0].x > previous_x, "Training duel permits the keyboard alongside a connected pad")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	game.show_test_menu()
	game.overlay_buttons[0].pressed.emit()
	check(game.phase == "training" and not game.training.guided, "Sandsack and diagnostics remain accessible under Testen")
	game.pads[0] = 7
	var axis := InputEventJoypadMotion.new()
	axis.device = 7
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = -0.7
	Input.parse_input_event(axis)
	game._physics_process(1.0 / 60.0)
	check(game.controls.pad_diagnostics(7).recognized == Vector3i(0, -1, 0)
		and game.training_command == Vector3i(0, -1, 4), "Training receives up without an automatic jump")
	axis = axis.duplicate()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.32
	Input.parse_input_event(axis)
	game._physics_process(1.0 / 60.0)
	check(game.training_command == Vector3i(1, -1, 4), "Training shows the actual diagonal delivered to the fighter")
	game.show_test_menu()
	game.overlay_buttons[2].pressed.emit()
	check(game.phase == "bonus" and game.bonus.ball_practice and not game.bonus.ball.is_empty(), "Ball practice survives in Testen")
	game.show_test_menu()
	game.overlay_buttons[4].pressed.emit()
	check(game.phase == "bonus" and game.bonus.kind == "bombs", "Original bomb practice survives in Testen")
	game.queue_free()
	await process_frame
	await process_frame

func close_campaign_round(game, winner: int) -> void:
	if winner >= 0:
		game.tournament.fighters[winner].points = 6
	game.tournament.frames_left = 1
	game._physics_process(1.0 / 60.0)
	check(game.phase == "round_end", "Campaign round resolves")


func test_computer_ball_practice() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# This accelerated test exercises scoring, so leave audio playback to the graphical run.
	game.tick_sound.stream = null
	game.show_test_menu()
	var demo: Button = null
	for button in game.overlay_buttons:
		if button.text == "Computer / Bälle abwehren":
			demo = button
			break
	check(demo != null, "The main menu offers a computer shield demo")
	if demo == null:
		game.queue_free()
		await process_frame
		return
	demo.pressed.emit()
	var round = game.bonus
	check(game.phase == "bonus" and round.guided_balls, "Computer uses the same ball practice")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_DPAD_LEFT
	press.pressed = true
	game._input(press)
	check(round.face == 1, "Viewer input cannot take over the computer shield")
	var reactions: Array[int] = []
	var contact_tick := -1
	var current_ball := 0
	for tick in 1600:
		if game.phase != "bonus":
			break
		if not round.ball.is_empty() and round.count != current_ball:
			current_ball = round.count
			contact_tick = -1
		if not round.ball.is_empty() and contact_tick == -1:
			var distance := absf(float(round.ball.x) - 320.0)
			if distance <= float(round.ball.bounce_distance):
				contact_tick = tick
		game._physics_process(1.0 / 60.0)
		if contact_tick >= 0 and current_ball > reactions.size() and not round.ball.is_empty() and round.computer_shield_command() != Vector3i.ZERO:
			reactions.append(tick - contact_tick)
	check(game.phase == "bonus_end" and round.score == 600, "Computer can finish the six-ball demo at the accepted speeds")
	check(reactions.size() == 6, "Computer visibly reacts to all six balls")
	for reaction in reactions:
		check(reaction >= 22 and reaction <= 25, "Computer takes about 0.4 seconds to react after each bounce")
	print("Computer ball practice: reaction ticks after bounce ", reactions, ", score ", round.score)
	if game.phase == "bonus_end":
		game.advance()
		check(game.phase == "bonus" and game.practice_cpu and round.resolved == 0, "Replay restarts the computer demonstration")
	game.queue_free()
	await process_frame
