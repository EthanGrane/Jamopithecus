extends Node2D

var boss_start : bool = true
var velocidad := 300.0
var change_velocity := false
func empezar():
	boss_start = true

func _process(delta: float) -> void:
	if boss_start:
		$Path2D/PathFollow2D.progress += velocidad * delta


func _on_area_2d_body_entered(body: Node2D) -> void:
	if change_velocity:
		velocidad = 300.0
	else:
		velocidad = 100.0


func _on_area_2d_2_body_entered(body: Node2D) -> void:
	var puertas = get_tree().get_nodes_in_group("Mosca")
	if puertas.size() > 0:
		var door2 = puertas[0]
		if door2.has_method("eliminate"):
			door2.eliminate()
