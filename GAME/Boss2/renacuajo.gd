extends StaticBody2D
class_name Boss2
enum state {movement, damage}
@onready var burbujas := preload("res://GAME/Boss2/burbujas.tscn")
@export var _player : player
var current_state : state = state.movement
var velocidad := 100.0
var x_position : float = 100.0
var tween : Tween
var bubles_distances := 400.0
var attack_position : float = 220
var direction : Vector2
func _ready() -> void:
	_on_timer_timeout()
	$Timer.start()
func _physics_process(delta: float) -> void:
	pass
	
func subir():
	var posicion_inicial : float = position.y
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position", Vector2(position.x,attack_position) , randf_range(1.4, 2.5))
	tween.parallel().tween_callback(atacar).set_delay(1.8)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.chain()
	tween.tween_property(self,"position", Vector2(position.x,posicion_inicial) , randf_range(0.8, 1.6))
func set_position_x():
	match randi_range(0,3):
		0: x_position = 70.0
		1: x_position = 400.0
		2: x_position = 770.0
		3: x_position = 1070.0
	global_position.x = x_position
func _on_timer_timeout() -> void:
	set_position_x()
	subir()
func atacar():
	print("ejecuta")
	for i in range(randi_range(3,5)):
		if global_position.x < _player.global_position.x:
			direction = Vector2(1.0,randf_range(-1.0,0.6))
		else:
			direction = Vector2(-1.0,randf_range(-1.0,0.6))
		var real_bubles = burbujas.instantiate()
		add_child(real_bubles)
		real_bubles.mover_burbujas(direction, bubles_distances, self.global_position)
