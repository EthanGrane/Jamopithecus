##
##	Summary:
##	Presentación de un boss. Cuando el jugador cruza el disparador:
##
##		1. Se le quita el control
##		2. La cámara panea hasta el boss y se queda un momento
##		3. Vuelve al jugador
##		4. Empieza la pelea y le devuelve el control
##
##	No sabe de qué boss se trata: le dices a quién mirar, qué nodos
##	despertar y cuál es el director de la pelea. Vale igual para los
##	tres, y para cualquier otra cosa que quieras enseñar.
##
##	Cómo se monta:
##		- mirar_a  → el nodo del boss (o un Marker2D si quieres
##		             encuadrar el centro de la sala en vez del bicho)
##		- dormidos → los nodos que no deben moverse todavía:
##		             normalmente el propio boss
##		- pelea    → el nodo director, si lo hay. Se le llama
##		             empezar() al acabar
##
##	Si no hay cámara o no hay a quién mirar, se salta el paneo pero
##	arranca la pelea igual: nunca deja el nivel colgado.
##

@tool
extends Node2D

signal intro_terminada

@export var mirar_a : Node2D
@export var dormidos : Array[Node] = []
@export var pelea : Node = null

@export_group("Tiempos")
# Lo que tarda en arrancar el paneo desde que cruzas el disparador.
# El control se te quita ya en el frame 0: el jugador se planta,
# hay un silencio, y ENTONCES la cámara se va. Ese silencio es la
# mitad del efecto, no lo dejes en 0
@export var retardo : float = 0.4
@export var duracion_ida : float = 1.2
@export var espera_mirando : float = 1.4     # el rato que se le queda mirando
@export var duracion_vuelta : float = 0.9

@export_group("Cámara")
# 1 = el mismo encuadre que en el juego. Menos de 1 acerca al boss,
# más de 1 se aleja para que se vea toda la sala
@export var fov_del_paneo : float = 1.0

@export_group("Extras")
@export var quitar_el_control : bool = true
@export var sonido : AudioStream = null
@export_range(-40.0, 12.0) var volumen : float = 0.0
@export var sacudida_al_llegar : float = 0.0   # 0 = nada

@onready var disparador : Area2D = $Disparador

var lanzada : bool = false
var dolly : CameraDolly = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	dormir_todo()

	# Le decimos al director que no arranque solo. Lo hacemos aquí,
	# en el _ready, porque él comprueba esto en diferido
	if pelea != null and pelea.has_method("esperar_intro"):
		pelea.esperar_intro()

	# El disparador escucha todas las capas y filtramos por clase.
	# Así no se rompe si mueves al jugador de capa
	disparador.collision_mask = 0xFFFFFFFF
	disparador.body_entered.connect(_al_entrar)


func _al_entrar(body: Node2D) -> void:
	if lanzada or not (body is player):
		return

	lanzada = true
	disparador.set_deferred("monitoring", false)
	reproducir()


# ---------------------------------------------------------------
#  La animación
# ---------------------------------------------------------------

func reproducir() -> void:
	dolly = buscar_dolly()

	if dolly == null or mirar_a == null:
		push_warning("BossIntro: sin cámara o sin 'mirar_a'. Empiezo la pelea sin paneo")
		terminar()
		return

	# Primero se le quita el control, y después esperamos. Al revés
	# seguiría corriendo durante el retardo y el paneo arrancaría
	# desde un sitio distinto del que cruzó el disparador
	bloquear_jugador(true)
	await esperar(retardo)

	dolly.mirar_a(mirar_a, fov_del_paneo)

	# Toda la animación es mover un número de 0 (jugador) a 1 (boss).
	# De convertir eso en movimiento se encarga la cámara
	await animar(0.0, 1.0, duracion_ida)

	if sonido != null:
		GameFeel.sonar(sonido, mirar_a.global_position, volumen)
	if sacudida_al_llegar > 0.0:
		GameFeel.sacudir(sacudida_al_llegar, 0.4)

	await esperar(espera_mirando)
	await animar(1.0, 0.0, duracion_vuelta)

	dolly.soltar_paneo()
	bloquear_jugador(false)

	terminar()


func animar(desde: float, hasta: float, duracion: float) -> void:
	if duracion <= 0.0:
		poner_peso(hasta)
		return

	var tw := create_tween()
	tw.tween_method(poner_peso, desde, hasta, duracion) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tw.finished


func poner_peso(valor: float) -> void:
	if dolly != null:
		dolly.peso_extra = valor


func esperar(segundos: float) -> void:
	if segundos <= 0.0:
		return
	await get_tree().create_timer(segundos).timeout


# ---------------------------------------------------------------

func terminar() -> void:
	despertar_todo()

	if pelea != null and pelea.has_method("empezar"):
		pelea.empezar()

	intro_terminada.emit()


# Dormidos de verdad: no procesan, no se mueven y no atacan
func dormir_todo() -> void:
	for n in dormidos:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_DISABLED


func despertar_todo() -> void:
	for n in dormidos:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_INHERIT


func bloquear_jugador(bloqueado: bool) -> void:
	if not quitar_el_control:
		return

	var jugador := buscar_jugador()
	if jugador != null and jugador.has_method("bloquear"):
		jugador.bloquear(bloqueado)


func buscar_dolly() -> CameraDolly:
	for n in get_tree().get_nodes_in_group("camera_shake"):
		if n is CameraDolly:
			return n
	return null


func buscar_jugador() -> Node2D:
	var por_grupo := get_tree().get_first_node_in_group("player")
	if por_grupo is Node2D:
		return por_grupo

	return buscar_por_clase(get_tree().current_scene)


func buscar_por_clase(nodo: Node) -> Node2D:
	if nodo == null:
		return null
	if nodo is player:
		return nodo

	for hijo in nodo.get_children():
		var encontrado := buscar_por_clase(hijo)
		if encontrado != null:
			return encontrado

	return null


# ---------------------------------------------------------------
#  Dibujo en el editor: la flecha del disparador al boss
# ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or mirar_a == null:
		return

	var color := Color(0.6, 1.0, 0.5)
	var destino := to_local(mirar_a.global_position)

	draw_line(Vector2.ZERO, destino, color, 2.0)
	draw_circle(destino, 12.0, color)
	draw_circle(Vector2.ZERO, 7.0, color)
