extends Node2D

@export var pipes : Array[Pipe]
@export var bubles_distances := 300.0
@onready var burbujas := preload("res://GAME/Boss2/burbujas.tscn")
var direction : Vector2
var current_pipe : int
var n_bubles : int
func _ready() -> void:
	$Timer.start()
	
func lanzar_burbujas():
	var real_bubles = burbujas.instantiate()
	add_child(real_bubles)
	real_bubles.mover_burbujas(direction, bubles_distances, pipes[current_pipe].position)
func chose_pipe():
	current_pipe = randi_range(0,2)
	n_bubles = randf_range(3, 7)
	for i in range(n_bubles):
		#match current_pipe:
			#0: direction = Vector2(1.0, randf_range(-1.0,1.0))
			#1: direction = Vector2(randf_range(-1.0,1.0), -1.0)
			#2: direction = Vector2(randf_range(-1.0,1.0), -1.0)
		direction = Vector2(randf_range(-1.0,1.0), -1.0)
		lanzar_burbujas()




func _on_timer_timeout() -> void:
	$Timer.wait_time = randf_range(0.8,1.4)
	chose_pipe()
