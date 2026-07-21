extends CharacterBody3D

@export var animation_player: AnimationPlayer
@export var head: Node3D
@export var camera: Camera3D
@export var ray_cast_3d: RayCast3D
@export var interact_action: String = "right_click"

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const TRANSITION_TIME = 0.6

var is_interacting := false
var current_pivot: Node3D = null
var tween: Tween

# Guardamos la pose original de la cámara dentro de head
var camera_home_position: Vector3
var camera_home_rotation: Vector3

func _ready() -> void:
	# Aseguramos que la cámara empiece dentro de head
	camera_home_position = camera.position
	camera_home_rotation = camera.rotation

func interaction() -> void:
	if is_interacting:
		return
	if Input.is_action_just_pressed(interact_action) and ray_cast_3d.is_colliding():
		var hit = ray_cast_3d.get_collider()
		var pivot = hit.get_node_or_null("Pivot")
		if pivot:
			enter_pivot_view(pivot)

func enter_pivot_view(pivot: Node3D) -> void:
	is_interacting = true
	current_pivot = pivot

	camera.reparent(pivot) # keep_global_transform = true por defecto

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", Vector3.ZERO, TRANSITION_TIME)
	tween.parallel().tween_property(camera, "rotation", Vector3.ZERO, TRANSITION_TIME)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_pivot_view() -> void:
	if not is_interacting:
		return

	camera.reparent(head) # mantiene transform global -> no hay salto visual

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", camera_home_position, TRANSITION_TIME)
	tween.parallel().tween_property(camera, "rotation", camera_home_rotation, TRANSITION_TIME)
	tween.finished.connect(func():
		is_interacting = false
		current_pivot = null
	)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func basic_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()

func _physics_process(delta: float) -> void:
	if is_interacting:
		interaction_input_while_pivoted()
		return
	basic_movement(delta)
	interaction()

func interaction_input_while_pivoted() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		exit_pivot_view()
