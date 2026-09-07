extends StaticBody2D
@onready var salud : HealthComponent = $HealthComponent
@onready var reaccion : HitReactionComponent = $HitReactionComponent

func _ready() -> void:
	call_deferred("ignorar_al_jugador")
	salud.invulnerable = false
func walk():
	$AnimatedSprite2D.play("Run")
func hurt():
	$AnimatedSprite2D.play("Hurt")
func _draw() -> void:
	pass



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
	var por_grupo := get_tree().get_first_node_in_group("player")
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
	$AnimatedSprite2D.play("Hurt")
	reaccion.reaccionar()
	$AnimatedSprite2D.animation_finished.connect(func(): $AnimatedSprite2D.play("Run"))
