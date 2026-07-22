extends Node3D

## ============================================================
## Cardumen animado (the_fish_particle.glb ya trae su propia
## animación interna de varios peces moviéndose entre sí).
## Este script solo lo instancia, lo reproduce en loop y permite
## ajustar escala/posición fácilmente desde el Inspector.
## ============================================================

## Escena del cardumen (arrastra aquí the_fish_particle.glb)
@export var fish_scene: PackedScene

## Escala del cardumen completo (sube este valor si se ve muy pequeño)
@export var fish_scale: float = 2.0

## Nombre de la animación a reproducir. Déjalo vacío para que el
## script intente reproducir la primera animación que encuentre.
@export var swim_animation_name: String = ""

## Movimiento suave opcional (deriva lenta), para que el cardumen
## no quede totalmente estático en un solo punto. Ponlo en 0 para
## desactivar el movimiento y dejarlo fijo.
@export var drift_amount: float = 0.5
@export var drift_speed: float = 0.15

var _fish: Node3D
var _base_position: Vector3
var _time: float = 0.0

func _ready() -> void:
	if fish_scene == null:
		push_warning("FishSchool: asigna 'fish_scene' en el Inspector (the_fish_particle.glb)")
		return

	_fish = fish_scene.instantiate()
	add_child(_fish)
	_fish.scale = Vector3(fish_scale, fish_scale, fish_scale)
	_base_position = _fish.position

	var anim_player = _find_animation_player(_fish)
	if anim_player:
		var anim_name = swim_animation_name
		if anim_name == "":
			var list = anim_player.get_animation_list()
			if list.size() > 0:
				anim_name = list[0]

		if anim_name != "" and anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
		else:
			push_warning("FishSchool: no se encontró la animación '%s'" % anim_name)
	else:
		push_warning("FishSchool: no se encontró AnimationPlayer dentro del modelo")


func _process(delta: float) -> void:
	if _fish == null or drift_amount <= 0.0:
		return
	_time += delta * drift_speed
	_fish.position = _base_position + Vector3(
		sin(_time) * drift_amount,
		sin(_time * 0.7) * drift_amount * 0.3,
		cos(_time) * drift_amount
	)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null
