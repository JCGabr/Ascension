extends Control

const GAME_SCENE_PATH := "res://map/test_map.tscn"
const FADE_TIME := 0.8

@onready var fade: ColorRect = $Fade
@onready var jugar_button: Button = $Panel/VBoxContainer/HBoxContainer/Jugar
@onready var salir_button: Button = $Panel/VBoxContainer/HBoxContainer/Salir

var is_transitioning := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_ambient("underwater_deep")
	# Arranca todo negro y hace fade in hacia el menú
	fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_TIME)


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
	tween.finished.connect(func():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	)


func _on_salir_pressed() -> void:
	get_tree().quit()
