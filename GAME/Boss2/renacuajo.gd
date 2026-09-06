##
##	Summary:
##	Boss2, el renacuajo. Ataca como el Ojo de Cthulhu de Terraria:
##
##		EMERGIENDO  sale del agua de un salto corto
##		APUNTANDO   se queda fijándote  ← el aviso
##		EMBISTE     se lanza a por ti en línea recta y no para
##		            hasta salirse de la pantalla
##
##	Tocarlo mata: hay que esquivar dasheando, que te vuelve inmune.
##	Atraviesa el escenario, así que no puedes refugiarte detrás de
##	nada: solo puedes quitarte de en medio.
##
##	El director (boss_2_fight.gd) le dice cuándo salir.
##

extends CharacterBody2D
class_name Boss2

signal ataque_terminado

enum Estado {
	BAJO_EL_AGUA,   # escondido, invulnerable
	EMERGIENDO,     # saliendo del agua
	APUNTANDO,      # quieto, fijándote: el aviso antes del embiste
	EMBISTE,        # a por ti, hasta salirse de la pantalla
	ESTAMPADO,      # solo si atraviesa_el_escenario está desmarcado
}

@export_group("Salida del agua")
@export var altura_de_salida : float = 260.0
@export var duracion_de_salida : float = 0.45

@export_group("Embiste")
@export var tiempo_apuntando : float = 0.5      # el aviso, te da tiempo a colocarte
@export var velocidad_del_embiste : float = 1200.0
@export var giro_al_embestir : float = 14.0     # vueltas del sprite mientras carga
# Si está marcado atraviesa paredes y se va de pantalla, como el
# Ojo de Cthulhu. Desmárcalo y podrá estamparse contra el escenario
@export var atraviesa_el_escenario : bool = true
@export var margen_fuera_de_pantalla : float = 250.0
@export var tiempo_maximo_embistiendo : float = 5.0   # red de seguridad

@export_group("Estampado")
@export var tiempo_estampado : float = 2.5
@export var rebote_al_estamparse : float = 260.0

var estado : Estado = Estado.BAJO_EL_AGUA
var salud : HealthComponent = null

var punto_de_salida : Vector2 = Vector2.ZERO
var punto_alto : Vector2 = Vector2.ZERO
var avance : float = 0.0
var contador : float = 0.0
var direccion_embiste : Vector2 = Vector2.RIGHT

var capa_original : int = 1
var mascara_original : int = 1

@onready var sprite : Sprite2D = $Sprite2D
@onready var reaccion : HitReactionComponent = $HitReactionComponent
@onready var contacto : CollisionShape2D = $Contacto/CollisionShape2D


func _ready() -> void:
	capa_original = collision_layer
	mascara_original = collision_mask if collision_mask != 0 else 1

	# Para que la campana lo encuentre sin conocerlo
	add_to_group("aturdible_por_sonido")

	salud = get_node_or_null("HealthComponent")
	volver_al_agua()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.EMERGIENDO:
			emerger(delta)
		Estado.APUNTANDO:
			apuntar(delta)
		Estado.EMBISTE:
			embestir(delta)
		Estado.ESTAMPADO:
			estar_estampado(delta)


# ---------------------------------------------------------------
#  1. Salir del agua
# ---------------------------------------------------------------

# La llama el director cuando arrancan los géiseres
func embestir_desde(punto: Vector2) -> void:
	punto_de_salida = punto
	punto_alto = punto + Vector2(0.0, -altura_de_salida)
	avance = 0.0

	estado = Estado.EMERGIENDO
	visible = true
	global_position = punto
	rotation = 0.0

	poner_capa(true)
	poner_contacto(true)

	# Volando no choca con nada: solo tiene que poder tocarte a ti
	set_deferred("collision_mask", 0)

	if salud != null:
		salud.invulnerable = true


func emerger(delta: float) -> void:
	avance = minf(avance + delta / maxf(duracion_de_salida, 0.05), 1.0)

	# Sale rápido y frena arriba, como un pez que asoma
	var suavizado := 1.0 - pow(1.0 - avance, 3.0)
	var destino := punto_de_salida.lerp(punto_alto, suavizado)

	# Se mueve con el motor, no teletransportando: si no, la lanza
	# y el jugador no detectarían el contacto
	velocity = (destino - global_position) / delta
	move_and_slide()

	if avance >= 1.0:
		empezar_a_apuntar()


# ---------------------------------------------------------------
#  2. Apuntar
# ---------------------------------------------------------------

func empezar_a_apuntar() -> void:
	estado = Estado.APUNTANDO
	contador = tiempo_apuntando
	velocity = Vector2.ZERO


func apuntar(delta: float) -> void:
	velocity = Vector2.ZERO

	# Te sigue apuntando hasta el último instante: ves de dónde
	# viene y decides cuándo esquivar
	var jugador := buscar_jugador()
	if jugador != null:
		direccion_embiste = (jugador.global_position - global_position).normalized()
		rotation = direccion_embiste.angle()

	contador -= delta
	if contador <= 0.0:
		lanzarse()


# ---------------------------------------------------------------
#  3. Embestir hasta salir de pantalla
# ---------------------------------------------------------------

func lanzarse() -> void:
	estado = Estado.EMBISTE
	contador = tiempo_maximo_embistiendo

	if not atraviesa_el_escenario:
		set_deferred("collision_mask", mascara_original)


func embestir(delta: float) -> void:
	velocity = direccion_embiste * velocidad_del_embiste
	move_and_slide()

	sprite.rotation += giro_al_embestir * delta

	# Si puede chocar y ha chocado, se estampa
	if not atraviesa_el_escenario and get_slide_collision_count() > 0:
		estamparse()
		return

	# No frena ni gira: sigue recto hasta perderse de vista
	if fuera_de_pantalla() or contador <= 0.0:
		volver_al_agua()

	contador -= delta


# En coordenadas de pantalla, así funciona con la cámara donde esté
func fuera_de_pantalla() -> bool:
	var pantalla := get_viewport_rect().size
	var pos := get_global_transform_with_canvas().origin

	return pos.x < -margen_fuera_de_pantalla \
			or pos.y < -margen_fuera_de_pantalla \
			or pos.x > pantalla.x + margen_fuera_de_pantalla \
			or pos.y > pantalla.y + margen_fuera_de_pantalla


# ---------------------------------------------------------------
#  Estampado (solo si no atraviesa el escenario)
# ---------------------------------------------------------------

func estamparse() -> void:
	caer_aturdido()
	velocity = -direccion_embiste * rebote_al_estamparse


# La llama la campana cuando su onda le alcanza. Solo funciona si
# está fuera del agua: si está sumergido, el campanazo se pierde
func aturdir_por_sonido() -> bool:
	if estado == Estado.BAJO_EL_AGUA or estado == Estado.ESTAMPADO:
		return false

	caer_aturdido()
	return true


func caer_aturdido() -> void:
	estado = Estado.ESTAMPADO
	contador = tiempo_estampado
	velocity = Vector2.ZERO

	# Le devolvemos las colisiones para que el suelo lo pare.
	# Volando las tenía a cero y se hundiría por el escenario
	set_deferred("collision_mask", mascara_original)

	poner_contacto(false)   # aturdido ya no mata al tocarlo

	if salud != null:
		salud.invulnerable = false   # AHORA sí se le puede dar

	reaccion.reaccionar()


func estar_estampado(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	velocity.y = minf(velocity.y + 1400.0 * delta, 900.0)
	move_and_slide()

	contador -= delta
	if contador <= 0.0:
		volver_al_agua()


# La llama el HealthComponent al recibir un golpe
func change_state() -> void:
	if estado != Estado.ESTAMPADO:
		return

	reaccion.reaccionar()
	volver_al_agua()


# ---------------------------------------------------------------

func volver_al_agua() -> void:
	estado = Estado.BAJO_EL_AGUA
	visible = false
	rotation = 0.0
	velocity = Vector2.ZERO

	if sprite != null:
		sprite.rotation = 0.0

	reaccion.restablecer()
	poner_capa(false)
	poner_contacto(false)

	if salud != null:
		salud.invulnerable = true

	ataque_terminado.emit()


# La capa es "quién puede verme": a cero, ni la lanza ni el jugador
func poner_capa(activa: bool) -> void:
	set_deferred("collision_layer", capa_original if activa else 0)


# El área que mata al tocarla
func poner_contacto(activo: bool) -> void:
	contacto.set_deferred("disabled", not activo)


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
