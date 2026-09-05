##
##	Summary:
##	Es un hitbox de daño, si un body que contiene 
##	HealthCompoenent entra a la hitbox se le restara ? vida
##

extends Area2D
class_name HitboxComponent
var can_take_damage = true
var invulnerability_time := 1.0
@export var health_component : HealthComponent
@export var damage_amount : int = 1

func onTakeDamage():
	var parent = get_parent()
	parent.change_state()
	print("ocurre")


func _on_area_entered(area: Area2D) -> void:
	pass
