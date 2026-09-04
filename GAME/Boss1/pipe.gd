extends StaticBody2D
class_name pipe
@export var pipe_n : int
@export var area_position : Vector2 = Vector2(0.0,0.0)
func _ready() -> void:
	$Area2D/CollisionShape2D.position = area_position
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("Tp_to_random_pipe"):
		body.Tp_to_random_pipe(pipe_n)
