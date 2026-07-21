extends Node3D

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -80.0  # grados
@export var max_pitch: float = 80.0   # grados
@export var invert_y: bool = false

@export var only_pitch_here: bool = true

var rot_x: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: Vector2 = event.relative
		var yaw_delta: float = -motion.x * mouse_sensitivity
		var pitch_delta: float = motion.y * mouse_sensitivity
		if invert_y:
			pitch_delta = -pitch_delta
		if only_pitch_here:
			rot_x -= pitch_delta
			rot_x = clamp(rot_x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			rotation.x = rot_x
			var body := get_parent()
			if body and body is Node3D:
				body.rotate_y(yaw_delta)
		else:
			rotate_y(yaw_delta)
			rot_x -= pitch_delta
			rot_x = clamp(rot_x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			rotation.x = rot_x
