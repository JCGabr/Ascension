extends Control
## Ejemplo de cómo envolver el PuzzleGrid como un minijuego dentro de tu juego real.
## Colgá este script en un Control que sea tu "panel de minijuego" (puede ser
## una ventana, un popup, o una escena completa que cargues con change_scene).

signal minigame_completed
signal minigame_closed

const PuzzleGridScene = preload("res://interactuable_objects/pipe_puzzle_godot/PuzzleGrid.gd")

var puzzle_instance: Control

@onready var container: Control = $CenterContainer
@onready var close_button: Button = $CloseButton
@onready var retry_button: Button = $RetryButton

func _ready() -> void:
	_spawn_puzzle()
	close_button.pressed.connect(func(): minigame_closed.emit(); queue_free())
	retry_button.pressed.connect(_on_retry)

func _spawn_puzzle() -> void:
	puzzle_instance = PuzzleGridScene.instantiate()
	puzzle_instance.puzzle_solved.connect(_on_puzzle_solved)
	container.add_child(puzzle_instance)

func _on_retry() -> void:
	puzzle_instance.reset_puzzle()

func _on_puzzle_solved() -> void:
	# Acá enganchás tu lógica real: dar recompensa, abrir puerta, etc.
	await get_tree().create_timer(1.0).timeout
	minigame_completed.emit()
	# queue_free() # descomentá si querés que se cierre solo al ganar
