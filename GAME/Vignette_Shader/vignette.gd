@tool
extends CanvasLayer
class_name Vignette

@export_group("Settings")

@export var colorRect: ColorRect

@export var center: Vector2 = Vector2(0.5, 0.5):
	set(value):
		center = value
		update_shader()

@export_range(0.0, 1.0) var radius: float = 0.5:
	set(value):
		radius = value
		update_shader()

@export var vignetteColor: Color = Color.BLACK:
	set(value):
		vignetteColor = value
		update_shader()


func _ready() -> void:
	add_to_group("Vignette")
	update_shader()


func update_shader() -> void:
	if not colorRect:
		return

	var shader_material := colorRect.material as ShaderMaterial
	
	if shader_material:
		shader_material.set_shader_parameter("circle_position", center)
		shader_material.set_shader_parameter("radius", radius)
		shader_material.set_shader_parameter("circle_color", vignetteColor)
