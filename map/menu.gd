extends Control

const GAME_SCENE_PATH := "res://map/test_map.tscn"
const FADE_TIME := 0.8

@onready var fade: ColorRect = $Fade
@onready var jugar_button: Button = $Panel/VBoxContainer/HBoxContainer/Jugar
@onready var salir_button: Button = $Panel/VBoxContainer/HBoxContainer/Salir

var is_transitioning := false
var map_scene: PackedScene = null
var map_loaded := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_ambient("underwater_deep")

	# Arranca todo negro y hace fade in hacia el menú
	fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_TIME)

	# Empieza a precargar el mapa en segundo plano
	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	set_process(true)

func _process(_delta: float) -> void:
	if map_loaded:
		set_process(false)
		return

	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			map_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH)
			map_loaded = true
			set_process(false)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Error al precargar el mapa: %s" % GAME_SCENE_PATH)
			set_process(false)

func _on_button_hover() -> void:
	AudioManager.play_sfx("sonar_ping-1")

func _on_jugar_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	jugar_button.disabled = true
	salir_button.disabled = true

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_TIME)
	tween.finished.connect(_go_to_map)

func _go_to_map() -> void:
	if not map_loaded or map_scene == null:
		await _wait_for_map_load()

	# Pantalla ya está negra por el fade. Esperamos un frame para
	# asegurarnos de que el frame negro se muestre en pantalla
	# ANTES de hacer el trabajo pesado de instanciar.
	await get_tree().process_frame
	await get_tree().process_frame

	# Ahora instanciamos manualmente en vez de usar change_scene_to_packed,
	# que nos da más control sobre el momento exacto
	var current_scene := get_tree().current_scene
	var new_scene := map_scene.instantiate()

	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	# Esperamos otro frame para que el nuevo árbol termine sus _ready()
	# y se estabilice (físicas, primer draw, etc.)
	await get_tree().process_frame

	current_scene.queue_free()

	# Recién ahora hacemos fade in, ya con la escena nueva lista y estable
	var tween_in := create_tween()
	tween_in.tween_property(fade, "color:a", 0.0, FADE_TIME)

func _wait_for_map_load() -> void:
	while not map_loaded:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			map_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH)
			map_loaded = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Error al cargar el mapa")
			return
		else:
			await get_tree().process_frame

func _on_salir_pressed() -> void:
	get_tree().quit()
