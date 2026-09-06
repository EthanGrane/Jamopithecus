##
##	Summary:
##	La campana de la sala. Le clavas la lanza y suena: sale una onda
##	de choque que se expande y aturde a lo que pille por el camino.
##
##	No hace daño. Lo único que hace es tumbar al renacuajo si está
##	fuera del agua cuando la onda le alcanza. Si está sumergido,
##	el campanazo se pierde y te has quedado sin lanza para nada.
##
##	Cualquier cosa que quiera reaccionar a la onda solo tiene que
##	estar en el grupo "aturdible_por_sonido" y tener el método
##	aturdir_por_sonido().
##

extends StaticBody2D
class_name Campana

signal tocada

@export var sonido : AudioStream
@export_range(-40.0, 12.0) var volumen : float = 0.0

@export_group("Onda")
@export var radio : float = 900.0            # hasta dónde llega
@export var duracion : float = 0.6           # lo que tarda en llegar al borde
@export var fuerza : float = 34.0            # deformación de la onda
@export var sacudida : float = 10.0

@export_group("Campana")
@export var cooldown : float = 1.0           # para que no se pueda spamear
@export var escala_del_golpe : Vector2 = Vector2(1.2, 0.82)
@export var duracion_del_golpe : float = 0.35

@onready var sprite : Sprite2D = $Sprite2D

var contador : float = 0.0
var escala_base : Vector2 = Vector2.ONE


func _ready() -> void:
	escala_base = sprite.scale


func _process(delta: float) -> void:
	contador -= delta


# La llama la lanza al clavarse. Devolver true/false permite que
# quien la golpee sepa si ha servido de algo
func golpear() -> bool:
	if contador > 0.0:
		return false

	contador = cooldown
	tocar()
	return true


func tocar() -> void:
	GameFeel.sonar(sonido, global_position, volumen)
	GameFeel.sacudir(sacudida, 0.3)

	balancearse()

	# La onda se crea en la escena para que siga existiendo
	# aunque la campana desaparezca.
	Shockwave.crear(get_tree().current_scene, global_position, radio, fuerza, duracion)

	propagar()
	tocada.emit()

	caerse()


func caerse() -> void:
	# La campana cae 1000 unidades hacia abajo.
	var tw := create_tween()

	tw.tween_property(
		self,
		"global_position:y",
		global_position.y + 1000.0,
		0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Cuando termina la caída, desaparece.
	tw.tween_callback(queue_free)


func balancearse() -> void:
	sprite.scale = escala_base * escala_del_golpe

	var tw := create_tween()
	tw.tween_property(sprite, "scale", escala_base, duracion_del_golpe)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------

# El aturdimiento no es instantáneo: llega cuando la onda llega.
# Los que estén lejos caen más tarde, y eso se ve
func propagar() -> void:
	for nodo in get_tree().get_nodes_in_group("aturdible_por_sonido"):
		if not is_instance_valid(nodo):
			continue

		var distancia := global_position.distance_to(nodo.global_position)
		if distancia > radio:
			continue

		aturdir_cuando_llegue(nodo, (distancia / radio) * duracion)


func aturdir_cuando_llegue(nodo: Node, retardo: float) -> void:
	if retardo > 0.0:
		await get_tree().create_timer(retardo).timeout

	if is_instance_valid(nodo) and nodo.has_method("aturdir_por_sonido"):
		nodo.aturdir_por_sonido()
