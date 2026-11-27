extends Node2D

const Tournament = preload("res://scripts/tournament.gd")
const BonusRound = preload("res://scripts/bonus_round.gd")
const Training = preload("res://scripts/training.gd")
const Survival = preload("res://scripts/survival.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Fighter = preload("res://scripts/fighter.gd")
const LocalInput = preload("res://scripts/local_input.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const MONO_FONT = preload("res://assets/IBMPlexMono-Medium.ttf")

enum MenuItem { TOURNAMENT, TRAINING, TESTS, HELP, QUIT }

var tournament := Tournament.new()
var bonus := BonusRound.new()
var training := Training.new()
var survival := Survival.new()
var campaign := Campaign.new()
var training_command := Vector3i.ZERO
var controls := LocalInput.new()
var phase := "menu"
var view: Node2D
var interface: Control
var menu_buttons: Array[Button] = []
var overlay_buttons: Array[Button] = []
var pads: Array[int] = []
var tournament_seats: Array[int] = []
var setup_options: Array[Vector2i] = []
var setup_index := 0
var setup_button: Button
var solo_duel := false
var preferred_pad := -1
var menu_axis: Dictionary = {}
var pending_turns: Dictionary = {}
var practice_cpu := false
var paused_from := "fight"
var help_from := "menu"
var banner := 0
var message := ""
var result_delay := 0
var hit_sound: AudioStreamPlayer
var tick_sound: AudioStreamPlayer

func _ready() -> void:
	view = ArenaView.new()
	view.game = self
	add_child(view)
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.size = Vector2(640, 360)
	add_child(interface)
	hit_sound = make_sound(false)
	tick_sound = make_sound(true)
	survival.load_records()
	Input.joy_connection_changed.connect(on_pad_connection)
	get_window().focus_exited.connect(on_focus_lost)
	show_menu()

func show_menu() -> void:
	campaign.active = false
	phase = "menu"
	Input.use_accumulated_input = true
	message = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_buttons()
	var names := ["Turnier  /  1 gegen 1 gegen 1", "Training", "Testen", "Steuerung", "Beenden"]
	for i in names.size():
		var y: int = [146, 187, 228, 291, 291][i]
		var width := 243 if i < MenuItem.HELP else 117
		var x := 162 if i == MenuItem.QUIT else 36
		var button := add_button(names[i], Vector2(x, y), Vector2(width, 29), i < MenuItem.HELP)
		button.pressed.connect(menu_action.bind(i))
		menu_buttons.append(button)
	set_neighbors(menu_buttons)
	menu_buttons[0].grab_focus()

func menu_action(index: int) -> void:
	match index:
		MenuItem.TOURNAMENT:
			show_tournament_setup()
		MenuItem.TRAINING:
			show_training_menu()
		MenuItem.TESTS:
			show_test_menu()
		MenuItem.HELP:
			show_help()
		MenuItem.QUIT:
			get_tree().quit()

func open_submenu(name: String) -> void:
	phase = name
	Input.use_accumulated_input = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_buttons()

func submenu_button(label: String, y: int, callback: Callable, primary: bool = false) -> Button:
	var button := add_button(label, Vector2(36, y), Vector2(243, 24), primary)
	button.pressed.connect(callback)
	overlay_buttons.append(button)
	return button

func finish_submenu() -> void:
	set_neighbors(overlay_buttons)
	overlay_buttons[0].grab_focus()

func show_tournament_setup() -> void:
	open_submenu("tournament_menu")
	setup_button = submenu_button("", 169, change_setup.bind(1))
	submenu_button("Turnier starten", 209, start_campaign, true)
	submenu_button("Hauptmenü", 277, show_menu)
	update_setup()
	finish_submenu()

func update_setup() -> void:
	var connected := Input.get_connected_joypads().size()
	setup_options.assign([Vector2i(1, 0)])
	for count in range(1, mini(connected, 3) + 1):
		setup_options.append(Vector2i(0, count))
		if count < 3:
			setup_options.append(Vector2i(1, count))
	setup_index = clampi(setup_index, 0, setup_options.size() - 1)
	var choice := setup_options[setup_index]
	var label := "Tastatur" if choice.x == 1 else ""
	if choice.y > 0:
		label += (" + " if choice.x == 1 else "") + "%d Gamepad%s" % [choice.y, "s" if choice.y > 1 else ""]
	setup_button.text = "‹  %s  ›" % label

func change_setup(offset: int) -> void:
	setup_index = posmod(setup_index + offset, setup_options.size())
	update_setup()

func start_campaign() -> void:
	update_setup()
	var choice := setup_options[setup_index]
	tournament_seats = seat_devices(connected_pads(), choice)
	campaign.start()
	solo_duel = false
	start_campaign_round()

static func seat_devices(connected: Array[int], choice: Vector2i) -> Array[int]:
	var seats: Array[int] = []
	if choice.x == 1:
		seats.append(LocalInput.KEYBOARD)
	for i in mini(choice.y, mini(connected.size(), 3 - seats.size())):
		seats.append(connected[i])
	while seats.size() < 3:
		seats.append(LocalInput.CPU)
	return seats

func start_campaign_round() -> void:
	pads.clear()
	for slot in campaign.roster:
		pads.append(tournament_seats[slot])
	tournament.start(pads.size(), 0, false)
	tournament.sudden_death = campaign.deciding
	tournament.round_number = campaign.round
	for i in pads.size():
		tournament.humans[i] = pads[i] != LocalInput.CPU
		if tournament.humans[i]:
			tournament.fighters[i].extra_windup = 0
	start_fight()
	if missing_tournament_device() >= 0:
		show_pause("Gamepad fehlt. Verbinde es und drücke eine Taste.")

func start_training_duel() -> void:
	campaign.active = false
	solo_duel = true
	tournament.start(2, 1, false)
	assign_solo_pad()
	pads.append(LocalInput.CPU)
	start_fight()

func start_fight() -> void:
	phase = "fight"
	clear_player_actions()
	Input.use_accumulated_input = false
	banner = 105
	clear_buttons()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func start_bonus(kind: String, difficulty: int, computer: bool = false) -> void:
	clear_player_actions()
	practice_cpu = computer
	assign_solo_pad()
	if kind == "balls":
		bonus.start_ball_practice()
	else:
		bonus.start(kind, difficulty)
	Input.use_accumulated_input = not bonus.guided_balls or practice_cpu
	phase = "bonus"
	banner = 0 if bonus.guided_balls else 42
	clear_buttons()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func show_training_menu() -> void:
	campaign.active = false
	open_submenu("training_menu")
	for i in Survival.TITLES.size():
		var time := survival.best_time(i)
		var label := "%d  %s" % [i + 1, Survival.TITLES[i]]
		if time > 0:
			label += "   %s" % Survival.time_text(time)
		submenu_button(label, 124 + i * 30, start_survival.bind(i), true)
	submenu_button("5  Zweikampf", 244, start_training_duel, true)
	submenu_button("Hauptmenü", 289, show_menu)
	finish_submenu()

func show_test_menu() -> void:
	campaign.active = false
	open_submenu("test_menu")
	submenu_button("Sandsack / Eingabetest", 124, start_training.bind(false), true)
	submenu_button("Geführte Manöverfolge", 154, start_training.bind(true))
	submenu_button("Bälle abwehren", 184, start_bonus.bind("balls", 0))
	submenu_button("Computer / Bälle abwehren", 214, start_bonus.bind("balls", 0, true))
	submenu_button("Bomben treten", 244, start_bonus.bind("bombs", 0))
	submenu_button("Hauptmenü", 289, show_menu)
	finish_submenu()

func start_survival(discipline: int) -> void:
	survival.start(discipline)
	start_solo("survival")

func start_training(guided: bool) -> void:
	training.start(guided)
	training_command = Vector3i.ZERO
	start_solo("training")

func start_solo(name: String) -> void:
	assign_solo_pad()
	phase = name
	clear_player_actions()
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	clear_buttons()

func connected_pads() -> Array[int]:
	var connected := Input.get_connected_joypads()
	connected.sort()
	if preferred_pad in connected:
		connected.erase(preferred_pad)
		connected.insert(0, preferred_pad)
	var devices: Array[int] = []
	devices.assign(connected)
	return devices

func assign_solo_pad() -> void:
	var connected := connected_pads()
	pads.assign([connected[0] if not connected.is_empty() else LocalInput.KEYBOARD])

func on_pad_connection(device: int, connected: bool) -> void:
	if phase == "tournament_menu":
		update_setup()
	if not connected:
		controls.forget(device)
		menu_axis.erase(device)
		var slot := pads.find(device)
		if slot >= 0:
			if campaign.active:
				if phase == "fight":
					show_pause("Gamepad fehlt. Verbinde es und drücke eine Taste.")
			else:
				pads[slot] = LocalInput.KEYBOARD
				if phase in ["fight", "bonus", "training", "survival"]:
					show_pause("Gamepad getrennt. Tastatur ist aktiv.")
		return
	if not campaign.active and phase in ["training", "survival", "bonus"] and pads[0] == LocalInput.KEYBOARD:
		pads[0] = device

func missing_tournament_device() -> int:
	for device in pads:
		if device >= 0 and device not in Input.get_connected_joypads():
			return device
	return LocalInput.KEYBOARD

func on_focus_lost() -> void:
	if phase in ["fight", "bonus", "training", "survival"]:
		show_pause()

func _physics_process(_delta: float) -> void:
	if phase == "fight":
		if banner > 0 and tournament.frames_left == Tournament.ROUND_FRAMES:
			clear_player_actions()
		banner = maxi(0, banner - 1)
		if banner > 0 and tournament.frames_left == Tournament.ROUND_FRAMES:
			return
		var commands: Array[Vector3i] = []
		for i in tournament.fighters.size():
			if not tournament.humans[i]:
				commands.append(tournament.computer_command(i))
			else:
				commands.append(fighter_input(i))
		tournament.tick(commands)
		if tournament.hits > 0:
			hit_sound.play()
		if tournament.finished:
			if campaign.active:
				var human_seats: Array[bool] = []
				for device in tournament_seats:
					human_seats.append(device != LocalInput.CPU)
				campaign.record_round(tournament.winners, human_seats)
			show_result("round_end")
	elif phase == "bonus":
		banner = maxi(0, banner - 1)
		var previous_score := bonus.score
		var command: Vector3i
		if practice_cpu:
			command = bonus.computer_shield_command()
		else:
			command = controls.ball_practice_command(pads[0]) if bonus.kind == "balls" else controls.combat_command(pads[0], true)
		bonus.tick(command)
		if bonus.score > previous_score:
			tick_sound.play()
		if bonus.finished:
			if not bonus.survived:
				hit_sound.play()
			show_result("bonus_end")
	elif phase == "training":
		var previous_hits := training.hits
		var command := fighter_input(0)
		training_command = command if training.next_wait == 0 else Vector3i.ZERO
		training.tick(command)
		if training.hits > previous_hits:
			tick_sound.play()
		if training.finished:
			show_result("training_end")
	elif phase == "survival":
		var previous_cleared := survival.cleared
		survival.tick(fighter_input(0))
		if survival.cleared > previous_cleared:
			tick_sound.play()
		if survival.finished:
			hit_sound.play()
			show_result("survival_end")
	elif result_delay > 0:
		result_delay -= 1
		if result_delay == 0 and not overlay_buttons.is_empty():
			overlay_buttons[0].disabled = false
			overlay_buttons[0].grab_focus()

func fighter_input(slot: int) -> Vector3i:
	if phase == "fight" and (tournament.is_repositioning(slot) or tournament.fighters[slot].down > 0):
		controls.clear_actions(pads[slot])
		tournament.fighters[slot].clear_buffer()
		pending_turns.erase(slot)
	if pending_turns.erase(slot):
		return Fighter.TURN_COMMAND
	return controls.combat_command(pads[slot], not campaign.active)

func clear_player_actions() -> void:
	pending_turns.clear()
	controls.clear_actions()
	training.fighter.clear_buffer()
	survival.fighter.clear_buffer()
	for fighter in tournament.fighters:
		fighter.clear_buffer()

func show_result(state: String) -> void:
	phase = state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_buttons()
	var label := "Weiter"
	if state != "round_end" or solo_duel:
		label = "Nochmal"
	elif campaign.finished:
		label = "Nach Marokko" if campaign.qualified else "Hauptmenü"
	elif campaign.round == Campaign.ROUNDS_PER_LOCATION:
		label = "Zum Stechen"
	result_delay = 52
	var primary := add_button(label, Vector2(206, 209), Vector2(109, 25), true)
	primary.disabled = true
	primary.pressed.connect(advance)
	var exit_label := "Hauptmenü"
	var exit_action := show_menu
	if state in ["training_end", "bonus_end"]:
		exit_label = "Testen"
		exit_action = show_test_menu
	elif state == "survival_end" or solo_duel:
		exit_label = "Training"
		exit_action = show_training_menu
	var secondary := add_button(exit_label, Vector2(325, 209), Vector2(109, 25))
	secondary.pressed.connect(exit_action)
	overlay_buttons.assign([primary, secondary])
	set_neighbors(overlay_buttons, true)

func advance() -> void:
	if phase == "training_end":
		start_training(true)
	elif phase == "survival_end":
		start_survival(survival.mode)
	elif phase == "round_end":
		if solo_duel:
			start_training_duel()
		elif campaign.finished:
			if campaign.qualified:
				for slot in tournament_seats.size():
					if slot != campaign.winner:
						tournament_seats[slot] = LocalInput.CPU
				campaign.next_location()
				start_campaign_round()
			else:
				show_menu()
		else:
			campaign.next_round()
			start_campaign_round()
	elif phase == "bonus_end":
		start_bonus(bonus.kind, 0, practice_cpu)

func show_pause(reason: String = "") -> void:
	clear_player_actions()
	paused_from = phase
	phase = "pause"
	message = reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_buttons()
	var resume := add_button("Fortsetzen", Vector2(206, 209), Vector2(109, 25), true)
	var to_tests := paused_from in ["training", "bonus"]
	var to_training := paused_from == "survival" or (paused_from == "fight" and solo_duel)
	var leave := add_button("Testen" if to_tests else ("Training" if to_training else "Hauptmenü"), Vector2(325, 209), Vector2(109, 25))
	resume.pressed.connect(resume_play)
	leave.pressed.connect(show_test_menu if to_tests else (show_training_menu if to_training else show_menu))
	overlay_buttons.assign([resume, leave])
	set_neighbors(overlay_buttons, true)
	resume.grab_focus()

func resume_play() -> void:
	if campaign.active and missing_tournament_device() >= 0:
		message = "Gamepad fehlt. Verbinde es und drücke eine Taste."
		return
	phase = paused_from
	clear_player_actions()
	message = ""
	clear_buttons()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func show_help() -> void:
	clear_player_actions()
	help_from = phase
	phase = "help"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_buttons()
	var close := add_button("Zurück", Vector2(250, 306), Vector2(140, 25), true)
	close.pressed.connect(close_help)
	overlay_buttons.append(close)
	close.grab_focus()

func close_help() -> void:
	clear_player_actions()
	if help_from == "menu":
		show_menu()
		menu_buttons[MenuItem.HELP].grab_focus()
	else:
		phase = help_from
		clear_buttons()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func clear_buttons() -> void:
	result_delay = 0
	menu_buttons.clear()
	overlay_buttons.clear()
	for child in interface.get_children():
		interface.remove_child(child)
		child.queue_free()

func add_button(label: String, at: Vector2, dimensions: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.position = at
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if dimensions.x > 150 else HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_override("font", MONO_FONT)
	button.add_theme_font_size_override("font_size", 10)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", Color("f4ede3"))
	button.add_theme_color_override("font_focus_color", Color("ffcc80"))
	button.add_theme_color_override("font_hover_color", Color("ffdcaa"))
	button.add_theme_stylebox_override("normal", button_style(Color("202b42") if primary else Color("151e32"), Color("485874")))
	button.add_theme_stylebox_override("hover", button_style(Color("33415c"), Color("788399")))
	button.add_theme_stylebox_override("pressed", button_style(Color("4b3d48"), Color("f2a85d")))
	button.add_theme_stylebox_override("disabled", button_style(Color("151e32"), Color("343c51")))
	var focus := button_style(Color.TRANSPARENT, Color("eeb475"))
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	interface.add_child(button)
	button.size = dimensions
	return button

func button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = edge
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	style.anti_aliasing = false
	return style

func set_neighbors(buttons: Array[Button], horizontal: bool = false) -> void:
	for i in buttons.size():
		var previous := buttons[posmod(i - 1, buttons.size())].get_path()
		var next := buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = previous
		buttons[i].focus_neighbor_bottom = next
		if horizontal:
			buttons[i].focus_neighbor_left = previous
			buttons[i].focus_neighbor_right = next

func _input(event: InputEvent) -> void:
	controls.receive(event)
	if phase not in ["fight", "training", "survival", "bonus"]:
		controls.clear_actions()
	if event is InputEventJoypadButton and event.pressed and phase == "pause" and campaign.active:
		var missing := missing_tournament_device()
		if missing >= 0 and event.device not in tournament_seats and event.device in Input.get_connected_joypads():
			tournament_seats[tournament_seats.find(missing)] = event.device
			pads[pads.find(missing)] = event.device
			message = "Gamepad verbunden. Du kannst fortsetzen."
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		var fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
		window.mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if phase in ["fight", "training", "survival"] and queue_turn(event):
		get_viewport().set_input_as_handled()
		return
	if phase == "bonus" and bonus.guided_balls and not practice_cpu:
		# Preserve even a turn pressed and released between physics ticks.
		# Ball travel still advances only in the fixed physics update.
		bonus.aim_shield(controls.ball_practice_command(pads[0]))
	if event is InputEventJoypadButton and event.pressed:
		if phase in ["menu", "training_menu", "tournament_menu", "test_menu"]:
			preferred_pad = event.device
		match event.button_index:
			JOY_BUTTON_START:
				back_or_pause()
			JOY_BUTTON_B:
				if phase not in ["fight", "bonus", "training", "survival"]:
					back_or_pause()
			JOY_BUTTON_Y:
				if phase in ["menu", "fight", "bonus", "training", "survival"]:
					show_help()
			JOY_BUTTON_BACK:
				if phase == "training" and training.next_wait == 0:
					clear_player_actions()
					training.reset_stance()
			JOY_BUTTON_DPAD_UP:
				move_focus(-1)
			JOY_BUTTON_DPAD_DOWN:
				move_focus(1)
			JOY_BUTTON_DPAD_LEFT:
				move_horizontal(-1)
			JOY_BUTTON_DPAD_RIGHT:
				move_horizontal(1)
			JOY_BUTTON_A:
				activate_focus()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var axes: Dictionary = menu_axis.get_or_add(event.device, {})
			var previous: int = axes.get(event.axis, 0)
			var direction := int(signf(event.axis_value)) if absf(event.axis_value) >= 0.7 else 0
			if absf(event.axis_value) < 0.35 or direction != 0:
				axes[event.axis] = direction
			if direction != 0 and direction != previous:
				if phase in ["menu", "training_menu", "tournament_menu", "test_menu"]:
					preferred_pad = event.device
				if event.axis == JOY_AXIS_LEFT_Y:
					move_focus(direction)
				else:
					move_horizontal(direction)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			back_or_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R and phase == "training" and training.next_wait == 0:
			clear_player_actions()
			training.reset_stance()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_H and phase in ["menu", "fight", "bonus", "training", "survival"]:
			show_help()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and phase not in ["fight", "bonus", "training", "survival"]:
			activate_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT] and phase not in ["fight", "bonus", "training", "survival"]:
			move_horizontal(-1 if event.keycode == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()

func queue_turn(event: InputEvent) -> bool:
	var slot := -1
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		slot = pads.find(LocalInput.KEYBOARD) if campaign.active else 0
	if slot < 0 or slot >= pads.size():
		return false
	if phase == "fight" and (not tournament.humans[slot] or banner > 0 or tournament.is_repositioning(slot)):
		return false
	pending_turns[slot] = true
	return true

func back_or_pause() -> void:
	match phase:
		"fight", "bonus", "training", "survival":
			show_pause()
		"pause":
			resume_play()
		"help":
			close_help()
		"round_end":
			show_training_menu() if solo_duel else show_menu()
		"bonus_end", "training_end":
			show_test_menu()
		"survival_end":
			show_training_menu()
		"training_menu", "test_menu", "tournament_menu":
			show_menu()

func move_focus(offset: int) -> void:
	var buttons := menu_buttons if phase == "menu" else overlay_buttons
	if buttons.is_empty() or result_delay > 0:
		return
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + offset, buttons.size())].grab_focus()

func move_horizontal(offset: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if phase == "tournament_menu" and focused == setup_button:
		change_setup(offset)
		return
	if phase != "menu":
		move_focus(offset)
	elif focused == menu_buttons[MenuItem.HELP] or focused == menu_buttons[MenuItem.QUIT]:
		menu_buttons[MenuItem.HELP if offset < 0 else MenuItem.QUIT].grab_focus()

func activate_focus() -> void:
	var button := get_viewport().gui_get_focus_owner() as Button
	if button and not button.disabled:
		button.pressed.emit()

func make_sound(bright: bool) -> AudioStreamPlayer:
	var sample := AudioStreamWAV.new()
	sample.mix_rate = 22050
	var frames := 2200 if bright else 3100
	var data := PackedByteArray()
	data.resize(frames)
	var angle := 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = 71
	for i in frames:
		var time := float(i) / frames
		angle += TAU * (lerpf(530.0, 890.0, time) if bright else lerpf(168.0, 49.0, time)) / sample.mix_rate
		var value := sin(angle) * 0.65 + noise.randf_range(-0.35, 0.35) * (0.25 if bright else 1.0)
		data[i] = posmod(int(110.0 * value * pow(1.0 - time, 2.0)), 256)
	sample.data = data
	var player := AudioStreamPlayer.new()
	player.stream = sample
	player.volume_db = -13.0
	add_child(player)
	return player
