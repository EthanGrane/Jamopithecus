extends Control
@onready var label: RichTextLabel = $Label
var n_dialogue := 0
var timer : Timer
var text := [
	{"texto" : "7/09/2026 en lo más profundo de las alcantarillas de la ciudad de Buenos aires", "imagen" : preload("res://GAME/Scenes/Into_scene/Tuberias.png")},
	{"texto" : "Había una mosca llamada Tilín, su vida era perfecta, ese día el estaba comiendo basura como de costumbre", "imagen" : preload("res://GAME/Scenes/Into_scene/Basura.png")},
	{"texto" : "Pero cometió el error de ser demasiado inocente y dar que su vida siempre sería feliz", "imagen" : preload("res://GAME/Scenes/Into_scene/Basura.png")},
	{"texto" : "Una rana le ataco con su lengua, arrevatandole sus preciadas alas", "imagen" : preload("res://GAME/Scenes/Into_scene/Rana.png")},
	{"texto" : "Tilín lo había perdido todo, ya no le quedaba ninguna razón para vivir. ¿Qué es una mosca sin sus alas? ", "imagen" : preload("res://GAME/Scenes/Into_scene/Rana.png")},
	{"texto" : "Pero aún le quedaba solo una cosa que hacer", "imagen" : preload("res://GAME/Scenes/Into_scene/Tilin1.png")},
	{"texto" : "[center][color=red][shake rate=30 level=12]Matar a esa puta Rana[/shake][color=red]", "imagen" : preload("res://GAME/Scenes/Into_scene/Tilin1.png")}
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
