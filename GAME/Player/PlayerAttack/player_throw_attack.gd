##
##	Summary:
##	Componente de ataque a distancia del jugador.
##	Va como HIJO del Player, colocado donde quieres que se vea la lanza.
##	Él solo crea la lanza al empezar la partida y la lanza al pulsar el botón.
##

extends Node2D
class_name PlayerThrowAttack

@export var spear_scene : PackedScene          # arrastra aquí spear.tscn
@export var accion_lanzar : String = "Lanzar"  # nombre de la acción en el Input Map

var lanza : Node2D = null
var mirando : float = 1.0     # 1 = derecha, -1 = izquierda
var offset_mano : float = 0.0 # a qué distancia del centro está la mano


func _ready() -> void:
	# Guardamos la posición original de la mano para poder voltearla
	offset_mano = absf(position.x)

	if spear_scene == null:
		push_error("PlayerThrowAttack: falta asignar spear_scene en el Inspector")
		return

	# Creamos la lanza y le decimos quién es su mano
	lanza = spear_scene.instantiate()
	add_child(lanza)
	lanza.top_level = true            # importante: así NO se mueve con el jugador
	lanza.global_position = global_position
	lanza.mano = self


func _physics_process(_delta: float) -> void:
	actualizar_direccion()

	# La mano se coloca delante del jugador según hacia dónde mire
	position.x = offset_mano * mirando

	if Input.is_action_just_pressed(accion_lanzar) and puede_lanzar():
		lanza.lanzar(Vector2(mirando, 0))


# Mira hacia dónde se está moviendo el cuerpo del jugador
func actualizar_direccion() -> void:
	var cuerpo = get_parent()
	if cuerpo is CharacterBody2D and not is_zero_approx(cuerpo.velocity.x):
		mirando = signf(cuerpo.velocity.x)


# Solo se puede lanzar si la lanza está en la mano
func puede_lanzar() -> bool:
	return lanza != null and lanza.estado == lanza.Estado.EN_MANO
