##
##	Summary:
##	Sube y baja el nivel del agua.
##
##	Dos cosas distintas y compatibles:
##	  - la MAREA: un vaivén suave y constante, decorativo
##	  - el NIVEL: subirla o bajarla a propósito desde un script,
##	    por ejemplo para una fase de un boss
##
##	La marea oscila alrededor del nivel actual, así que puedes
##	cambiar el nivel sin que el vaivén se entere.
##

extends ColorRect
class_name Agua

@export_group("Marea")
@export var marea_activa : bool = true
@export var amplitud : float = 20.0            # píxeles que sube y baja
@export var duracion_del_ciclo : float = 8.0   # segundos del ciclo completo
@export_range(0.0, 1.0) var desfase : float = 0.0  # para que dos aguas no vayan iguales

@export_group("Forma")
# Si está marcado, al subir el agua crece hacia arriba y el fondo
# se queda donde está. Si no, se mueve el rectángulo entero
@export var fondo_fijo : bool = true

var y_inicial : float = 0.0
var alto_inicial : float = 0.0
var nivel : float = 0.0        # desplazamiento respecto al inicio, negativo = arriba
var tiempo : float = 0.0


func _ready() -> void:
	y_inicial = position.y
	alto_inicial = size.y
	tiempo = desfase * duracion_del_ciclo


func _process(delta: float) -> void:
	var vaiven := 0.0

	if marea_activa:
		tiempo += delta
		vaiven = sin(tiempo / maxf(duracion_del_ciclo, 0.01) * TAU) * amplitud

	aplicar(nivel + vaiven)


# En Godot -Y es arriba, así que un desplazamiento negativo sube el agua
func aplicar(desplazamiento: float) -> void:
	position.y = y_inicial + desplazamiento

	if fondo_fijo:
		# El fondo se queda quieto: el agua crece o mengua por arriba
		size.y = maxf(alto_inicial - desplazamiento, 1.0)


# ---------------------------------------------------------------
#  API para los scripts
# ---------------------------------------------------------------

# Cambia el nivel poco a poco. Negativo sube, positivo baja.
#   $Agua.cambiar_nivel(-150.0, 3.0)   # sube 150px en 3 segundos
func cambiar_nivel(desplazamiento: float, duracion: float = 2.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "nivel", desplazamiento, maxf(duracion, 0.01))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Vuelve al nivel de partida
func restaurar_nivel(duracion: float = 2.0) -> void:
	cambiar_nivel(0.0, duracion)
