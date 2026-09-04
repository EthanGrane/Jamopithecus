extends CharacterBody2D

@export var jump_height : float= 0.0
@export var jump_time_to_peak : float= 0.0
@export var jump_time_to_descent :float = 0.0
@export var jump_cut_multiplayer := 0.4
@onready var jump_speed : float = calculate_jump_speed(jump_height, jump_time_to_peak)
@onready var jump_gravity : float = calculate_jump_gravity(jump_height, jump_time_to_peak)
@onready var fall_gravity : float = calculate_fall_gravity(jump_height, jump_time_to_descent)

const coyote_jump := 0.1
const SPEED = 300.0
const JUMP_VELOCITY = -400.0




func _physics_process(delta: float) -> void:
	velocity.y += to_get_gravity()
	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_released("Salto") and not is_on_floor():
		velocity.y *= jump_cut_multiplayer
	var direction := signf(Input.get_axis("Left","Right"))
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func calculate_jump_speed(height : float, time_to_peak: float) -> float:
	return (-2.0 * height / time_to_peak)

func calculate_jump_gravity(height : float, time_to_peak: float) -> float:
	return (2.0 * height / pow(time_to_peak,2.0))

func calculate_fall_gravity(height : float, time_to_descent: float) -> float:
	return (2.0 * height / pow(time_to_descent,2.0))
	
func to_get_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity
	

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		print("mori")
