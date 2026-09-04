##
##	Summary:
##	Es un hitbox de daño, si un body que contiene 
##	HealthCompoenent entra a la hitbox se le restara ? vida
##

extends Area2D
class_name HitboxComponent

@export var damage_amount : int = 1

func _on_body_entered(body: Node2D) -> void:
	var health_component = body.get_node_or_null("HealthComponent")
	if health_component:
		health_component.take_damage(damage_amount)
