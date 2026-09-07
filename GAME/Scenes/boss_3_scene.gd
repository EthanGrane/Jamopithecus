extends Node2D

var boss_start : bool = false
var velocidad := 270.0
var change_velocity := false
func empezar():
	boss_start = true

func _process(delta: float) -> void:
	if boss_start:
		$Path2D/PathFollow2D.progress += velocidad * delta


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Boss_3"):
		if change_velocity:
			velocidad = 270.0
		else:
			velocidad = 50.0


func _on_area_2d_2_body_entered(body: Node2D) -> void:
	var puertas = get_tree().get_nodes_in_group("Mosca")
	if puertas.size() > 0:
		var door2 = puertas[0]
		if door2.has_method("eliminate"):
			door2.eliminate()


func _on_boss_intro_intro_terminada() -> void:
	boss_start = true
	$Path2D/PathFollow2D/StaticBody2D.walka()


func _on_area_2d_3_body_entered(body: Node2D) -> void:
	print("works")
	get_tree().reload_current_scene()

func got_damage():
	velocidad = 600.0
	$Timer.start()



func _on_timer_timeout() -> void:
	velocidad = 270
