extends Node2D
class_name HealthComponent

@export var max_health : int = 3	# es un int porq se mide por hits (1 de vida = 1 hit)
var current_health

# Mientras esté a true, los golpes no hacen nada.
# El Boss1 la usa para volverse inmortal tras un golpe
var invulnerable : bool = false


signal on_health_changed(current_health: int)


func _ready() -> void:
	current_health = max_health

func take_damage(amount : int) -> void:
	if invulnerable:
		return
	var padre := get_parent()
	if padre and padre.has_method("damage"):
		print("ahhhh")
		padre.damage()
	current_health = clampi(current_health - amount, 0, max_health)	#clamp capa los valores, en este caso entre 0 y vida maxima
	on_health_changed.emit(current_health)
	if current_health <= 0:
		if get_parent() is Boss3:
			get_tree().change_scene_to_file("res://GAME/Scenes/final_bueno.tscn")
			return
		get_parent().queue_free()
	print("Take Damage")
	print(current_health)
	onTakeDamage()

func onTakeDamage():
	var padre := get_parent()
	if padre and padre.has_method("change_state"):
		padre.change_state()
