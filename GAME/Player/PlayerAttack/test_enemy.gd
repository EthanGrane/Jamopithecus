extends Node2D

@export var health_component : HealthComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_component.on_health_changed.connect(onTakeDamage)
	
func onTakeDamage():
	print("Hit")
