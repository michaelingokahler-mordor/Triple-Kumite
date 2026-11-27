extends Node2D

const Art = preload("res://scripts/fighter_art.gd")
const BACKGROUND = preload("res://assets/arena.png")
const MOROCCO = preload("res://assets/arena-morocco.png")
const WATER = preload("res://assets/arena-ripples.png")
const DISPLAY_FONT = preload("res://assets/BarlowCondensed-ExtraBold.ttf")
const MONO_FONT = preload("res://assets/IBMPlexMono-Medium.ttf")
const GROUND := 310
const INK := Color("111725")
const PAPER := Color("f5eddf")
const MUTED := Color("b6bdcf")
const GOLD := Color("f3bb76")
const ACCENTS := [Color("f7e9d5"), Color("ff8a7c"), Color("82c8fb")]
const BALL_COLORS := [Color("8ce0ab"), Color("fbd079"), Color("94cbff")]

var game
var art := Art.new()
var elapsed := 0.0
var version: String = ProjectSettings.get_setting("application/config/version")

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var morocco: bool = game.campaign.active and game.campaign.location == 1
	draw_texture(MOROCCO if morocco else BACKGROUND, Vector2.ZERO)
	if not morocco:
		draw_water()
	if game.phase in ["menu", "training_menu", "tournament_menu", "test_menu"]:
		draw_menu()
		return
	var mode: String = game.phase
	if mode == "pause":
		mode = game.paused_from
	if mode == "help":
		mode = game.help_from
	if mode in ["bonus", "bonus_end"]:
		draw_bonus()
	elif mode in ["fight", "round_end"]:
		draw_fight()
	elif mode in ["training", "training_end"]:
		draw_training()
	elif mode in ["survival", "survival_end"]:
		draw_survival()
	if game.phase in ["pause", "round_end", "bonus_end", "training_end", "survival_end"]:
		draw_overlay()
	elif game.phase == "help":
		draw_help()

func draw_water() -> void:
	var frame := int(elapsed / 0.09) % 24
	var source := Rect2((frame % 6) * 192, (frame / 6) * 64, 192, 64)
	draw_texture_rect_region(WATER, Rect2(270, 211, 192, 64), source)

func draw_menu() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.06, 0.12, 0.11))
	draw_rect(Rect2(22, 25, 272, 320), Color(0.06, 0.085, 0.15, 0.96))
	draw_rect(Rect2(22, 25, 272, 320), Color("4e556c"), false)
	draw_rect(Rect2(22, 25, 272, 2), GOLD)
	match game.phase:
		"training_menu":
			text("TRAINING", 34, 86, 48, GOLD, DISPLAY_FONT)
			text("Zeitdisziplinen und Zweikampf", 36, 106, 9, MUTED)
		"test_menu":
			text("TESTEN", 34, 86, 48, GOLD, DISPLAY_FONT)
		"tournament_menu":
			text("TURNIER", 34, 91, 48, GOLD, DISPLAY_FONT)
			text("Japan  →  Marokko", 36, 114, 10, MUTED)
			text("Freie Plätze übernimmt die CPU.", 36, 151, 9, MUTED)
		_:
			text("TRIPLE", 34, 78, 53, PAPER, DISPLAY_FONT)
			text("KUMITE", 34, 124, 53, GOLD, DISPLAY_FONT)
	text("↑ / ↓  Wählen   ·   Enter / A  Bestätigen", 36, 336, 9, MUTED)
	var display_x := 441.0
	art.draw_fighter(self, Vector2(display_x, 315), 1, 0, "idle", int(elapsed * 25.0), 315)
	art.draw_fighter(self, Vector2(display_x + 72.0, 315), -1, 1, "idle", int(elapsed * 25.0) + 10, 315)
	art.draw_fighter(self, Vector2(display_x + 132.0, 315), -1, 2, "idle", int(elapsed * 25.0) + 20, 315)

func draw_fight() -> void:
	var match_state = game.tournament
	var count: int = match_state.fighters.size()
	var card_width := 135 if count == 3 else 161
	var interpolation := Engine.get_physics_interpolation_fraction() if game.phase == "fight" and game.banner == 0 else 1.0
	for i in count:
		var fighter = match_state.fighters[i]
		var x: int = [19, 166, 486][i] if count == 3 else [19, 460][i]
		var slot: int = game.campaign.roster[i] if game.campaign.active else i
		panel(Rect2(x, 13, card_width, 43))
		draw_rect(Rect2(x, 13, 2, 43), ACCENTS[slot])
		text("SPIELER %d" % (slot + 1) if match_state.humans[i] else "CPU %d" % (slot + 1), x + 9, 27, 9, ACCENTS[slot])
		var total := "%d SIEGE" % game.campaign.wins[slot] if game.campaign.active else "%06d" % fighter.total
		right_text(total, x + card_width - 7, 27, 10, PAPER)
		for p in 6:
			var fill: Color = ACCENTS[slot] if p < fighter.points else Color("3a4358")
			draw_rect(Rect2(x + 9 + p * 12, 36, 9, 8), fill)
		var pose: String = fighter.action
		if fighter.blocking:
			pose = "block"
		var position_x := lerpf(fighter.previous_x, fighter.x, interpolation)
		var lift := lerpf(fighter.previous_lift, fighter.lift, interpolation)
		var pose_age: int = fighter.age
		if Art.Fighter.ATTACKS.has(pose):
			pose_age = maxi(0, pose_age - fighter.extra_windup)
		art.draw_fighter(self, Vector2(position_x, GROUND - lift).round(), fighter.face, slot, pose, pose_age)
		if fighter.down > 9:
			draw_stars(Vector2(roundf(position_x + fighter.face * 17), GROUND - 21 - roundf(lift)), fighter.down)
		if fighter.hit_frames > 0:
			var rise := (42 - int(fighter.hit_frames)) >> 1
			center_text(fighter.hit_label, roundf(position_x), GROUND - 63 - rise, 11, GOLD)
	var timer_panel := Rect2(308, 13, 160, 43) if count == 3 else Rect2(266, 13, 108, 43)
	panel(timer_panel)
	var timer_x := 388 if count == 3 else 320
	center_text("%02d" % int(ceil(match_state.frames_left / 60.0)), timer_x, 43, 30, GOLD, DISPLAY_FONT)
	var round_label := "RUNDE %02d" % match_state.round_number
	if game.campaign.active:
		round_label = "STECHEN" if game.campaign.deciding else "RUNDE %d/3" % match_state.round_number
	if count == 3:
		text(round_label, 318, 28, 8, MUTED)
	else:
		center_text(round_label, timer_x, 51, 7, MUTED)
	if game.banner > 0 and game.phase == "fight":
		var venue: String = game.campaign.LOCATIONS[game.campaign.location] if game.campaign.active else "Bereit machen"
		banner(round_label, venue if game.banner > 25 else "Kämpfen!")
	elif match_state.reset_left > 0 and game.phase == "fight":
		if count == 2:
			center_text("NEUER ANSATZ", 320, 73, 16, GOLD, DISPLAY_FONT)
		else:
			for slot in match_state.reset_slots:
				var participant = match_state.fighters[slot]
				draw_rect(Rect2(roundf(participant.x) - 5, GROUND + 8, 10, 2), ACCENTS[slot])
	footer("A/RB Schlag  ·  B/RT Tritt  ·  X/LT Sprung  ·  LB Drehen  ·  Start Pause")

func draw_training() -> void:
	var state = game.training
	var fighter = state.fighter
	var interpolation := Engine.get_physics_interpolation_fraction() if game.phase == "training" else 1.0
	var x := lerpf(fighter.previous_x, fighter.x, interpolation)
	var y := GROUND - lerpf(fighter.previous_lift, fighter.lift, interpolation)
	draw_training_bag(float(state.bag.x), state.swing_frames, state.swing_direction)
	art.draw_fighter(self, Vector2(x, y).round(), fighter.face, 0, fighter.action, fighter.age)

	panel(Rect2(19, 13, 602, 65))
	var title := "SANDSACK  /  FREIES TRAINING"
	if state.guided:
		title = "MANÖVER  %02d / %02d" % [mini(state.lesson_index + 1, state.LESSONS.size()), state.LESSONS.size()]
	text(title, 30, 33, 17, GOLD, DISPLAY_FONT)
	right_text("TREFFER  %d" % state.hits, 607, 32, 10, PAPER)
	if state.guided and not state.finished:
		var lesson: Array = state.LESSONS[state.lesson_index]
		var name: String = lesson[1]
		text(name, 30, 53, 13, PAPER)
		var keys: String = lesson[3] + (" + F" if lesson[4] else "")
		var pad: String = lesson[2]
		text("Tastatur  %s     Gamepad  %s" % [keys, pad], 30, 69, 9, MUTED)
		if state.next_wait > 0:
			right_text("GESCHAFFT", 607, 60, 12, GOLD)
		elif state.Fighter.ATTACKS.has(lesson[0]):
			right_text("Sandsack treffen", 607, 60, 9, MUTED)
	else:
		text("A/RB Schlag  ·  B/RT Tritt  ·  X/LT Sprung/Rolle  ·  LB Drehen", 30, 57, 9, MUTED)
	draw_gamepad_diagnostics()
	footer("LB / E Drehen  ·  View / R Ausgangsposition  ·  Y / H Steuerung  ·  Start Pause")

func draw_gamepad_diagnostics() -> void:
	var device: int = game.pads[0]
	panel(Rect2(19, 90, 270, 128))
	draw_rect(Rect2(19, 90, 2, 128), GOLD)
	text("GAMEPAD-TEST", 30, 107, 13, GOLD, DISPLAY_FONT)
	var name := Input.get_joy_name(device) if device >= 0 else ""
	if name.is_empty():
		name = "Gamepad %d" % (device + 1) if device >= 0 else "Kein Gamepad verbunden"
	text(name.left(39), 30, 123, 8, MUTED)
	var data: Dictionary = game.controls.pad_diagnostics(device)
	var stick: Vector2 = data.stick
	var stick_dir: Vector2i = data.stick_direction
	var direction: Vector3i = data.recognized
	text("Stick X %+.2f   Y %+.2f   %s" % [stick.x, stick.y, direction_label(stick_dir)], 30, 141, 9, PAPER)
	text("Steuerkreuz   %s" % (data.dpad if not data.dpad.is_empty() else "—"), 30, 156, 9, PAPER)
	text("LT %.2f  RT %.2f   Richtung %s" % [data.lt, data.rt, direction_label(Vector2i(direction.x, direction.y))], 30, 172, 9, GOLD)
	var held: Dictionary = data.held_actions
	var actions := ""
	for group in [Art.Fighter.PAD_PUNCH, Art.Fighter.PAD_KICK, Art.Fighter.PAD_JUMP, Art.Fighter.PAD_TURN]:
		if held.get(group, false):
			actions += ["Schlag ", "Tritt ", "Sprung ", "Drehen "][group - Art.Fighter.PAD_PUNCH]
	text("Tasten  %s" % (actions.strip_edges() if not actions.is_empty() else "—"), 30, 188, 9, MUTED)
	var action: String = game.training.fighter.action
	var applied: String = {"idle": "Bereit", "duck": "Ducken", "roll_forward": "Vorwärtsrolle", "roll_back": "Rückwärtsrolle",
		"turn_duck_punch": "Tiefer Fauststoß mit Drehung"}.get(action, action)
	for lesson in game.training.LESSONS:
		if lesson[0] == action:
			applied = lesson[1]
	text("Figur   %s" % applied, 30, 205, 9, PAPER)

func direction_label(direction: Vector2i) -> String:
	return ["↖", "↑", "↗", "←", "Neutral", "→", "↙", "↓", "↘"][(direction.y + 1) * 3 + direction.x + 1]

func draw_survival() -> void:
	var state = game.survival
	var fighter = state.fighter
	var blend := Engine.get_physics_interpolation_fraction() if game.phase == "survival" else 1.0
	var position := Vector2(lerpf(fighter.previous_x, fighter.x, blend),
		GROUND - lerpf(fighter.previous_lift, fighter.lift, blend))
	if state.mode in [1, 2]:
		draw_thrower(int(state.mode), state.spawn_wait < 14)
	for hazard in state.hazards:
		var x := roundf(float(hazard.x) - float(hazard.speed) * (1.0 - blend)) if hazard.age > 1 else roundf(float(hazard.x))
		var at := Vector2(x, hazard.y)
		match state.mode:
			0:
				draw_barrel(at, hazard.age)
			1:
				draw_arrow(at)
			2:
				draw_plate(at)
			3:
				draw_grenade(at, hazard.fuse, hazard.deflected)
	for effect in state.effects:
		draw_survival_effect(Vector2(effect.x, effect.y), effect.life, state.mode)
	art.draw_fighter(self, position.round(), fighter.face, 0, fighter.action, fighter.age)
	panel(Rect2(19, 13, 602, 65))
	text("%d  /  %s" % [state.mode + 1, String(state.TITLES[state.mode]).to_upper()], 30, 35, 20, GOLD, DISPLAY_FONT)
	text(state.HINTS[state.mode], 30, 59, 9, PAPER)
	right_text("ZEIT  %s" % state.time_text(state.ticks), 606, 34, 12, PAPER)
	right_text("BEST  %s" % state.time_text(state.best_time(state.mode)), 606, 54, 10, MUTED)
	var instruction: String = [
		"↑ + X/LT Sprung  ·  ↓ + B/RT Fußfeger  ·  Start Pause",
		"↓ Ducken  ·  ↑ + X/LT Sprung  ·  Start Pause",
		"Hoch: ↑ + A/RB  ·  Mitte: Vorne + B/RT  ·  Tief: ↓ + B/RT",
		"↓ + B/RT Fußfeger  ·  Vorne + B/RT Tritt  ·  Start Pause",
	][state.mode]
	footer(instruction)

func draw_barrel(at: Vector2, age: int) -> void:
	draw_circle(at, 12, INK)
	draw_circle(at, 10, Color("9b5835"))
	draw_circle(at - Vector2(2, 2), 7, Color("be7c49"))
	var axis := Vector2.from_angle(age * 0.19)
	draw_line((at - axis * 9).round(), (at + axis * 9).round(), Color("5e3d36"), 2)
	draw_circle(at, 4, Color("6d4939"), false, 1.0)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), GOLD)

func draw_arrow(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 15, at.y - 1, 29, 3), INK)
	draw_rect(Rect2(at.x - 13, at.y, 26, 1), GOLD)
	draw_rect(Rect2(at.x - 15, at.y - 3, 5, 6), Color("e07d66"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(15, 0), at + Vector2(9, -4), at + Vector2(9, 4)]), PAPER)

func draw_plate(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 9, at.y - 3, 18, 6), INK)
	draw_rect(Rect2(at.x - 7, at.y - 5, 14, 10), INK)
	draw_rect(Rect2(at.x - 7, at.y - 2, 14, 4), Color("94cbff"))
	draw_rect(Rect2(at.x - 5, at.y - 3, 10, 3), PAPER)

func draw_grenade(at: Vector2, fuse: int, deflected: bool) -> void:
	draw_rect(Rect2(at.x - 6, at.y - 4, 12, 10), INK)
	draw_rect(Rect2(at.x - 4, at.y - 6, 8, 14), INK)
	draw_rect(Rect2(at.x - 4, at.y - 3, 8, 8), Color("6b784c"))
	draw_rect(Rect2(at.x - 3, at.y, 6, 1), Color("ad9c63"))
	draw_rect(Rect2(at.x + 2, at.y - 8, 5, 2), PAPER)
	if not deflected and (fuse / 4) % 2 == 0:
		draw_rect(Rect2(at.x + 5, at.y - 11, 3, 3), GOLD)

func draw_survival_effect(at: Vector2, life: int, mode: int) -> void:
	var travel := 20 - life
	var tint := PAPER if mode == 2 else GOLD
	for i in 5:
		var direction := Vector2.from_angle(i * TAU / 5.0 + 0.6)
		var chip := (at + direction * travel).round()
		draw_rect(Rect2(chip, Vector2(3, 2)), tint)

func draw_thrower(mode: int, ready: bool) -> void:
	var chef := mode == 2
	var jacket := PAPER if chef else Color("728a64")
	var x := 48.0
	draw_rect(Rect2(x - 13, 304, 26, 5), INK)
	draw_rect(Rect2(x - 9, 284, 18, 22), INK)
	draw_rect(Rect2(x - 11, 264, 22, 23), INK)
	draw_rect(Rect2(x - 9, 266, 18, 19), jacket)
	draw_rect(Rect2(x - 7, 250, 15, 15), INK)
	draw_rect(Rect2(x - 5, 253, 11, 10), Color("e0a178"))
	draw_rect(Rect2(x + 3, 254, 3, 2), INK)
	if chef:
		draw_rect(Rect2(x - 10, 245, 19, 6), PAPER)
		draw_rect(Rect2(x - 8, 240, 15, 8), PAPER)
		draw_rect(Rect2(x + 9, 266 if ready else 274, 11, 5), jacket)
		if ready:
			draw_plate(Vector2(x + 21, 263))
	else:
		draw_rect(Rect2(x - 8, 247, 15, 5), jacket)
		draw_rect(Rect2(x + 7, 267, 11, 5), jacket)
		draw_polyline(PackedVector2Array([Vector2(x + 15, 251), Vector2(x + 23, 260),
			Vector2(x + 25, 270), Vector2(x + 22, 282), Vector2(x + 15, 290)]), GOLD, 2)
		draw_line(Vector2(x + 15, 251), Vector2(x + 15, 290), MUTED)

func draw_training_bag(x: float, swing_frames: int, direction: int) -> void:
	var swing := roundf(sin((32 - swing_frames) * 0.22) * swing_frames * 0.23 * direction)
	var center := roundf(x + swing)
	draw_rect(Rect2(x - 13, 310, 26, 4), Color(0.05, 0.07, 0.13, 0.55))
	draw_rect(Rect2(x + 32, 218, 5, 94), INK)
	draw_rect(Rect2(x + 33, 220, 2, 88), Color("666277"))
	draw_rect(Rect2(x - 2, 215, 39, 6), INK)
	draw_rect(Rect2(x + 17, 307, 30, 6), INK)
	draw_line(Vector2(x, 220), Vector2(center, 247), INK, 2.0)
	draw_rect(Rect2(center - 10, 249, 20, 50), INK)
	draw_rect(Rect2(center - 7, 246, 14, 56), INK)
	draw_rect(Rect2(center - 8, 251, 16, 46), Color("874c3d"))
	draw_rect(Rect2(center - 6, 249, 10, 50), Color("b66948"))
	draw_rect(Rect2(center - 5, 255, 3, 39), Color("d28b5c"))
	draw_rect(Rect2(center - 8, 256, 16, 2), Color("614050"))
	draw_rect(Rect2(center - 8, 292, 16, 2), Color("614050"))

func draw_bonus() -> void:
	var state = game.bonus
	panel(Rect2(19, 13, 212, 43))
	draw_rect(Rect2(19, 13, 2, 43), GOLD)
	text("BÄLLE ABWEHREN" if state.kind == "balls" else "BOMBEN TRETEN", 28, 32, 18, PAPER, DISPLAY_FONT)
	var subtitle := "TEST"
	if state.guided_balls:
		subtitle = "BALLTEST %s  ·  %d FPS" % [version, Engine.get_frames_per_second()]
		if game.practice_cpu:
			subtitle = "CPU  ·  %s  ·  %d FPS" % [version, Engine.get_frames_per_second()]
	text(subtitle, 29, 46, 8, GOLD)
	panel(Rect2(451, 13, 170, 43))
	text("PUNKTE", 462, 28, 9, MUTED)
	right_text("%05d" % state.score, 610, 28, 11, PAPER)
	text("VERSUCHE" if state.guided_balls else "GESCHAFFT", 462, 45, 9, MUTED)
	var total: int = state.ball_limit() if state.kind == "balls" else state.BOMB_LIMIT
	right_text("%02d / %02d" % [state.resolved, total], 610, 45, 10, GOLD)
	var palette := 0
	var pose := "down" if state.finished and not state.survived else "idle"
	var age: int = Art.Fighter.FALL_FRAMES if pose == "down" else state.clock
	if state.kind == "balls":
		if pose != "down":
			pose = ["shield_high", "shield_middle", "shield_low"][state.guard + 1]
		art.draw_fighter(self, Vector2(state.x, GROUND), state.face, palette, pose, age)
		if pose != "down" and pose != "shield_low":
			draw_shield(Vector2(state.x + 15 * state.face, state.shield_y()))
		for ball in state.outgoing:
			draw_ball(ball, state.guided_balls)
		if not state.ball.is_empty():
			draw_ball(state.ball, state.guided_balls)
		if state.guided_balls:
			draw_ball_practice_hint(state)
			if game.practice_cpu:
				footer("Computer spielt   ·   Esc / Start  Pause")
			else:
				footer("WASD / Pfeile / Gamepad  Schild ausrichten   ·   Esc / Start  Pause")
		else:
			footer("← / →  Seite   ·   ↑ / ↓  Schildhöhe   ·   ↓  Ducken   ·   Esc / Start  Pause")
	else:
		if state.kick > 0 and pose != "down":
			pose = "sweep" if state.kick_low else "shin"
			age = 4 + (22 - state.kick) * 5 / 4
		elif state.moving and pose != "down":
			pose = "walk"
		art.draw_fighter(self, Vector2(roundf(state.x), GROUND), state.face, palette, pose, age)
		for bomb in state.bombs:
			draw_bomb(bomb, state.clock)
		footer("← / → Laufen  ·  Richtung + B/RT Tritt  ·  Esc / Start Pause")
	if state.signal_time > 0 and not state.finished:
		center_text(state.signal_text, int(state.x), 225 - ((34 - state.signal_time) >> 1), 12, GOLD)
	if game.banner > 0 and game.phase == "bonus":
		banner("BÄLLE ABWEHREN" if state.kind == "balls" else "BOMBEN TRETEN", "Schild auf Anflugseite und Höhe ausrichten" if state.kind == "balls" else "Bomben wegtreten oder Abstand halten")

func draw_ball_practice_hint(state) -> void:
	if state.finished:
		return
	panel(Rect2(242, 13, 198, 43))
	if state.ball.is_empty():
		center_text("NÄCHSTER BALL", 341, 38, 10, MUTED)
		return
	var ball: Dictionary = state.ball
	var from_side := "LINKS" if ball.side == -1 else "RECHTS"
	var height_index := int(ball.color)
	var height: String = ["UNTEN", "MITTE", "OBEN"][height_index]
	var aligned: bool = state.face == ball.side and is_equal_approx(state.shield_y(), float(ball.target_y))
	center_text("%s  /  %s" % [from_side, height], 341, 29, 12, BALL_COLORS[height_index])
	var hint := "Schild auf Seite und Höhe bringen"
	if game.practice_cpu:
		hint = "CPU beobachtet den Ball"
	center_text("Schild ausgerichtet" if aligned else hint, 341, 45, 9, PAPER)

func draw_shield(at: Vector2) -> void:
	var x := roundf(at.x)
	var y := roundf(at.y)
	draw_rect(Rect2(x - 7, y - 10, 14, 20), INK)
	draw_rect(Rect2(x - 5, y - 12, 10, 24), INK)
	draw_rect(Rect2(x - 5, y - 9, 10, 18), Color("c68a55"))
	draw_rect(Rect2(x - 3, y - 10, 6, 20), Color("dea96c"))
	draw_rect(Rect2(x - 2, y - 3, 4, 6), Color("573947"))
	draw_rect(Rect2(x - 2, y - 7, 2, 2), PAPER)

func draw_ball(ball: Dictionary, practice_ball: bool = false) -> void:
	var x := roundf(ball.x)
	var y := roundf(ball.y)
	var color: Color = BALL_COLORS[int(ball.get("color", 1))]
	if practice_ball:
		draw_rect(Rect2(x - 8, y - 5, 17, 11), INK)
		draw_rect(Rect2(x - 5, y - 8, 11, 17), INK)
		draw_rect(Rect2(x - 6, y - 4, 13, 9), PAPER)
		draw_rect(Rect2(x - 4, y - 6, 9, 13), PAPER)
		draw_rect(Rect2(x - 4, y - 4, 9, 9), color)
		draw_rect(Rect2(x - 3, y - 3, 4, 3), Color.WHITE)
		return
	draw_rect(Rect2(x - 6, y - 4, 12, 8), INK)
	draw_rect(Rect2(x - 4, y - 6, 8, 12), INK)
	draw_rect(Rect2(x - 4, y - 4, 8, 8), color)
	draw_rect(Rect2(x - 3, y - 3, 3, 2), PAPER)

func draw_bomb(bomb: Dictionary, clock: int) -> void:
	var x := roundf(bomb.x)
	if bomb.blast > 0:
		var scale := 7 + int(15.0 * sin(float(bomb.blast) / 19.0 * PI))
		draw_rect(Rect2(x - scale, GROUND - scale, 2 * scale, scale), Color("e66549"))
		draw_rect(Rect2(x - scale / 2.0, GROUND - scale * 1.5, scale, scale * 1.5), GOLD)
		draw_rect(Rect2(x - 4, GROUND - 10, 8, 8), PAPER)
		return
	draw_rect(Rect2(x - 6, GROUND - 12, 12, 10), INK)
	draw_rect(Rect2(x - 4, GROUND - 14, 8, 14), INK)
	draw_rect(Rect2(x - 3, GROUND - 11, 3, 3), Color("677589"))
	draw_rect(Rect2(x, GROUND - 17, 5, 3), Color("ac784a"))
	if clock % (10 if bomb.fuse < 48 else 16) < 8:
		draw_rect(Rect2(x + 3, GROUND - 20, 4, 4), Color("ffb258"))

func draw_stars(at: Vector2, remaining: int) -> void:
	for i in 3:
		var offset := Vector2(roundf(cos(remaining * 0.17 + i * TAU / 3.0) * 12), roundf(sin(remaining * 0.17 + i * TAU / 3.0) * 3))
		var pos := at + offset
		draw_rect(Rect2(pos - Vector2(2, 0), Vector2(5, 1)), GOLD)
		draw_rect(Rect2(pos - Vector2(0, 2), Vector2(1, 5)), GOLD)

func draw_overlay() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.06, 0.12, 0.49))
	panel(Rect2(172, 119, 296, 134))
	draw_rect(Rect2(172, 119, 296, 2), GOLD)
	var title := "PAUSE"
	var detail: String = game.message
	var score_line := ""
	if game.phase == "round_end":
		var state = game.tournament
		if game.campaign.active and game.campaign.finished:
			title = "QUALIFIZIERT" if game.campaign.qualified else "TURNIER BEENDET"
			detail = "%s gewinnt in %s" % [fighter_name(game.campaign.winner), game.campaign.LOCATIONS[game.campaign.location].split(" · ")[0]]
			if game.campaign.location == 1 and game.tournament_seats[game.campaign.winner] != -2:
				title = "TURNIER GEWONNEN"
		elif state.winners.size() > 1:
			title = "UNENTSCHIEDEN"
		else:
			var slot: int = game.campaign.roster[state.winners[0]] if game.campaign.active else state.winners[0]
			title = fighter_name(slot) + " GEWINNT"
		if game.campaign.active:
			score_line = "%d  :  %d  :  %d Siege" % [game.campaign.wins[0], game.campaign.wins[1], game.campaign.wins[2]]
			if not game.campaign.finished and game.campaign.round >= game.campaign.ROUNDS_PER_LOCATION:
				detail = "Die Führenden kämpfen um den nächsten Treffer."
		elif state.match_over:
			detail = "Turnier beendet  ·  Spieler %d: %06d Punkte" % [state.eliminated + 1, state.fighters[state.eliminated].total]
		elif state.eliminated >= 0:
			detail = "Spieler %d ausgeschieden. Der Computer übernimmt." % (state.eliminated + 1)
		elif state.time_bonus > 0:
			detail = "+%d Zeitbonus" % state.time_bonus
		else:
			detail = "Runde %d beendet" % state.round_number
		if not game.campaign.active:
			var points := PackedStringArray()
			for fighter in state.fighters:
				points.append(str(fighter.points))
			score_line = "  :  ".join(points)
	elif game.phase == "bonus_end":
		if game.bonus.ball_practice:
			title = "CPU-RUNDE BEENDET" if game.practice_cpu else "ÜBUNG BEENDET"
			detail = "%d von %d Bällen abgewehrt" % [game.bonus.score / 100, game.bonus.ball_limit()]
		else:
			title = "GESCHAFFT" if game.bonus.survived else "BONUS BEENDET"
			detail = "%d Punkte" % game.bonus.score
	elif game.phase == "training_end":
		title = "TRAINING GESCHAFFT"
		detail = "Alle %d Manöver ausgeführt" % game.training.LESSONS.size()
	elif game.phase == "survival_end":
		var state = game.survival
		title = "NEUE BESTZEIT" if state.record else "TRAINING BEENDET"
		score_line = state.time_text(state.ticks)
		detail = "%s  ·  Bestzeit %s" % [state.TITLES[state.mode], state.time_text(state.best_time(state.mode))]
	center_text(title, 320, 158, 34, PAPER, DISPLAY_FONT)
	if not score_line.is_empty():
		center_text(score_line, 320, 177, 12, GOLD)
	center_text(detail, 320, 194, 9, MUTED)

func fighter_name(slot: int) -> String:
	return ["WEISS", "ROT", "BLAU"][slot]

func draw_help() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.06, 0.12, 0.74))
	panel(Rect2(12, 14, 616, 322))
	draw_rect(Rect2(12, 14, 616, 2), GOLD)
	text("STEUERUNG", 26, 46, 27, PAPER, DISPLAY_FONT)
	text("A/RB Schlag   B/RT Tritt   X/LT Sprung/Rolle   LB Umdrehen", 26, 65, 10, PAPER)
	text("Tastatur WASD + F, E drehen   ·   Y/H Hilfe   ·   Start/Esc Pause", 26, 83, 9, MUTED)
	text("STICK", 26, 105, 9, GOLD)
	text("A / RB", 185, 105, 9, GOLD)
	text("B / RT", 340, 105, 9, GOLD)
	text("X / LT", 478, 105, 9, GOLD)
	var rows := [
		["Neutral", "—", "—", "—"],
		["Oben", "Kopfstoß", "Hoher Tritt", "Sprung"],
		["Vorne oben", "Schlag zum Kopf", "Hoher Tritt", "Split / Doppelkick"],
		["Vorne", "Fauststoß", "Bauchtritt", "Sprungtritt"],
		["Vorne unten", "Geduckter Fauststoß", "Schienbeintritt", "Vorwärtsrolle"],
		["Unten", "Geduckter Fauststoß", "Fußfeger", "Sprung"],
		["Hinten unten", "Fauststoß tief + Dreh.", "Rückwärtsfeger", "Rückwärtsrolle"],
		["Hinten", "Fauststoß + Drehung", "Tritt + Drehung", "Rückwärtssalto"],
		["Hinten oben", "Fauststoß + Drehung", "Tritt + Drehung", "Split / Doppelkick"],
	]
	for i in rows.size():
		var y := 122 + 15 * i
		draw_rect(Rect2(25, y + 4, 589, 1), Color("333e54"))
		text(rows[i][0], 26, y, 9, MUTED)
		text(rows[i][1], 185, y, 8, PAPER)
		text(rows[i][2], 340, y, 8, PAPER)
		text(rows[i][3], 478, y, 8, PAPER)
	text("Vorne/hinten beziehen sich auf die Blickrichtung. Stick allein: Gehen/Ducken.", 26, 265, 9, MUTED)
	text("Richtung wählen, Taste antippen. Halten wiederholt keine Attacke.", 26, 281, 9, GOLD)
	text("Sandsack: View/R zurücksetzen   ·   F11 Vollbild", 26, 297, 9, MUTED)

func banner(title: String, detail: String) -> void:
	panel(Rect2(165, 123, 310, 61))
	center_text(title, 320, 151, 25, PAPER, DISPLAY_FONT)
	center_text(detail, 320, 170, 9, GOLD)

func footer(label: String) -> void:
	draw_rect(Rect2(0, 339, 640, 21), Color(0.06, 0.085, 0.15, 0.87))
	center_text(label, 320, 352, 9, MUTED)

func panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.06, 0.085, 0.15, 0.96))
	draw_rect(rect, Color("4e556c"), false)

func text(label: String, x: float, y: float, size: int, color: Color, font: Font = MONO_FONT) -> void:
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func center_text(label: String, x: float, y: float, size: int, color: Color, font: Font = MONO_FONT) -> void:
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(label, roundf(x - width / 2.0), y, size, color, font)

func right_text(label: String, x: float, y: float, size: int, color: Color) -> void:
	var width := MONO_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(label, x - width, y, size, color)
