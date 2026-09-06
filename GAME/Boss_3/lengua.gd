extends StaticBody2D

#@onready var get_player := get_tree().get_first_node_in_group("Mosca")
@onready var tonge: NinePatchRect = $NinePatchRect
@onready var colision: CollisionShape2D = $Area2D/CollisionShape2D
@export var get_player : player
@export var tongue_reach_time := 1.0
var original_position : Vector2
var tonge_exist := false
var tween : Tween
func _ready() -> void:
	$Timer.start()


func _process(delta: float) -> void:
	if not tonge_exist:
		tonge.rotation = (get_player.position - position).normalized().angle()
		colision.rotation = (get_player.global_position - global_position).normalized().angle()

func drow_tongue():
	original_position = global_position
	var distance = global_position.distance_to(get_player.global_position)
	var scale_x = distance /  tonge.texture.get_width()
	if tween:
		tween.kill()
	tonge_exist = true
	tween = create_tween()
	tween.set_parallel()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tonge,"scale:x",scale_x, tongue_reach_time)
	tween.tween_property(colision.shape,"scale:x",scale_x, tongue_reach_time)
	tween.chain()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tonge,"scale:x",1.0, tongue_reach_time / 3)
	tween.tween_callback(func(): tonge_exist = false)


func _on_timer_timeout() -> void:
	drow_tongue()
