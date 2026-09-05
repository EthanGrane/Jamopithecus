##
##	Summary:
##	Onda de choque de un solo uso. Se crea, se expande y se borra sola.
##
##	Uso rápido desde cualquier sitio:
##		Shockwave.crear(get_tree().current_scene, global_position)
##

extends ColorRect
class_name Shockwave

const ESCENA := "res://GAME/VFX/shockwave.tscn"

@export var duracion : float = 0.45
@export var radio_maximo : float = 300.0   # en píxeles
@export var fuerza : float = 24.0          # px que desplaza la imagen
@export var grosor : float = 0.08          # ancho del anillo
@export var auto_destruir : bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poner_progreso(0.0)


# Crea una onda en un punto del mundo y la lanza.
# Los tres últimos son opcionales: con 0 se usan los valores de la escena
static func crear(padre: Node, punto: Vector2, radio := 0.0, potencia := 0.0, dur := 0.0) -> Shockwave:
	var onda : Shockwave = load(ESCENA).instantiate()

	if radio > 0.0:
		onda.radio_maximo = radio
	if potencia > 0.0:
		onda.fuerza = potencia
	if dur > 0.0:
		onda.duracion = dur

	padre.add_child(onda)
	onda.lanzar(punto)
	return onda


func lanzar(punto: Vector2) -> void:
	# El rect se hace cuadrado y se centra en el punto del impacto
	size = Vector2.ONE * radio_maximo * 2.0
	global_position = punto - size * 0.5

	var mat := material as ShaderMaterial
	if mat == null:
		push_error("Shockwave: falta el ShaderMaterial")
		return

	mat.set_shader_parameter("fuerza", fuerza)
	mat.set_shader_parameter("grosor", grosor)

	var tw := create_tween()
	tw.tween_method(_poner_progreso, 0.0, 1.0, duracion)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if auto_destruir:
		tw.tween_callback(queue_free)


func _poner_progreso(valor: float) -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("progreso", valor)
