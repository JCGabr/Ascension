extends Node3D

## ============================================================
## Escena de introducción: reproduce la animación del modelo
## (ej. tv.glb) mientras muestra subtítulos sincronizados
## contando la historia. Al terminar, carga el nivel de juego.
## ============================================================

## Escena del modelo animado (arrastra aquí tv.glb, o usa el que
## ya esté puesto como hijo en el editor y deja esto vacío)
@export var model_scene: PackedScene

## Nombre de la animación a reproducir (vacío = usa la primera que encuentre)
@export var animation_name: String = ""

## Ruta de la escena a cargar cuando termine la intro (tu nivel real)
@export var next_scene_path: String = "res://map/test_map.tscn"

## Cada subtítulo: el texto y el segundo exacto en que debe aparecer.
## La duración es cuánto tiempo se queda en pantalla antes de que
## aparezca el siguiente (o desaparecer si es el último).
@export var subtitles: Array[Dictionary] = [
	{"time": 0.5, "text": "El temblor llegó sin aviso.", "duration": 3.0},
	{"time": 4.0, "text": "Una cadena de volcanes despertó en el fondo del mar.", "duration": 3.5},
	{"time": 8.0, "text": "Ahora, atrapado a cientos de metros de profundidad...", "duration": 3.0},
	{"time": 11.5, "text": "...solo queda una salida: llegar a la superficie.", "duration": 3.5},
]

@onready var subtitle_label: Label = $CanvasLayer/SubtitleLabel
@onready var skip_button: Button = $CanvasLayer/SkipButton

var _model: Node3D
var _anim_player: AnimationPlayer
var _time_elapsed: float = 0.0
var _current_subtitle_index: int = -1
var _subtitle_hide_timer: float = 0.0


func _ready() -> void:
	subtitle_label.text = ""
	skip_button.pressed.connect(_on_skip_pressed)

	if model_scene:
		_model = model_scene.instantiate()
		add_child(_model)
		_anim_player = _find_animation_player(_model)
		if _anim_player:
			var anim = animation_name
			if anim == "":
				var list = _anim_player.get_animation_list()
				if list.size() > 0:
					anim = list[0]
			if anim != "" and _anim_player.has_animation(anim):
				_anim_player.play(anim)
				# Cuando termina la animación (si no está en loop), pasa al juego
				_anim_player.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	_time_elapsed += delta

	# Revisa si toca mostrar el siguiente subtítulo
	var next_index = _current_subtitle_index + 1
	if next_index < subtitles.size() and _time_elapsed >= subtitles[next_index]["time"]:
		_current_subtitle_index = next_index
		subtitle_label.text = subtitles[next_index]["text"]
		_subtitle_hide_timer = subtitles[next_index]["duration"]

	# Cuenta regresiva para ocultar el subtítulo actual
	if _subtitle_hide_timer > 0.0:
		_subtitle_hide_timer -= delta
		if _subtitle_hide_timer <= 0.0:
			subtitle_label.text = ""


func _on_animation_finished(_anim_name: String) -> void:
	_go_to_next_scene()


func _on_skip_pressed() -> void:
	_go_to_next_scene()


func _go_to_next_scene() -> void:
	get_tree().change_scene_to_file(next_scene_path)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null
