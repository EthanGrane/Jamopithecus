##
##	Summary:
##	Boss2, el renacuajo. No decide nada por su cuenta: el director
##	(boss_2_fight.gd) le dice cuándo saltar y él salta.
##
##	Solo es vulnerable mientras está en el aire. Si le aciertas,
##	se corta el arco y se cae al agua.
##

# CharacterBody2D movido con move_and_slide(), igual que el Boss1.
# Teletransportarlo con global_position movía el sprite pero el motor
# de físicas no generaba los eventos de las Area2D, y la lanza lo
# atravesaba aunque las formas se solaparan en pantalla.
extends CharacterBody2D
class_name Boss2

signal salto_terminado

enum Estado {
	BAJO_EL_AGUA,   # escondido, invulnerable
	SALTANDO,       # en el aire: la ventana para atacarle
	CAYENDO,        # le han dado, se hunde
}

@export_group("Salto")
@export var girar_con_el_arco : bool = true   # el sprite apunta hacia donde va

@export_group("Caída")
@export var velocidad_de_caida : float = 900.0
@export var giro_al_caer : float = 6.0

var estado : Estado = Estado.BAJO_EL_AGUA
var salud : HealthComponent = null

var punto_inicio : Vector2 = Vector2.ZERO
var punto_fin : Vector2 = Vector2.ZERO
var altura : float = 300.0
var duracion : float = 1.6
var y_del_agua : float = 0.0
var avance : float = 0.0      # 0 a 1 dentro del arco
var capa_original : int = 1

@onready var sprite : Sprite2D = $Sprite2D
@onready var reaccion : HitReactionComponent = $HitReactionComponent


func _ready() -> void:
	capa_original = collision_layer

	# No choca contra nada: vuela por el aire y solo necesita
	# que la lanza pueda detectarlo
	collision_mask = 0

	salud = get_node_or_null("HealthComponent")
	esconderse()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.SALTANDO:
			avanzar_por_el_arco(delta)
		Estado.CAYENDO:
			caer_al_agua(delta)


# ---------------------------------------------------------------
#  Salto
# ---------------------------------------------------------------

# La llama el director. desde/hasta son los dos Marker2D del arco
func saltar(desde: Vector2, hasta: Vector2, altura_del_arco: float, dur: float) -> void:
	punto_inicio = desde
	punto_fin = hasta
	altura = altura_del_arco
	duracion = maxf(dur, 0.05)
	# El más bajo de los dos extremos: así vale igual en A→B que en B→A
	# aunque los marcadores no estén exactamente a la misma altura
	y_del_agua = maxf(desde.y, hasta.y)
	avance = 0.0

	estado = Estado.SALTANDO
	visible = true
	poner_colisiones(true)

	if salud != null:
		salud.invulnerable = false   # solo se le puede dar en el aire

	global_position = desde


func avanzar_por_el_arco(delta: float) -> void:
	avance = minf(avance + delta / duracion, 1.0)
	var destino := punto_del_arco(avance)

	# La clave: en vez de saltar a la posición, calculamos la velocidad
	# que hace falta para llegar y dejamos que la mueva el motor.
	# Así el motor sabe que se ha movido y avisa a las Area2D
	velocity = (destino - global_position) / delta
	move_and_slide()

	# Se orienta hacia donde va, como un pez saltando
	if girar_con_el_arco and velocity.length() > 1.0:
		rotation = velocity.angle()

	if avance >= 1.0:
		terminar_salto()


# Curva de tres puntos: salida, un punto alto en medio, y entrada
func punto_del_arco(t: float) -> Vector2:
	var medio := (punto_inicio + punto_fin) * 0.5
	medio.y -= altura
	return punto_inicio.lerp(medio, t).lerp(medio.lerp(punto_fin, t), t)


func terminar_salto() -> void:
	esconderse()
	salto_terminado.emit()


# ---------------------------------------------------------------
#  Le han dado
# ---------------------------------------------------------------

# La llama el HealthComponent. Mismo nombre que en el Boss1
func change_state() -> void:
	# Solo cuenta si estaba en el aire
	if estado != Estado.SALTANDO:
		return
	caer()


func caer() -> void:
	estado = Estado.CAYENDO

	if salud != null:
		salud.invulnerable = true   # no se le puede rematar mientras cae

	# Sonido, destello, punch, onda, hitstop y sacudida, todo de golpe
	reaccion.reaccionar()


func caer_al_agua(delta: float) -> void:
	velocity = Vector2(0.0, velocidad_de_caida)
	move_and_slide()
	rotation += giro_al_caer * delta

	if global_position.y >= y_del_agua:
		terminar_salto()


# ---------------------------------------------------------------

func esconderse() -> void:
	estado = Estado.BAJO_EL_AGUA
	visible = false
	rotation = 0.0
	velocity = Vector2.ZERO
	reaccion.restablecer()   # por si se escondió a mitad del punch o del destello
	poner_colisiones(false)

	if salud != null:
		salud.invulnerable = true


# Se quita la capa y no la máscara, igual que en el Boss1:
# deja de existir para la lanza y para el jugador
func poner_colisiones(activas: bool) -> void:
	set_deferred("collision_layer", capa_original if activas else 0)
