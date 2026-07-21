extends Node
class_name ScreenInputRelay

## ============================================================
##  ScreenInputRelay
##  Traduce clicks/movimiento del mouse del sistema en eventos
##  de InputEvent inyectados dentro de un SubViewport que se usa
##  como render-to-texture sobre un Sprite3D (pantalla en el
##  mundo 3D, ej: la consola de tuberías).
##
##  Un SubViewport que solo se usa como textura NO recibe input
##  del sistema automáticamente. Este script hace de puente:
##  1) Detecta si el mouse (en pantalla) cae sobre el Sprite3D.
##  2) Convierte esa posición a coordenadas locales del Viewport.
##  3) Llama a viewport.push_input() con el evento traducido.
##
##  Colocalo como hijo de tu Player (o donde tengas la Camera3D),
##  o cuélgalo directo en la escena y asignale las referencias
##  desde el inspector.
## ============================================================

## Cámara desde la que se lanza el rayo (normalmente la del jugador).
@export var camera: Camera3D

## Sprite3D que muestra el ViewportTexture (ej: "Pipes" o "Console").
@export var target_sprite: Sprite3D

## El SubViewport cuyo contenido se está mostrando en target_sprite.
@export var target_viewport: SubViewport

## Si es true, el relay solo procesa input cuando "activo" es true.
## Útil para activarlo solo cuando el jugador está en modo pivot
## mirando esta pantalla en particular.
@export var activo: bool = false

@export var debug: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not activo:
		return
	if camera == null or target_sprite == null or target_viewport == null:
		return

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_relay_mouse_event(event)


func _relay_mouse_event(event: InputEvent) -> void:
	var mouse_pos: Vector2 = event.position if "position" in event else get_viewport().get_mouse_position()

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * 1000.0

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Ajusta esto a la collision_layer que uses para las "pantallas" (ConsoleCollision/PipesCollision)
	query.collision_mask = 4
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return

	# Verifica que lo que golpeamos sea el StaticBody3D "dueño" de esta pantalla.
	# Si tu StaticBody3D es distinto al target_sprite (como en tu escena, donde
	# ConsoleCollision/PipesCollision son StaticBody3D separados), asigná ese
	# StaticBody3D como "hit_body_filter" o comparalo por nombre/grupo.
	var local_uv: Vector2 = _get_uv_on_sprite(result.position)
	if local_uv.x < 0.0 or local_uv.x > 1.0 or local_uv.y < 0.0 or local_uv.y > 1.0:
		return

	var viewport_size: Vector2 = target_viewport.size
	var local_pos: Vector2 = local_uv * viewport_size

	var relayed_event: InputEvent = event.duplicate()
	relayed_event.position = local_pos
	if relayed_event is InputEventMouseMotion:
		relayed_event.global_position = local_pos

	if debug:
		print("[ScreenInputRelay] uv=", local_uv, " local_pos=", local_pos)

	target_viewport.push_input(relayed_event)

	# Evita que el mismo click siga propagándose como interacción del mundo 3D
	# (por ejemplo, que el player.gd lo interprete como otra cosa).
	get_viewport().set_input_as_handled()


## Convierte un punto de impacto en el mundo 3D (sobre la superficie del
## Sprite3D) a coordenadas UV (0..1, 0..1) relativas al sprite.
## Asume que el Sprite3D no tiene billboard rotado en runtime y que su
## eje "up" es Y y su eje "right" es X local.
func _get_uv_on_sprite(hit_position: Vector3) -> Vector2:
	var local_hit: Vector3 = target_sprite.to_local(hit_position)

	# El tamaño real en unidades del mundo del sprite (pixel_size * texture_size)
	var tex_size: Vector2 = target_sprite.texture.get_size() if target_sprite.texture else target_viewport.size
	var world_width: float = tex_size.x * target_sprite.pixel_size
	var world_height: float = tex_size.y * target_sprite.pixel_size

	# local_hit.x va de -width/2 a +width/2 (offset/centered depende de tu sprite)
	var u: float = (local_hit.x / world_width) + 0.5
	# En Godot, Y de sprite crece hacia arriba, pero UV/viewport crece hacia abajo
	var v: float = 0.5 - (local_hit.y / world_height)

	return Vector2(u, v)
