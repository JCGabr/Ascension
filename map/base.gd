extends Node3D

@export var animation_player: AnimationPlayer
@export var player: CharacterBody3D

func _ready() -> void:
	animation_player.play("shake")
	player.animation_player.play("shake")
