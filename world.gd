extends Node2D

var decoy_unlocked := true
var can_create_decoy := true
var decoy_time := 0.0
@onready var decoy = preload("res://GAME/Player/PlayerAttack/decoy.tscn")
@export var the_player : player

func _ready() -> void:
	pass # Replace with function body.
func _process(delta: float) -> void:
	if  decoy_time > 0:
		decoy_time -= delta
		if decoy_time <= 0:
			can_create_decoy = true

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Decoy") and can_create_decoy and decoy_unlocked:
		var create_decoy = decoy.instantiate()
		add_child(create_decoy)
		create_decoy.position = the_player.position
		create_decoy.tree_exited.connect(on_detroid_exited)
		can_create_decoy = false

func on_detroid_exited():
	decoy_time = 3.0
	
