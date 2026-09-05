extends CharacterBody2D
class_name Boss1
enum state {movement, damage}
var current_state : state = state.movement
var max_velocity := 600.0
var current_velocity : float
var timer = 3.0
var rotate_velocity := 10.0
var last_pipe = 0
var tp_to_position : Vector2
var direction := 1.0
var diference := Vector2(-200.0,0.0)
@export var pipe_list : Array[pipe]



func _ready() -> void:
	current_velocity = randf_range(max_velocity - 100.0, max_velocity)

func _physics_process(delta: float) -> void:
	movement_gravity(delta)
	move_and_slide()
func Tp_to_random_pipe(current_pipe : int):
	print("hey")
	var pipe_n = randi_range(1,4)
	if pipe_n == current_pipe:
		Tp_to_random_pipe(current_pipe)
	else:
		velocity = Vector2.ZERO
		match pipe_n:
			1:
				direction = 1.0
				position = pipe_list[0].position
			2:
				direction = 1.0
				position = pipe_list[1].position

			3: 
				direction = -1.0
				position = pipe_list[2].position + diference

			4: 
				direction = 1.0
				position = pipe_list[3].position + diference

		print(global_position)
func movement_gravity(delta):
	if current_state == state.movement:
		velocity.x = current_velocity * direction
		if not is_on_floor():
			$Sprite2D.rotation += 5.0 * delta
		else:
			$Sprite2D.rotation += 10.0 * delta
	else:
		velocity = Vector2.ZERO
		timer -= delta
		if timer <= 0:
			current_state = state.movement
	if not is_on_floor():
		velocity.y = 1000.0
func change_state():
	print("hola")
	timer = 3.0
	current_state = state.damage
	velocity = Vector2.ZERO
	movement_gravity(0.0)
