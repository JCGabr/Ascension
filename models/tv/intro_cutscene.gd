extends Node3D
@export var animation_player: AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("intro")
	AudioManager.play_ambient("radio")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func cambiar_escena():
	get_tree().change_scene_to_file("res://map/test_map.tscn")
