##
##	Summary:
##	La tubería del Boss2. Hereda de Pipe (de ahí saca el aviso que
##	tiembla y el estallido) y le añade el chorro.
##
##	La zona NO mata: es un trampolín. Al entrar te da un impulso
##	seco hacia arriba, como un salto muy fuerte, y a partir de ahí
##	caes con tu gravedad normal. Es una herramienta, no un peligro.
##

@tool
extends Pipe
class_name PipeChorro

@export_group("Zona del géiser")
@export var largo_de_la_zona : float = 420.0   # cuánto alcanza el chorro
@export var ancho_de_la_zona : float = 110.0
# El impulso que te pega al entrar, en la dirección de la tubería.
# Es de una sola vez: entras, sales disparado y luego caes normal
@export var impulso_del_geiser : float = 1300.0
# Se dibuja en el editor para que puedas ajustarla viéndola
@export var mostrar_zona : bool = true
@export var color_zona : Color = Color(0.35, 0.8, 1.0, 0.22)

@onready var zona : Area2D = $ZonaDeMuerte
@onready var zona_forma : CollisionShape2D = $ZonaDeMuerte/CollisionShape2D
@onready var burbujas : CPUParticles2D = $ZonaDeMuerte/Burbujas

var dentro : Array = []   # quién estaba dentro del géiser el frame anterior


func _ready() -> void:
	super._ready()   # grupo "pipes", offset de la boca y datos del aviso

	if Engine.is_editor_hint():
		set_process(true)   # solo para refrescar el dibujo
		queue_redraw()
		return

	colocar_zona()
	activar_zona(false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	super._process(delta)   # el temblor del aviso


# El empuje va en físicas, no en _process: estamos tocando la
# velocidad de un CharacterBody2D
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not zona_activa():
		return

	empujar_al_jugador()


# Impulso de una sola vez POR ENTRADA. Comparamos con quién había
# dentro el frame anterior: los que acaban de entrar salen disparados,
# los que ya estaban no se reimpulsan. Si empujáramos cada frame
# sería un ascensor, no un trampolín
func empujar_al_jugador() -> void:
	for cuerpo in zona.get_overlapping_bodies():
		print("BODY DETECTADO: ", cuerpo.name)

		if cuerpo is player:
			print("PLAYER DETECTADO")
			var direccion := direccion_del_geiser()
			print("DIRECCION: ", direccion)
			cuerpo.empujar(direccion * impulso_del_geiser)

# De la boca hacia el centro de la zona: esa es la dirección en la
# que sopla, ya venga la tubería girada, escalada o espejada
func direccion_del_geiser() -> Vector2:
	return (to_global(centro_de_la_zona()) - to_global(boca_local())).normalized()


# ---------------------------------------------------------------
#  La zona de muerte
# ---------------------------------------------------------------

# El centro de la zona: nace en la boca y tira hacia -X local,
# que es hacia donde se abre la tubería
func centro_de_la_zona() -> Vector2:
	return boca_local() + Vector2(-largo_de_la_zona * 0.5, 0.0)


# La forma se crea aquí, en código, para que cada tubería tenga
# la suya y no compartan una sola entre todas las instancias
func colocar_zona() -> void:
	var forma := RectangleShape2D.new()
	forma.size = Vector2(largo_de_la_zona, ancho_de_la_zona)
	zona_forma.shape = forma
	zona_forma.position = centro_de_la_zona()

	burbujas.position = centro_de_la_zona()
	burbujas.emission_rect_extents = Vector2(largo_de_la_zona * 0.5, ancho_de_la_zona * 0.4)


func activar_zona(activa: bool) -> void:
	# La forma se activa en diferido: tocarla a mitad del paso
	# de físicas hace que Godot se queje
	zona_forma.set_deferred("disabled", not activa)
	burbujas.emitting = activa

	# Al apagarse se olvida de quién había dentro, para que el
	# siguiente chorro vuelva a impulsar a quien siga ahí
	if not activa:
		dentro.clear()

	if activa:
		estallar()


func zona_activa() -> bool:
	return not zona_forma.disabled


# ---------------------------------------------------------------
#  Dibujo de la zona en el editor
# ---------------------------------------------------------------

func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_zona:
		return

	var centro := centro_de_la_zona()
	var tam := Vector2(largo_de_la_zona, ancho_de_la_zona)
	var rect := Rect2(centro - tam * 0.5, tam)
	var borde := Color(color_zona.r, color_zona.g, color_zona.b, 0.9)

	# El relleno es exactamente el Area2D que mata
	draw_rect(rect, color_zona, true)
	draw_rect(rect, borde, false, 2.0)

	# Una flecha desde la boca hacia donde escupe, para ver el sentido
	# aunque hayas girado o espejado la tubería
	var boca_p := boca_local()
	var punta := boca_p + Vector2(-largo_de_la_zona, 0.0)

	draw_line(boca_p, punta, borde, 2.0)
	draw_circle(boca_p, 6.0, borde)
	draw_line(punta, punta + Vector2(24.0, -14.0), borde, 2.0)
	draw_line(punta, punta + Vector2(24.0, 14.0), borde, 2.0)
