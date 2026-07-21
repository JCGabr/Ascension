extends Control
class_name PipeCell

## Tipos de pieza. Cada uno define qué lados quedan "abiertos" en rotación 0.
## Lados: 0=Norte, 1=Este, 2=Sur, 3=Oeste
enum PieceType { EMPTY, STRAIGHT, ELBOW, T_JUNCTION, SOURCE, TARGET }

@export var piece_type: PieceType = PieceType.EMPTY
@export var rotation_steps: int = 0 # 0..3, cada paso = 90°
@export var locked: bool = false # si true, esta celda no responde a clicks

var is_energized: bool = false
var cell_size: float = 96.0

# Lados abiertos base (sin rotar) por tipo
const BASE_SIDES := {
	PieceType.EMPTY: [],
	PieceType.STRAIGHT: [0, 2],      # vertical: N-S
	PieceType.ELBOW: [0, 1],         # esquina: N-E
	PieceType.T_JUNCTION: [0, 1, 2], # T: N-E-S
	PieceType.SOURCE: [1],           # apunta al Este por defecto
	PieceType.TARGET: [3],           # recibe desde el Oeste por defecto
}

signal rotated(cell: PipeCell)

func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		rotation_steps = (rotation_steps + 1) % 4
		rotated.emit(self)
		_animate_rotation()
		queue_redraw()

func _animate_rotation() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	scale = Vector2(0.85, 0.85)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)

## Devuelve la lista de lados abiertos (0=N,1=E,2=S,3=O) considerando rotación actual
func get_open_sides() -> Array:
	var base: Array = BASE_SIDES[piece_type]
	var result: Array = []
	for s in base:
		result.append((s + rotation_steps) % 4)
	return result

func set_energized(value: bool) -> void:
	if is_energized != value:
		is_energized = value
		queue_redraw()

## --- Paleta tétrica ---
# Tubo apagado: hueso sucio/óxido. Tubo energizado: verde tóxico enfermizo.
const COLOR_PIPE_OFF := Color(0.32, 0.30, 0.27)      # óxido/hueso sucio
const COLOR_PIPE_OFF_EDGE := Color(0.12, 0.11, 0.10) # sombra del tubo apagado
const COLOR_PIPE_ON := Color(0.55, 0.95, 0.25)       # verde tóxico
const COLOR_GLOW_ON := Color(0.45, 0.85, 0.20, 0.40) # halo tóxico
const COLOR_BG := Color(0.05, 0.045, 0.05)           # casi negro, tibio
const COLOR_BG_CRACK := Color(0.0, 0.0, 0.0, 0.35)   # grietas
const COLOR_SOURCE_IRIS := Color(0.75, 0.05, 0.08)   # rojo sangre oscuro
const COLOR_SOURCE_IRIS_ON := Color(1.0, 0.15, 0.15)
const COLOR_TARGET := Color(0.10, 0.08, 0.10)
const COLOR_TARGET_EDGE := Color(0.55, 0.95, 0.25)

var _pulse_t: float = 0.0

func _process(delta: float) -> void:
	if is_energized:
		_pulse_t += delta
		queue_redraw()

func _draw() -> void:
	var c := cell_size
	var center := Vector2(c / 2.0, c / 2.0)
	var thickness := c * 0.20
	var pulse := (sin(_pulse_t * 4.0) * 0.5 + 0.5) if is_energized else 0.0

	var pipe_color := COLOR_PIPE_ON.lerp(Color(0.75, 1.0, 0.45), pulse * 0.4) if is_energized else COLOR_PIPE_OFF
	var glow_color := COLOR_GLOW_ON
	glow_color.a = 0.25 + pulse * 0.25

	# Fondo sucio con borde casi imperceptible y grietas random-fijas (por posición)
	draw_rect(Rect2(Vector2.ZERO, Vector2(c, c)), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(c, c)), Color(1, 1, 1, 0.03), false, 1.0)
	_draw_cracks(c)

	if piece_type == PieceType.EMPTY:
		return

	var dir_vec := {
		0: Vector2(0, -1), # Norte
		1: Vector2(1, 0),  # Este
		2: Vector2(0, 1),  # Sur
		3: Vector2(-1, 0), # Oeste
	}

	var open_sides := get_open_sides()

	# Halo tóxico si está energizado
	if is_energized:
		for side in open_sides:
			var end_point: Vector2 = center + dir_vec[side] * (c / 2.0)
			draw_line(center, end_point, glow_color, thickness * 2.4)
		if piece_type == PieceType.SOURCE or piece_type == PieceType.TARGET:
			draw_circle(center, c * 0.24 + pulse * c * 0.03, glow_color)

	# Sombra/óxido del tubo (línea ligeramente más ancha y oscura debajo)
	if piece_type != PieceType.SOURCE and piece_type != PieceType.TARGET:
		for side in open_sides:
			var end_point: Vector2 = center + dir_vec[side] * (c / 2.0)
			draw_line(center, end_point, COLOR_PIPE_OFF_EDGE, thickness * 1.35, true)

	# Nodo central para T/codo
	if piece_type in [PieceType.ELBOW, PieceType.T_JUNCTION]:
		for side in open_sides:
			var end_point: Vector2 = center + dir_vec[side] * (c / 2.0)
			draw_line(center, end_point, pipe_color, thickness, true)
		draw_circle(center, thickness * 0.55, pipe_color)
		draw_circle(center, thickness * 0.55, COLOR_PIPE_OFF_EDGE, false, 1.5)
	elif piece_type == PieceType.STRAIGHT:
		for side in open_sides:
			var end_point: Vector2 = center + dir_vec[side] * (c / 2.0)
			draw_line(center, end_point, pipe_color, thickness, true)
		# remaches/óxido: puntitos a lo largo del tubo
		_draw_rivets(center, dir_vec, open_sides, c)
	elif piece_type == PieceType.SOURCE:
		_draw_pipes_stub(center, dir_vec, open_sides, c, thickness, pipe_color)
		_draw_eye(center, c, pulse)
	elif piece_type == PieceType.TARGET:
		_draw_pipes_stub(center, dir_vec, open_sides, c, thickness, pipe_color)
		_draw_wound(center, c, pulse)

func _draw_pipes_stub(center: Vector2, dir_vec: Dictionary, open_sides: Array, c: float, thickness: float, pipe_color: Color) -> void:
	for side in open_sides:
		var end_point: Vector2 = center + dir_vec[side] * (c / 2.0)
		draw_line(center, end_point, pipe_color, thickness, true)

## Fuente: un ojo inyectado en sangre que se abre/pulsa al energizarse
func _draw_eye(center: Vector2, c: float, pulse: float) -> void:
	var r := c * 0.18
	draw_circle(center, r, Color(0.08, 0.05, 0.05))
	draw_circle(center, r, Color(0.02, 0.02, 0.02), false, 2.0)
	var iris_r := r * (0.55 + (0.1 if is_energized else 0.0) * pulse)
	var iris_color := COLOR_SOURCE_IRIS_ON.lerp(COLOR_SOURCE_IRIS, 1.0 - pulse) if is_energized else COLOR_SOURCE_IRIS
	draw_circle(center, iris_r, iris_color)
	draw_circle(center, iris_r * 0.4, Color(0.0, 0.0, 0.0))
	# venitas rojas alrededor
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 1000 + center.y)
	for i in 5:
		var ang: float = rng.randf_range(0, TAU)
		var start: Vector2 = center + Vector2(cos(ang), sin(ang)) * r * 0.7
		var end: Vector2 = center + Vector2(cos(ang), sin(ang)) * r * 1.15
		draw_line(start, end, Color(0.5, 0.05, 0.05, 0.6), 1.5)

## Meta: una herida/grieta que rezuma glow tóxico cuando conecta
func _draw_wound(center: Vector2, c: float, pulse: float) -> void:
	var r := c * 0.16
	var edge_color := COLOR_TARGET_EDGE if is_energized else Color(0.3, 0.28, 0.25)
	draw_circle(center, r, COLOR_TARGET)
	draw_arc(center, r, 0, TAU, 16, edge_color, 2.0 + pulse * 1.5, true)
	# grieta en zigzag desde el centro
	var pts := PackedVector2Array([
		center + Vector2(-r * 0.5, -r * 0.6),
		center + Vector2(r * 0.1, -r * 0.1),
		center + Vector2(-r * 0.2, r * 0.2),
		center + Vector2(r * 0.5, r * 0.6),
	])
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], edge_color, 1.5, true)

func _draw_rivets(center: Vector2, dir_vec: Dictionary, open_sides: Array, c: float) -> void:
	for side in open_sides:
		var dir: Vector2 = dir_vec[side]
		var end_point: Vector2 = center + dir * (c / 2.0)
		var mid: Vector2 = center.lerp(end_point, 0.6)
		draw_circle(mid, 2.0, Color(0.0, 0.0, 0.0, 0.5))

## Grietas fijas en el fondo de la celda, deterministas según posición para no
## "titilar" entre redraws.
func _draw_cracks(c: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 37 + global_position.y * 17)
	var count: int = rng.randi_range(1, 3)
	for i in count:
		var start := Vector2(rng.randf_range(0, c), rng.randf_range(0, c))
		var segs: int = rng.randi_range(2, 3)
		var p := start
		for s in segs:
			var next: Vector2 = p + Vector2(rng.randf_range(-c * 0.15, c * 0.15), rng.randf_range(-c * 0.15, c * 0.15))
			draw_line(p, next, COLOR_BG_CRACK, 1.0)
			p = next
