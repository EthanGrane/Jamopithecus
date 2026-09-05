##
##	Summary:
##	Dolly de cámara: un raíl horizontal entre dos puntos A y B.
##	La cámara sigue al jugador pero no puede salirse del raíl,
##	así controlas exactamente qué trozo del mapa se llega a ver.
##
##	En el editor dibuja el raíl y el rectángulo de TODO lo que
##	el jugador podrá ver alguna vez. Si una zona que no quieres
##	enseñar cae dentro de ese rectángulo, acorta el raíl.
##

@tool
extends Node2D
class_name CameraDolly

@export var objetivo : Node2D   # si lo dejas vacío busca el grupo "player"

@export_group("Raíl")
# Los dos puntos van en coordenadas locales del dolly.
# La altura la manda punto_a: la Y de punto_b se iguala sola.
@export var punto_a : Vector2 = Vector2(-400, 0) : set = _set_punto_a
@export var punto_b : Vector2 = Vector2(400, 0) : set = _set_punto_b

@export_group("Seguimiento")
@export var zona_muerta : float = 40.0        # px que puede moverse sin que la cámara reaccione
@export var suavizado : float = 6.0           # más alto = más pegada al jugador
@export var adelanto : float = 80.0           # px que se asoma hacia donde corre
@export var suavizado_adelanto : float = 3.0

@export_group("Sacudida")
@export var sacudida_maxima : float = 20.0   # px de desplazamiento como mucho

@export_group("Dibujo en el editor")
@export var mostrar_bounds : bool = true : set = _set_mostrar_bounds
@export var color_rail : Color = Color(0.35, 0.85, 1.0)
@export var color_zona : Color = Color(0.35, 0.85, 1.0, 0.10)

var camara : Camera2D = null
var centro_x : float = 0.0
var adelanto_actual : float = 0.0
var primer_frame : bool = true

var trauma : float = 0.0            # 0 a 1, cuánto tiembla ahora mismo
var caida_del_trauma : float = 4.0


func _ready() -> void:
	camara = get_node_or_null("Camera2D")

	if Engine.is_editor_hint():
		return

	# Para que GameFeel.sacudir() la encuentre sin conocerla
	add_to_group("camera_shake")

	if camara == null:
		push_error("CameraDolly: falta un Camera2D como hijo")
		return

	if objetivo == null:
		objetivo = get_tree().get_first_node_in_group("player")

	colocar_al_instante()


func _process(_delta: float) -> void:
	# Solo en el editor: mantener el raíl recto y refrescar el dibujo
	if not Engine.is_editor_hint():
		return

	punto_b.y = punto_a.y

	# Preview: la cámara se coloca en el centro del raíl
	if camara == null:
		camara = get_node_or_null("Camera2D")
	if camara != null:
		camara.position = Vector2((punto_a.x + punto_b.x) * 0.5, punto_a.y)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or camara == null:
		return

	actualizar_sacudida(delta)

	if objetivo == null:
		return

	# Al arrancar la cámara aparece ya en su sitio, sin viajar hasta él.
	# Se hace aquí y no solo en _ready por si el objetivo tardó en aparecer
	if primer_frame:
		primer_frame = false
		colocar_al_instante()
		return

	# 1) Adelanto: la cámara se asoma hacia donde corre el jugador
	var vel_x := 0.0
	if objetivo is CharacterBody2D:
		vel_x = objetivo.velocity.x

	var adelanto_deseado := 0.0
	if absf(vel_x) > 10.0:
		adelanto_deseado = signf(vel_x) * adelanto

	adelanto_actual = lerpf(adelanto_actual, adelanto_deseado, suavizar(suavizado_adelanto, delta))

	# 2) Zona muerta: dentro de esta ventana la cámara ni se entera
	var destino := to_local(objetivo.global_position).x + adelanto_actual
	var diferencia := destino - centro_x
	if absf(diferencia) > zona_muerta:
		centro_x += diferencia - signf(diferencia) * zona_muerta

	# 3) El raíl: pase lo que pase, la cámara no sale de A-B
	centro_x = clampf(centro_x, minf(punto_a.x, punto_b.x), maxf(punto_a.x, punto_b.x))

	# 4) Suavizado
	camara.position.x = lerpf(camara.position.x, centro_x, suavizar(suavizado, delta))
	camara.position.y = punto_a.y


# ---------------------------------------------------------------
#  Sacudida
# ---------------------------------------------------------------

# La llama GameFeel.sacudir() a través del grupo "camera_shake"
func sacudir(fuerza: float = 10.0, duracion: float = 0.25) -> void:
	trauma = minf(trauma + fuerza / sacudida_maxima, 1.0)
	caida_del_trauma = 1.0 / maxf(duracion, 0.05)


func actualizar_sacudida(delta: float) -> void:
	if trauma <= 0.0:
		if camara.offset != Vector2.ZERO:
			camara.offset = Vector2.ZERO
		return

	trauma = maxf(trauma - caida_del_trauma * delta, 0.0)

	# Al cuadrado: arranca fuerte y se apaga suave. Con trauma lineal
	# la sacudida se corta de golpe y se nota artificial
	var f := trauma * trauma * sacudida_maxima

	# Va en 'offset' y no en 'position' porque de la position
	# ya se encarga el raíl cada frame
	camara.offset = Vector2(randf_range(-f, f), randf_range(-f, f))


# Planta la cámara en su sitio de golpe, sin suavizar.
# Llámala también al hacer respawn o al teletransportar al jugador
func colocar_al_instante() -> void:
	if objetivo == null or camara == null:
		return

	adelanto_actual = 0.0
	centro_x = to_local(objetivo.global_position).x
	centro_x = clampf(centro_x, minf(punto_a.x, punto_b.x), maxf(punto_a.x, punto_b.x))

	camara.position = Vector2(centro_x, punto_a.y)
	camara.reset_smoothing()   # por si el Camera2D trae su propio suavizado


# Un lerp normal con un valor fijo va más rápido cuantos más FPS tengas.
# Esta fórmula da el mismo movimiento a 30 que a 144 fps.
func suavizar(velocidad: float, delta: float) -> float:
	return 1.0 - exp(-velocidad * delta)


# ---------------------------------------------------------------
#  Dibujo en el editor
# ---------------------------------------------------------------

func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_bounds:
		return

	var izq := minf(punto_a.x, punto_b.x)
	var der := maxf(punto_a.x, punto_b.x)
	var y := punto_a.y
	var mitad := tam_de_pantalla() * 0.5

	# TODO lo que se podrá ver alguna vez desde este raíl.
	# Lo que quede fuera de aquí no se enseña nunca
	var zona := Rect2(
		Vector2(izq - mitad.x, y - mitad.y),
		Vector2((der - izq) + mitad.x * 2.0, mitad.y * 2.0)
	)
	draw_rect(zona, color_zona, true)
	draw_rect(zona, Color(color_rail, 0.5), false, 2.0)

	# El encuadre exacto en cada extremo del raíl
	draw_rect(Rect2(Vector2(izq - mitad.x, y - mitad.y), mitad * 2.0), color_rail, false, 1.0)
	draw_rect(Rect2(Vector2(der - mitad.x, y - mitad.y), mitad * 2.0), color_rail, false, 1.0)

	# El raíl y sus dos puntos
	draw_line(Vector2(izq, y), Vector2(der, y), color_rail, 3.0)
	draw_circle(Vector2(punto_a.x, y), 9.0, color_rail)
	draw_circle(Vector2(punto_b.x, y), 9.0, color_rail)


# El tamaño de la ventana del juego, no el del editor.
# Si usas zoom en la cámara hay que dividir por él
func tam_de_pantalla() -> Vector2:
	var ancho := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var alto := float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var zoom := Vector2.ONE
	if camara != null and camara.zoom.x > 0.0 and camara.zoom.y > 0.0:
		zoom = camara.zoom
	return Vector2(ancho / zoom.x, alto / zoom.y)


# ---------------------------------------------------------------

func _set_punto_a(valor: Vector2) -> void:
	punto_a = valor
	queue_redraw()


func _set_punto_b(valor: Vector2) -> void:
	punto_b = valor
	queue_redraw()


func _set_mostrar_bounds(valor: bool) -> void:
	mostrar_bounds = valor
	queue_redraw()
