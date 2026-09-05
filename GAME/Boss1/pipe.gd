##
##	Summary:
##	Una tubería por la que el boss entra y sale.
##	Se registra sola en el grupo "pipes", así que el boss NO necesita
##	ninguna lista: puedes añadir o quitar tuberías sin tocar código.
##
##	La dirección hacia la que escupe al boss la manda la escala en X
##	del nodo: 1 = derecha, -1 = izquierda.
##

extends StaticBody2D
class_name Pipe

# Desplazamiento de la boca respecto a donde esté puesta en la escena.
# Sirve para ajustar una instancia concreta sin activar "hijos editables"
@export var area_position : Vector2 = Vector2.ZERO

# Marca esto si una tubería escupe hacia el lado contrario del que debería
@export var invertir_direccion : bool = false

@onready var boca : CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	add_to_group("pipes")
	boca.position += area_position


# 1 hacia la derecha, -1 hacia la izquierda
func direccion_salida() -> float:
	var dir := signf(global_scale.x)
	if dir == 0.0:
		dir = 1.0
	return -dir if invertir_direccion else dir


# Dónde aparece el boss al salir por aquí
func punto_de_salida() -> Vector2:
	return boca.global_position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Boss1:
		body.entrar_en_tuberia(self)
