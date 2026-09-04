extends Area2D

# Los estados posibles de la lanza.
# Un enum es una lista de nombres que Godot convierte en números por dentro,
# así no hay riesgo de escribir mal un texto y que falle en silencio.
enum Estado {
	EN_MANO,   # pegada a la mano del jugador
	VOLANDO,   # lanzada, haciendo su parábola
	CLAVADA,   # clavada en un enemigo
	SALIENDO,  # volando hacia el punto aleatorio (lo hace el Tween)
	EN_SUELO,  # clavada en el suelo, esperando a que la recojan
}

@export_group("Lanzamiento")
@export var velocidad_lanzamiento : float = 700.0
@export var impulso_hacia_arriba : float = 300.0  # sale un poco hacia arriba
@export var gravedad_al_lanzar : float = 1600.0   # cuánto se curva la trayectoria

@export_group("Golpe")
@export var tiempo_que_se_queda_clavada : float = 0.3
@export var dano : int = 1

@export_group("Recoger")
@export var distancia_para_recoger : float = 40.0
@export var distancia_minima_del_punto : float = 250.0

@export_group("Salir volando")
@export var duracion_del_arco : float = 0.7
@export var altura_del_arco : float = 200.0
@export var vueltas : float = 1.0            # cuántas vueltas da en el aire
@export var duracion_colocarse : float = 0.2 # el "se coloca" del final

# El PlayerThrowAttack se asigna solo aquí al crear la lanza
var mano : Node2D = null

var estado : Estado = Estado.EN_MANO
var velocidad : Vector2 = Vector2.ZERO
var enemigo_clavado : Node2D = null
var contador_clavada : float = 0.0

# Puntos del arco por el que vuela al salir despedida
var punto_inicio : Vector2 = Vector2.ZERO
var punto_final : Vector2 = Vector2.ZERO
var tween_vuelo : Tween = null


func _physics_process(delta: float) -> void:
	# Sin mano no hay nada que hacer (la crea el PlayerThrowAttack)
	if mano == null:
		return

	# match es como un if/elif pero más limpio con enums
	match estado:

		Estado.EN_MANO:
			# La lanza se pega a la mano del jugador
			global_position = mano.global_position
			rotation = 0.0 if mano.mirando > 0 else PI

		Estado.VOLANDO:
			# La gravedad la va curvando hacia abajo
			velocidad.y += gravedad_al_lanzar * delta
			global_position += velocidad * delta
			# La punta siempre mira hacia donde va, así entra de punta al caer
			rotation = velocidad.angle()

		Estado.CLAVADA:
			# Se queda pegada al enemigo un momento
			if enemigo_clavado != null and is_instance_valid(enemigo_clavado):
				global_position = enemigo_clavado.global_position
			contador_clavada -= delta
			if contador_clavada <= 0:
				salir_volando()

		Estado.SALIENDO:
			pass  # de esto se encarga el Tween

		Estado.EN_SUELO:
			# Si el jugador se acerca lo suficiente, la recoge
			if global_position.distance_to(mano.global_position) < distancia_para_recoger:
				estado = Estado.EN_MANO


# El PlayerThrowAttack llama a esta función al pulsar el botón
func lanzar(direccion: Vector2) -> void:
	velocidad = direccion.normalized() * velocidad_lanzamiento
	velocidad.y -= impulso_hacia_arriba   # en Godot, -y es hacia arriba
	rotation = velocidad.angle()
	estado = Estado.VOLANDO


# Se ejecuta cuando la lanza toca algo (señal body_entered)
func _on_body_entered(body: Node2D) -> void:
	# Solo nos importa si está volando
	if estado != Estado.VOLANDO:
		return

	# Nunca clavarse en el propio jugador
	if mano != null and body == mano.get_parent():
		return

	# "Es un enemigo" = tiene un HealthComponent, igual que en tu HitboxComponent
	var health_component = body.get_node_or_null("HealthComponent")

	if health_component:
		health_component.take_damage(dano)
		enemigo_clavado = body
		contador_clavada = tiempo_que_se_queda_clavada
		estado = Estado.CLAVADA
	else:
		# Ha chocado con una pared o el suelo: se queda clavada
		# en el ángulo con el que llegó, como una lanza de verdad
		velocidad = Vector2.ZERO
		estado = Estado.EN_SUELO


# ---------------------------------------------------------------
#  Salir volando hacia el punto aleatorio (con Tween)
# ---------------------------------------------------------------

func salir_volando() -> void:
	enemigo_clavado = null
	punto_inicio = global_position
	punto_final = elegir_punto_aleatorio()
	estado = Estado.SALIENDO

	# Dejamos la rotación entre 0 y una vuelta, así el giro
	# siempre dura lo mismo salgas del ángulo que salgas
	rotation = fposmod(rotation, TAU)   # TAU = una vuelta entera = 2 * PI

	var rotacion_girando = rotation + TAU * vueltas  # las vueltas en el aire
	var rotacion_final = TAU * (vueltas + 1.0)       # múltiplo de vuelta = queda recta

	# Si había un Tween a medias lo cancelamos
	if tween_vuelo != null and tween_vuelo.is_valid():
		tween_vuelo.kill()

	tween_vuelo = create_tween()

	# 1) El Tween mueve un número de 0 a 1 y nosotros calculamos la curva
	tween_vuelo.tween_method(_mover_por_el_arco, 0.0, 1.0, duracion_del_arco)

	# 2) parallel() = esto pasa A LA VEZ que lo de arriba: da la vuelta en el aire
	tween_vuelo.parallel().tween_property(self, "rotation", rotacion_girando, duracion_del_arco)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3) Al llegar al suelo se coloca recta con un pequeño rebote
	tween_vuelo.tween_property(self, "rotation", rotacion_final, duracion_colocarse)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 4) Y cuando termina todo, cambiamos de estado
	tween_vuelo.tween_callback(_al_aterrizar)


# El Tween llama a esta función con t de 0 a 1
func _mover_por_el_arco(t: float) -> void:
	# Punto de en medio, elevado, para que haga curva hacia arriba
	var medio = (punto_inicio + punto_final) / 2
	medio.y -= altura_del_arco

	# Curva suave entre los tres puntos
	var a = punto_inicio.lerp(medio, t)
	var b = medio.lerp(punto_final, t)
	global_position = a.lerp(b, t)


func _al_aterrizar() -> void:
	rotation = 0.0
	estado = Estado.EN_SUELO


func elegir_punto_aleatorio() -> Vector2:
	var puntos = get_tree().get_nodes_in_group("spear_points")

	# Si no hay ningún punto colocado en el nivel, se queda donde está
	if puntos.size() == 0:
		push_warning("No hay nodos en el grupo 'spear_points'")
		return global_position

	var buenos = []

	# Nos quedamos solo con los puntos lejos del jugador,
	# para obligarle a moverse
	for p in puntos:
		if p.global_position.distance_to(mano.global_position) > distancia_minima_del_punto:
			buenos.append(p)

	# Si ninguno está lejos, valen todos
	if buenos.size() == 0:
		buenos = puntos

	var elegido = buenos[randi() % buenos.size()]
	return elegido.global_position
