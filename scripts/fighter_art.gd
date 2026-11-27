extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const SPRITES = preload("res://assets/karateka.png")
const FRAME_SIZE := Vector2(108, 80)
const ORIGIN := Vector2(54, 74)
const FRAMES := {
	"idle": 0, "guard_alt": 1, "walk_contact": 2, "walk_pass": 3,
	"block": 4, "punch": 5, "duck_punch": 6, "headbutt": 7,
	"shin": 8, "body": 9, "high": 10, "sweep": 11,
	"jump": 12, "flying": 13, "double": 14, "prone": 15,
	"flip": 16, "hit": 17, "fall": 18, "rise": 19,
	"walk_other_contact": 20, "walk_other_pass": 21,
	"shield_low": 22,
}
const ATTACK_POSES := {"turn_punch": "punch", "turn_kick": "high", "turn_sweep": "sweep", "turn_duck_punch": "duck_punch"}
const SHIELD_POSES := {"shield_high": "block", "shield_middle": "guard_alt", "shield_low": "shield_low"}
const WALK_CYCLE := ["walk_contact", "walk_pass", "walk_other_contact", "walk_other_pass"]

func draw_fighter(canvas: Node2D, at: Vector2, facing: int, palette: int, action: String, age: int, shadow_y: float = 310.0) -> void:
	var frame: int = FRAMES[pose_for(action, age)]
	var shadow_width := 51 if frame == FRAMES.prone else 37
	var shadow_opacity := lerpf(0.48, 0.22, clampf((shadow_y - at.y) / 34.0, 0.0, 1.0))
	var shadow := Color(0.05, 0.07, 0.13, shadow_opacity)
	canvas.draw_rect(Rect2(roundf(at.x - shadow_width * 0.5), shadow_y + 1, shadow_width, 3), shadow)
	canvas.draw_rect(Rect2(roundf(at.x - shadow_width * 0.5) + 4, shadow_y - 1, shadow_width - 8, 7), shadow)
	var region := Rect2((frame % 6) * FRAME_SIZE.x, (palette * 4 + frame / 6) * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	var sprite_rect := Rect2(-ORIGIN, FRAME_SIZE)
	if action in ["roll_forward", "roll_back"] and age >= 4 and age < Fighter.ROLL_FRAMES - 4:
		var progress := float(age - 4) / (Fighter.ROLL_FRAMES - 8)
		var direction := facing if action == "roll_forward" else -facing
		canvas.draw_set_transform(at + Vector2(0, -20), direction * TAU * progress, Vector2(facing * 0.72, 0.72))
		sprite_rect.position.y += 38
	else:
		canvas.draw_set_transform(at, 0.0, Vector2(facing, 1))
	canvas.draw_texture_rect_region(SPRITES, sprite_rect, region)
	canvas.draw_set_transform(Vector2.ZERO)

func pose_for(action: String, age: int) -> String:
	if SHIELD_POSES.has(action):
		return SHIELD_POSES[action]
	if Fighter.ATTACKS.has(action):
		var attack: Array = Fighter.ATTACKS[action]
		var impact: int = attack[3]
		var end: int = attack[4]
		if age >= impact - 2 and age < end - 5:
			return ATTACK_POSES.get(action, action)
		if action in ["flying", "double"]:
			return "jump"
		if action in ["sweep", "turn_sweep", "duck_punch", "turn_duck_punch"]:
			return "rise"
		return "block" if age < impact else "guard_alt"
	match action:
		"roll_forward", "roll_back":
			return "jump" if age >= 4 and age < Fighter.ROLL_FRAMES - 4 else "rise"
		"duck":
			return "rise"
		"walk", "back":
			var stride := (age / 7) % WALK_CYCLE.size()
			return WALK_CYCLE[stride if action == "walk" else WALK_CYCLE.size() - 1 - stride]
		"jump", "landing":
			return "jump"
		"flip":
			return "flip" if age >= 8 and age < 25 else "jump"
		"down":
			if age < 4:
				return "hit"
			if age < Fighter.FALL_FRAMES:
				return "fall"
			return "rise" if age >= Fighter.DOWN_FRAMES - Fighter.RISE_FRAMES else "prone"
		"idle":
			return "idle" if age % 44 < 25 else "guard_alt"
		_:
			return "block"
