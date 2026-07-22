extends Node3D

@export var animation_player: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("close")

func open() -> void:
	animation_player.play("open")

func close() -> void:
	animation_player.play("close")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
