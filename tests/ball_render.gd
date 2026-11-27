extends SceneTree

# Graphical acceptance check on the target PC. Run without --headless.
# Counts completed draws and reads the actual ball pixel on every flight frame.
var game
var intervals: Array[float] = []
var last_draw := 0
var flight_frames := [0, 0, 0, 0, 0, 0]
var missing_balls := 0
var drawing_started := 0
var failures: Array[String] = []
var controller_latencies: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ball_render requires a graphical window")
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	var computer := "--computer" in OS.get_cmdline_user_args()
	game.menu_buttons[game.MenuItem.TESTS].pressed.emit()
	game.overlay_buttons[3 if computer else 2].pressed.emit()
	drawing_started = Time.get_ticks_usec()
	last_draw = drawing_started
	RenderingServer.frame_post_draw.connect(inspect_frame)
	while not game.bonus.finished and Time.get_ticks_usec() - drawing_started < 30000000:
		await process_frame
	RenderingServer.frame_post_draw.disconnect(inspect_frame)
	intervals.sort()
	var p95: float = intervals[mini(intervals.size() - 1, int(intervals.size() * 0.95))]
	var median: float = intervals[intervals.size() / 2]
	if not game.bonus.finished or flight_frames[0] < 140 or flight_frames[-1] < 75:
		failures.append("Incomplete ball round or too few visible flight frames: %s" % str(flight_frames))
	if missing_balls > 0:
		failures.append("Ball missing from %d rendered frames" % missing_balls)
	if p95 > 35.0:
		failures.append("Frame pacing exceeds 35 ms at p95: %.2f ms" % p95)
	if computer and game.bonus.score != 600:
		failures.append("Computer did not deflect all six balls")
	print("BALL_RENDER version=%s frames=%d flight_frames=%s missing=%d median=%.2fms p95=%.2fms" % [ProjectSettings.get_setting("application/config/version"), intervals.size(), str(flight_frames), missing_balls, median, p95])
	print("BALL_RESULT computer=%s score=%d" % [computer, game.bonus.score])
	await inspect_controller()
	print("SHIELD_RENDER event_to_draw_ms=", controller_latencies)
	for failure in failures:
		printerr(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func inspect_frame() -> void:
	var now := Time.get_ticks_usec()
	intervals.append((now - last_draw) / 1000.0)
	last_draw = now
	var ball: Dictionary = game.bonus.ball
	if ball.is_empty() or game.bonus.launch_wait > 0:
		return
	var frame := root.get_texture().get_image()
	var scale := Vector2(frame.get_size()) / Vector2(640, 360)
	var pixel := Vector2i(Vector2(roundf(ball.x), roundf(ball.y)) * scale)
	var color := frame.get_pixelv(pixel)
	var expected := [Color("8ce0ab"), Color("fbd079"), Color("94cbff")]
	if color.is_equal_approx(expected[int(ball.color)]):
		flight_frames[game.bonus.count - 1] += 1
	else:
		missing_balls += 1

func inspect_controller() -> void:
	# Isolate shield response from ball movement and the fixed physics tick.
	game.set_physics_process(false)
	game.show_menu()
	game.menu_buttons[game.MenuItem.TESTS].pressed.emit()
	game.overlay_buttons[2].pressed.emit()
	game.pads[0] = 7
	for target in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
		await RenderingServer.frame_post_draw
		var sent := Time.get_ticks_usec()
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var event := InputEventJoypadMotion.new()
			event.device = 7
			event.axis = axis
			event.axis_value = 0.9 * (target.x if axis == JOY_AXIS_LEFT_X else target.y)
			Input.parse_input_event(event)
		if game.bonus.face != target.x or game.bonus.guard != target.y:
			failures.append("Shield does not immediately follow delivered controller direction %s" % target)
		await RenderingServer.frame_post_draw
		controller_latencies.append((Time.get_ticks_usec() - sent) / 1000.0)
		var frame := root.get_texture().get_image()
		var scale := Vector2(frame.get_size()) / Vector2(640, 360)
		var pixel := Vector2i(Vector2(320 + target.x * 15, 273 + target.y * 16) * scale)
		var color := frame.get_pixelv(pixel)
		# The low stance has its shield grip built into the mirrored sprite.
		var grip_is_visible := color.r8 in range(85, 100) and color.g8 in range(88, 104) and color.b8 in range(96, 108)
		if not (grip_is_visible if target.y == 1 else color.is_equal_approx(Color("573947"))):
			failures.append("Rendered shield is not at requested side and height %s" % target)
	for latency in controller_latencies:
		if latency > 35.0:
			failures.append("Controller event takes more than 35 ms to render: %.2f" % latency)
