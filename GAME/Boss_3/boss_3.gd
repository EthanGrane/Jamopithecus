extends StaticBody2D

var tween : Tween
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func vuelta():
	$AnimationPlayer.play("Vuelta")
	
func volver_vuelta():
	$AnimationPlayer.play("volver_vuelta")
