##
##	Summary:
##	Un punto del raíl de la cámara: una posición y un FOV.
##	No es un nodo, es un recurso: se rellenan desde la lista
##	"puntos" del CameraDolly, en su Inspector.
##

extends Resource
class_name DollyPoint

# Posición LOCAL respecto al CameraDolly. Así puedes mover el dolly
# entero por el nivel y el raíl se va con él
@export var posicion : Vector2 = Vector2.ZERO

# Cuánto se ve desde aquí. 1 = lo normal, 2 = el doble de campo
# (más lejos), 0.5 = la mitad (más cerca). Es el inverso del zoom
# de Camera2D, que se calcula solo
@export var fov : float = 1.0
