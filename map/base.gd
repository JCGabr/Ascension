extends Node3D

@export var animation_player: AnimationPlayer
@export var player: CharacterBody3D

@export var enemies: Node3D

func shake() -> void:
	animation_player.play("shake")
	player.animation_player.play("shake")
	
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	enemies.position += Vector3(5,0,0) * delta 
