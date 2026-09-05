extends StaticBody2D


func mover_burbujas(direccion : Vector2, distancia : float, pipe_position : Vector2):
	global_position = pipe_position
	print(global_position)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position", position + direccion.normalized() * distancia * randf_range(1.0, 1.5), randf_range(1.4,2.2))
	tween.tween_callback(queue_free)
