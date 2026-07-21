extends Control
class_name PuzzleGrid

## Puzzle simple de "conectar tubos": rotá las piezas para llevar
## energía desde la fuente (el ojo) hasta la meta (la herida).
## Estética tétrica: fondo oscuro, tubos oxidados, glow verde tóxico.

signal puzzle_solved

@export var grid_width: int = 5
@export var grid_height: int = 4
@export var cell_size: float = 96.0

## true cuando el circuito está completo. Leela desde tu juego real,
## o conectate a la señal puzzle_solved para reaccionar al momento exacto.
var solved: bool = false

var cells: Array = [] # cells[y][x] = PipeCell
var source_pos: Vector2i
var target_pos: Vector2i

@onready var grid_container: GridContainer = $GridContainer

const PipeCellScene = preload("res://interactuable_objects/pipe_puzzle_godot/PipeCell.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_level()
	_check_connection()

func _draw() -> void:
	# Fondo negro detrás de todo el grid para que la estética no dependa
	# del fondo del juego host.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.018, 0.02), true)

## Genera un nivel resoluble: crea un camino garantizado de fuente a meta
## y luego "revuelve" las rotaciones para que el jugador tenga que resolverlo.
func _build_level() -> void:
	grid_container.columns = grid_width
	grid_container.add_theme_constant_override("h_separation", 4)
	grid_container.add_theme_constant_override("v_separation", 4)

	cells.clear()
	for y in grid_height:
		var row: Array = []
		for x in grid_width:
			row.append(null)
		cells.append(row)

	source_pos = Vector2i(0, randi() % grid_height)
	target_pos = Vector2i(grid_width - 1, randi() % grid_height)

	# 1) Genera un camino aleatorio válido entre source y target (random walk con sesgo)
	var path := _generate_path(source_pos, target_pos)

	# 2) Determina el tipo de pieza necesario en cada celda del camino según sus vecinos
	var path_types := {} # Vector2i -> {type, connections: [sides]}
	for i in path.size():
		var p: Vector2i = path[i]
		var sides: Array = []
		if i > 0:
			sides.append(_dir_to_side(path[i] - path[i - 1]))
		if i < path.size() - 1:
			sides.append(_dir_to_side(path[i + 1] - path[i]))
		path_types[p] = sides

	# 3) Instancia todas las celdas
	for y in grid_height:
		for x in grid_width:
			var pos := Vector2i(x, y)
			var cell := PipeCell.new()
			cell.cell_size = cell_size

			if pos == source_pos:
				cell.piece_type = PipeCell.PieceType.SOURCE
				cell.locked = false
				# Rotación inicial random: el jugador tiene que girarla para
				# que apunte hacia el camino en vez de "hacia afuera".
				cell.rotation_steps = randi() % 4
			elif pos == target_pos:
				cell.piece_type = PipeCell.PieceType.TARGET
				cell.locked = false
				cell.rotation_steps = randi() % 4
			elif path_types.has(pos):
				var sides: Array = path_types[pos]
				if sides.size() == 2:
					if _is_straight_pair(sides):
						cell.piece_type = PipeCell.PieceType.STRAIGHT
					else:
						cell.piece_type = PipeCell.PieceType.ELBOW
					cell.rotation_steps = _rotation_for(cell.piece_type, sides)
				else:
					cell.piece_type = PipeCell.PieceType.STRAIGHT
					cell.rotation_steps = 0
				# Revuelve: rotación random distinta a la solución
				cell.rotation_steps = randi() % 4
			else:
				# Pieza decorativa/no funcional: elige una pieza random como relleno
				var fill_types = [PipeCell.PieceType.STRAIGHT, PipeCell.PieceType.ELBOW, PipeCell.PieceType.T_JUNCTION]
				cell.piece_type = fill_types[randi() % fill_types.size()]
				cell.rotation_steps = randi() % 4

			cell.rotated.connect(_on_cell_rotated)
			grid_container.add_child(cell)
			cells[y][x] = cell

	custom_minimum_size = Vector2(grid_width * (cell_size + 4), grid_height * (cell_size + 4))

func _is_straight_pair(sides: Array) -> bool:
	return (sides[0] + 2) % 4 == sides[1]

## Encuentra qué rotación (0-3) hace que la pieza base tenga exactamente estos lados abiertos
func _rotation_for(type: PipeCell.PieceType, target_sides: Array) -> int:
	var base: Array = PipeCell.BASE_SIDES[type]
	var target_sorted: Array = target_sides.duplicate()
	target_sorted.sort()
	for r in range(4):
		var rotated_sides: Array = []
		for s in base:
			rotated_sides.append((s + r) % 4)
		rotated_sides.sort()
		if rotated_sides == target_sorted:
			return r
	return 0

func _dir_to_side(dir: Vector2i) -> int:
	if dir == Vector2i(0, -1): return 0
	if dir == Vector2i(1, 0): return 1
	if dir == Vector2i(0, 1): return 2
	if dir == Vector2i(-1, 0): return 3
	return 0

## Random walk simple que conecta source y target sin cruzarse a sí mismo
func _generate_path(start: Vector2i, goal: Vector2i) -> Array:
	var path: Array = [start]
	var current := start
	var visited := {start: true}
	var max_steps := grid_width * grid_height * 2
	var steps := 0

	while current != goal and steps < max_steps:
		steps += 1
		var options: Array = []
		var diff := goal - current
		# Prioriza moverse hacia la meta, con algo de variación
		var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dirs.shuffle()
		# Sesga: mete direcciones hacia la meta más veces al frente
		if diff.x > 0: dirs.push_front(Vector2i(1, 0))
		if diff.y > 0: dirs.push_front(Vector2i(0, 1))
		if diff.y < 0: dirs.push_front(Vector2i(0, -1))

		for d in dirs:
			var np : Vector2i = current + d
			if np.x >= 0 and np.x < grid_width and np.y >= 0 and np.y < grid_height and not visited.has(np):
				options.append(np)

		if options.is_empty():
			# Sin salida: retrocede
			if path.size() > 1:
				path.pop_back()
				current = path[path.size() - 1]
				continue
			else:
				break

		var next: Vector2i = options[0]
		path.append(next)
		visited[next] = true
		current = next

	return path

func _on_cell_rotated(_cell: PipeCell) -> void:
	_check_connection()

## BFS desde la fuente siguiendo únicamente conexiones abiertas y recíprocas
func _check_connection() -> void:
	for row in cells:
		for c in row:
			c.set_energized(false)

	var start := source_pos
	var visited := {start: true}
	var queue: Array = [start]
	var reached_target := false

	var dir_vec := {0: Vector2i(0, -1), 1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0)}
	var opposite := {0: 2, 1: 3, 2: 0, 3: 1}

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var cell: PipeCell = cells[pos.y][pos.x]
		cell.set_energized(true)
		if pos == target_pos:
			reached_target = true

		for side in cell.get_open_sides():
			var npos: Vector2i = pos + dir_vec[side]
			if npos.x < 0 or npos.x >= grid_width or npos.y < 0 or npos.y >= grid_height:
				continue
			if visited.has(npos):
				continue
			var ncell: PipeCell = cells[npos.y][npos.x]
			var needed_side: int = opposite[side]
			if needed_side in ncell.get_open_sides():
				visited[npos] = true
				queue.append(npos)

	if reached_target and not solved:
		solved = true
		puzzle_solved.emit()
	elif not reached_target and solved:
		solved = false

func reset_puzzle() -> void:
	solved = false
	for child in grid_container.get_children():
		child.queue_free()
	_build_level()
	_check_connection()
