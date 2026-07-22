extends Control

## Minijuego de interruptores estilo "Lights Out".
## Al pulsar un interruptor, se alterna su estado y el de sus vecinos
## (arriba, abajo, izquierda, derecha). El juego se completa cuando
## todos los interruptores quedan encendidos.

@export var grid_size: int = 3          # Tamaño de la grilla (grid_size x grid_size)
@export var button_size: Vector2 = Vector2(80, 80)
@export var spacing: float = 10.0

## Se pone en true una única vez cuando se completa el puzzle.
var completed: bool = false

var _buttons: Array = []      # Array 2D de Button
var _state: Array = []        # Array 2D de bool (true = encendido)

func _ready() -> void:
	_generate_solvable_state()
	_build_grid()
	_update_visuals()


func _generate_solvable_state() -> void:
	# Empieza todo encendido (estado resuelto) y aplica pulsaciones
	# aleatorias para garantizar que el puzzle tiene solución.
	_state.clear()
	for x in grid_size:
		var col: Array = []
		for y in grid_size:
			col.append(true)
		_state.append(col)

	var shuffle_moves: int = grid_size * grid_size
	for i in shuffle_moves:
		var rx: int = randi() % grid_size
		var ry: int = randi() % grid_size
		_toggle_state(rx, ry)

	# Evita el caso trivial de que ya quede resuelto tras el mezclado.
	if _is_complete():
		_generate_solvable_state()


func _build_grid() -> void:
	for child in get_children():
		child.queue_free()

	_buttons.clear()

	var container := GridContainer.new()
	container.columns = grid_size
	container.add_theme_constant_override("h_separation", int(spacing))
	container.add_theme_constant_override("v_separation", int(spacing))
	add_child(container)

	for y in grid_size:
		var row: Array = []
		for x in grid_size:
			var btn := Button.new()
			btn.custom_minimum_size = button_size
			btn.toggle_mode = false
			btn.pressed.connect(_on_switch_pressed.bind(x, y))
			container.add_child(btn)
			row.append(btn)
		_buttons.append(row)


func _on_switch_pressed(x: int, y: int) -> void:
	if completed:
		return

	_toggle_state(x, y)
	_update_visuals()

	if _is_complete():
		completed = true


func _toggle_state(x: int, y: int) -> void:
	_flip(x, y)
	_flip(x - 1, y)
	_flip(x + 1, y)
	_flip(x, y - 1)
	_flip(x, y + 1)


func _flip(x: int, y: int) -> void:
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return
	_state[x][y] = not _state[x][y]


func _update_visuals() -> void:
	for y in grid_size:
		for x in grid_size:
			var btn: Button = _buttons[y][x]
			var on: bool = _state[x][y]
			btn.text = "ON" if on else "OFF"
			btn.modulate = Color(1, 1, 1) if on else Color(0.35, 0.35, 0.35)
			btn.add_theme_font_size_override("font_size", 24)

func _is_complete() -> bool:
	for x in grid_size:
		for y in grid_size:
			if not _state[x][y]:
				return false
	return true
