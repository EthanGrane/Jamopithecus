class_name Boss3 extends StaticBody2D
@onready var salud : HealthComponent = $HealthComponent
@onready var reaccion : HitReactionComponent = $HitReactionComponent

func _ready() -> void:
	call_deferred("ignorar_al_jugador")
	salud.invulnerable = false
	$AnimatedSprite2D.flip_h = true
func walk():
	$AnimatedSprite2D.play("Run")
func hurt():
	$AnimatedSprite2D.play("Hurt")




# Le dice al motor que estos dos cuerpos no chocan entre sí, sin
# tocar capas ni máscaras. Se pone en los dos lados por si acaso
func ignorar_al_jugador() -> void:
	var jugador := buscar_jugador()
	if jugador == null:
		push_warning("Boss1: no encuentro al jugador para ignorar su colisión")
		return

	add_collision_exception_with(jugador)
	jugador.add_collision_exception_with(self)

func buscar_jugador() -> PhysicsBody2D:
	# Primero por grupo, que es lo barato
	var por_grupo := get_tree().get_first_node_in_group("Mosca")
	if por_grupo is PhysicsBody2D:
		return por_grupo

	# Y si no está en el grupo, lo buscamos por su clase
	return buscar_por_clase(get_tree().current_scene)


func buscar_por_clase(nodo: Node) -> PhysicsBody2D:
	if nodo == null:
		return null
	if nodo is player:
		return nodo

	for hijo in nodo.get_children():
		var encontrado := buscar_por_clase(hijo)
		if encontrado != null:
			return encontrado

	return null
	
func damage():
	if get_parent().has_method("got_damaged"):
		get_parent().got_damaged()
	$AnimatedSprite2D.play("Hurt")
	reaccion.reaccionar()
	$AnimatedSprite2D.animation_finished.connect(func(): $AnimatedSprite2D.play("Run"))

func walka():
	$AnimatedSprite2D.flip_h = false
	$AnimatedSprite2D.play("Run")
