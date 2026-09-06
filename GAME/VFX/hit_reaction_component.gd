##
##	Summary:
##	Todo lo que se ve y se oye cuando algo recibe un golpe:
##	sonido, destello blanco, punch de escala, onda de choque,
##	hitstop y sacudida de cámara.
##
##	NO decide nada: no aturde, no quita vida, no toca la
##	invulnerabilidad. Eso sigue siendo cosa de cada enemigo.
##
##	Uso:
##		$HitReactionComponent.reaccionar()
##
##	Cuélgalo como hijo del enemigo. Si no le asignas sprite,
##	busca un Sprite2D hermano.
##

extends Node2D
class_name HitReactionComponent

@export var sprite : Node2D   # vacío = busca un "Sprite2D" hermano

@export_group("Sonido")
@export var sonido : AudioStream
@export_range(-40.0, 12.0) var volumen : float = 0.0
@export var tono_min : float = 0.94   # variación para que no suene a copia
@export var tono_max : float = 1.06

@export_group("Destello")
# Necesita el hit_flash.gdshader en el material del sprite
@export var destello_duracion : float = 0.12

@export_group("Punch")
@export var escala_del_golpe : Vector2 = Vector2(1.35, 0.65)
@export var duracion_del_golpe : float = 0.25

@export_group("Onda de choque")
@export var lanzar_onda_al_golpear : bool = true
@export var onda_radio : float = 320.0
@export var onda_fuerza : float = 28.0
@export var onda_duracion : float = 0.40

@export_group("Pantalla")
@export var hitstop : float = 0.08
@export var sacudida_fuerza : float = 12.0
@export var sacudida_duracion : float = 0.30

var escala_base : Vector2 = Vector2.ONE
var tween_sprite : Tween = null


func _ready() -> void:
	if sprite == null:
		sprite = buscar_sprite()

	if sprite != null:
		escala_base = sprite.scale


func buscar_sprite() -> Node2D:
	var padre := get_parent()
	if padre == null:
		return null
	return padre.get_node_or_null("Sprite2D") as Node2D


# ---------------------------------------------------------------
#  Lo único que hay que llamar
# ---------------------------------------------------------------

func reaccionar() -> void:
	# Primero lo que pasa encima del enemigo, luego lo que
	# afecta a toda la pantalla
	GameFeel.sonar(sonido, global_position, volumen, tono_min, tono_max)
	destello()
	punch()
	onda()
	GameFeel.golpe(hitstop, sacudida_fuerza, sacudida_duracion)


# Deja el sprite como estaba. Útil si el enemigo desaparece a mitad
# de un punch y no quieres que reaparezca deformado o blanco
func restablecer() -> void:
	if sprite == null:
		return

	matar_tween()
	sprite.scale = escala_base
	poner_blanco(0.0)


# ---------------------------------------------------------------
#  Las piezas, por si alguna la quieres suelta
# ---------------------------------------------------------------

func destello() -> void:
	if sprite == null or sprite.material == null:
		return

	poner_blanco(1.0)
	var tw := create_tween()
	tw.tween_method(poner_blanco, 1.0, 0.0, destello_duracion)


func poner_blanco(valor: float) -> void:
	if sprite == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blanco", valor)


# Se aplasta de golpe y vuelve a su escala con un rebote
func punch() -> void:
	if sprite == null:
		return

	sprite.scale = escala_base * escala_del_golpe

	var tw := crear_tween_de_sprite()
	tw.tween_property(sprite, "scale", escala_base, duracion_del_golpe)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# La onda cuelga de la escena, no del enemigo: si el golpe lo mata,
# el enemigo se borra pero la onda termina de expandirse igual
func onda() -> void:
	if not lanzar_onda_al_golpear:
		return

	Shockwave.crear(
		get_tree().current_scene,
		global_position,
		onda_radio,
		onda_fuerza,
		onda_duracion
	)


# ---------------------------------------------------------------

# Este componente es el ÚNICO dueño del Tween que deforma el sprite.
# Si el enemigo quiere animar la escala por su cuenta (entrar en una
# tubería, por ejemplo), que pida el suyo por aquí: así nunca hay
# dos tweens peleándose por la misma propiedad
func crear_tween_de_sprite() -> Tween:
	matar_tween()
	tween_sprite = create_tween()
	return tween_sprite


func matar_tween() -> void:
	if tween_sprite != null and tween_sprite.is_valid():
		tween_sprite.kill()
