extends Node2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is player:
		GlobalMusic.play_music(preload("res://Extras/idea pachio (primer jefe).mp3"))
		get_tree().change_scene_to_file("res://GAME/Scenes/Boss_Battle_1.tscn")
