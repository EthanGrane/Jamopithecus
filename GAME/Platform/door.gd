extends StaticBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _on_area_2d_area_entered(area: Area2D) -> void:
	$Area2D.queue_free()
	var tween := create_tween()
	tween.tween_property(self,"position:y",500, 4.0)
