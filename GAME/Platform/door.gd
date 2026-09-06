extends StaticBody2D

@export var Door_position : Vector2 = Vector2(0.0,0.0)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area2D.position += Door_position

func _on_area_2d_area_entered(area: Area2D) -> void:
	$Area2D.queue_free()
	var tween := create_tween()
	tween.tween_property(self,"position:y",500, 4.0)
