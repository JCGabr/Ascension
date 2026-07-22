extends Node3D

## ============================================================
## Criatura marina animada (pez, calamar, etc.)
## Soporta dos modos de movimiento:
##  - DRIFT: se mueve suavemente alrededor de un punto fijo (cardumen)
##  - PATH:  viaja de un punto a otro (recorre una ruta)
## ============================================================

enum MovementMode { DRIFT, PATH, RANDOM }

@export var movement_mode: MovementMode = MovementMode.DRIFT

## Escena de la criatura (arrastra aquí el .glb)
@export var fish_scene: PackedScene

## Escala de la criatura
@export var fish_scale: float = 2.0

## Nombre de la animación a reproducir. Vacío = usa la primera que encuentre.
@export var swim_animation_name: String = ""

## --- Modo DRIFT ---
@export_group("Drift (movimiento alrededor de un punto)")
@export var drift_amount: float = 0.5
@export var drift_speed: float = 0.15

## --- Modo PATH ---
@export_group("Path (viaje de un punto a otro)")
## Arrastra aquí nodos Marker3D o Node3D que marquen el recorrido
## (colócalos como hijos de este nodo en la escena, con Add Child Node > Marker3D)
@export var path_points: Array[Node3D] = []
## Velocidad de desplazamiento (unidades por segundo)
@export var path_speed: float = 2.0
## Si está activo, al llegar al último punto vuelve a recorrer la ruta
## desde el principio. Si está desactivado, hace ida y vuelta (ping-pong).
@export var loop_from_start: bool = true

## --- Modo RANDOM ---
@export_group("Random (destinos aleatorios dentro de un área)")
## Tamaño de la caja invisible (centrada en la posición inicial del nodo)
## dentro de la cual se eligen destinos al azar
@export var random_area: Vector3 = Vector3(10.0, 3.0, 10.0)
## Velocidad de desplazamiento hacia cada destino aleatorio
@export var random_speed: float = 1.5
## Tiempo (segundos) que espera "quieto" antes de elegir el siguiente destino.
## Usa un rango (min, max) para que no todas las criaturas se muevan al mismo ritmo.
## Ponlos en 0 para que nunca se detenga (cambia de destino sin pausa).
@export var random_pause_min: float = 0.0
@export var random_pause_max: float = 0.0
## Qué tan rápido gira hacia la nueva dirección (más alto = giro más brusco,
## más bajo = giro más suave/curvo). Sirve para que no "frene" al girar.
@export var turn_smoothness: float = 3.0

var _fish: Node3D
var _base_position: Vector3
var _time: float = 0.0

# Para modo PATH
var _current_target_index: int = 0
var _direction: int = 1

# Para modo RANDOM
var _random_target: Vector3
var _random_pause_timer: float = 0.0
var _random_waiting: bool = false


func _ready() -> void:
	if fish_scene == null:
		push_warning("MarineCreature: asigna 'fish_scene' en el Inspector")
		return

	_fish = fish_scene.instantiate()
	add_child(_fish)
	_fish.scale = Vector3(fish_scale, fish_scale, fish_scale)
	# IMPORTANTE: usamos global_position (no position local) porque los modos
	# PATH y RANDOM mueven al pez con global_position. Si aquí usáramos la
	# posición local, el área quedaría centrada en el origen del mundo (0,0,0)
	# en vez de en el punto donde colocaste el nodo en la escena.
	_base_position = _fish.global_position

	if movement_mode == MovementMode.PATH and path_points.size() > 0:
		_fish.global_position = path_points[0].global_position

	if movement_mode == MovementMode.RANDOM:
		_random_target = _pick_random_point()

	var anim_player = _find_animation_player(_fish)
	if anim_player:
		var anim_name = swim_animation_name
		if anim_name == "":
			var list = anim_player.get_animation_list()
			if list.size() > 0:
				anim_name = list[0]

		if anim_name != "" and anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
		else:
			push_warning("MarineCreature: no se encontró la animación '%s'" % anim_name)
	else:
		push_warning("MarineCreature: no se encontró AnimationPlayer dentro del modelo")


func _process(delta: float) -> void:
	if _fish == null:
		return

	match movement_mode:
		MovementMode.DRIFT:
			_process_drift(delta)
		MovementMode.PATH:
			_process_path(delta)
		MovementMode.RANDOM:
			_process_random(delta)


func _process_drift(delta: float) -> void:
	if drift_amount <= 0.0:
		return
	_time += delta * drift_speed
	_fish.global_position = _base_position + Vector3(
		sin(_time) * drift_amount,
		sin(_time * 0.7) * drift_amount * 0.3,
		cos(_time) * drift_amount
	)


func _process_path(delta: float) -> void:
	if path_points.size() < 2:
		return

	var target = path_points[_current_target_index]
	var target_pos = target.global_position
	var current_pos = _fish.global_position

	var to_target = target_pos - current_pos
	var distance = to_target.length()

	if distance < 0.2:
		# Llegó al punto, avanza al siguiente
		if loop_from_start:
			_current_target_index = (_current_target_index + 1) % path_points.size()
		else:
			# ping-pong: rebota entre el primero y el último punto
			if _current_target_index + _direction >= path_points.size() or _current_target_index + _direction < 0:
				_direction *= -1
			_current_target_index += _direction
	else:
		var move_dir = to_target.normalized()
		_fish.global_position += move_dir * path_speed * delta
		# Orienta la criatura hacia donde se mueve, con giro suave
		var target_transform = _fish.global_transform.looking_at(_fish.global_position + move_dir, Vector3.UP)
		_fish.global_transform.basis = _fish.global_transform.basis.slerp(target_transform.basis, delta * turn_smoothness)


func _process_random(delta: float) -> void:
	if _random_waiting:
		_random_pause_timer -= delta
		if _random_pause_timer <= 0.0:
			_random_waiting = false
			_random_target = _pick_random_point()
		return

	var current_pos = _fish.global_position
	var to_target = _random_target - current_pos
	var distance = to_target.length()

	if distance < 0.3:
		# Llegó al destino: elige el siguiente de inmediato (o hace una
		# pausa breve si random_pause_max > 0)
		_random_target = _pick_random_point()
		if random_pause_max > 0.0:
			_random_waiting = true
			_random_pause_timer = randf_range(random_pause_min, random_pause_max)
	else:
		var move_dir = to_target.normalized()
		_fish.global_position += move_dir * random_speed * delta
		# Giro suave: interpola la rotación en vez de "saltar" a la nueva
		# dirección, así no se ve como que frena de golpe al cambiar de rumbo
		var target_transform = _fish.global_transform.looking_at(_fish.global_position + move_dir, Vector3.UP)
		_fish.global_transform.basis = _fish.global_transform.basis.slerp(target_transform.basis, delta * turn_smoothness)


func _pick_random_point() -> Vector3:
	return _base_position + Vector3(
		randf_range(-random_area.x, random_area.x),
		randf_range(-random_area.y, random_area.y),
		randf_range(-random_area.z, random_area.z)
	)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null
