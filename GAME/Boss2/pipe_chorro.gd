##
##	Summary:
##	La tubería del Boss2. Hereda de Pipe (de ahí saca el aviso que
##	tiembla y el estallido) y le añade el chorro.
##
##	El peligro NO son las burbujas: es la ZonaDeMuerte, un Area2D
##	que se enciende y se apaga. Las burbujas son solo el adorno
##	que te dice que está encendida.
##

@tool
extends Pipe
class_name PipeChorro

@export_group("Zona de muerte")
@export var largo_de_la_zona : float = 420.0   # cuánto alcanza el chorro
@export var ancho_de_la_zona : float = 110.0
# Se dibuja en el editor para que puedas ajustarla viéndola
@export var mostrar_zona : bool = true
@export var color_zona : Color = Color(1.0, 0.25, 0.25, 0.22)

@onready var zona : Area2D = $ZonaDeMuerte
@onready var zona_forma : CollisionShape2D = $ZonaDeMuerte/CollisionShape2D
@onready var burbujas : CPUParticles2D = $ZonaDeMuerte/Burbujas


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
