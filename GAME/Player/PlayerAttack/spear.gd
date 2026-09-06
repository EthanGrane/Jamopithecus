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

@export_group("En la mano")
@export var offset_en_mano : Vector2 = Vector2.ZERO  # desplazamiento respecto a la mano
@export_range(-180.0, 180.0) var angulo_en_mano : float = 0.0  # en grados
@export var balanceo_amplitud : float = 2.0   # flotación suave, 0 para quitarla
@export var balanceo_velocidad : float = 2.0

@export_group("Golpe")
@export var tiempo_que_se_queda_clavada : float = 0.3
@export var dano : int = 1
# Contra qué capas choca la lanza. Por defecto la 1, que es donde
# están tus bosses y el escenario
@export_flags_2d_physics var capas_de_impacto : int = 1
@export var largo_de_la_punta : float = 26.0   # desde el centro hasta la punta
@export var radio_de_impacto : float = 10.0    # grosor de la punta al comprobar
@export var depurar : bool = false             # imprime cada choque por consola

@export_group("Rescate")
# Si lleva este rato volando sin tocar nada, se la considera perdida
# (lanzada fuera del mapa) y se va sola a uno de los spear_points
@export var tiempo_maximo_en_el_aire : float = 3.0

# Clavada en el escenario y sin recoger: al cabo de este rato tiembla
# y se va sola a un spear_point. No cuenta si ya está en uno
@export var tiempo_en_el_suelo : float = 5.0
@export var duracion_del_temblor : float = 0.6
@export var amplitud_del_temblor : float = 3.0
@export var velocidad_del_temblor : float = 40.0

@export_group("Recoger")
@export var distancia_para_recoger : float = 40.0
@export var distancia_minima_del_punto : float = 250.0

@export_group("Salir volando")
@export var duracion_del_arco : float = 0.7
@export var altura_del_arco : float = 200.0
@export var vueltas : float = 1.0            # cuántas vueltas da en el aire
@export var duracion_colocarse : float = 0.2 # el "se coloca" del final

@export_group("Sonidos")
@export var sonido_lanzar : AudioStream = preload("res://GAME/SFX/SpearThrowWoosh.wav")
@export var sonido_superficie : AudioStream = preload("res://GAME/SFX/HitSurface.wav")
@export var sonido_recoger : AudioStream = preload("res://GAME/SFX/Pickup_Spear.wav")
@export_range(-40.0, 12.0) var volumen_lanzar : float = 0.0
@export_range(-40.0, 12.0) var volumen_superficie : float = 0.0
@export_range(-40.0, 12.0) var volumen_recoger : float = 0.0
@export var tono_min : float = 0.94   # variación de tono para que no suene a copia
@export var tono_max : float = 1.06

# El PlayerThrowAttack se asigna solo aquí al crear la lanza
var mano : Node2D = null

var estado : Estado = Estado.EN_MANO
var velocidad : Vector2 = Vector2.ZERO
var enemigo_clavado : Node2D = null
var contador_clavada : float = 0.0
var contador_de_vuelo : float = 0.0
var tiempo_en_mano : float = 0.0   # solo para el balanceo

# Puntos del arco por el que vuela al salir despedida
var punto_inicio : Vector2 = Vector2.ZERO
var punto_final : Vector2 = Vector2.ZERO
var tween_vuelo : Tween = null
var forma_de_impacto : CircleShape2D = null

var contador_en_suelo : float = 0.0
var fase_temblor : float = 0.0
var en_un_marker : bool = false   # si ya está en un spear_point, no se mueve

@onready var sprite : Sprite2D = $Sprite2D


func _ready() -> void:
	# El círculo que barremos por delante de la punta en cada frame
	forma_de_impacto = CircleShape2D.new()
	forma_de_impacto.radius = radio_de_impacto


func _physics_process(delta: float) -> void:
	# Sin mano no hay nada que hacer (la crea el PlayerThrowAttack)
	if mano == null:
		return

	# match es como un if/elif pero más limpio con enums
	match estado:

		Estado.EN_MANO:
			estar_en_la_mano(delta)

		Estado.VOLANDO:
			# Red de seguridad: si lleva demasiado volando es que se ha
			# ido del mapa y nunca va a chocar con nada
			contador_de_vuelo += delta
			if contador_de_vuelo >= tiempo_maximo_en_el_aire:
				rescatar()
				return

			var antes := punta()

			# La gravedad la va curvando hacia abajo
			velocidad.y += gravedad_al_lanzar * delta
			global_position += velocidad * delta
			# La punta siempre mira hacia donde va, así entra de punta al caer
			rotation = velocidad.angle()

			# Comprobamos TODO el tramo recorrido este frame, no solo
			# dónde ha acabado. Es lo que evita que atraviese cosas
			comprobar_impacto(antes, punta())

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
				recoger()
			elif not en_un_marker:
				# Clavada en el escenario: si nadie la recoge, se va sola
				esperar_en_el_suelo(delta)


func recoger() -> void:
	sprite.position = Vector2.ZERO   # por si estaba temblando
	estado = Estado.EN_MANO
	GameFeel.sonar(sonido_recoger, global_position, volumen_recoger, tono_min, tono_max)


# Cuenta atrás mientras está clavada en el escenario, con un temblor
# al final para avisar de que se va a mover
func esperar_en_el_suelo(delta: float) -> void:
	contador_en_suelo += delta

	# Fase 1: quieta, esperando a que la recojas
	if contador_en_suelo < tiempo_en_el_suelo:
		return

	# Fase 2: tiembla, cada vez un poco más
	var t := contador_en_suelo - tiempo_en_el_suelo
	var intensidad := 0.3 + (t / duracion_del_temblor) * 0.7

	fase_temblor += delta * velocidad_del_temblor

	# En el eje Y local, que es perpendicular al asta:
	# así vibra de lado y no se hunde en la pared
	sprite.position = Vector2(0.0, sin(fase_temblor) * amplitud_del_temblor * intensidad)

	if t >= duracion_del_temblor:
		sprite.position = Vector2.ZERO
		salir_volando()


# Estado de reposo: la lanza sujeta, esperando a que la lancen
func estar_en_la_mano(delta: float) -> void:
	tiempo_en_mano += delta

	# 1 mirando a la derecha, -1 a la izquierda
	var lado := 1.0 if mano.mirando > 0 else -1.0

	# El offset se voltea con el jugador
	var offset := offset_en_mano
	offset.x *= lado

	# Flotación suave para que no se vea completamente muerta
	offset.y += sin(tiempo_en_mano * balanceo_velocidad) * balanceo_amplitud

	global_position = mano.global_position + offset

	# El ángulo también se refleja: PI - angulo es su espejo
	var angulo := deg_to_rad(angulo_en_mano)
	rotation = angulo if lado > 0 else PI - angulo


# El PlayerThrowAttack llama a esta función al pulsar el botón
func lanzar(direccion: Vector2) -> void:
	velocidad = direccion.normalized() * velocidad_lanzamiento
	velocidad.y -= impulso_hacia_arriba   # en Godot, -y es hacia arriba
	rotation = velocidad.angle()
	estado = Estado.VOLANDO
	contador_de_vuelo = 0.0

	GameFeel.sonar(sonido_lanzar, global_position, volumen_lanzar, tono_min, tono_max)


# Dónde está la punta ahora mismo, en coordenadas del mundo
func punta() -> Vector2:
	return global_position + Vector2(largo_de_la_punta, 0.0).rotated(rotation)


# Barre un círculo por todo el tramo que la punta ha recorrido este frame.
# Un rayo es una línea infinitamente fina y el enemigo puede pasar rozando
# por al lado; un círculo barrido cubre el volumen entero del recorrido
func comprobar_impacto(desde: Vector2, hasta: Vector2) -> void:
	var movimiento := hasta - desde
	if movimiento.is_zero_approx():
		return

	var espacio := get_world_2d().direct_space_state

	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma_de_impacto
	consulta.transform = Transform2D(0.0, desde)
	consulta.motion = movimiento
	consulta.collision_mask = capas_de_impacto
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false

	# El propio jugador nunca cuenta
	if mano != null and mano.get_parent() is CollisionObject2D:
		consulta.exclude = [mano.get_parent().get_rid()]

	# Devuelve [hasta dónde puede llegar sin chocar, dónde ya está chocando]
	var tramo := espacio.cast_motion(consulta)
	if tramo.size() < 2 or tramo[0] >= 1.0:
		return   # el camino está libre

	# Nos colocamos en el punto de contacto y preguntamos con quién
	consulta.transform = Transform2D(0.0, desde + movimiento * tramo[1])
	consulta.motion = Vector2.ZERO
	var golpes := espacio.intersect_shape(consulta, 1)
	if golpes.is_empty():
		return

	# La clavamos justo donde ha tocado, no donde había llegado de más
	var contacto := desde + movimiento * tramo[0]
	global_position = contacto - Vector2(largo_de_la_punta, 0.0).rotated(rotation)

	procesar_choque(golpes[0].collider)


# La señal body_entered sigue conectada como red de seguridad:
# si el rayo falla por lo que sea, esto lo pilla igual
func _on_body_entered(body: Node2D) -> void:
	procesar_choque(body)


func procesar_choque(body: Node2D) -> void:
	# Solo nos importa si está volando
	if estado != Estado.VOLANDO or body == null:
		return

	# Nunca clavarse en el propio jugador
	if mano != null and body == mano.get_parent():
		return

	if depurar:
		print("[lanza] choca con ", body.name, " (capa ", body.collision_layer, ")")

	# "Es un enemigo" = tiene un HealthComponent, igual que en tu HitboxComponent
	var health_component = body.get_node_or_null("HealthComponent")

	# Si es invulnerable, la lanza lo atraviesa en vez de clavarse.
	# Si no, se quedaría enganchada al boss mientras se hunde
	if health_component and not health_component.invulnerable:
		health_component.take_damage(dano)
		enemigo_clavado = body
		contador_clavada = tiempo_que_se_queda_clavada
		estado = Estado.CLAVADA
	else:
		# Ha chocado con una pared o el suelo: se queda clavada
		# en el ángulo con el que llegó, como una lanza de verdad
		velocidad = Vector2.ZERO
		estado = Estado.EN_SUELO
		en_un_marker = false        # está en el escenario: empieza la cuenta atrás
		contador_en_suelo = 0.0
		fase_temblor = 0.0
		sonar_superficie()


# ---------------------------------------------------------------
#  Salir volando hacia el punto aleatorio (con Tween)
# ---------------------------------------------------------------

# La lanza se ha ido del mapa o a un sitio donde nunca va a chocar.
# La recuperamos con el mismo vuelo en arco que cuando sale despedida
# de un enemigo, así el jugador ve a dónde ha ido
func rescatar() -> void:
	if depurar:
		print("[lanza] perdida tras ", tiempo_maximo_en_el_aire, "s en el aire, la rescato")

	velocidad = Vector2.ZERO
	salir_volando()


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
	# Ya está en un spear_point: aquí se queda hasta que la recojas.
	# Si no, iría saltando de marcador en marcador para siempre
	en_un_marker = true
	sonar_superficie()


# Suena cuando la lanza se clava en algo que no es un enemigo
func sonar_superficie() -> void:
	GameFeel.sonar(sonido_superficie, global_position, volumen_superficie, tono_min, tono_max)


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
