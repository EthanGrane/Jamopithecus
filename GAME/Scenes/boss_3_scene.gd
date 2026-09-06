extends Node2D

var boss_start : bool = true
var velocidad := 500.0
func empezar():
	boss_start = true

func _process(delta: float) -> void:
	if boss_start:
		$Path2D/PathFollow2D.progress += velocidad * delta
