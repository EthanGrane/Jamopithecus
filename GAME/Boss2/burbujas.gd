##
##	Summary:
##	Burbuja que sale de una tubería y hace daño al tocarla.
##	Es un Area2D en el grupo "enemy": no empuja ni sirve de plataforma,
##	solo hay que esquivarla. Se borra sola al agotar su vida.
##

extends Area2D

var velocidad : Vector2 = Vector2.ZERO
var vida : float = 3.0
var bamboleo : float = 0.0      # cuánto serpentea
var frecuencia : float = 4.0
var tiempo : float = 0.0
var perpendicular : Vector2 = Vector2.ZERO


func lanzar(punto: Vector2, direccion: Vector2, vel: float, duracion: float, serpenteo: float = 20.0) -> void:
	global_position = punto
	velocidad = direccion.normalized() * vel
	vida = duracion
	bamboleo = serpenteo

	# La dirección en la que se bambolea es perpendicular a su avance
	perpendicular = velocidad.normalized().orthogonal()

	# Aparece creciendo, que si no salen de la nada
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	tiempo += delta

	# Avance + un serpenteo lateral suave, para que no vayan en línea recta
	var desvio := perpendicular * sin(tiempo * frecuencia) * bamboleo
	global_position += (velocidad + desvio) * delta

	vida -= delta
	if vida <= 0.0:
		reventar()


func reventar() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# Al tocar al jugador la burbuja estalla. El daño lo gestiona
# el propio jugador, que detecta las áreas del grupo "enemy"
func _on_body_entered(body: Node2D) -> void:
	if body is player:
		reventar()
