extends Control
@onready var label: Label = $Label
var n_dialogue := 0
var timer : Timer
var text := [
	{"texto" : "7/09/2026 en lo mas profundo de las alcantarillas", "imagen" : preload("res://GAME/Scenes/Into_scene/Tuberias.png")},
	{"texto" : "Habia una mosca llamada tilin volando de lo mas feliz, comiendo basura como de costumbre", "imagen" : preload("res://GAME/Scenes/Into_scene/Basura.png")},
	{"texto" : "Pero ese dia todo cambio", "imagen" : preload("res://GAME/Scenes/Into_scene/Basura.png")},
	{"texto" : "Una rana de lanzo su lengua, arrevatandole sus preciadas alas", "imagen" : preload("res://GAME/Scenes/Into_scene/Rana.png")},
	{"texto" : "Esta es la historia trata sobre la venganza de Tilin", "imagen" : preload("res://GAME/Scenes/Into_scene/Tilin1.png")}
]



func _ready() -> void:
	process_dialogue()
	
func process_dialogue():
	label.visible_ratio = 0
	label.text = text[n_dialogue].texto
	$Sprite2D.texture = text[n_dialogue].imagen
	var read_time = float(label.text.length() / 14.0)
	var tween : Tween
	tween = create_tween()
	tween.tween_property(label,"visible_ratio",1.0,read_time)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	if n_dialogue < text.size() - 1:
		n_dialogue += 1
		process_dialogue()
	else:
		get_tree().change_scene_to_file("res://GAME/Player/TEST.tscn")
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://GAME/Player/TEST.tscn")
