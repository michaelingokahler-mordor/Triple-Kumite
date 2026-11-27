extends SceneTree

const LocalInput = preload("res://scripts/local_input.gd")
const Fighter = preload("res://scripts/fighter.gd")

var failures: Array[String] = []
var checks := 0
var integration_finished := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func axis(controls, device: int, which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = which
	event.axis_value = value
	controls.receive(event)

func stick(controls, direction: Vector2i, device: int = 7) -> void:
	axis(controls, device, JOY_AXIS_LEFT_X, direction.x * 0.8)
	axis(controls, device, JOY_AXIS_LEFT_Y, direction.y * 0.8)

func button(controls, which: JoyButton, pressed: bool, device: int = 7) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = which
	event.pressed = pressed
	controls.receive(event)

func run() -> void:
	test_combinations()
	test_short_presses()
	test_triggers()
	test_aliases_and_devices()
	test_buffer_and_rolls()
	test_turning_threat_and_legacy_input()
	await test_game_entry()
	check(integration_finished, "The complete game entry test reaches its final assertion")
	for failure in failures:
		printerr(failure)
	print("GAMEPAD checks=%d failures=%d" % [checks, failures.size()])
	quit(int(not failures.is_empty()))

func test_combinations() -> void:
	# Literal expectations from the approved table, viewed facing right.
	var directions := [Vector2i.ZERO, Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
	var expected := [
		["idle", "headbutt", "punch", "punch", "duck_punch", "duck_punch", "turn_duck_punch", "turn_punch", "turn_punch"],
		["idle", "high", "high", "body", "shin", "sweep", "turn_sweep", "turn_kick", "turn_kick"],
		["idle", "jump", "double", "flying", "roll_forward", "jump", "roll_back", "flip", "double"],
	]
	for facing in [1, -1]:
		for group in 3:
			for i in directions.size():
				for source in 2:
					var controls := LocalInput.new()
					var direction: Vector2i = directions[i]
					direction.x *= facing
					stick(controls, direction)
					if source == 0:
						button(controls, [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X][group], true)
					elif group == 0:
						button(controls, JOY_BUTTON_RIGHT_SHOULDER, true)
					else:
						axis(controls, 7, JOY_AXIS_TRIGGER_RIGHT if group == 1 else JOY_AXIS_TRIGGER_LEFT, 0.8)
					var fighter := Fighter.new()
					fighter.reset(320.0, facing)
					fighter.step(controls.combat_command(7), false)
					check(fighter.action == expected[group][i], "Mapping face=%d group=%d source=%d direction=%s expected %s, got %s" %
						[facing, group, source, direction, expected[group][i], fighter.action])

func test_short_presses() -> void:
	var controls := LocalInput.new()
	stick(controls, Vector2i(1, -1))
	button(controls, JOY_BUTTON_A, true)
	button(controls, JOY_BUTTON_A, false)
	stick(controls, Vector2i.ZERO)
	var fighter := Fighter.new()
	var impacts := 0
	for tick in 65:
		fighter.step(controls.combat_command(7), false)
		impacts += int(fighter.attack_live)
	check(impacts == 1, "A press and release between physics steps completes exactly one attack")

	controls = LocalInput.new()
	fighter = Fighter.new()
	stick(controls, Vector2i(1, 0))
	button(controls, JOY_BUTTON_B, true)
	impacts = 0
	for tick in 100:
		fighter.step(controls.combat_command(7), false)
		impacts += int(fighter.attack_live)
	check(impacts == 1, "Holding an attack button never repeats the attack")

	controls = LocalInput.new()
	fighter = Fighter.new()
	button(controls, JOY_BUTTON_A, true)
	fighter.step(controls.combat_command(7), false)
	stick(controls, Vector2i(1, -1))
	impacts = 0
	for tick in 40:
		fighter.step(controls.combat_command(7), false)
		impacts += int(fighter.attack_live)
	check(impacts == 0, "A button pressed in neutral stays inactive when the held stick later moves")
	controls = LocalInput.new()
	fighter = Fighter.new()
	stick(controls, Vector2i(0, -1))
	for tick in 4:
		fighter.step(controls.combat_command(7), false)
	stick(controls, Vector2i(1, -1))
	button(controls, JOY_BUTTON_A, true)
	fighter.step(controls.combat_command(7), false)
	check(fighter.action == "punch" and fighter.lift == 0, "Moving through up before a punch never starts an unwanted jump")

func test_triggers() -> void:
	for trigger in [JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT]:
		var controls := LocalInput.new()
		stick(controls, Vector2i(1, 0))
		axis(controls, 7, trigger, 0.60)
		var fighter := Fighter.new()
		fighter.step(controls.combat_command(7), false)
		check(fighter.action == ("body" if trigger == JOY_AXIS_TRIGGER_RIGHT else "flying"),
			"RT and LT start the same moves as B and X")
		for value in [0.54, 0.41, 0.58, 0.85]:
			axis(controls, 7, trigger, value)
			check(controls.combat_command(7).z == 4, "Trigger noise does not generate another press")
		axis(controls, 7, trigger, 0.2)
		controls.combat_command(7)
		axis(controls, 7, trigger, 0.8)
		check(controls.combat_command(7).z == (6 if trigger == JOY_AXIS_TRIGGER_RIGHT else 7),
			"A released trigger can start a new move")

func test_aliases_and_devices() -> void:
	var controls := LocalInput.new()
	stick(controls, Vector2i(1, -1))
	button(controls, JOY_BUTTON_RIGHT_SHOULDER, true)
	check(controls.combat_command(7) == Vector3i(1, -1, 5), "RB is a punch alias")
	button(controls, JOY_BUTTON_A, true)
	check(controls.combat_command(7).z == 4, "Pressing A while RB is held does not duplicate the punch")
	button(controls, JOY_BUTTON_RIGHT_SHOULDER, false)
	button(controls, JOY_BUTTON_A, false)
	button(controls, JOY_BUTTON_A, true)
	check(controls.combat_command(7).z == 5, "Releasing both aliases rearms the punch")
	button(controls, JOY_BUTTON_LEFT_SHOULDER, true, 9)
	var other := Fighter.new()
	other.step(controls.combat_command(9), false)
	check(other.face == -1 and other.x == 320, "LB turns only its own player in place")
	check(controls.combat_command(7).z == 4, "Devices do not consume each other's action")
	button(controls, JOY_BUTTON_A, false)
	button(controls, JOY_BUTTON_A, true)
	controls.forget(7)
	check(controls.combat_command(7).z == 4, "Disconnect discards the pending attack")

func test_buffer_and_rolls() -> void:
	var fighter := Fighter.new()
	fighter.step(Vector3i(1, -1, 5), false)
	for tick in 23:
		fighter.step(Vector3i(0, 0, 4), false)
	fighter.step(Vector3i(1, 0, 6), false)
	for tick in 4:
		fighter.step(Vector3i(0, 0, 4), false)
	check(fighter.action == "body", "A short next attack near the end of recovery is buffered")
	for facing in [1, -1]:
		for forward in [true, false]:
			fighter = Fighter.new()
			fighter.reset(320.0, facing)
			fighter.step(Vector3i(facing if forward else -facing, 1, 7), false)
			var expected := "roll_forward" if forward else "roll_back"
			check(fighter.action == expected and fighter.lift == 0, "A ground roll starts without jumping")
			for tick in 12:
				fighter.step(Vector3i(0, 0, 4), false)
			check((fighter.x - 320) * facing * (1 if forward else -1) > 20 and fighter.face == facing and fighter.lift == 0,
				"Roll direction mirrors correctly and keeps facing and ground contact")
			var attacker := Fighter.new()
			attacker.reset(fighter.x - 25.0, 1)
			attacker.action = "punch"
			attacker.attack_live = true
			check(not attacker.can_hit(fighter), "A high punch passes over a ground roll")
			attacker.action = "sweep"
			check(attacker.can_hit(fighter), "A ground roll remains vulnerable to a sweep")
			for tick in 50:
				fighter.step(Vector3i(0, 0, 4), false)
			check(fighter.action == "idle", "Releasing the button finishes a single roll")
		fighter.reset(610.0, facing)
		fighter.step(Vector3i(1, 1, 7), false)
		for tick in 40:
			fighter.step(Vector3i(0, 0, 4), false)
		check(fighter.x <= 612 and fighter.x >= 28, "Rolls stay inside arena boundaries")

func test_game_entry() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.tick_sound.stream = null
	game.show_test_menu()
	game.overlay_buttons[0].pressed.emit()
	game.pads[0] = 7
	stick(game.controls, Vector2i(1, 0))
	var press := InputEventJoypadButton.new()
	press.device = 7
	press.pressed = true
	press.button_index = JOY_BUTTON_B
	game._input(press)
	check(game.phase == "training", "B is a kick and never opens pause during play")
	if game.phase == "training":
		game._physics_process(1.0 / 60.0)
		check(game.training.fighter.action == "body", "The normal menu entry delivers B as a kick")
	for reset_with_pad in [true, false]:
		game.training.reset_stance()
		press.button_index = JOY_BUTTON_A
		press.pressed = false
		game._input(press)
		press.pressed = true
		game._input(press)
		if reset_with_pad:
			press.button_index = JOY_BUTTON_BACK
			game._input(press)
		else:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_R
			key.keycode = KEY_R
			key.pressed = true
			game._input(key)
		game._physics_process(1.0 / 60.0)
		check(game.training.fighter.action == "walk", "Reset discards an attack pressed earlier in the same physics step")
	game.show_test_menu()
	game.overlay_buttons[0].pressed.emit()
	game.pads[0] = 7
	stick(game.controls, Vector2i(0, -1))
	press.button_index = JOY_BUTTON_X
	game._input(press)
	game._physics_process(1.0 / 60.0)
	check(game.training.fighter.action == "jump", "X starts a jump through the normal input callback")
	press.button_index = JOY_BUTTON_START
	game._input(press)
	check(game.phase == "pause", "Start still pauses")
	press.button_index = JOY_BUTTON_A
	game._input(press)
	check(game.phase == "training", "A resumes from pause")
	game._physics_process(1.0 / 60.0)
	check(game.training.fighter.action == "jump", "A used to resume does not queue a punch")
	game.show_tournament_setup()
	game.start_campaign()
	game.pads[0] = 7
	game.tournament_seats[0] = 7
	game.banner = 1
	stick(game.controls, Vector2i(1, -1))
	press.button_index = JOY_BUTTON_A
	press.pressed = false
	game._input(press)
	press.pressed = true
	game._input(press)
	game._physics_process(1.0 / 60.0)
	check(not Fighter.ATTACKS.has(game.tournament.fighters[0].action)
		and game.tournament.frames_left == 1799, "The final countdown tick discards pre-fight attack presses")
	game.queue_free()
	await process_frame
	integration_finished = true

func test_turning_threat_and_legacy_input() -> void:
	var match_state = load("res://scripts/tournament.gd").new()
	for facing in [1, -1]:
		var attacker := Fighter.new()
		attacker.reset(320, facing)
		attacker.step(Vector3i(-facing, 1, 5), false)
		check(match_state.is_attack_threat(attacker, 25.0 * facing),
			"CPU recognizes the side threatened by a turning crouched punch")
	var fighter := Fighter.new()
	fighter.step(Vector3i(0, 0, 8), false)
	fighter.step(Vector3i(-1, -1, 0), false)
	fighter.step(Vector3i.ZERO, false)
	check(fighter.action == "idle", "An instant gamepad turn preserves keyboard attack release behavior")
