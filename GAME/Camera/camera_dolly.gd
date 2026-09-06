##
##	Summary:
##	Cámara del juego.
##
##	  Sin puntos → sigue al jugador. Marca bloquear_x o bloquear_y
##	               y ese eje se queda clavado donde esté este nodo.
##	  Con puntos → se mueve por la línea que forman, cambiando de
##	               fov de uno a otro.
##
##	Además tiene un "objetivo extra": otro nodo al que mirar sin
##	dejar de ser la cámara del jugador. Lo usa BossIntro para los
##	paneos. Se controla con peso_extra, de 0 (jugador) a 1 (el otro).
##
##	El Camera2D va como hijo de este nodo, nunca del Player.
##

@tool
extends Node2D
class_name CameraDolly

@export var objetivo : Node2D             # vacío = busca el grupo "player"
@export var puntos : Array[DollyPoint] = []   # vacío = seguimiento libre

@export var bloquear_x : bool = false
@export var bloquear_y : bool = true
@export var fov : float = 1.0             # el que usa sin puntos

@export var zona_muerta : Vector2 = Vector2(40.0, 30.0)
@export var suavizado : float = 6.0
@export var adelanto : float = 80.0       # px que se asoma hacia donde corre
@export var sacudida_maxima : float = 20.0

@onready var camara : Camera2D = $Camera2D

var centro : Vector2 = Vector2.ZERO
var adelanto_actual : float = 0.0
var trauma : float = 0.0
var caida_del_trauma : float = 4.0

# Paneo. No son @export a propósito: los mueve BossIntro por código
var objetivo_extra : Node2D = null
var peso_extra : float = 0.0
var fov_extra : float = 1.0
# De dónde sale el paneo. Se guarda al empezar y no es lo mismo que
# "donde debería estar la cámara": con el suavizado siempre va un
# poco por detrás del jugador. Si el paneo saliera del sitio teórico
# en vez del real, daría un tirón en el primer frame
var paneo_desde : Vector2 = Vector2.ZERO
var paneo_fov_desde : float = 1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("camera_shake")

	if objetivo == null:
		objetivo = get_tree().get_first_node_in_group("player")

	colocar_al_instante()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or camara == null:
		return

	sacudir_camara(delta)

	if objetivo == null:
		return

	actualizar_adelanto(delta)

	var meta := destino()
	var f := 1.0 / maxf(fov_actual(), 0.05)

	if hay_paneo():
		# Durante el paneo la cámara va donde se le dice, sin suavizar.
		# El suavizado ya lo pone la curva del tween: si además lo
		# suavizara aquí, el paneo llegaría tarde y no duraría lo
		# que le has pedido
		camara.global_position = meta
		camara.zoom = Vector2(f, f)
		return

	var suave := suavizar(delta)
	camara.global_position = camara.global_position.lerp(meta, suave)

	# En Camera2D más zoom es MÁS cerca, así que el fov es su inverso
	var z := lerpf(camara.zoom.x, f, suave)
	camara.zoom = Vector2(z, z)


# ---------------------------------------------------------------
#  Paneo: la API que usa BossIntro
# ---------------------------------------------------------------

func hay_paneo() -> bool:
	return objetivo_extra != null and peso_extra > 0.0


func mirar_a(nodo: Node2D, fov_del_paneo: float = 1.0) -> void:
	objetivo_extra = nodo
	fov_extra = fov_del_paneo

	# El punto de partida es donde está la cámara AHORA MISMO
	if camara != null:
		paneo_desde = camara.global_position
		paneo_fov_desde = 1.0 / maxf(camara.zoom.x, 0.001)


func soltar_paneo() -> void:
	objetivo_extra = null
	peso_extra = 0.0

	# La cámara ha vuelto a mano hasta el jugador, así que el
	# seguimiento tiene que continuar desde aquí y no pegar un salto
	if camara != null:
		centro = camara.global_position


# ---------------------------------------------------------------

func destino() -> Vector2:
	# Durante el paneo se va del punto guardado al objetivo. Con peso
	# 0 se queda exactamente donde estaba, así que ni al empezar ni
	# al volver hay salto: entra y sale por el mismo sitio
	if hay_paneo():
		return paneo_desde.lerp(objetivo_extra.global_position, peso_extra)

	return destino_normal()


func destino_normal() -> Vector2:
	var deseado := objetivo.global_position + Vector2(adelanto_actual, 0.0)

	if puntos.size() > 0:
		centro = deseado
		return proyectar(deseado)[0]

	# Zona muerta: dentro de esta ventana el jugador se mueve y la
	# cámara ni se entera. Sin esto tiembla con cada pasito
	var dif := deseado - centro
	if absf(dif.x) > zona_muerta.x:
		centro.x += dif.x - signf(dif.x) * zona_muerta.x
	if absf(dif.y) > zona_muerta.y:
		centro.y += dif.y - signf(dif.y) * zona_muerta.y

	var d := centro

	# El eje bloqueado se clava donde esté este nodo, así lo colocas
	# arrastrándolo en el editor en vez de escribir coordenadas
	if bloquear_x:
		d.x = global_position.x
	if bloquear_y:
		d.y = global_position.y

	return d


func fov_actual() -> float:
	if hay_paneo():
		return lerpf(paneo_fov_desde, fov_extra, peso_extra)

	return fov_normal()


func fov_normal() -> float:
	if puntos.is_empty():
		return fov
	return proyectar(objetivo.global_position)[1]


# Proyecta una posición sobre la línea de puntos.
# Devuelve [posición en el raíl, fov interpolado]
func proyectar(pos: Vector2) -> Array:
	if puntos.size() == 1 and puntos[0] != null:
		return [to_global(puntos[0].posicion), puntos[0].fov]

	var mejor_pos := pos
	var mejor_fov := fov
	var mejor_distancia := INF

	for i in puntos.size() - 1:
		if puntos[i] == null or puntos[i + 1] == null:
			continue

		var a := to_global(puntos[i].posicion)
		var b := to_global(puntos[i + 1].posicion)
		var ab := b - a

		var t := 0.0
		if ab.length_squared() > 0.0:
			t = clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)

		var sobre_el_rail := a + ab * t
		var d := pos.distance_squared_to(sobre_el_rail)

		if d < mejor_distancia:
			mejor_distancia = d
			mejor_pos = sobre_el_rail
			mejor_fov = lerpf(puntos[i].fov, puntos[i + 1].fov, t)

	return [mejor_pos, mejor_fov]


# La cámara se asoma hacia donde corre el jugador
func actualizar_adelanto(delta: float) -> void:
	var deseado := 0.0
	if objetivo is CharacterBody2D and absf(objetivo.velocity.x) > 10.0:
		deseado = signf(objetivo.velocity.x) * adelanto

	adelanto_actual = lerpf(adelanto_actual, deseado, suavizar(delta) * 0.5)


# Un lerp con un valor fijo va más rápido cuantos más FPS tengas.
# Esta fórmula da el mismo movimiento a 30 que a 144 fps
func suavizar(delta: float) -> float:
	return 1.0 - exp(-suavizado * delta)


# Planta la cámara en su sitio de golpe, sin suavizar. Llámala
# también al hacer respawn o al teletransportar al jugador
func colocar_al_instante() -> void:
	if objetivo == null or camara == null:
		return

	adelanto_actual = 0.0
	centro = objetivo.global_position
	camara.global_position = destino()

	var z := 1.0 / maxf(fov_actual(), 0.05)
	camara.zoom = Vector2(z, z)
	camara.reset_smoothing()


# ---------------------------------------------------------------
#  Sacudida. La llama GameFeel a través del grupo "camera_shake"
# ---------------------------------------------------------------

func sacudir(fuerza: float = 10.0, duracion: float = 0.25) -> void:
	trauma = minf(trauma + fuerza / sacudida_maxima, 1.0)
	caida_del_trauma = 1.0 / maxf(duracion, 0.05)


func sacudir_camara(delta: float) -> void:
	if trauma <= 0.0:
		if camara.offset != Vector2.ZERO:
			camara.offset = Vector2.ZERO
		return

	trauma = maxf(trauma - caida_del_trauma * delta, 0.0)

	# Al cuadrado: arranca fuerte y se apaga suave
	var f := trauma * trauma * sacudida_maxima

	# En offset y no en position, que de esa se encarga el seguimiento
	camara.offset = Vector2(randf_range(-f, f), randf_range(-f, f))


# ---------------------------------------------------------------
#  Dibujo en el editor
# ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var azul := Color(0.35, 0.85, 1.0)
	var naranja := Color(1.0, 0.75, 0.3)

	if puntos.is_empty():
		# El encuadre y los ejes que quedan clavados
		var mitad := tam_de_pantalla(fov) * 0.5
		draw_rect(Rect2(-mitad, mitad * 2.0), naranja, false, 2.0)
		if bloquear_x:
			draw_line(Vector2(0.0, -mitad.y), Vector2(0.0, mitad.y), azul, 3.0)
		if bloquear_y:
			draw_line(Vector2(-mitad.x, 0.0), Vector2(mitad.x, 0.0), azul, 3.0)
		draw_circle(Vector2.ZERO, 9.0, azul)
		return

	# El raíl, y en cada punto el encuadre que tendrá con su fov
	var linea : PackedVector2Array = []
	for p in puntos:
		if p == null:
			continue
		linea.append(p.posicion)

		var mitad := tam_de_pantalla(p.fov) * 0.5
		draw_rect(Rect2(p.posicion - mitad, mitad * 2.0), naranja, false, 2.0)
		draw_circle(p.posicion, 9.0, azul)

	if linea.size() > 1:
		draw_polyline(linea, azul, 3.0)


func tam_de_pantalla(f: float) -> Vector2:
	var ancho := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var alto := float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	return Vector2(ancho, alto) * maxf(f, 0.05)
