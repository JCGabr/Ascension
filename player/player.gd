extends CharacterBody3D
@export var animation_player: AnimationPlayer
@export var head: Node3D
@export var camera: Camera3D
@export var ray_cast_3d: RayCast3D
@export var interact_action: String = "right_click"
const SPEED = 5.0
const TRANSITION_TIME = 0.6
var is_interacting := false
var current_pivot: Node3D = null
var current_relay: ScreenInputRelay = null
var current_box: Node = null
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
	if Input.is_action_just_pressed(interact_action):
		print("Input detectado") # ¿aparece?
		if ray_cast_3d.is_colliding():
			print("Raycast colisiona con: ", ray_cast_3d.get_collider().name)
			var hit = ray_cast_3d.get_collider()
			var parent = hit.get_parent()
			var box_ref: Node = null
			if parent.name == "box" and parent.has_method("open"):
				parent.open()
				box_ref = parent
			var pivot = hit.get_node_or_null("Pivot")
			if pivot:
				print("Pivot encontrado, entrando...")
				var relay = hit.get_node_or_null("Relay") as ScreenInputRelay
				print(relay)
				enter_pivot_view(pivot, relay, box_ref)
			else:
				print("No se encontró nodo 'Pivot' como hijo del collider")
		else:
			print("Raycast no colisiona con nada")

func enter_pivot_view(pivot: Node3D, relay: ScreenInputRelay = null, box: Node = null) -> void:
	is_interacting = true
	current_pivot = pivot
	current_box = box
	camera.reparent(pivot) # keep_global_transform = true por defecto
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_relay = relay
	if current_relay:
		current_relay.camera = camera
		current_relay.activo = true
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", Vector3.ZERO, TRANSITION_TIME)
	tween.parallel().tween_property(camera, "rotation", Vector3.ZERO, TRANSITION_TIME)

func exit_pivot_view() -> void:
	if not is_interacting:
		return
	if current_relay:
		current_relay.activo = false
		current_relay = null
	if current_box and current_box.has_method("close"):
		current_box.close()
	camera.reparent(head)
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", camera_home_position, TRANSITION_TIME)
	tween.parallel().tween_property(camera, "rotation", camera_home_rotation, TRANSITION_TIME)
	tween.finished.connect(func():
		is_interacting = false
		current_pivot = null
		current_box = null
	)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func basic_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
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
		visible = false
		interaction_input_while_pivoted()
		return
	basic_movement(delta)
	interaction()

func interaction_input_while_pivoted() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		visible = true
		exit_pivot_view()
