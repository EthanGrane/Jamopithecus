##
##	Summary:
##	Boss1. Rueda sin parar por la sala, se mete por una tubería y sale
##	por otra. Al golpearle se queda aturdido y se vuelve inmortal;
##	solo vuelve a ser atacable después de pasar por una tubería.
##

extends CharacterBody2D
class_name Boss1

enum Estado {
	RODANDO,    # va a lo suyo, rebotando por la sala
	ATURDIDO,   # le han dado: quieto, sin colisiones y sin poder recibir más
}

@export_group("Movimiento")
@export var velocidad_min : float = 500.0
@export var velocidad_max : float = 600.0
@export var gravedad : float = 1800.0
@export var velocidad_maxima_de_caida : float = 1000.0
@export var giro_en_suelo : float = 10.0   # vueltas del sprite al rodar
@export var giro_en_aire : float = 5.0

@export_group("Tuberías")
@export var distancia_de_salida : float = 60.0   # px que sale por delante de la boca
@export var tiempo_entre_tuberias : float = 0.4  # evita el bucle de entrar y salir sin fin

@export_group("Aturdimiento")
@export var tiempo_aturdido : float = 1.5
@export var escala_del_golpe : Vector2 = Vector2(1.35, 0.65)  # el squash del punch
@export var duracion_del_golpe : float = 0.25

@export_group("Gamefeel del golpe")
@export var hitstop : float = 0.08          # cuánto se congela el juego
@export var sacudida_fuerza : float = 12.0
@export var sacudida_duracion : float = 0.30
@export var destello_duracion : float = 0.12

@export_group("Onda de choque")
@export var onda_al_golpear : bool = true
@export var onda_radio : float = 320.0
@export var onda_fuerza : float = 28.0
@export var onda_duracion : float = 0.40

var estado : Estado = Estado.RODANDO
var direccion : float = 1.0
var velocidad : float = 0.0
var contador_aturdido : float = 0.0
var cooldown_tuberia : float = 0.0
var ultima_tuberia : Pipe = null
var capa_original : int = 0
var escala_base : Vector2 = Vector2.ONE

@onready var sprite : Sprite2D = $Sprite2D
@onready var salud : HealthComponent = $HealthComponent


func _ready() -> void:
	capa_original = collision_layer
	escala_base = sprite.scale
	velocidad = randf_range(velocidad_min, velocidad_max)
	direccion = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	cooldown_tuberia -= delta

	match estado:
		Estado.RODANDO:
			rodar(delta)
		Estado.ATURDIDO:
			estar_aturdido(delta)

	aplicar_gravedad(delta)
	move_and_slide()

	# Si choca con una pared se da la vuelta y sigue rodando
	if estado == Estado.RODANDO and is_on_wall():
		direccion = -direccion


# ---------------------------------------------------------------
#  Rodar
# ---------------------------------------------------------------

func rodar(delta: float) -> void:
	velocity.x = velocidad * direccion
	# El sprite gira hacia donde avanza, no siempre al mismo lado
	var giro = giro_en_suelo if is_on_floor() else giro_en_aire
	sprite.rotation += giro * direccion * delta


func aplicar_gravedad(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravedad * delta, velocidad_maxima_de_caida)


# ---------------------------------------------------------------
#  Tuberías
# ---------------------------------------------------------------

# La llama la propia tubería cuando el boss entra en su boca
func entrar_en_tuberia(entrada: Pipe) -> void:
	if estado == Estado.ATURDIDO or cooldown_tuberia > 0.0:
		return

	var destino := elegir_otra_tuberia(entrada)
	if destino == null:
		return

	direccion = destino.direccion_salida()

	# Aparece un poco por delante de la boca, mirando hacia fuera.
	# Si saliera justo encima volvería a entrar en su propia área
	global_position = destino.punto_de_salida() + Vector2(direccion * distancia_de_salida, 0.0)
	velocity = Vector2.ZERO

	ultima_tuberia = destino
	cooldown_tuberia = tiempo_entre_tuberias

	# Sale de la tubería volviendo a ser atacable
	volver_a_ser_vulnerable()


func elegir_otra_tuberia(entrada: Pipe) -> Pipe:
	var todas := get_tree().get_nodes_in_group("pipes")
	var candidatas : Array[Pipe] = []

	# Ni la que acaba de pisar ni la última por la que salió
	for t in todas:
		if t != entrada and t != ultima_tuberia:
			candidatas.append(t)

	# Si con eso no queda ninguna, relajamos y vale cualquiera menos la de entrada
	if candidatas.is_empty():
		for t in todas:
			if t != entrada:
				candidatas.append(t)

	if candidatas.is_empty():
		push_warning("Boss1: no hay otra tubería en el grupo 'pipes'")
		return null

	return candidatas[randi() % candidatas.size()]


# ---------------------------------------------------------------
#  Aturdimiento
# ---------------------------------------------------------------

# La llama el HealthComponent al recibir un golpe.
# Mantengo el nombre para no romper nada de lo que ya tienes
func change_state() -> void:
	if estado == Estado.ATURDIDO:
		return
	aturdir()


func aturdir() -> void:
	estado = Estado.ATURDIDO
	contador_aturdido = tiempo_aturdido
	velocity = Vector2.ZERO

	# Inmortal hasta que pase por una tubería
	salud.invulnerable = true

	# Sin colisiones. Se quita la CAPA y no la máscara: así el jugador
	# y la lanza dejan de detectarlo, pero él sigue apoyado en el suelo
	set_deferred("collision_layer", 0)

	# El orden importa poco, pero así se lee: primero lo que se ve
	# encima del boss, luego lo que afecta a toda la pantalla
	destello()
	golpe_de_escala()
	lanzar_onda()
	GameFeel.golpe(hitstop, sacudida_fuerza, sacudida_duracion)


func estar_aturdido(delta: float) -> void:
	velocity.x = 0.0
	contador_aturdido -= delta
	if contador_aturdido <= 0.0:
		terminar_aturdimiento()


func terminar_aturdimiento() -> void:
	estado = Estado.RODANDO
	set_deferred("collision_layer", capa_original)
	# Ojo: sigue siendo inmortal. Solo se cura pasando por una tubería


func volver_a_ser_vulnerable() -> void:
	salud.invulnerable = false


# La onda cuelga de la escena, no del boss: si el golpe lo mata,
# el boss se borra pero la onda termina de expandirse igual
func lanzar_onda() -> void:
	if not onda_al_golpear:
		return

	Shockwave.crear(
		get_tree().current_scene,
		global_position,
		onda_radio,
		onda_fuerza,
		onda_duracion
	)


# Destello blanco. Necesita el hit_flash.gdshader en el material del Sprite2D
func destello() -> void:
	if sprite.material == null:
		return

	_poner_blanco(1.0)
	var tw := create_tween()
	tw.tween_method(_poner_blanco, 1.0, 0.0, destello_duracion)


func _poner_blanco(valor: float) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blanco", valor)


# El punch: se aplasta de golpe y vuelve a su escala con un rebote
func golpe_de_escala() -> void:
	sprite.scale = escala_base * escala_del_golpe

	var tw := create_tween()
	tw.tween_property(sprite, "scale", escala_base, duracion_del_golpe)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
