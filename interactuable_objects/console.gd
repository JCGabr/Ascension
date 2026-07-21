extends Control

## ============================================================
##  RADAR 2D para Godot 4.7
##  Colocar este script en un nodo Control (ej: dentro de un
##  CanvasLayer / HUD). El radar detecta nodos Node2D o Node3D
##  que pertenezcan al grupo "radar_target" y los dibuja como
##  puntos (blips) alrededor de un nodo "centro" (normalmente
##  el jugador).
## ============================================================

## --- CONFIGURACIÓN ---------------------------------------------------

## Nodo que representa el centro del radar (normalmente el jugador).
## Puede ser Node2D o Node3D.
@export var centro: Node = null

## Grupo al que deben pertenecer los objetos detectables.
@export var grupo_objetivos: String = "radar_target"

## Distancia máxima que el radar puede detectar (en unidades del mundo).
@export var rango_deteccion: float = 500.0

## Si es true, el radar rota junto con el "centro" (modo relativo,
## como en muchos juegos de naves). Si es false, el norte siempre
## apunta hacia arriba (modo mapa).
@export var rotar_con_centro: bool = false

## Actualizar automáticamente cada frame (_process).
@export var auto_actualizar: bool = true

## --- ESTILO ------------------------------------------------------------

@export_group("Estilo")
@export var color_fondo: Color = Color(0.02, 0.08, 0.03, 1)
@export var color_borde: Color = Color(0.2, 1.0, 0.3, 1.0)
@export var color_lineas: Color = Color(0.2, 1.0, 0.3, 0.35)
@export var color_barrido: Color = Color(0.2, 1.0, 0.3, 0.5)
@export var color_centro: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var color_blip_default: Color = Color(1.0, 0.3, 0.2, 1.0)
@export var grosor_borde: float = 2.0
@export var num_anillos: int = 3
@export var mostrar_barrido: bool = true
@export var velocidad_barrido: float = 90.0  # grados por segundo
@export var radio_blip: float = 4.0

@export_group("Efecto Ping")
## Si es true, los objetivos SOLO se dibujan cuando el barrido pasa
## sobre ellos, con un pulso que se desvanece. Si es false, se
## dibujan siempre (comportamiento anterior).
@export var solo_ping_al_pasar_barrido: bool = true

## Cuánto tiempo (segundos) dura visible el pulso después de que
## el barrido detecta al objetivo.
@export var duracion_ping: float = 1.6

## Multiplicador de tamaño máximo que alcanza el pulso al aparecer
## (1.0 = tamaño normal del blip, 2.5 = empieza grande y se encoge).
@export var escala_maxima_ping: float = 2.5

## Cuántos "anillos" de pulso se dibujan por ping (efecto sonar).
@export var anillos_ping: int = 2

## --- INTERNO -------------------------------------------------------------

var _angulo_barrido: float = 0.0
var _angulo_barrido_anterior: float = 0.0

## Diccionario: objetivo (Node) -> tiempo restante de vida del ping (float)
var _pings_activos: Dictionary = {}

## Diccionario opcional para dar color/etiqueta distinta a ciertos objetivos.
## key: NodePath o grupo secundario -> value: Color
## (uso opcional, ver _obtener_color_objetivo)


## Activa mensajes de depuración en la consola de salida (Output).
@export var debug: bool = false


func _ready() -> void:
	# Asegura que el control se redibuje constantemente si hace falta.
	set_process(auto_actualizar)

	if debug:
		print("[Radar] _ready(). centro asignado = ", centro)
		if centro == null:
			push_warning("[Radar] El campo 'centro' está vacío. Asígnalo en el Inspector o desde código.")
		var objetivos := get_tree().get_nodes_in_group(grupo_objetivos)
		print("[Radar] Objetivos encontrados en grupo '", grupo_objetivos, "': ", objetivos.size())
		for o in objetivos:
			print("   -> ", o.name, " (", o.get_class(), ")")


func _process(delta: float) -> void:
	_angulo_barrido_anterior = _angulo_barrido

	if mostrar_barrido:
		_angulo_barrido = fmod(_angulo_barrido + velocidad_barrido * delta, 360.0)

	if solo_ping_al_pasar_barrido and mostrar_barrido:
		_actualizar_pings(delta)

	queue_redraw()


## Revisa qué objetivos fueron "tocados" por el barrido este frame
## (creando o reiniciando su ping), y reduce el tiempo de vida de
## los pings ya activos, eliminando los que expiraron.
func _actualizar_pings(delta: float) -> void:
	if centro == null:
		return

	var pos_centro: Vector2 = _obtener_posicion_2d(centro)
	var rotacion_centro: float = 0.0
	if rotar_con_centro:
		rotacion_centro = _obtener_rotacion(centro)

	var objetivos := get_tree().get_nodes_in_group(grupo_objetivos)

	for objetivo in objetivos:
		if objetivo == centro:
			continue
		if not (objetivo is Node2D or objetivo is Node3D):
			continue

		var pos_obj: Vector2 = _obtener_posicion_2d(objetivo)
		var delta_pos: Vector2 = pos_obj - pos_centro
		var distancia: float = delta_pos.length()

		if distancia > rango_deteccion:
			continue

		# Ángulo del objetivo relativo al centro, en el mismo sistema
		# de referencia que usa el barrido (0-360, sentido de draw_arc).
		var angulo_objetivo: float = rad_to_deg(delta_pos.angle())
		if rotar_con_centro:
			angulo_objetivo = rad_to_deg(delta_pos.rotated(-rotacion_centro + PI * 0.5).angle())
		angulo_objetivo = fmod(angulo_objetivo + 360.0, 360.0)

		if _barrido_cruzo_angulo(angulo_objetivo):
			_pings_activos[objetivo] = duracion_ping

	# Reduce el tiempo de vida de todos los pings activos.
	var expirados: Array = []
	for obj in _pings_activos.keys():
		_pings_activos[obj] -= delta
		if _pings_activos[obj] <= 0.0 or not is_instance_valid(obj):
			expirados.append(obj)

	for obj in expirados:
		_pings_activos.erase(obj)


## Determina si, entre el frame anterior y el actual, la línea del
## barrido cruzó el ángulo dado (en grados, 0-360).
func _barrido_cruzo_angulo(angulo: float) -> bool:
	var a0: float = _angulo_barrido_anterior
	var a1: float = _angulo_barrido

	if a1 >= a0:
		return angulo >= a0 and angulo <= a1
	else:
		# El barrido dio la vuelta completa (ej: 350 -> 5)
		return angulo >= a0 or angulo <= a1


func _draw() -> void:
	var radio: float = min(size.x, size.y) * 0.5 - grosor_borde
	var centro_px: Vector2 = size * 0.5

	if radio <= 0.0:
		return

	# --- Fondo circular ---
	draw_circle(centro_px, radio, color_fondo)

	# --- Anillos concéntricos ---
	for i in range(1, num_anillos + 1):
		var r: float = radio * (float(i) / float(num_anillos))
		draw_arc(centro_px, r, 0.0, TAU, 64, color_lineas, 1.0, true)

	# --- Líneas cruzadas (cruz central) ---
	draw_line(centro_px + Vector2(-radio, 0), centro_px + Vector2(radio, 0), color_lineas, 1.0)
	draw_line(centro_px + Vector2(0, -radio), centro_px + Vector2(0, radio), color_lineas, 1.0)

	# --- Barrido tipo sonar ---
	if mostrar_barrido:
		_dibujar_barrido(centro_px, radio)

	# --- Borde exterior ---
	draw_arc(centro_px, radio, 0.0, TAU, 64, color_borde, grosor_borde, true)

	# --- Punto central (jugador) ---
	draw_circle(centro_px, 3.0, color_centro)

	# --- Objetivos detectados ---
	_dibujar_objetivos(centro_px, radio)


func _dibujar_barrido(centro_px: Vector2, radio: float) -> void:
	var puntos: PackedVector2Array = PackedVector2Array()
	var colores: PackedColorArray = PackedColorArray()

	var ang_rad: float = deg_to_rad(_angulo_barrido)
	var ancho_barrido: float = deg_to_rad(35.0)  # ancho del abanico

	puntos.append(centro_px)
	colores.append(color_barrido)

	var pasos: int = 12
	for i in range(pasos + 1):
		var a: float = ang_rad - ancho_barrido + (ancho_barrido * 2.0 * i / pasos)
		var p: Vector2 = centro_px + Vector2(cos(a), sin(a)) * radio
		puntos.append(p)
		var alpha_factor: float = 1.0 - abs(float(i) - pasos * 0.5) / (pasos * 0.5)
		var c: Color = color_barrido
		c.a *= alpha_factor
		colores.append(c)

	draw_polygon(puntos, colores)

	# Línea principal del barrido, más brillante
	var punta: Vector2 = centro_px + Vector2(cos(ang_rad), sin(ang_rad)) * radio
	draw_line(centro_px, punta, color_borde, 1.5)


func _dibujar_objetivos(centro_px: Vector2, radio: float) -> void:
	if centro == null:
		return

	if solo_ping_al_pasar_barrido and mostrar_barrido:
		_dibujar_pings(centro_px, radio)
	else:
		_dibujar_objetivos_estaticos(centro_px, radio)


## Modo clásico: todos los objetivos en rango siempre visibles.
func _dibujar_objetivos_estaticos(centro_px: Vector2, radio: float) -> void:
	var pos_centro: Vector2 = _obtener_posicion_2d(centro)
	var objetivos := get_tree().get_nodes_in_group(grupo_objetivos)

	var rotacion_centro: float = 0.0
	if rotar_con_centro:
		rotacion_centro = _obtener_rotacion(centro)

	for objetivo in objetivos:
		if objetivo == centro:
			continue
		if not (objetivo is Node2D or objetivo is Node3D):
			continue

		var pos_obj: Vector2 = _obtener_posicion_2d(objetivo)
		var delta: Vector2 = pos_obj - pos_centro
		var distancia: float = delta.length()

		if distancia > rango_deteccion:
			continue

		var distancia_normalizada: float = distancia / rango_deteccion
		var punto_local: Vector2 = delta.normalized() * distancia_normalizada * radio

		if rotar_con_centro:
			punto_local = punto_local.rotated(-rotacion_centro + PI * 0.5)

		var punto_final: Vector2 = centro_px + punto_local
		var color_blip: Color = _obtener_color_objetivo(objetivo)
		draw_circle(punto_final, radio_blip, color_blip)
		draw_circle(punto_final, radio_blip + 2.0, Color(color_blip.r, color_blip.g, color_blip.b, 0.25))


## Modo ping: solo dibuja objetivos con un ping activo, con
## animación de pulso (crece y se desvanece con el tiempo).
func _dibujar_pings(centro_px: Vector2, radio: float) -> void:
	var pos_centro: Vector2 = _obtener_posicion_2d(centro)

	var rotacion_centro: float = 0.0
	if rotar_con_centro:
		rotacion_centro = _obtener_rotacion(centro)

	for objetivo in _pings_activos.keys():
		if not is_instance_valid(objetivo):
			continue

		var tiempo_restante: float = _pings_activos[objetivo]
		# progreso: 0.0 = recién detectado, 1.0 = a punto de desaparecer
		var progreso: float = 1.0 - clamp(tiempo_restante / duracion_ping, 0.0, 1.0)

		var pos_obj: Vector2 = _obtener_posicion_2d(objetivo)
		var delta_pos: Vector2 = pos_obj - pos_centro
		var distancia: float = delta_pos.length()

		if distancia > rango_deteccion:
			continue

		var distancia_normalizada: float = distancia / rango_deteccion
		var punto_local: Vector2 = delta_pos.normalized() * distancia_normalizada * radio

		if rotar_con_centro:
			punto_local = punto_local.rotated(-rotacion_centro + PI * 0.5)

		var punto_final: Vector2 = centro_px + punto_local
		var color_base: Color = _obtener_color_objetivo(objetivo)

		# --- Punto central del blip: aparece fuerte y se desvanece suave ---
		var alpha_punto: float = 1.0 - pow(progreso, 2.0)
		var color_punto: Color = color_base
		color_punto.a = alpha_punto
		draw_circle(punto_final, radio_blip, color_punto)

		# --- Anillos de pulso: se expanden desde el centro del blip ---
		for i in range(anillos_ping):
			# Cada anillo empieza su expansión con un pequeño retraso.
			var retraso: float = float(i) / float(max(anillos_ping, 1)) * 0.5
			var progreso_anillo: float = clamp((progreso - retraso) / (1.0 - retraso), 0.0, 1.0)

			if progreso_anillo <= 0.0:
				continue

			var radio_anillo: float = radio_blip * lerp(1.0, escala_maxima_ping, progreso_anillo)
			var alpha_anillo: float = (1.0 - progreso_anillo) * 0.6

			if alpha_anillo <= 0.01:
				continue

			var color_anillo: Color = color_base
			color_anillo.a = alpha_anillo
			draw_arc(punto_final, radio_anillo, 0.0, TAU, 24, color_anillo, 1.5, true)


## Devuelve la posición 2D de un nodo, ya sea Node2D (x,y) o Node3D (x,z).
func _obtener_posicion_2d(nodo: Node) -> Vector2:
	if nodo is Node2D:
		return (nodo as Node2D).global_position
	elif nodo is Node3D:
		var p3: Vector3 = (nodo as Node3D).global_position
		return Vector2(p3.x, p3.z)
	return Vector2.ZERO


## Devuelve el ángulo de rotación (en radianes) de un nodo, usado para
## el modo "rotar_con_centro".
func _obtener_rotacion(nodo: Node) -> float:
	if nodo is Node2D:
		return (nodo as Node2D).global_rotation
	elif nodo is Node3D:
		return (nodo as Node3D).global_rotation.y
	return 0.0


## Permite personalizar el color de cada blip. Por defecto usa
## color_blip_default, pero si el nodo tiene un método/propiedad
## "radar_color" lo usará en su lugar.
func _obtener_color_objetivo(objetivo: Node) -> Color:
	if objetivo.has_method("get_radar_color"):
		return objetivo.call("get_radar_color")
	if "radar_color" in objetivo:
		return objetivo.radar_color
	return color_blip_default
