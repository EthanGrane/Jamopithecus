extends Node2D

class_name music

func play_music(song : AudioStreamMP3):
	$AudioStreamPlayer.stream = song
	$AudioStreamPlayer.play()
	$AudioStreamPlayer.stream.loop = true
	$AudioStreamPlayer.volume_db = -8.0
