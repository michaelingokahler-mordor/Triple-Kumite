extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const KEYBOARD := -1
const CPU := -2
const STICK_ENTER := 0.28
const STICK_RELEASE := 0.21
const DIAGONAL_ENTER := 0.38
const DIAGONAL_RELEASE := 0.28
const TRIGGER_ENTER := 0.55
const TRIGGER_RELEASE := 0.35

var pads: Dictionary = {}

func receive(event: InputEvent) -> void:
	if event is not InputEventJoypadButton and event is not InputEventJoypadMotion:
		return
	var pad: Dictionary = pads.get_or_add(event.device, {"buttons": {}, "axes": {}})
	if event is InputEventJoypadButton:
		pad.buttons[event.button_index] = event.pressed
	else:
		pad.axes[event.axis] = event.axis_value
	update_actions(event.device, pad)

func forget(device: int) -> void:
	pads.erase(device)

func clear_actions(device: int = CPU) -> void:
	if device != CPU:
		if pads.has(device):
			pads[device].erase("pending")
		return
	for pad in pads.values():
		pad.erase("pending")

func update_actions(device: int, pad: Dictionary) -> void:
	var buttons: Dictionary = pad.buttons
	var axes: Dictionary = pad.axes
	var triggers: Dictionary = pad.get_or_add("triggers", {})
	for which in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var value: float = axes.get(which, 0.0)
		triggers[which] = value >= TRIGGER_ENTER if not triggers.get(which, false) else value > TRIGGER_RELEASE
	var held := {
		Fighter.PAD_PUNCH: buttons.get(JOY_BUTTON_A, false) or buttons.get(JOY_BUTTON_RIGHT_SHOULDER, false),
		Fighter.PAD_KICK: buttons.get(JOY_BUTTON_B, false) or triggers[JOY_AXIS_TRIGGER_RIGHT],
		Fighter.PAD_JUMP: buttons.get(JOY_BUTTON_X, false) or triggers[JOY_AXIS_TRIGGER_LEFT],
		Fighter.PAD_TURN: buttons.get(JOY_BUTTON_LEFT_SHOULDER, false),
	}
	var previous: Dictionary = pad.get_or_add("held_actions", {})
	for group in held:
		if held[group] and not previous.get(group, false):
			var direction := pad_command(device)
			if group == Fighter.PAD_TURN or direction.x != 0 or direction.y != 0:
				pad.pending = Vector3i(direction.x, direction.y, group)
		previous[group] = held[group]

func pad_command(device: int) -> Vector3i:
	if not pads.has(device):
		return Vector3i.ZERO
	var pad: Dictionary = pads[device]
	var buttons: Dictionary = pad.buttons
	var axes: Dictionary = pad.axes
	var horizontal := int(buttons.get(JOY_BUTTON_DPAD_RIGHT, false)) - int(buttons.get(JOY_BUTTON_DPAD_LEFT, false))
	var vertical := int(buttons.get(JOY_BUTTON_DPAD_DOWN, false)) - int(buttons.get(JOY_BUTTON_DPAD_UP, false))
	var stick := Vector2(axes.get(JOY_AXIS_LEFT_X, 0.0), axes.get(JOY_AXIS_LEFT_Y, 0.0))
	var recognized_stick := stick_direction(stick, pad.get("stick_direction", Vector2i.ZERO))
	pad.stick_direction = recognized_stick
	var dpad := Vector2i(horizontal, vertical)
	var direction := recognized_stick if dpad == Vector2i.ZERO else dpad
	var command := Vector3i(direction.x, direction.y, int(buttons.get(JOY_BUTTON_A, false)))
	pad.recognized = command
	return command

func pad_diagnostics(device: int) -> Dictionary:
	var pad: Dictionary = pads.get(device, {})
	var buttons: Dictionary = pad.get("buttons", {})
	var axes: Dictionary = pad.get("axes", {})
	var held := ""
	for index in 4:
		var button: int = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT][index]
		if buttons.get(button, false):
			held += ["↑", "←", "↓", "→"][index] + " "
	return {
		"stick": Vector2(axes.get(JOY_AXIS_LEFT_X, 0.0), axes.get(JOY_AXIS_LEFT_Y, 0.0)),
		"dpad": held.strip_edges(),
		"stick_direction": pad.get("stick_direction", Vector2i.ZERO),
		"recognized": pad.get("recognized", Vector3i.ZERO),
		"lt": axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0),
		"rt": axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0),
		"held_actions": pad.get("held_actions", {}),
	}

func combat_command(device: int, allow_keyboard: bool = false) -> Vector3i:
	if device == KEYBOARD or allow_keyboard:
		var keyboard := keyboard_command()
		if keyboard != Vector3i.ZERO or device == KEYBOARD:
			clear_actions(device)
			return keyboard
	if device < 0:
		return Vector3i(0, 0, Fighter.PAD_MOVE)
	if pads.has(device) and pads[device].has("pending"):
		var pending: Vector3i = pads[device].pending
		pads[device].erase("pending")
		return pending
	var command := pad_command(device)
	return Vector3i(command.x, command.y, Fighter.PAD_MOVE)

func keyboard_command() -> Vector3i:
	var x := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var y := int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	var action := Input.is_physical_key_pressed(KEY_F)
	return Vector3i(x, y, int(action))

func ball_practice_command(device: int) -> Vector3i:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	if left or right or up or down:
		return Vector3i(int(right) - int(left), int(down) - int(up), 0)
	return pad_command(device)

static func stick_direction(stick: Vector2, previous: Vector2i) -> Vector2i:
	var threshold := STICK_ENTER if previous == Vector2i.ZERO else STICK_RELEASE
	if stick.length_squared() < threshold * threshold:
		return Vector2i.ZERO
	var horizontal := absf(stick.x)
	var vertical := absf(stick.y)
	var direction := Vector2i(int(signf(stick.x)), int(signf(stick.y)))
	var diagonal_threshold := DIAGONAL_RELEASE if previous == direction else DIAGONAL_ENTER
	if minf(horizontal, vertical) >= maxf(horizontal, vertical) * diagonal_threshold:
		return direction
	return Vector2i(direction.x, 0) if horizontal > vertical else Vector2i(0, direction.y)
