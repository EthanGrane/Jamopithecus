##
##	Summary:
##	Tubería base. Es la del Boss1: el boss entra por su boca
##	y sale por otra.
##
##	Sabe avisar antes de que algo salga por ella: tiembla cada vez
##	más fuerte y luego estalla. Lo usan tanto el Boss1 (antes de
##	asomar) como el Boss2 (antes de escupir el chorro).
##
##	Se registra sola en el grupo "pipes", así que el boss no
##	necesita ninguna lista.
##

@tool
extends StaticBody2D
class_name Pipe

# Desplazamiento de la boca respecto a donde esté puesta en la escena.
# Sirve para ajustar una instancia concreta sin activar "hijos editables"
@export var area_position : Vector2 = Vector2.ZERO

# Marca esto si la tubería escupe hacia el lado contrario del que debería
@export var invertir_direccion : bool = false

@export_group("Aviso")
@export var duracion_del_aviso : float = 1.0   # cuánto tiembla antes de que salga algo
@export var sacudida_vertical : float = 12.0   # píxeles arriba y abajo, al final
@export var sacudida_rotacion : float = 6.0    # grados, al final
@export var velocidad_del_temblor : float = 26.0
# Cuanto más alto, más tarda en notarse y más brusco es el final.
# 1 = crece de forma plana, 3 = casi no se mueve hasta el último tercio
@export_range(1.0, 5.0) var curva_del_temblor : float = 2.5

@export_group("Punch")
# Algo SALE: la tubería se estira a lo ancho, como un escupitajo
@export var escala_del_estallido : Vector2 = Vector2(1.25, 0.78)
@export var duracion_del_estallido : float = 0.25
# Algo ENTRA: se estrecha bastante a lo ancho y se estira solo un
# poco a lo alto. Si el estirado fuera tan grande como el encogido,
# parecería que se hincha; así se lee como que absorbe
@export var escala_al_tragar : Vector2 = Vector2(0.72, 1.08)
@export var duracion_al_tragar : float = 0.28

@onready var sprite : NinePatchRect = $Sprite2D
@onready var boca : CollisionShape2D = $Area2D/CollisionShape2D

var posicion_original : Vector2 = Vector2.ZERO
var rotacion_original : float = 0.0
var escala_base_sprite : Vector2 = Vector2.ONE

var avisando : bool = false
var tiempo_restante : float = 0.0
var duracion_actual : float = 1.0
var fase : float = 0.0
var tween_sprite : Tween = null


func _ready() -> void:
	# En el editor no tocamos la escena: si moviéramos la boca aquí,
	# se desplazaría un poco más cada vez que abres la escena
	if Engine.is_editor_hint():
		return

	add_to_group("pipes")
	boca.position += area_position

	posicion_original = position
	rotacion_original = rotation
	escala_base_sprite = sprite.scale
	set_process(false)


# Dónde está la boca en coordenadas locales.
# En el editor el area_position aún no se ha sumado, en el juego sí
func boca_local() -> Vector2:
	if Engine.is_editor_hint():
		return boca.position + area_position
	return boca.position


# Dónde aparece el boss al salir por aquí
func punto_de_salida() -> Vector2:
	return boca.global_position


# 1 hacia la derecha, -1 hacia la izquierda
func direccion_salida() -> float:
	var dir := signf(global_scale.x)
	if dir == 0.0:
		dir = 1.0
	return -dir if invertir_direccion else dir


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Boss1:
		body.entrar_en_tuberia(self)


# ---------------------------------------------------------------
#  Aviso: tiembla cada vez más hasta que estalla
# ---------------------------------------------------------------

# Devuelve cuánto va a durar, para que quien la llame sepa cuánto esperar
func avisar() -> float:
	duracion_actual = maxf(duracion_del_aviso, 0.05)

	tiempo_restante = duracion_actual
	fase = 0.0
	avisando = true
	set_process(true)

	return duracion_actual


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not avisando:
		return

	tiempo_restante -= delta
	if tiempo_restante <= 0.0:
		terminar_aviso()
		return

	# avance va de 0 a 1 a lo largo del aviso
	var avance := 1.0 - (tiempo_restante / duracion_actual)

	# La curva es lo que hace que sea progresivo de verdad: al principio
	# casi ni se mueve y en el último tramo se desboca
	var intensidad := pow(avance, curva_del_temblor)

	# La fase se acumula en vez de calcularse desde cero. Si no,
	# al subir la velocidad el temblor daría saltos en vez de acelerar
	fase += delta * velocidad_del_temblor * (0.4 + intensidad * 2.0)

	position = posicion_original + Vector2(0.0, sin(fase) * sacudida_vertical * intensidad)
	rotation = rotacion_original + deg_to_rad(sin(fase * 0.7) * sacudida_rotacion * intensidad)


func terminar_aviso() -> void:
	avisando = false
	position = posicion_original
	rotation = rotacion_original
	set_process(false)


# El golpe seco del momento en que sale algo
func estallar() -> void:
	terminar_aviso()   # deja de temblar y vuelve a su sitio
	punch(escala_del_estallido, duracion_del_estallido)


# Se encoge a lo ancho: acaba de entrar algo por aquí
func tragar() -> void:
	punch(escala_al_tragar, duracion_al_tragar)


# Deforma el sprite de golpe y lo deja volver con un rebote elástico
func punch(escala: Vector2, duracion: float) -> void:
	if sprite == null:
		return

	# Si se solapan dos punches, el segundo arrancaría desde una
	# escala a medias y la tubería se quedaría deformada
	if tween_sprite != null and tween_sprite.is_valid():
		tween_sprite.kill()

	sprite.scale = escala_base_sprite * escala

	tween_sprite = create_tween()
	tween_sprite.tween_property(sprite, "scale", escala_base_sprite, duracion)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
